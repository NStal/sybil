SourceBasicTester = require("../lib/sourceTester").SourceBasicTester
global.env.settings = {
    proxies:[
        "http://localhost:7072"
        "phttp://nstal.me:12222"
    ]
}
Twitter = require("../../collector/sources/twitter")
tester = new SourceBasicTester({Source:Twitter,uri:"https://twitter.com/nstalorz/lists/vips"})
tester.on "requireLocalAuth",(handler)->
    handler(process.env.username,process.env.secret)
tester.test()