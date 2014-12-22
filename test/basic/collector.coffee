console.debug = console.log
#console.debug = ()->
#console.log = ()->
global.env = {logger:{create:()->return console}}
Source = require "../../collector/source/source.coffee"
EventEmitter = (require "events").EventEmitter
Collector = require "../../collector/collector.coffee"
Errors = Source.Errors
TestEventCenter = new EventEmitter()
TestEventCenter.conduct = (name,who,data)->
    @emit "conduct/#{name}",who,data
EC = TestEventCenter
toggleSourceDebug = ()->
    
    Source.prototype._isDebugging = true
    Source::Updater.prototype._isDebugging = true
    Source::Initializer.prototype._isDebugging = true
    Source::Authorizer.prototype._isDebugging = true

class TestSource extends Source
    @detectStream = (uri)->
        if uri.indexOf("test_source_uri://") is 0
            sources = [new TestSource({uri:uri})]
        else
            sources = []
        return Source.delayStream sources
    constructor:(info)->
        super(info)
        @type = "testSource"
class TestInitializer extends Source::Initializer
    constructor:(source)->
        super(source)
    atInitializing:(sole)->
        TestEventCenter.once "initializeData",(err,data)=>
            if not @checkSole sole
                return
            if err
                @error err
                return
            for prop of data
                @data[prop] = data[prop]
            @setState "initialized"
        TestEventCenter.conduct "initialize",this,{authorizationInfo:@data.authorizationInfo}
class TestAuthorizer extends Source::Authorizer
    constructor:(source)->
        super(source)
    atPrelogin:(sole)->
        TestEventCenter.once "preloginData",(err,data)=>
            if err
                @error err
                return
            if not @checkSole sole
                return
                
            for prop of data
                @data[prop] = data[prop]
            @setState "prelogined"
        TestEventCenter.conduct "prelogin",this
    atLogining:(sole)->
        TestEventCenter.once "loginData",(err,data)=>
            if err
                @error err
                return
            if not @checkSole sole
                return
            @data.authorizeInfo = data.authorizeInfo
            @setState "authorized"
        TestEventCenter.conduct "login"
        
class TestUpdater extends Source::Updater
    constructor:()->
        super()
        @data.nextFetchInterval = 1
    atFetching:(sole)->
        TestEventCenter.once "archive",(err,archives)=>
            if err
                @error err
                return
            @_fetchHasCheckSole = true
            if not @checkSole sole
                return
            @data.rawFetchedArchives = archives
            @setState "fetched"
        TestEventCenter.conduct "fetch",this,{initializeInfo:@data.initializeInfo,authorizeInfo:@data.authorizeInfo}
    parseRawArchive:(raw)->
        if @fakeParseError
            throw @fakeParseError
        archive = {}
        for prop of raw
            archive[prop] = raw[prop]
        archive.processed = true
        return archive
TestSource::Initializer = TestInitializer
TestSource::Updater = TestUpdater
TestSource::Authorizer = TestAuthorizer
describe "collector basic source/updater/authorizer test",()->
    source = null
    it "basic init should works",(done)-> 
        source = new TestSource({uri:"test_source_uri://a.b.d/test"})
        source.once "initialized",()->
            source.guid isnt "testSource_test_source_uri://a.b.d/test" and throw new Error "guid not set"
            done()
            
        TestEventCenter.once "conduct/initialize",(who,info)->
            TestEventCenter.emit "initializeData",null,{initializeInfo:{name:"mikuPic"},guid:"testSource_"+source.uri}
        source.start()

    it "basic give startUpdateSignal should works",(done)->
        TestEventCenter.once "conduct/fetch",()=>
            TestEventCenter.emit "archive",null,[{guid:"mikuImage0",value:1},{guid:"mikuImage1",value:2}]
        length = 0
        source.on "archive",(archive)=>
            length += 1
            archive.value isnt length or 
            archive.processed isnt true and
            throw new Error "fail to parse archives"

        source.once "update",()=>
            if length isnt 2
                throw new Error "fail to update"
            source.removeAllListeners "archive"
            done()
        source.give "startUpdateSignal"
describe "collector complext source/updater/authorizer",()->
    source = null
    it "basic init should works",(done)->
        EC.removeAllListeners()
        source = new TestSource({uri:"test_source_uri://a.b.d/test"})
        source.once "initialized",()->
            source.guid isnt "testSource_test_source_uri://a.b.d/test" and throw new Error "guid not set"
            source.removeAllListeners "wait/localAuth"
            done()

        hasFail = false
        EC.on "conduct/initialize",(who,info)->
            data = source.initializer.data
            if not data.authorizeInfo or data.authorizeInfo.key isnt "miku"
                hasFail = true
                EC.emit "initializeData",new Errors.AuthorizationFailed()
            else
                if not hasFail
                    throw new LogicError "didin't pass authorization failed"
                EC.emit "initializeData",null,{name:"V+"}
        EC.on "conduct/prelogin",(who,info)->
            EC.emit "preloginData",null,{preloginData:"miku"}
        EC.on "conduct/login",(who,info)->
            data = source.authorizer.data
            if data.preloginData isnt "miku"
                throw new Error "fail to prelogin"
            if data.username isnt "miku"
                throw new Error "invalid username"
            if data.secret isnt "ukim"
                throw new Error "invalid secret"
            EC.emit "loginData",null,{authorizeInfo:{key:"miku"}}
        localAuthCount = 0
        source.on "wait/localAuth",()->
            setTimeout (()=>
                source.give "localAuth","miku","ukim"
                ),100
        source.start()
    it "basic give startUpdateSignal should works",(done)->
        EC.once "conduct/fetch",()=>
            EC.emit "archive",null,[{guid:"mikuImage0",value:1},{guid:"mikuImage1",value:2}]
        length = 0
        source.on "archive",(archive)=>
            length += 1
            archive.value isnt length or 
            archive.processed isnt true and
            throw new Error "fail to parse archives"

        source.once "update",()=>
            if length isnt 2
                throw new Error "fail to update"
            source.removeAllListeners "archive"
            done()
        source.give "startUpdateSignal"
    it "test source when authorization failed again",(done)->
        
