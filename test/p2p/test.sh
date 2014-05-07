#!/bin/bash
mocha -R spec -b --compilers .coffee:coffee-script \
./key.coffee \
./sandbox.coffee 

