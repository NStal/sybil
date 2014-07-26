EventEmitter = (require "events").EventEmitter
States = require "./states.coffee"
sourceList = require "./sourceList.coffee"
errorDoc = require "error-doc"
async = require "async"
console = env.logger.create __filename
# we will do many complicated user interaction here.
# source in this buffer are waiting to be tested
# or waiting to be confirmed/abondoned by user.
# 
# Events
# subscribe: (source)
#     The source is ready to add to source manager
#     it should already be initialized and authorized
#     you can even expect it to has some pre buffered 
#     archives at source.updater.prefetchArchiveBuffer
#
# determine: (adapter)
#     The adapter is ready to be accept or decline
#     we may display the adapter.source information
#     to user to hint him to determine
#
# requireLocalAuth: (adapterInfo)
#     please get username and secret from user and call
#     setAdapterLocalAuth(cid,username,secret,callback)
#
# requirePinCode: (adapterInfo)
#     please display adapterInfo.pinCodeInfo to user
#     and call setAdapterPinCode(cid,pinCode,callback)
#     with the user recognized PinCode.
# fail: (adapterInfo)
#    fail to init the source in adapter, and this is the last
#    time you receive any information from the adapter, it
#    will be destroy immediately after destroy. But you may
#    manually recreate it by calling test(type,uri,callback)
#    to manually create this adapter, but usally a adapter
#    is coming from detect a given uri.
Errors = errorDoc.create()
    .define "InvalidSource"
    .define "NotExists"
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
            async.each sourceList.List,((Source,done)=>
                subStream = Source.detectStream uri
                if not subStream
                    done()
                    return
                subStream.on "data",(source)=>
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
                    adapter.start()
                subStream.on "end",()->
                    done()
                ),()->
                    console.debug "stream end"
                    stream.emit "end"
        console.log "return stream"
        return stream
    detect:(uri,callback)->
        stream = @detectStream uri
        result = []
        stream.on "data",(adapter)->
            result.push adapter
        stream.on "end",()->
            callback null,result
    test:(type,uri,callback)->
        Source = sourceList.Map[type]
        if not Source
            callback new Errors.InvalidSource "Unkown source type #{type}"
            return
        source = new Source {uri,uri}
        adapter = new SubscribeAdapter source
        @addAdapter adapter
        callback null,adapter
        adapter.start()
    addAdapter:(adapter)->
        console.log "add adapter",adapter.cid
        @adapters.push adapter
        adapter.once "accept",()=>
            console.log "accept"
            @removeAdapter adapter
            source = adapter.handover()
            @emit "subscribe",source
        adapter.once "decline",()=>
            @removeAdapter(adapter)
            adapter.destroy()
        adapter.on "determine",()=>
            @emit "determine",adapter.getInfo()
        adapter.on "requireLocalAuth",()=>
            @emit "requireLocalAuth",adapter.getInfo()
        adapter.on "requirePinCode",()=>
            @emit "requirePinCode",adapter.getInfo()
        adapter.on "fail",()=>
            @emit "fail",adapter.getInfo()
            @removeAdapter(adapter)
            adapter.destroy()
    removeAdapter:(adapter)->
        @adapters = @adapters.filter (item)->
            return item isnt adapter
        adapter.removeAllListeners()
        
    getCandidates:()->
        return @adapters.map (adapter)->
            return adapter.getInfo()
    setAdapterLocalAuth:(cid,username,secret,callback)-> 
        exists = @adapters.some (adapter)->
            if adapter.cid is cid
                adapter.source.setLocalAuth username,secret
                callback()
                return true
            return false
        if not exists
            callback new Erros.NotExists("adapter not found")
    setAdapterPinCode:(cid,pinCode,callback)->
        exists = @adapters.some (adapter)->
            if adapter.cid is cid
                adapter.source.setPinCode pinCode
                callback()
                return true
            return false
        if not exists
            callback new Erros.NotExists("adapter not found")
            
    accept:(cid,callback)->
        exists = @adapters.some (adapter)->
            if adapter.cid is cid
                adapter.accept()
                callback()
                return true
            return false
        if not exists
            callback new Errors.NotExists("#{cid} not exists")
    decline:(cid,callback)->
        exists = @adapters.some (adapter)->
            if adapter.cid is cid
                adapter.decline()
                callback()
                return true
            return false
        if not exists
            callback new Errors.NotExists("#{cid} not exists")
            
class SubscribeAdapter extends States
    constructor:(@source)->
        super()
        @cid = "adapter:"+@source.type + @source.uri
        # save as less state info as possible
        # use more info on @source itself as possible.
        @acceptance = "unset"
        @setState "void"
        @source.on "requireLocalAuth",()=>
            console.log "source require auth??"
            @emit "requireLocalAuth"
        @source.on "requirePinCode",()=>
            @emit "requirePinCode"
    start:()->
        @setState "wait"
        @source.initializer.once "initialized",()=>
            @setState "initialized"
        @source.initializer.once "fail",()=>
            @setState "fail"
        # if by chance we have already initialized this source
        # just the skip the initialized process
        if @source.initializer.initialized
            @setState "initialized"
            return
        console.log "initialzie at addapter"
        @source.initializer.initialize()
    atFail:()->
        @emit "fail"
    atInitialized:()->
        # duplicate accept and decline is OK
        # since subscribe buffer should remove listener
        # at any of these event.
        @initialized = true
        console.log "at initialized",@acceptance,@source.uri
        if @acceptance is "accept"
            console.log "accept?"
            @emit "accept"
        else if @acceptance is "decline"
            @emit "decline"
        else
            @emit "determine"
        @emit "initialized"
    containSource:(source)->
        return @source.type is source.type and @source.uri is source.uri
    getInfo:()->
        return {
            @acceptance
            ,@state
            ,@cid
            ,needAuth:@source.needAuth
            ,needPinCode:@source.needPinCode
            ,pinCodeInfo:@source.needPinCode and @source.pinCodeInfo or null
            ,uri:@source.uri
            ,type:@source.type
            ,name:@source.name
        }
    handover:()->
        source = @source
        source.removeAllListeners()
        @destroy()
        return source
    decline:()->
        @acceptance = "decline"
        @emit "decline"
    accept:()->
        @acceptance = "accept"
        if @initialized
            @emit "accept"
    destroy:()->
        console.log "destoried???"
        super()
        @source = null
module.exports = SourceSubscribeManager