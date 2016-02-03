#!/usr/bin/python
from __future__ import print_function 
import argparse
import os
import sys
from subprocess import call
import logging
import config
from argparse import RawTextHelpFormatter
from config import path_sep
from step import Step
from db_exception import DbException
import datetime
 
supported_steps = []
supported_vendors = []


## Parse args procedure
def parse_args(base_dir):
	#Defining supported vendors
	global supported_vendors
	vendors_dir = base_dir + path_sep + "resources"
	supported_vendors = config.read_supported_vendors(vendors_dir)
	## create all available steps
	
	for vendor in supported_vendors:
		config_dir = base_dir + path_sep + "config" + path_sep + vendor
		current_steps = config.read_supported_steps(config_dir)
		for step in current_steps:
			if not step in supported_steps:
				supported_steps.append(step)
	
	## format strings	
	str_steps = os.linesep.join(supported_steps)
	str_vendors = os.linesep.join(supported_vendors)
	parser = argparse.ArgumentParser(description="run deployer to deploy/upgrade the supported database", formatter_class=RawTextHelpFormatter)
	parser.add_argument("-s","--step", help="The step to run :  " + os.linesep + str_steps , required=True)
	parser.add_argument("-c","--cloud", help="Supported vendors :" + os.linesep + str_vendors, required=True)
	parser.add_argument("-m", "--mode", help="Mode for the deployer to run: " + os.linesep +  "x : Use Properties.conf " + os.linesep + "i : Use interactive mode",type=config.is_mode_supported)
	parser.add_argument("-lvl", "--log_level",default=logging.INFO, help="log level to run: DEBUG,INFO,ERROR,WARN",type=config.is_level_supported)
	parser.add_argument("-d", "--dry_run",default=False,action='store_true' ,help="Specifying dry run only generates the scripts and not actually runs them")
	parser.add_argument("-l", "--log",default="{0}{1}log{1}".format(base_dir, path_sep), help="Logging dir output ( by default {0}{1}log{1}<step>_<vendor>_yyyymmdd_hhmm.log)".format(base_dir, path_sep))
	args = parser.parse_args()
	return args

def setup_logging(args,debug_level,log_name):
    # set file logger
    FORMAT = "%(asctime)s [%(levelname)-5.5s]  %(message)s"
    LEVEL = debug_level
    logging.basicConfig(filename=args.log + path_sep + log_name, level=LEVEL, format=FORMAT)
    # add console logger
    console = logging.StreamHandler(stream=sys.stdout)
    console.setLevel(LEVEL)
    formatter = logging.Formatter(FORMAT)
    console.setFormatter(formatter)
    logging.getLogger('').addHandler(console)


	
def main():
	#excluded_dirs = ["log","resources","conf"]
	# parse command-line arguments
	script_main_dir = os.path.dirname(os.path.realpath(__file__))
	args = parse_args(script_main_dir)
	#supported_vendors = config.read_supported_vendors(script_main_dir + path_sep + "config")
	os.environ["BASE_DIR"] = script_main_dir
	log_dir = args.log
	if not os.path.isdir(log_dir):
		os.mkdir(log_dir)

	step = args.step
	vendor = args.cloud
	mode = args.mode
	dry_run = args.dry_run
	# set logger
	dt = datetime.datetime.now()
	
	log_name = step + "_" + vendor + "_" + dt.strftime("%Y%m%d_%H%M") + ".log"
	setup_logging(args,args.log_level,log_name)
	
	#Check input
	if not config.is_configuration_supported(supported_vendors,vendor):
		logging.error("No support for provided 'cloud' value : {}".format(vendor))
		exit(1)
	elif not config.is_configuration_supported(supported_steps,step):
		logging.error("No support for provided 'step' value : {}".format(step))
		exit(1)

	full_log = 	log_dir  + log_name	
	logging.info("Starting running step : {} for vendor {} see log file : {} ".format(step,vendor,full_log))
	
	#Create step object
	current_step = Step(step,vendor,logging,script_main_dir,script_main_dir + path_sep + "config",script_main_dir + path_sep + "resources",mode)
	
	#Read the input data and verify it
	current_step.read_input_data()
	
	#Copy sources from source directory
	current_step.copy_sources()
	
	#Intialize the db components with all running necessary configs
	current_step.intialize_db_components()
	
	#Replace all placeholders accoridng to <db.compnenet.name>.plcholders file
	current_step.replace_placeholders()
	
	if dry_run:
		try:
			logging.info("Dry run instructions :")
			current_step.print_script_order()
		finally:
			logging.info("Finished running step : {} for vendor {} see log file : {}".format(step,vendor,full_log))
	else:
		try:
			# Execute Scripts
			current_step.run_sql_scripts()
		except DbException as e:
			logging.error("Running scripts for step {} failed with error : {}".format(step,e.value))
			exit(2)
		finally:
			logging.info("Finished running step : {} for vendor {} see log file : {}".format(step,vendor,full_log))
		#except Exception as e:	
		#	logging.error("Running scripts for step {} failed error {} ".format(step,e))
			
		#	exit(2)
		
if __name__ == "__main__":
    main()
	 
