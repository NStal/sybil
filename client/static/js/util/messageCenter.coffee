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
class MessageCenter extends Leaf.EventEmitter
    @stringify:(obj)->
        return JSON.stringify(@normalize(obj))
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
        else
            _ = {}
            for prop of obj
                _[prop] = @normalize(obj[prop])
            return _
    @denormalize:(obj)->
        if typeof obj isnt "object"
            return obj
        if obj is null
            return null
        if obj instanceof Array
            return (@denormalize item for item in obj)
        else if obj.__mc_type is "buffer"
            return new Buffer(obj.value,"base64")
        else if obj.__mc_type is "date"
            return new Date(obj.value)
        else
            _ = {}
            for prop of obj
                _[prop] = @denormalize(obj[prop])
            return _
    @parse:(str)->
        json = JSON.parse(str)
        _ = @denormalize json
        return _
    constructor:()->
        @idPool = 1000
        @invokeWaiters = []
        @apis = []
        @timeout = 1000 * 60
        super()
    getInvokeId:()->
        return @idPool++;
    registerApi:(name,handler,overwrite)->
        name = name.trim()
        if not handler
            throw new Error "need handler to work"
        for api,index in @apis
            if api.name is name
                if not overwrite
                    throw new Eror "duplicated api name #{name}"
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
            try
                @handleMessage(message)
            catch e
                @emit "error",e
        @connection.on "message",@_handler
    unsetConnection:()->
        if @connection
            @connection.removeListener("message",@_handler)
        @_handler = null
        @connection = null
        @clearAll()
    response:(id,err,data)->
        message = MessageCenter.stringify({id:id,type:"response",data:data,error:err})
        if not @connection
            @emit "message",message
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
        message = MessageCenter.stringify(req)
        controller = {
            _timer:null
            ,waiter:waiter
            ,timeout:(value)->
                if @_timer
                    clearTimeout @_timer
                @_timer = setTimeout controller.clear,value
            ,clear:(error)=>
                @clearInvokeWaiter waiter.id,error || "timeout"
        }
        
        waiter.controller = controller
        controller.timeout(@timeout)
        if @connection
            try
                @connection.send message
            catch e
                controller.clear("connection not opened")
                return
        return controller
    fireEvent:(name,data)->
        message = MessageCenter.stringify({type:"event",name:name,data:data})
        if @connection
            try
                @connection.send message
            catch e
                return message
        return message
    handleMessage:(message)->
        try
            info = MessageCenter.parse(message)
        catch e
            throw  new Error "invalid message #{message}"
        if not info.type or info.type not in ["invoke","event","response"]
            throw  new Error "invalid message #{message} invalid info type"
        if info.type is "response"
            @handleResponse(info)
        else if info.type is "invoke"
            @handleInvoke(info)
        else if info.type is "event"
            @handleEvent(info)
        else
            throw new Error "invalid message"
    handleEvent:(info)->
        if not info.name
            throw new Error "invalid message #{JSON.stringify(info)}"
        @emit "event/"+info.name,info.data
        
    handleResponse:(info)->
        if not info.id
            throw new Error "invalid message #{JSON.stringify(info)}"
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
            throw new Error "invalid message #{JSON.stringify(info)}"
        target = null
        for api in @apis
            if api.name is info.name
                target = api
                break
        if not target
            return @response(info.id,"#{info.name} api not found")
        target.handler info.data,(err,data)=>
            @response info.id,err,data
    clearAll:()->
        while @invokeWaiters[0]
            waiter = @invokeWaiters[0]
            @clearInvokeWaiter(waiter.id,"abort")
window.MessageCenter = MessageCenter