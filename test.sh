#!/bin/bash

set -e

./run_deployer.py -m x -v amazon -s init-bootstrap
./run_deployer.py -m x -v amazon -s deploy
