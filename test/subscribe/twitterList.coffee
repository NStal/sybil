env = require "../../core/env"
SourceBasicTester = require("../lib/sourceTester").SourceBasicTester
global.env.settings.proxies = [
    "phttp://citidal.nstal.me:12222/"
#    "http://lili:7072/"
]
Twitter = require("../../collector/sources/twitter")
tester = new SourceBasicTester({Source:Twitter,uri:"https://twitter.com/nstalorz/lists/vips"})
hasRequire = false

tester.on "requireLocalAuth",(handler)->
    if hasRequire
        console.log "fail to local auth"
        process.exit(0)
    handler(process.env.username,process.env.secret)
    hasRequire = true
tester.test()
