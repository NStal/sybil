#!/bin/bash
#mocha -R spec -b --compilers .coffee:coffee-script ./p2p/p2pConnectionTest.coffee
#mocha -R spec -b --compilers .coffee:coffee-script ./p2p/domainTest.coffee
#
mocha -R spec -b --compilers .coffee:coffee-script ./p2p/rsaTest.coffee
#mocha -R spec -b --compilers .coffee:coffee-script ./p2p/p2pFunctionTest.coffee
#mocha -R spec -b --compilers .coffee:coffee-script ./pluginTest.coffee
#mocha -R spec -b --compilers .coffee:coffee-script ./basic/basic.coffee

