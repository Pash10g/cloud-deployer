import os
import sys
import subprocess
from subprocess import call
import config
from config import path_sep
import logging
from distutils.spawn import find_executable
import re
import types
import glob
from  db_exception import DbException
from  pipe_class import LogPipe

 

class DbComponent:
    place_holder_files = []
    
    def __init__(self,component_name,component_base_dir,run_base_dir,activation_dir,utility,placehodlers_map,input_data,error_handling):
        self.name = component_name
        self.base_dir = component_base_dir + path_sep + self.name
        self.run_base_dir = run_base_dir 
        if not os.path.isdir(self.base_dir):
            logging.error("Path {} of compnent {} cannot be found ".format(self.base_dir,self.name))
            self.fatal()
        self.utility = utility
        self.placehodlers_map=placehodlers_map
        self.input_data = input_data
        self.activation_dir = activation_dir
        ## Find all input parameters of the utility string
        self.util_params = []
        for util in self.utility:
            self.util_params = self.util_params + config.rec_param_holders(util)
        self.script_order = config.get_script_order(self.base_dir + path_sep + "script_order.cfg")
        self.error_handling = error_handling
        

           
    def get_placeholders_mapping(self):
        return self.placehodlers_map
    
    def get_script_order(self):
        return self.script_order
    
    def replace_string_in_path(self,base_dir,input,output):
        if os.path.isfile(base_dir):
            fpath = base_dir
            with open(fpath) as f:
                s = f.read()
            s = s.replace(input, output)
            with open(fpath, "w") as f:
                f.write(s)
        else:           
            for dname, dirs, files in os.walk(base_dir):
                for fname in files:
                    self.replace_string_in_path(dname + path_sep +  fname,input,output)
                    
    def run_file_in_path(self,base_dir):
        if os.path.isfile(base_dir):
            self.run_single_file(base_dir)    
        else:   
            files = [] 
            list_dirs = os.listdir(base_dir)
            list_dirs.sort()
            for file in list_dirs:
                if os.path.isfile(base_dir + path_sep + file):
                    files.append(base_dir + path_sep + file)
            for fname in files:
                self.run_file_in_path(fname)
                
    def search_for_errors(self,log_file,error_list,ignore_error_list):
        #out_file = config.read_file_content(log_file)
        with open(log_file) as f:
            content = f.readlines()
		#logging.debug("searching for error '{}' in file : {}".format(error,log_file))
        line_no = 1
        for line in content:
            errors = any(e for e in error_list if e in line)
            ignore = any(e for e in ignore_error_list if e in line)
            if ignore:
                logging.warning("Script {} line {} failed with errors , skipping termination due to {} setting on 'ignored_err_list' property.".format(os.environ.get("SQL_FILE"),line_no,self.error_handling.ignored_error_list))
            elif errors:
                return True
            line_no = line_no + 1
        return False    
    
    def run_single_file (self,current_script):
        
        for util in self.utility:     
            log_number=0
            is_success=False
            out_file = None
            while not is_success and log_number < int(self.error_handling.num_of_retries):
                os.environ["SQL_FILE"] = current_script
                os.environ["LOG_FILE"] = current_script + ".log_" + str(log_number) 
                for param in self.util_params:
                    if not os.environ.get(param):
                       logging.error("No parameter {} is set in environment but it is requested by the db_component utility {} ".format(param,self.utility))
                       raise DbException("No parameter {} is set in environment but it is requested by the db_component utility {} ".format(param,self.utility))
               
                run_util = config.replace_string_params(util,self.util_params)
                logging.info("running  script : {} on database : {}  ".format(os.environ.get("SQL_FILE"),os.environ.get("DB_NAME")))
                logging.debug("running statement (password masked XXXX) : {}".format(run_util))
		logpipe = LogPipe(logging.INFO)
		#errpipe = LogPipe(logging.ERROR)
                process = subprocess.Popen(run_util, shell=True,
                           stdout=logpipe, 
                           stderr=logpipe)
				# wait for the process to terminate
                out, err = process.communicate()
                ret_code = process.returncode
		logpipe.close()
		#errpipe.close()
                if ret_code != 0 :
                    if not self.error_handling.ignored_error_list:
                        out_file = config.read_file_content(os.environ.get("LOG_FILE"))
                        raise DbException("script failed : {} please see log {}  ".format(os.environ.get("SQL_FILE"),os.environ.get("LOG_FILE")))
                    if  "all" in self.error_handling.ignored_error_list:
                        logging.warning("Script {} failed with errors , skipping termination due to {} setting on 'ignored_err_list' property.".format(os.environ.get("SQL_FILE"),self.error_handling.ignored_error_list))
                        is_success = True
                        break
				    # Check for ignored errors and regular erros	
                    if os.path.exists(os.environ.get("LOG_FILE")):
                        if self.search_for_errors(os.environ.get("LOG_FILE"), self.error_handling.error_list,self.error_handling.ignored_error_list):
                            if not out_file:
                                out_file = config.read_file_content(os.environ.get("LOG_FILE"))
                            raise DbException("script failed : {} please check log {} content : {}".format(os.environ.get("SQL_FILE"),os.environ.get("LOG_FILE"),os.linesep + out_file))
                        else:    
                            is_success = True  
                    else:
                        is_success = True

                    out_file = config.read_file_content(os.environ.get("LOG_FILE"))
                    logging.warning("Retry [ {} ] script failed : {} please check log {}".format(log_number,os.environ.get("SQL_FILE"),os.environ.get("LOG_FILE")))
                    if not out_file and os.path.exists(os.environ["LOG_FILE"]):
                        out_file = config.read_file_content(os.environ.get("LOG_FILE"))
                    log_number = log_number + 1
                else:
                    if os.path.exists(os.environ.get("LOG_FILE")):
                        if self.search_for_errors(os.environ.get("LOG_FILE"), self.error_handling.error_list,self.error_handling.ignored_error_list):
                            if not out_file:
                                out_file = config.read_file_content(os.environ.get("LOG_FILE"))
                            raise DbException("script failed : {} please check log {} content : {}".format(os.environ.get("SQL_FILE"),os.environ.get("LOG_FILE"),os.linesep + out_file))
                        else:    
                            is_success = True  
                    else:
                        is_success = True
                                     
                    if log_number == int(self.error_handling.num_of_retries) and os.path.exists(os.environ.get("LOG_FILE")):
                        raise DbException("script failed : {} please check log {} content : {}".format(os.environ.get("SQL_FILE"),os.environ.get("LOG_FILE"),os.linesep + out_file))
                    else:
                        if log_number == int(self.error_handling.num_of_retries):
                            raise DbException("script failed : {}  ".format(os.environ.get("SQL_FILE")))
     
    
    def run_scripts(self,db_mappings):
        tmp_script_map=self.get_script_order()
        for script in tmp_script_map:     
            current_script =  self.run_base_dir + path_sep + script.script_file.replace("/",path_sep)
            if not os.path.exists(current_script):
                
                activation_script = self.activation_dir + path_sep + script.script_file.replace("/",path_sep)
                logging.warning("No script file found under : {} looking under {} ".format(current_script,activation_script))
                if  not os.path.exists(activation_script):
                    logging.error("Cannot find file {} which is stated in {} script_order ".format(activation_script,self.name))
                    raise DbException("Cannot find file {} which is stated in {} script_order ".format(activation_script,self.name))
                
                else:
                    current_script = activation_script 
            log_number = 0
            if os.path.isdir(current_script):
                logging.debug("Changing dir to {}".format(current_script)) 
                os.chdir(current_script)
            else:
                logging.debug("Changing dir to {}".format(os.path.dirname(current_script)))
                os.chdir(os.path.dirname(current_script))
                
            if script.database_mapping == "default": 
                os.environ["DB_NAME"] = os.environ.get(db_mappings[self.name]) 
            else:
                os.environ["DB_NAME"] = script.database_mapping
            os.environ["USERNAME"] = os.environ.get("SYSTEM_NAME")
            os.environ["PASSWORD"] = os.environ.get("SYSTEM_PASSWORD") 
            self.run_file_in_path(current_script)               
    
    def replace_placeholders(self):
        
            tmp_plcholders_map=self.get_placeholders_mapping().items()
            tmp_script_map=self.get_script_order()
            for key, value in  tmp_plcholders_map:
               ## try:
               ## logging.info("replacing placeholder {} ".format(key))
                    for script in tmp_script_map:
                        
                        current_script =  self.run_base_dir + path_sep + script.script_file.replace("/",path_sep)
                        
                        


                        if key == '<dbkit_path>':
                            x = 1
						# Populate the current dir inside the SCRIPT_DIR env.
                        if os.path.isdir(current_script):
                            os.environ["SCRIPT_DIR"] = current_script
                            os.environ["CRE_KIT_PATH"] = current_script
                        elif   os.path.isfile(current_script):
                            os.environ["SCRIPT_DIR"] = os.path.dirname(current_script)
                            os.environ["CRE_KIT_PATH"] = os.path.dirname(current_script)
                        replaced_value = os.environ.get(value)

                        if not replaced_value:
                            continue
                        while len(config.rec_param_holders(replaced_value)) > 0:    
                            replaced_value = config.replace_string_params(replaced_value,config.rec_param_holders(replaced_value))
                            
                        
                        
                        os.environ[value] = replaced_value
                        replaced_key = key
                        logging.debug("replacing {} with {} in file {} ".format(replaced_key,replaced_value,current_script))
                        self.replace_string_in_path(current_script,replaced_key,replaced_value)
                        logging.debug("replacing {} with {} in file {} ".format(replaced_key,replaced_value,self.activation_dir))
                        self.replace_string_in_path(self.activation_dir,replaced_key,replaced_value)
               # except Exception as e:
               #     raise DbException("Error in replacing file {} placeholder {} ".format(current_script,replaced_key))
                
                      
             
    def is_found(pgm):
        path=os.getenv('PATH')
        for p in path.split(os.path.pathsep):
            p=os.path.join(p,pgm)
            if os.path.exists(p) and os.access(p,os.X_OK):
                return True
            else:
                return False
