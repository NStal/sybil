Buffer = Buffer or Array

# MessageCenter Accept a JSON format message
# MessageCenter is designed for 1 to 1 messaging
# 
# FORMATS
# Invoke: {id:'id',type:'invoke',name:'actionName',data:data}
# Event:   {type:'event',name:'eventName',data:data}
# for Invoke we should response something with (err,data) callback
# for Event we only dispatch them to who ever cares but dont return anything
# for Invoke response
# InvokeResponse: {id:'original id',type:'response',data:data,error:err}
# MessageCenter Accept a JSON format message
# MessageCenter is designed for 1 to 1 messaging
# 
# FORMATS
# Invoke: {id:'id',type:'invoke',name:'actionName',data:data}
# Event:   {type:'event',name:'eventName',data:data}
# for Invoke we should response something with (err,data) callback
# for Event we only dispatch them to who ever cares but dont return anything
# for Invoke response
# InvokeResponse: {id:'original id',type:'response',data:data,error:err}
#
# Strategies:
# When it's a connection error, fail silently. (connection independant,
# you should be able to handle it)
#
# When it's an broken data format, emit an error. unlikely.
#
# In case of silent, invoke should eventually fail due to a timeout.
# Other type of RPC are designed for totally not fail concerned.
EventEmitter = Leaf.EventEmitter
class MessageCenter extends EventEmitter
    @stringify:(obj)->
        return JSON.stringify @normalize obj
    @normalize:(obj)->
        if typeof obj isnt "object"
            return obj
        if obj instanceof Array
            return (@normalize item for item in obj)
        if obj is null
            return null
        else if obj instanceof Buffer
            return {__mc_type:"buffer",value:obj.toString("base64")}
        else if obj instanceof Date
            return {__mc_type:"date",value:obj.getTime()}
        else if obj instanceof WritableStream
            return {__mc_type:"stream",id:obj.id}
        else
            _ = {}
            for prop of obj
                _[prop] = @normalize(obj[prop])
            return _
    @denormalize:(obj,option = {})->
        if typeof obj isnt "object"
            return obj
        if obj is null
            return null
        if obj instanceof Array
            return (@denormalize(item,option) for item in obj)
        else if obj.__mc_type is "buffer"
            return new Buffer(obj.value,"base64")
        else if obj.__mc_type is "date"
            return new Date(obj.value)
        else if obj.__mc_type is "stream"
            return new ReadableStream(option.owner,obj.id)
        else
            _ = {}
            for prop of obj
                _[prop] = @denormalize(obj[prop],option)
            return _
    @parse:(str,option)->
        json = JSON.parse(str)
        _ = @denormalize json,option
        return _
    constructor:()->
        @idPool = 1000
        @invokeWaiters = []
        @apis = []
        @timeout = 1000 * 60
        @streams = []
        super()
    stringify:(data)->
        # maybe add size limit check in future
        return MessageCenter.stringify(data)
    getInvokeId:()->
        return @idPool++;
    registerApi:(name,handler,overwrite)->
        name = name.trim()
        if not handler
            throw new Error "need handler to work"
        for api,index in @apis
            if api.name is name
                if not overwrite
                    throw new Error "duplicated api name #{name}"
                else
                    # overwrite
                    @apis[index] = null
        @apis = @apis.filter (api)->api
        @apis.push {name:name,handler:handler}
    setConnection:(connection)->
        @connection = connection
        @_handler = (message)=>
            if @connection isnt connection
                # connection changed.. i can't handle you
                return
            @handleMessage(message)
        @connection.on "message",@_handler
    unsetConnection:()->
        if @connection
            @connection.removeListener("message",@_handler)
        @_handler = null
        @connection = null
        for stream in @streams.slice()
            stream.close()
        @emit "unsetConnection"
        @clearAll()
    response:(id,err,data)->
        message = @stringify({id:id,type:"response",data:data,error:err})
        if not @connection
            # fail silently
            # @emit "message",message
            return
        try
            @connection.send message
        catch e
            return
    invoke:(name,data,callback)->
        callback = callback or ()->true
        req = {
        type:"invoke"
        ,id:@getInvokeId()
        ,name:name
        ,data:data
        }
        # date is used for check timeout or clear old broken waiters
        waiter = {request:req,id:req.id,callback:callback,date:new Date}
        @invokeWaiters.push waiter
        message = @stringify(req)
        controller = {
            _timer:null
            ,waiter:waiter
            ,timeout:(value)->
                if @_timer
                    clearTimeout @_timer
                @_timer = setTimeout controller.clear,value
            ,clear:(error)=>
                @clearInvokeWaiter waiter.id,error || new Error "timeout"
        }
        
        waiter.controller = controller
        controller.timeout(@timeout)
        if @connection
            try
                @connection.send message
            catch e
                controller.clear(e)
                return
        else
            controller.clear(new Error "connection not set")
        return controller
    fireEvent:(name,params...)->
        message = @stringify({type:"event",name:name,params:params})
        if @connection
            try
                @connection.send message
            catch e
                return message
        return message
    handleMessage:(message)->
        try
            info = MessageCenter.parse(message,{owner:this})
        catch e
            @emit "error",new Error "invalid message #{message}"
            return
        if not info.type or info.type not in ["invoke","event","response","stream"]
            @emit "error",new Error "invalid message #{message} invalid info type"
            return
        if info.type is "stream"
            @handleStreamData(info)
        else if info.type is "response"
            @handleResponse(info)
        else if info.type is "invoke"
            @handleInvoke(info)
        else if info.type is "event"
            @handleEvent(info)
        else
            @emit "error",new Error "invalid message"
    handleEvent:(info)->
        if not info.name
            @emit "error",new Error "invalid message #{JSON.stringify(info)}"
        args = ["event/"+info.name].concat info.params or []
        @emit.apply this,args
        
    handleResponse:(info)->
        if not info.id
            @emit "error",new Error "invalid message #{JSON.stringify(info)}"
        found = @invokeWaiters.some (waiter,index)=>
            if waiter.id is info.id
                @clearInvokeWaiter(info.id,null);
                waiter.callback(info.error,info.data)
                return true
            return false
        # if not found it may either a timeout error
        # just fail silently
        return found
    clearInvokeWaiter:(id,error)->
        @invokeWaiters = @invokeWaiters.filter (waiter)->
            if waiter.id is id
                if waiter.controller and waiter.controller._timer
                    clearTimeout(waiter.controller._timer)
                if error
                    waiter.callback(error)
                return false
            return true
    handleInvoke:(info)->
        if not info.id or not info.name
            @emit "error",new Error "invalid message #{JSON.stringify(info)}"
        target = null
        for api in @apis
            if api.name is info.name
                target = api
                break
        if not target
            return @response(info.id,{message:"#{info.name} api not found",code:"ERRNOTFOUND"})
        target.handler info.data,(err,data)=>
            @response info.id,err,data
    clearAll:()->
        while @invokeWaiters[0]
            waiter = @invokeWaiters[0]
            @clearInvokeWaiter(waiter.id,new Error "abort")
    createStream:()->
        stream = new WritableStream(this)
        return stream
    handleStreamData:(info)->
        if not info.id
            @emit "error",new Error "invalid stream data #{JSON.stringify(info)}"
        @streams.some (stream)->
            if stream.id is info.id
                if info.end
                    stream.close()
                else 
                    stream.emit "data",info.data
                return true
    transferStream:(stream)->
        # currently we just transfer what they give ,
        # no matter it will block the connection or not.
        # since the user side can always use and async method to write
        # to the stream, to gain an none blocked connection.
        #
        # we may build a more durable stream implementation
        # in cost of performance, by ensure the data recieved before send the
        # next chunk of data. this will slow down the speed at high latency network
        # of course.
        # 
        if @connection
            try
                # data should already been encoded
                if stream.isEnd
                    return
                while stream.buffers.length > 0
                    data = stream.buffers.shift()
                    @connection.send data
            catch e
                # connection problem fail silently
                return
    endStream:(stream)->
        @transferStream stream
        if @connection
            try
                @connection.send JSON.stringify({id:stream.id,end:true,type:"stream"})
                stream.isEnd = true
            catch e
                # connection problem fail silently
                return
    addStream:(stream)->
        if stream not in @streams
            @streams.push stream
    removeStream:(stream)->
        index = @streams.indexOf stream
        if index < 0
            return
        @streams.splice(index,1)
    @isReadableStream = (stream)->
        return stream instanceof ReadableStream
    @isWritableStream = (stream)->
        return stream instanceof WritableStream
class ReadableStream extends EventEmitter
    # maybe some better id implementation with smaller size
    # and less posibility to conflict between reconnect/reconstruction
    constructor:(@messageCenter,@id)->
        super()
        @messageCenter.addStream(this)
    close:()->
        if @isClose
            return
        @isClose = true
        @emit "end"
        @messageCenter.removeStream this
class WritableStream extends EventEmitter
    @id = 1000
    constructor:(@messageCenter)->
        super()
        @buffers = []
        @index = 0
        @id = WritableStream.id++
        @messageCenter.once "unsetConnection",()=>
            @isEnd = true
    write:(data)->
        if @isEnd
            throw new Error "stream already end"
        if not data
            return
        # may throw error when stringify non supported 
        @buffers.push @messageCenter.stringify {id:this.id,index:@index++,data:data,type:"stream"}
        @messageCenter.transferStream this
    end:(data)->
        if @isEnd
            throw new Error "stream already end"
        @write data
        @messageCenter.endStream this
        if process and process.nextTick
            process.nextTick ()=>@emit "finish"
        else
            setTimeout (()=>@emit "finish"),0
module.exports = MessageCenter
module.exports.MessageCenter = MessageCenter
