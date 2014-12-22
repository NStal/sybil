#!/bin/bash
#mocha -R spec -b --compilers .coffee:coffee-script ./p2p/p2pConnectionTest.coffee
#mocha -R spec -b --compilers .coffee:coffee-script ./p2p/domainTest.coffee
#
#mocha -R spec -b --compilers .coffee:coffee-script ./p2p/rsaTest.coffee
#mocha -R spec -b --compilers .coffee:coffee-script ./p2p/key.coffee
#mocha -R spec -b --compilers .coffee:coffee-script ./p2p/p2pFunctionTest.coffee
#mocha -R spec -b --compilers .coffee:coffee-script ./pluginTest.coffee
#mocha -R spec -b --compilers .coffee:coffee-script ./basic/basic.coffee
#mocha -R spec -b --compilers .coffee:coffee-script ./common/httpUtil.coffee -t 50000

#mocha -R spec -b --compilers .coffee:coffee-script ./basic/settingManagerTest.coffee

#mocha -R spec -b --compilers .coffee:coffee-script/register ./basic/collector.coffee -t 1000

#mocha -R spec -b --compilers .coffee:coffee-script/register ./subscribe/weibo.coffee -t 10000
#mocha -R spec -b --compilers .coffee:coffee-script/register ./subscribe/twitter.coffee -t 300000

mocha -R spec -b --compilers .coffee:coffee-script/register ./subscribe/twitterList.coffee -t 300000

