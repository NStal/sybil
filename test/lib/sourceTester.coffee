global.env ?= {
    logger:{create:()->return console}
}

httpUtil = require "../../common/httpUtil.coffee"
global.env.httpUtil = httpUtil

EventEmitter = (require "events").EventEmitter
console.debug = console.log
# monkey patch for global logger
class SourceBasicTester extends EventEmitter
    constructor:(option = {})->
        @Source = option.Source
        @uri = option.uri
        @Case = {
            containInitialArchive:option.containInitialArchive
        }
    test:()->
        describe "test initialize",()=>
            source = null
            it "test initialize",(done)=>
                if @Source.create
                    source = @Source.create {uri:@uri}
                else
                    source = new @Source({uri:@uri})
                source.debug()
                source.on "initialized",()=>
                    if @Case.containInitialArchive and source.initializer.data.prefetchArchiveBuffer.length is 0
                        throw new Error "doesn't contain initial archives"
                    done()
                source.on "panic",(err)->
                    throw err
                source.on "wait/localAuth",()=>
                    @emit "requireLocalAuth",(username,secret)=>
                        source.give "localAuth",username,secret
                source.on "wait/captcha",()=>
                    @emit "requireLocalAuth",source.authorizer.getCaptchaInfo(),(username,secret)=>
                        source.give "localAuth",username,secret
                source.give "startSignal"
            it "test updater",(done)=>
                source.on "archive",(archive)=>
                    @emit "archive",archive
                source.updater.on "fetch",()=>
                    done()
                source.give "startUpdateSignal"
exports.SourceBasicTester = SourceBasicTester

