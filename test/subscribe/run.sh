#!/bin/bash
mocha -R spec -b --compilers .coffee:coffee-script/register ./weibo.coffee -t 300000
