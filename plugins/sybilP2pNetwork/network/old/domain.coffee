EventEmitter = require("events").EventEmitter
class Domain extends EventEmitter
    constructor:(name)->
        if not name
            throw new Error("domain need a name")
        @name = name
        @nodes = []
        @nodeEventListenerMap = {}
        @nodeInvokeListenerMap = {}
        @nodeEventListeners = []
        @nodeInvokeListeners = []
        @removeNode = @removeNode.bind(this)
        super()
    handleNode:(node)->
        return false
    addNode:(node)->
        hasAdd = @nodes.some (item)->
            return item is node
        if hasAdd
            return
        node.retain()
        node._domainRemove = ()=>
            @removeNode(node)
        node.on "close",node._domainRemove
        for event of @nodeEventListenerMap
            @_attachNodeEvent(event,node)
        for name of @nodeInvokeListenerMap
            @_attachNodeInvoke(name,node)
        @nodes.push node
        # we use on add node here
        # because on add node is designed to be overwritten by
        # the subclass or reassign dynamically
        # and we don't want any one to use MY node
        # so there are no "node" event
        @emit "node",node
        if @onAddNode
            @onAddNode node
        
    # Note: remove node won't destroy the connection
    #       but when connection destroyed it should be removed as well.
    removeNode:(node)->
        node.release()
        @nodes = @nodes.filter (item)->item isnt node
        node.removeListener("close",node._domainRemove)
        @emit "offline",node
    boardCast:(name,message)->
        @nodes.forEach (node)->
            node.messageCenter.fireEvent name,message
    listenEvent:(name,callback)->
        if name isnt "*"
            if not @nodeEventListenerMap[name]
                @nodeEventListenerMap[name] = []
            @nodeEventListenerMap[name].push(callback)
            @nodes.forEach (node)=>
                @_attachNodeEvent(name,node) 
        @nodeEventListeners.push {name:name,callback:callback}
    listenInvoke:(name,callback)->
        if name isnt "*"
            if not @nodeInvokeListenerMap[name]
                @nodeInvokeListenerMap[name] = []
            @nodeInvokeListenerMap[name].push(callback)
            @nodes.forEach (node)=>
                @_attachNodeInvoke(name,node)
        @nodeInvokeListeners.push {name:name,callback:callback}
    _handleNodeEvent:(node,name,data,callback)->
        handlers = @nodeEventListeners.slice(0)
        next = ()->
            handler = handlers.shift()
            if not handler
                return
            if handler.name is name or handler.name is "*"
                handler.callback(node,data,next)
            else
                next()
        next()
    _handleNodeInvoke:(node,name,data,callback)->
        handlers = @nodeInvokeListeners.slice(0)
        next = ()->
            handler = handlers.shift()
            if handler
                if handler.name is "*" or handler.name is name
                    handler.callback(node,data,callback,next)
                else
                    next()
            else
                callback("node api not exists")
        next()
    _attachNodeEvent:(event,node)->
        node.listenEvents = node.listenEvents or {}
        if node.listenEvents[event]
            return
        node.listenEvents[event] = true
        node.messageCenter.on "event/"+event,(data)=>
            @_handleNodeEvent(node,event,data)
    _attachNodeInvoke:(name,node)->
        node.listenInvokes = node.listenInvokes or {}
        if node.listenInvokes[name]
            return
        node.listenInvokes[name] = true
        node.messageCenter.registerApi name,(data,callback)=>
            @_handleNodeInvoke(node,name,data,callback)
module.exports = Domain