#!/usr/bin/python
from __future__ import print_function 
import argparse
import os
import sys
import subprocess
import logging
import config
from argparse import RawTextHelpFormatter
from config import path_sep
from step import Step
import re
from db_exception import DbException
import datetime
 

	
def main(argv):
	#excluded_dirs = ["log","resources","conf"]
	# parse command-line arguments
	if len(argv) < 2:
		print("Not enough values passed to the validate.py . Usage : validate.py <cmd> %s " % argv)
		print("Not enough values passed to the validate.py . Usage : validate.py <cmd> ")
		exit(1)
	
	if argv[0] == __file__:
		util = argv[1]
	else:
		util = argv[0]
	
		
	script_main_dir = os.path.dirname(os.path.realpath(__file__))
	#supported_vendors = config.read_supported_vendors(script_main_dir + path_sep + "config")
	os.environ["BASE_DIR"] = script_main_dir
	
	process = subprocess.Popen(util, shell=True,
                           stdout=subprocess.PIPE, 
                           stderr=subprocess.PIPE)

	# wait for the process to terminate
	out, err = process.communicate()
	errcode = process.returncode
	out = out.strip()
	if err or errcode != 0:
		print("Error : {}".format(err))
		exit(1)
	
	#import pdb; pdb.set_trace()
	if not re.match("Failure",out) and not re.search("                  1",out):
		exit(0)
	else:
		print ("%s" % out)
		exit(1)
	 		
if __name__ == "__main__":
	main(sys.argv)
	 