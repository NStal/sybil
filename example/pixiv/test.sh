#!/bin/bash
mocha -R spec --compilers .coffee:coffee-script/register ./test.coffee -t 30000 -b
