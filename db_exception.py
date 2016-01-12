
import os
import sys
from subprocess import call
import shutil


class DbException(Exception):
     def __init__(self, value):
         self.value = value
     def __str__(self):
        return repr(self.value)