#        toggleSourceDebug(source)
        EC.removeAllListeners()
        if source.state isnt "updating" or source.updater.state isnt "sleep"
            throw new Error "source not in correct state"
            
        EC.on "conduct/fetch",()->
            if not source.updater.data.authorizeInfo.passPinCode
                EC.emit "archive",new Errors.AuthorizationFailed("fake one")
            else
                setTimeout (()->
                    EC.emit "archive",null,[{guid:"archive1",value:"test_source_uri://a.b.d/test"}]
                    ),100

        # also test captcha here
        EC.once "conduct/prelogin",()->
            EC.emit "preloginData",null,{
                requireCaptcha:true
                captchaBuffer:"12345"
                captchaType:"text"
                captchaFormat:"string"
            }
        EC.once "conduct/login",()->
            source.authorizer.data.captcha isnt "12345" or
            source.authorizer.data.requireCaptcha or
            source.authorizer.data.username isnt "miku" or
            source.authorizer.data.secret isnt "PPP" or
            source.authorizer.data.authorized and
            throw new Error "fail to login"
            EC.emit "loginData",null,{authorized:true,authorizeInfo:{passPinCode:true}}
        source.once "wait/captcha",()->
            source.authorizer.data.requireCaptcha isnt true or
            source.authorizer.data.captchaBuffer.toString() isnt "12345" or
            source.authorizer.data.captchaType isnt "text" or
            source.authorizer.data.captchaFormat isnt "string" and
            throw new Error "invalid captcha data"
            source.give "captcha","12345"
        source.once "wait/localAuth",()->
            source.give "localAuth","miku","PPP"
        archiveLength = 0
        source.on "archive",(archive)->
            archiveLength += 1 
            if archive.guid isnt "archive1" or archive.value isnt "test_source_uri://a.b.d/test"
                throw new Error "invalid archive"
        source.on "update",()->
            if archiveLength isnt 1
                throw new Error "invalid update process"
            source.removeAllListeners("update")
            source.removeAllListeners("archive")
            done()
        source.forceUpdate (err)->
            if err not instanceof  Source.Errors.AuthorizationFailed
                throw new Error "force update should bubble AuthorizationFailed Error"

    it  "test sleep time algo",(done)->
        EC.removeAllListeners()
        source.updater.data.maxFetchInterval = 1000
        source.updater.data.minFetchInterval = 15
        source.updater.data.nextFetchInterval = 20
        source.updater.data.timeFactor = 2
        updateCounter = 0
        times = []
        guid = 1
        start = 0
        EC.on "conduct/fetch",()->
            EC.emit "archive",null,[{guid:1}]
        start = Date.now()
        source.updater.on "fetch",()->
            updateCounter += 1
            times.push [Date.now()]
            if updateCounter is 3
                check()
        times.push Date.now()
        check = ()=>
            # initial 20
            # first fetch 20/2 = 10 but less than minimum so it's 15
            # second no updates 15 *2 = 30
            # third no updates 30 * 2 = 60
            if source.updater.data.nextFetchInterval isnt 60
                throw new Error "invalid source"
            done()
        source.forceUpdate (err)->
            if err
                throw new Error()
        
describe "key path test for collector",()->
    list = require("../../collector/sourceList")
    list.getMap = ()->
        return {testSource:TestSource}
    it "test stream detection",(done)->
        EC.removeAllListeners()
        collector = new Collector()
        stream = collector.sourceSubscribeManager.detectStream "test_source_uri://example"
        candidateCount = 0
        stream.on "data",(candidate)->
            candidateCount += 1
            candidate = candidate
        stream.on "end",()->
            if candidateCount isnt 1
                throw new Error "fail detect stream failure"
            done()
    source = null
    adapter = null
    collector = null
    it "test basic subscribe",(done)->
        
        EC.removeAllListeners()
        collector = new Collector()
        EC.on "conduct/initialize",()->
            setTimeout (()->
                EC.emit "initializeData",null,{testInitializeInfo:{done:true}}
                ),100
        candidate = null
        end = false
        collector.sourceSubscribeManager.on "subscribe",(_source)->
            if not end
                throw new Error "fail to end"
            source = _source
            if adapter.source
                throw new Error "handover didn't delete source"
            if adapter in collector.sourceSubscribeManager.adapters
                throw new Error "fail to remove adapter"
            done()
        
        stream = collector.sourceSubscribeManager.detectStream "test_source_uri://example"
        stream.on "data",(c)->
            toggleSourceDebug collector.sourceSubscribeManager.adapters[0].source
            candidate = c
            adapter = collector.sourceSubscribeManager.getAdapter c.cid
            if adapter.isWaitingFor "accept"
                adapter.give "accept",true
            else
                adapter.data.acceptance = "accept"
        collector.sourceSubscribeManager.on "requireAccept",(c)->
            console.debug "accept?"
            if c.cid isnt candidate.cid
                throw new Error "invalid require accept"
            collector.sourceSubscribeManager.accept cid,(err)->
                if err
                    throw err
        stream.on "end",()->
            end = true
    it "test our new source in source subscribe manager",(done)->
        if collector.sourceManager.sources.length isnt 1
            throw new Error "sourceSubscribeManager fail to give subscribed source to SourceManager"
        console.debug source.state
        if source.state isnt "updating"
            throw new Error "handovered source not auto updating it's self"
        done()
