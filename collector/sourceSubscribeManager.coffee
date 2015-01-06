EventEmitter = (require "events").EventEmitter
States = sybilRequire "common/states.coffee"
sourceList = require "./sourceList.coffee"
errorDoc = require "error-doc"
async = require "async"
console = env.logger.create __filename
# We will do many complicated user interaction here.
# Sources in this manager are waiting to be tested
# or waiting to be accept/declined by user.
#
# Events
# subscribe: (source)
#     The source is ready to add to source manager
#     it should already be initialized and authorized
#     you can even expect it to has some pre buffered
#     archives at source.updater.prefetchArchiveBuffer
#     , which may be set by Source::Initializer
#
# determine: (adapter)
#     The adapter is ready to be accept or decline
#     we may display the adapter.source information
#     to user to hint him to determine.
#
# requireLocalAuth: (adapterInfo)
#     please get username and secret from user and call
#     setAdapterLocalAuth(cid,username,secret,callback)
#
# requireCaptcha: (adapterInfo)
#     please display adapterInfo.captchaInfo to user
#     and call setAdapterCaptcha(cid,captcha,callback)
#     with the user recognized Captcha.
#
# fail: (adapterInfo)
#    fail to init the source in adapter, and this is the last
#    time you receive any information from the adapter, it
#    will be destroy immediately after destroy. But you may
#    manually recreate it by calling test(type,uri,callback)
#    to manually create this adapter, but usally a adapter
#    is coming from detect a given uri.
Errors = errorDoc.create()
    .define("InvalidSource")
    .define("NotExists")
    .define("InvalidAction")
    .define("LogicError")
    .generate()
class SourceSubscribeManager extends EventEmitter
    constructor:()->
        # store the temperary source
        # that may be abandoned or add to
        # source manager
        @adapters = []
        super()
    detectStream:(uri)->
        stream = new EventEmitter()
        process.nextTick ()=>
            SourceList = sourceList.getList()
            async.each SourceList,((Source,done)=>
                subStream = Source.detectStream uri
                if not subStream
                    console.debug "#{Source.name} doesn't match #{uri}"
                    done()
                    return
                else
                    console.debug "#{Source.name} match #{uri}"
                subStream.on "data",(source)=>
                    console.debug "get source for subscribe #{uri} #{source.uri}"
                    if not source
                        throw new Error "no source"
                    existAdapter = null
                    @adapters.some (adapter)->
                        if adapter.containSource source
                            existAdapter = adapter
                            return true
                        return false
                    if existAdapter
                        console.debug "exists adapter",existAdapter.source.uri
                        stream.emit "data",existAdapter.getInfo()
                        return
                    adapter = new SubscribeAdapter(source)
                    @addAdapter adapter
                    stream.emit "data",adapter.getInfo()
                subStream.on "end",()->
                    console.debug "substream #{Source.name} end"
                    done()
                ),()->
                    console.debug "source scribe for #{uri} ends"
                    stream.emit "end"
        return stream
    # A none stream implementation based on the stream
    # implementation.
    detect:(uri,callback)->
        stream = @detectStream uri
        result = []
        stream.on "data",(adapter)->
            result.push adapter
        stream.on "end",()->
            callback null,result
    # `addAdapter` will not check duplication
    addAdapter:(adapter)->
        console.debug "add adapter",adapter.cid
        @adapters.push adapter
        adapter.on "subscribe",()=>
            console.log "Source subscribe confirmed #{adapter.source.guid}"
            info = adapter.getInfo()
            source = adapter.handover()
            @removeAdapter adapter
            @emit "subscribe",info
            @emit "source",source
        adapter.on "cancel",()=>
            info = adapter.getInfo()
            @removeAdapter(adapter)
            @emit "cancel",info
        adapter.on "wait/accept",()=>
            @emit "requireAccept",adapter.getInfo()
        adapter.on "wait/localAuth",()=>
            @emit "requireLocalAuth",adapter.getInfo()
        adapter.on "wait/captcha",()=>
            @emit "requireCaptcha",adapter.getInfo()
        adapter.on "wait/retrySignal",()=>
            @emit "fail",adapter.getInfo()
        adapter.on "cancel",()=>
            @emit "cancel",adapter.getInfo()
    removeAdapter:(adapter)->
        @adapters = @adapters.filter (item)->
            if item isnt adapter
                return true
            item.reset()
            item.source = null
            item.removeAllListeners()
            return false
        # Reset will check if have adapter has @source.
        # It's safe event after handovered


    # A adapter represents a source candidate,
    # but IS NOT a candidate. The information adapter
    # carried with, should be considered the info of
    # the candidate.
    getCandidates:()->
        return @adapters.map (adapter)->
            return adapter.getInfo()
    getCandidate:(cid)->
        adapter = @getAdapter(cid)
        if adapter
            return adapter.getInfo()
        return null
    getAdapter:(cid)->
        for adapter in @adapters
            if adapter.cid is cid
                return adapter
        return null
    setAdapterLocalAuth:(cid,username,secret,callback)->
        exists = @adapters.some (adapter)->
            if adapter.cid is cid
                if adapter.isWaitingFor "localAuth"
                    adapter.give "localAuth",username,secret
                    callback()
                else
                    callback new Errors.InvalidAction "adapter is not waiting for `localAuth`"
                return true
            return false
        if not exists
            callback new Errors.NotExists("adapter not found")
    setAdapterCaptcha:(cid,captcha,callback)->
        exists = @adapters.some (adapter)->
            if adapter.cid is cid
                if adapter.isWaitingFor "captcha"
                    adapter.give "captcha",captcha
                    callback()
                else
                    callback new Errors.InvalidAction("adapter is not waiting for the captcha")
                return true
            return false
        if not exists
            callback new Errors.NotExists("adapter not found")
    retry:(cid,retry,callback)->
        exists = @adapters.some (adapter)->
            if adapter.cid is cid
                if adapter.isWaitingFor "retrySignal"
                    adapter.give "retrySignal",retry
                    callback()
                else
                    callback new Errors.InvalidAction("adapter is not waiting for the retry")
                return true
            return false
        if not exists
            callback new Errors.NotExists("adapter not found")

    accept:(cid,callback = ()-> )->
        exists = @adapters.some (adapter)->
            if adapter.cid is cid
                process.nextTick ()->adapter.accept()
                callback()
                return true
            return false
        if not exists
            callback new Errors.NotExists("#{cid} not exists")
    decline:(cid,callback = ()-> )->
        exists = @adapters.some (adapter)->
            if adapter.cid is cid
                process.nextTick ()->adapter.decline()
                callback()
                return true
            return false
        if not exists
            callback new Errors.NotExists("#{cid} not exists")

