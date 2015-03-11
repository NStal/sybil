#!/bin/bash
mocha -R spec -b --compilers .coffee:coffee-script/register ./twitterList.coffee -t 300000

