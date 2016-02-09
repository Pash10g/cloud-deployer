#!/usr/bin/python
import argparse
import os
import sys
import subprocess
from subprocess import call
import logging
import re
from  db_exception import DbException

path_sep = os.path.sep

class ErrorHandle:
	def __init__(self,input_data):
		self.error_list = []
		self.ignored_error_list = []
		if re.search(",",input_data["error_list"]):
			self.error_list =  self.error_list + (input_data["error_list"].split(","))
		else:
			if not input_data["error_list"] == '':
				self.error_list.append(input_data["error_list"])
		if re.search(",",input_data["ignored_error_list"]):
			self.ignored_error_list=input_data["ignored_error_list"].split(",")
		else:
			if not input_data["error_list"] == '':
				self.ignored_error_list.append(input_data["ignored_error_list"])	
			
		self.num_of_retries = input_data["num_of_retries"] 
		
			
class Script:
	def __init__(self,database_mapping,script_file):
		self.database_mapping = database_mapping
		self.script_file = script_file 

def read_file_content(file_name):
	if os.path.exists(file_name):
		with open(file_name) as f:
			s = f.read()
	else:
		raise DbException("File {} is not found. so content cannot be retrieved".format(file_name))
	return s

def read_supported_vendors(resources_dir):
	return read_config_dirs(resources_dir)
	
def read_supported_steps(config_dir):
	return read_config_dirs(config_dir)

def is_configuration_supported(supported_config_obj,item):
	if item in supported_config_obj:
		return True
	else:
		return False
	

def read_config_dirs(resources_dir):
	if os.path.exists(resources_dir):
		all_dirs = os.listdir(resources_dir)
		all_dirs.sort()
		supported_dirs = []
		for dir in all_dirs:
			if not os.path.isfile(resources_dir + path_sep + dir):
					supported_dirs.append(dir)
	else:
		raise DbException("folder {} was not found".format(resources_dir))
	
	return supported_dirs


def rec_param_holders(string):	
	util_params = []
	param_array = string.split("]]")
	for util_section in param_array:
		util_param = util_section.strip()
		if util_section.find("[[") > -1:
  			temp_param = util_param.split("[[")
  			if len(temp_param) > 1:
  				util_param = temp_param[1]
  			else:
  				util_param = temp_param[0]
  			util_params.append(util_param)
            
	return util_params
    
def replace_string_params(string,params):             
	
	for param in params:
		value = os.environ.get(param)
		if value:
			string = string.replace("[[" + param + "]]",value)
		else:
			string = ''
		              
	return string
                
def get_map_input(prefix,param_name,step_config_full_file,mode):
	param_ret = {}
	if re.search("^pass", prefix):
		param_value = os.environ.get(param_name)
		if param_value == None or param_value == "":
			raise argparse.ArgumentTypeError("%s is not provided and it is mandatory " % param_name)
		#param_value = replace_string_params(param_value,rec_param_holders(param_value))
		#os.environ[param_name] = param_value
		logging.debug("-{} : {}".format(param_name,param_value))
		param_ret = {param_name:param_value}
	elif re.search("^param", prefix):
		param_value = os.environ.get(param_name)
		if param_value == None or param_value == "":
			raise argparse.ArgumentTypeError("%s is not provided and it is mandatory " % param_name)
		#param_value = replace_string_params(param_value,rec_param_holders(param_value))
		#os.environ[param_name] = param_value
		param_ret = {param_name:param_value}
		logging.info("-{} : {}".format(param_name,param_value))
	elif re.search("^util", prefix):
		param_name = param_name.split(";")
		logging.info("utility : {}".format(param_name))
		param_ret = {"util":param_name}
	elif re.search("^activate_identifier", prefix):
		logging.info("activate_identifier : {}".format(param_name))
		param_ret = {prefix:param_name}
	elif re.search("^activation_file", prefix):
		logging.info("activation_file : {}".format(param_name))
		param_ret = {prefix:param_name}
	elif re.search("^prestep", prefix):
		param_name = replace_string_params(param_name,rec_param_holders(param_name)) 
		param_name = param_name + " -m " + mode 
		logging.info("prestep : {}".format(param_name))
		process = subprocess.Popen(param_name, shell=True,
                           stdout=subprocess.PIPE, 
                           stderr=subprocess.PIPE)

	# wait for the process to terminate
		out, err = process.communicate()
		errcode = process.returncode
		out = out.strip()
		if errcode != 0:
			logging.error("Prestep {} has failed with error code {} ".format(param_name,ret_code)) 
			exit(1)
		sids = out.split(os.linesep) 
		for sid_value in sids:
			sid_arr = sid_value.split("=")
			sid_key = sid_arr[0]
			sid_value = sid_arr[1]
			
	 		os.environ[sid_key] = sid_value
		param_ret = {prefix:param_name}	
	else:
		logging.error("Uknown prefix {} for parameter {} in file {}".format(prefix,param_name,step_config_full_file))
		exit(1)
		
	return param_ret 