class SubscribeAdapter extends States
    constructor:(@source)->
        super()
        # we use this format as a temprory idenditier
        @cid = "adapter:#{@source.type}:#{@source.uri}"
        # save as less state info as possible
        # use more info on @source itself as possible.
        @data.accept = false

        # No reason for waiting.
        # We start detect immediately after create
        @setState "detecting"
    atDetecting:()->
        if not @source
            @error Errors.InvalidAction("SubscribeAdapter.source is not set, likely due to this adapter is already done it's work, and been destroyed")
            return
        # For source that don't event need a initialize state
        # or can may a sync initialize state at start up
        if not @source.isWaitingFor "startSignal"
            @error new Errors.LogicError "adapter should recieve a source at standby"
            return
        @clear ()=>
            @source.stopListenBy this
        @source.listenBy this,"wait/localAuth",()=>
            @waitFor "localAuth",(u,s)=>
                @source.give "localAuth",u,s
        @source.listenBy this,"wait/captcha",()=>
            @waitFor "captcha",(c)=>
                @source.give "captcha",c
        @source.listenBy this,"initialized",()=>
            @clear()
            @setState "subscribing"
        @source.listenBy this,"panic",(error)=>
            @clear()
            @setState "fail"
        @source.start()
    atFail:(sole)->
        @waitFor "retrySignal",(tryAgain)=>
            if not @checkSole sole
                return
            if tryAgain
                @source.reset()
                @source.standBy()
                @setState "detecting"
            else
                @setState "cancel"
    atSubscribing:(sole)->
        if @data.acceptance is "accept"
            @setState "subscribed"
        else if @data.acceptance is "decline"
            @setState "cancel"
        else
            @waitFor "accept",(acceptIt)=>
                if not @checkSole sole
                    return
                if acceptIt
                    @setState "subscribed"
                else
                    @setState "cancel"
    atSubscribed:(sole)->
        @data.subscribed = true
        # A subscribed source should be waiting for startUpdateSignal.
        # If not we wait until it's at this state. So who every recieve
        # the source, is garanteed that it will be waiting for a `startUpdateSignal`
        @source.clearError()
        if @source.isWaitingFor "startUpdateSignal"
            @emit "subscribe",@source
        else
            @source.once "wait/startUpdateSignal",()=>
                if not @checkSole sole
                    return
                @emit "subscribe",@source
    atCancel:()->
        @source.reset()
        @emit "cancel"
    accept:()->
        @data.acceptance = "accept"
        if @isWaitingFor "accept"
            @give "accept",true
    decline:()->
        @data.acceptance = "decline"
        if @isWaitingFor "accept"
            @give "accept",false
    containSource:(source)->
        return @source.type is source.type and @source.uri is source.uri
    getInfo:()->
        model = @source and @source.toSourceModel() or {}
        return {
            acceptance:@data.acceptance
            ,@state
            ,@cid
            ,requireLocalAuth:@isWaitingFor("localAuth")
            ,requireCaptcha:@isWaitingFor("captcha")
            ,captchaInfo:@source and @source.authorizer.getCaptchaInfo()
            ,uri:model.uri
            ,type:model.type
            ,name:model.name
            ,panic:@source and @source.panicError
        }
    handover:()->
        # A source not subscribed shouldn't be handover to others.
        if @state isnt "subscribed"
            return null
        source = @source
        @source = null
        return source
    reset:()->
        super()
        if @source
            @source.reset()
module.exports = SourceSubscribeManager
module.exports.SubscribeAdapter = SubscribeAdapter
