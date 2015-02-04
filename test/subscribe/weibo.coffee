env = require "../../core/env"
SourceBasicTester = require("../lib/sourceTester").SourceBasicTester
Weibo = require("../../collector/sources/weibo")
tester = new SourceBasicTester({Source:Weibo,uri:"http://weibo.com/"})
hasRequire = false
tester.on "requireLocalAuth",(handler)->
    if hasRequire
        console.log "fail to local auth"
        process.exit(0)
    hasRequire = true
    handler(process.env.username,process.env.password)
tester.test()
