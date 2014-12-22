require "../../core/env.coffee"
SourceBasicTester = sybilRequire("test/lib/sourceTester").SourceBasicTester
Pixiv = require("./index.coffee")
tester = new SourceBasicTester({Source:Pixiv})
hasRequire = false
tester.on "requireLocalAuth",(handler)->
    if hasRequire
        console.log "local auth failed"
        process.exit(0)
    hasRequire = true
    handler(process.env.username,process.env.password)

tester.test()
