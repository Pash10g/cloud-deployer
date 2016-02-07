
import os
import sys
from subprocess import call
import config
from config import path_sep
import logging
from db_component import DbComponent
import shutil
from db_exception import DbException
import re

class Step:
    place_holder_files = []
    
    # Step class constructor.
    def __init__(self,step_name,vendor,logger,main_dir,base_config_dir,base_resource_dir,mode):
        #Define main class attribures.
        self.step_name = step_name
        self.vendor = vendor
        self.logger = logger
        self.mode = mode
        self.main_dir = main_dir
        self.set_config_dir(base_config_dir)
        #Populate the properties form properties.conf file
        if self.mode == "x":
            config.populate_prop_values(self.get_config_dir() + path_sep +"properties.conf")
        self.input_file = self.get_config_dir() + path_sep + step_name + path_sep +  self.vendor + ".input"
        self.resource_dir = base_resource_dir + path_sep + vendor
        self.component_dir = self.get_config_dir() + path_sep + step_name 
        self.working_dir = self.main_dir + path_sep + "tmp"
        #Get db components and validate input.
        self.components_names = config.read_db_components(self.component_dir)
        self.db_mappings = config.read_db_mappings(self.get_config_dir() + path_sep + step_name)
        self.error_handling = config.read_error_handling(self.get_config_dir() + path_sep + step_name) 

        
    def set_config_dir(self,base_config_dir):
        self.config_dir = base_config_dir + path_sep + self.vendor
        if not os.path.isdir(self.config_dir):
           self.logger.error("Step directory dir : {} does not exists".format(self.config_dir))
           exit(1)
        
    def get_config_dir(self):
        return self.config_dir 
    
    def get_resource_dir(self):
        return self.resource_dir
    
    def get_working_dir(self):
        return self.working_dir  
    
    ## Copy the sources from relevant resource di
    def copy_sources(self):
        if os.path.isdir(self.get_resource_dir()):
            resource_dirs = config.read_config_dirs(self.get_resource_dir())
            self.run_dir = self.get_working_dir() + path_sep + "run_" + self.step_name + "_" + self.vendor + "_" + os.environ[self.input_data["activate_identifier"]]
            if os.path.isdir(self.run_dir):
                shutil.rmtree(self.run_dir)
                    
            if not os.path.isdir(self.run_dir):
                os.makedirs(self.run_dir)
            
    
            if "activate_identifier" in self.input_data:
                self.activation_dir= self.get_working_dir() + path_sep + "activation_" + os.environ[self.input_data["activate_identifier"]]                   
                   # if  os.path.exists(self.activation_dir):
                   #    shutil.rmtree(self.activation_dir)
                if not os.path.exists(self.activation_dir):
                    os.makedirs(self.activation_dir) 

                    
            for step_type in resource_dirs:
                
                src = self.get_resource_dir() + path_sep + step_type
                dst = self.run_dir + path_sep + step_type
                shutil.copytree(src, dst)
               
                if "activation_file" in self.input_data: 
                    self.copy_activation_file(self.activation_dir,self.run_dir)

                    
             
        else:
            self.logger.error("The resource directory {} was not found ".format(self.get_resource_dir()))
            exit(1)
            
    def copy_activation_file(self,dst,base_dir):          
            for dname, dirs, files in os.walk(base_dir):
                for fname in files:
                   if fname == self.input_data["activation_file"]:
                       shutil.copy(dname + path_sep + fname, dst + path_sep + fname)
                       
    def cleanup(self,base_dir):
        
        if os.path.isfile(base_dir) and re.search(".*\.sh$",base_dir):
            logging.debug("Removing file {} ".format(base_dir))
            os.remove(base_dir)
        else:           
            for dname, dirs, files in os.walk(base_dir):
                for fname in files:
                    self.cleanup(dname + path_sep +  fname)
                                           
    def print_script_order(self):
		for db_component in self.db_components:
			current_component = db_component
			for script in current_component.script_order:
				script_path = self.run_dir + path_sep + script.script_file.replace("/",path_sep)
				if (os.path.isdir(script_path)):
					logging.info("run all scripts in directory (lexicographic order): {}".format(script_path))
				else:
					logging.info("run file: {}".format(script_path))
	
    def read_input_data(self): 
        self.input_data = config.read_step_input(self.input_file,self.logger,self.mode)
        #return self.input_data
    
    def intialize_db_components(self):
        self.db_components = []
        for component in  self.components_names:
            place_holders_map = config.read_placeholders_config(component,self.get_config_dir())
            current_component = DbComponent(component,self.component_dir,self.run_dir,self.activation_dir,self.input_data["util"],place_holders_map,self.input_data,self.error_handling)
            self.db_components.append(current_component)
            
    def replace_placeholders(self): 
        for db_component in self.db_components:
            db_component.replace_placeholders()
    
    def run_sql_scripts(self):
        try:
            for db_component in self.db_components:
                current_component = db_component
                db_component.run_scripts(self.db_mappings)
                
        except DbException as e:
            raise DbException("DB Component {} failed on running scripts see error : {}".format(current_component.name,e.value)) 
        except Exception as e:
            raise DbException("DB Component {} failed on running scripts see error : {}".format(current_component.name,e))
        finally:
            if re.search("activate",self.step_name):
                if  logging.getLogger().getEffectiveLevel() != logging.DEBUG: 
                    logging.info("Cleaning up files [cql|sql] from directory : {}".format(self.activation_dir))
                    self.cleanup(self.activation_dir)  
            else:
                if  logging.getLogger().getEffectiveLevel() != logging.DEBUG:
                    logging.info("Cleaning up files [cql|sql] from directory : {}".format(self.run_dir))   
                    self.cleanup(self.run_dir)
        
        