def read_step_input(step_config_full_file,loger,mode,default_properties):
	input_map = {}
	if os.path.isfile(step_config_full_file):
		step_input = [line.strip() for line in open(step_config_full_file,'r')]
		if mode == "i":
			populate_prop_values(default_properties)

		for input_line in step_input:
			input_line = input_line.split(":")
			prefix = input_line[0]
			param_name = input_line[1]
			if mode == "i":
				if  prefix in ["pass","param"]:
					value = raw_input("Insert value for - " + param_name  + " [" + str(os.environ.get(param_name)) + "] : ") 
					if value != "":
						os.environ[param_name] = value
			#logging.info("Using value : {}".format(os.environ.get(param_name)))		
			input_map.update(get_map_input(prefix,param_name,step_config_full_file,mode))
			##loger.info("{}".format(input_line))S
	else:
		loger.error("No input file found : {}".format(step_config_full_file))
		raise DbException("No input file found : {}".format(step_config_full_file))
	
	return input_map
	
def read_properties_file(file_name,delimiter):
	input_map = {}
	if os.path.isfile(file_name):
		step_input = [line.strip() for line in open(file_name,'r')]
		for input_line in step_input:
			if not re.search("^#",input_line):
				new_line = input_line.split(delimiter)
				#if not new_line:
				param_name = new_line[0]
				param_value = new_line[1]
	
				input_map.update({param_name:param_value})
	else:
		raise DbException("No input file found : {}".format(file_name))
			
	return 	input_map

def read_db_components (step_config_dir):
	return read_config_dirs(step_config_dir) 

def read_db_mappings(step_config_dir):
	return read_properties_file(step_config_dir + path_sep + "db_mappings.input","=")

def read_error_handling(step_config_dir):
	error_data = read_properties_file(step_config_dir + path_sep + "error_handling.input",":")
	return ErrorHandle(error_data)

def read_placeholders_config(component_name,step_config_dir):
	return read_properties_file(step_config_dir + path_sep + component_name + ".plcholders","=")



def get_err_configs(file_name):
	return read_properties_file(file_name,":")

def get_script_order(file_name):
	input_map = []
	if os.path.isfile(file_name):
		step_input = [line.strip() for line in open(file_name,'r')]
		for input_line in step_input:
			if not re.search("^#",input_line):
				input_line = input_line.split(":")
				param_name = input_line[0]
				param_value = input_line[1] 
				
				input_map.append(Script(param_name,param_value))
	return input_map


def populate_prop_values(properties_file):
	values_map=read_properties_file(properties_file,"=")
	for key, value in values_map.items():
		os.environ[key]=value

		
def is_mode_supported(value):
	ret_value = value
	if not ret_value in ['x','i']:
		raise argparse.ArgumentTypeError("%s is not a supported value check -h " % ret_value)
	
	return ret_value

def is_level_supported(value):
	ret_value = value
	if not logging.getLevelName(ret_value):
		raise argparse.ArgumentTypeError("%s is not a supported value check -h " % ret_value)
	
	return ret_value

def read_configuration(step,vendor,logger,config_dir):
	placeholder_file_location = config_dir + "/" + vendor 
	

	
def main():
	#excluded_dirs = ["log","resources","conf"]
	# parse command-line arguments
	script_main_dir = os.path.dirname(os.path.realpath(__file__))

	
if __name__ == "__main__":
    main()
	 
