MessageCenter = require("message-center").MessageCenter
Node = require("./node.coffee")
EventEmitter = require("events").EventEmitter
WebSocket = require("ws")
WebSocketServer = WebSocket.Server
async = require "async"
console = require("../../../common/logger.coffee").create("P2p/NodeProvider")
class NodeProvider extends EventEmitter
    constructor:()->
        super()
        @nodes = []
    discover:(callback)->
        callback("not implemented")
    attachNode:(node)->
        node.once "close",()=>
            for item,index in @nodes
                if item is node
                    @nodes.splice index,1
                    return

class Address
    constructor:()->
        true
    toString:()->
        throw new Error "address not implemented"
module.exports = NodeProvider;
# When serverl different type of connection are setup between 2 node.
# We don't kill connection at connection level
# We will kill connection at node level
# After have auth setup, we can now choose one good connection and drop the others
# An I have to implement a switch connection method for message center
class DirectConnectionProvider extends NodeProvider
    class DirectAddress extends Address
        @test = (address)->
            urlModule = require("url")
            urlObject = urlModule.parse(address.toString())
            return urlObject.protocol is "sybil:" and urlObject.host
        @parse = (address)->
            if not @test address
                throw new Error "invalid direct node connection address format"
            urlModule = require("url")
            urlObject = urlModule.parse(address.toString())
            return new DirectAddress urlObject.hostname,urlObject.port or 5000
        constructor:(@host,@port)->
            super()
        toString:()->
            return "sybil://#{@host}:#{@port}/"
    class DirectConnection extends EventEmitter
        constructor:(@address)->
            super()
            @connectState = "close"
            @connect()
        connect:()->
            if @connectState isnt "close"
                return
            @connectState = "connecting"
            @websocket = new WebSocket("ws://#{@address.host}:#{@address.port}")
            @websocket.on "open",()=>
                @connectState = "connected"
                @createDate = new Date()
                @emit "open"
            @websocket.on "message",(data)=>
                @emit "message",data
            @websocket.on "error",(err)=>
                @emit "error",err
                @close()
            @websocket.once "close",()=>
                @close()
        send:(message)->
            if @websocket and @connectState is "connected"
                @websocket.send message
                return
            throw new Error "connection not open"
        close:()->
            if @connectState is "close"
                return
            @connectState = "close"
            if @websocket
                @websocket.close()
                @websocket.removeAllListeners()
            @websocket = null
            @emit "close"
    class PassiveDirectAddress extends Address
        @test = (address)->
            urlModule = require("url")
            urlObject = urlModule.parse(address.toString())
            return urlObject.protocol is "sybil:" and urlObject.hostname and urlObject.path is "/passive"
        @parse = (address)->
            if not @test address
                throw new Error "invalid direct node connection address format"
            urlModule = require("url")
            urlObject = urlModule.parse(address.toString())
            return new PassiveDirectAddress urlObject.hostname
        constructor:(@host)->
            super()
        toString:()->
            return "sybil://#{@host}/passive"
    class DirectPassiveConnection extends EventEmitter
        constructor:(ws)->
            super()
            @ws = ws
            @address = new PassiveDirectAddress(@ws._socket.remoteAddress)
            @close = @close.bind(this)
            @ws.on "close",@close
            @ws.on "error",@close
            @createDate = new Date()
            @ws.on "message",(message)=>
                @emit "message",message
        send:(message)->
            @ws.send message
        close:()->
            if @isClose
                return
            @isClose = true
            @ws.removeListener "error",@close
            @ws.removeListener "close",@close
            @ws = null
            @emit "close"
    class NodeInfoServerInterface extends EventEmitter
        constructor:(@host,@port)->
            super()
            @messageCenter = new MessageCenter()
            @connectState = "close"
            @readyCallbacks = []
        ready:(callback)->
            if @connectState is "connected"
                callback()
                return
            @readyCallbacks.push callback
        connect:(callback = ()->true)->
            if @connectState isnt "close"
                if @connectState is "connecting"
                    @readyCallbacks.push callback
                else
                    callback()
                return
            @connectState = "connecting"
            @connection = new WebSocket("ws://#{@host}:#{@port}")
            @connection.once "open",()=>
                @messageCenter.setConnection @connection
                @connectState = "connected"
                for _callback in @readyCallbacks
                    _callback()
                @readyCallbacks = []
                callback null
                callback = null
            @connection.once "error",(err)=>
                for _callback in @readyCallbacks
                    _callback(err)
                @readyCallbacks = []
                if callback
                    callback err
                callback = null
                @close()
            @connection.on "close",()=>
                if @connectState is "close"
                    return
                @close()
        close:()->
            @connectState = "close"
            @connection.close()
            @messageCenter.unsetConnection()
            @connection.removeAllListeners()
            @connection = null
    constructor:(port)->
        @name = "DirectProvider"
        super()
        @port = port or 5000;
        @nodeInfoServers = []
        @connectionMaps = {}
        @server = new WebSocketServer({port:@port,host:"0.0.0.0"})
        @server.on "connection",(connection)=>
            passiveConnection = new DirectPassiveConnection(connection)
            node = new Node(passiveConnection)
            @attachNode node
            @emit "node",node
    addServer:(host,port)->
        serverInterface = new NodeInfoServerInterface(host,port)
        @nodeInfoServers.push serverInterface
        return serverInterface
    discover:(callback = ()->true)->
        async.eachSeries @nodeInfoServers,((server,done)=>
            @discoverAtServer server,()=>
                done()
            ),(err)=>
                callback()
    discoverAtServer:(nodeServer,callback = ()->true)->
        nodeServer.ready (err)=>
            if err
                callback err
                return
            # checkin by the way...
            if nodeServer.connectState isnt "connected"
                callback "network error"
                return
            nodeServer.messageCenter.invoke "checkIn",@port,()->
                true
            nodeServer.messageCenter.invoke "getNodes",{count:50},(err,records=[])=>
                if err
                    callback(err)
                    return
                async.eachSeries records,((record,done)=>
                    @discoverAt record.address,()->
                        done()
                    ),()=>
                        callback()
        if nodeServer.connectState isnt "connected"
            nodeServer.connect()
    discoverAt:(address,callback)->
        if not DirectAddress.test address
            callback "invalid address"
            return
        directAddress = DirectAddress.parse(address)
        if @connectionMaps[directAddress.toString()]
            callback("already connected")
            return;
        connection = new DirectConnection(directAddress)
        @connectionMaps[directAddress.toString()] = connection
        connection.on "open",()=>
            connection.removeAllListeners("error")
            node = new Node(connection)
            @attachNode node
            @emit "node",node
            callback null,node
        connection.once "error",(err)->
            connection.close()
            callback err
        connection.on "close",()=>
            delete @connectionMaps[directAddress.toString()];
class HubProvider extends NodeProvider
    class HubVirtualAddress extends Address
        @test = (address)->
            urlModule = require("url")
            urlObject = urlModule.parse(address.toString())
            # should be like sybil-hub://<host>:<port>/<virtualIndex>
            return urlObject.protocol is "sybil-hub:" and urlObject.hostname and urlObject.port and urlObject.path and urlObject.path.replace("/","").trim()
        @parse = (address)->
            if not @test address
                throw new Error "invalid hub virtual address format"
            urlModule = require("url")
            urlObject = urlModule.parse(address.toString())
            return new HubVirtualAddress urlObject.hostname,urlObject.port,urlObject.path.replace("/","").trim()
        constructor:(@host,@port,@virtualIndex)->
            super()
        toString:()->
            return "sybil-hub://#{@host}:#{@port}/#{@virtualIndex}"
        
    class HubVirtualConnection extends Node.Connection
        constructor:(@address,@server)->
            super()
            @close = @close.bind(this)
            console.assert @address.host is @server.host
            console.assert @address.port is @server.port
            @server.on "close",@close
            @server.on "error",@close
            @connectionState = "close"
            
        connect:(callback = ()->true)->
            if @connectionState is "connecting"
                callback new Error "already connecting"
                return
            @connectionState = "connecting"
            @server.messageCenter.invoke "handleVirtualMessage",{type:"connect",virtualIndex:@address.virtualIndex},(err)=>
                if err
                    @emit "err"
                    callback err
                    @close()
                    return
                @connectionState = "open"
                @createDate = new Date()
                @emit "open"
                callback()
                return
        handleMessage:(message)->
            @emit "message",message.toString()
        send:(message)->
            if @connectionState isnt "open"
                throw new Error "not open"
            @server.messageCenter.invoke "handleVirtualMessage",{type:"message",message:message.toString(),virtualIndex:@address.virtualIndex},(err)=>
                if err
                    console.debug err
                    @close()
        close:()->
            if @connectionState is "close"
                return
            @connectionState = "close"
            @server.removeListener "close",@close
            @server.removeListener "error",@close
            try
                @server.messageCenter.invoke "handleVirtualMessage",{type:"close",virtualIndex:@address.virtualIndex},(err)->true
            catch e
                # fail silently
                true
            @emit "close"
    class HubServer extends EventEmitter
        constructor:(@host,@port = 57611)->
            super()
            @nodes = []
            @routes = {}
            @connectState = "close"
            @messageCenter = new MessageCenter()
            @messageCenter.registerApi "handleVirtualMessage",(message,callback)=>
                if not message.virtualIndex
                    # there must be something wrong with the server
                    callback "invalid virtual index"
                    console.error message
                    @emit "error",new Error "broken protocol"
                    return
                if message.type is "connect"
                    # retrun success
                    callback()
                    if !@routes[message.virtualIndex]
                        address = new HubVirtualAddress(@host,@port,message.virtualIndex)
                        connection = new HubVirtualConnection(address,this)
                        connection.connectionState = "open"
                        @routes[message.virtualIndex] = connection 
                        @attachConnection(connection)
                        node = new Node(connection)
                        connection.node = node
                        @attachNode(node)
                        @emit "node",node
                    return
                if message.type is "close"
                    callback()
                    connection = @routes[message.virtualIndex]
                    if connection
                        connection.close()
                    return
                if message.type is "message"
                    connection = @routes[message.virtualIndex]
                    if not connection
                        callback "not connect"
                        return
                    connection.handleMessage(message.message or "")
                    callback null
                    return
        attachNode:(node)->
            NodeProvider.prototype.attachNode.call(this,node);
        discover:(callback = ()->true)->
            console.debug "discover start with virtual index"
            if @isDiscovering
                callback()
                return
            console.log "inside"
            @isDiscovering = true
            @messageCenter.invoke "getSomeVirtualIndex",{},(err,indexes)=>
                console.log("try get virtual index",err,indexes)
                if err
                    @isDiscovering = false
                    callback()
                    return
                if not indexes or not (indexes instanceof Array)
                    @isDiscovering = false
                    callback()
                    return
                async.eachLimit indexes,5,((index,done)=> 
                    @createNode index,(err)->
                        done()
                    ),(err)=>
                        @isDiscovering = false
                        callback()
                        
        createNode:(virtualIndex,callback)->
            @createConnection virtualIndex,(err,connection)=>
                if err
                    callback err
                    return
                node = new Node(connection)
                @attachNode node
                @emit "node",node
                callback null,node
        createConnection:(virtualIndex,callback)->
            if @routes[virtualIndex]
                callback "exists"
                return
            address = new HubVirtualAddress(@host,@port,virtualIndex)
            connection = new HubVirtualConnection(address,this)
            @attachConnection(connection)
            @routes[virtualIndex] = connection
            connection.connect (err)=>
                if err
                    callback err
                    return
                callback null,connection
        attachConnection:(connection)->
            connection.once "close",()=>
                delete @routes[connection.address.virtualIndex]
        connect:()->
            if @connectState is "connecting"
                throw new Error "already connecting"
            
            if @connection
                @connection.close()
            @connectState = "connecting"
            if @connection
                @connection.close()
                @connection = null
            @connection = new WebSocket "ws://#{@host}:#{@port}/"
            console.log "create new connection"
            @connection.once "open",()=>
                @connectState = "connected"
                console.log "connected!"
                @messageCenter.setConnection(@connection)
                @initServerState()
            @connection.once "close",()=>
                @close()
            @connection.once "error",()=>
                @close()
        close:()->
            if @connectState is "close"
                return
            console.log("...close")
            @messageCenter.unsetConnection()
            @connection.removeAllListeners()
            @connection = null
            @isDiscovering = false
            @connectState = "close"
            @emit "close"
        initServerState:()->
            if not @connected
                return
            @messageCenter.invoke "getVirtualIndex",null,(err,data)=>
                if err or not data
                    @emit "error",err or new Error "fail to get current virtual index"
                else
                    @address = new HubVirtualAddress(@host,@port,data.virtualIndex)
                    @emit "ready"
                    
    @HubVirtualAddress = HubVirtualAddress
    @HubServer = HubServer
    constructor:()->
        @name = "HubProvider"
        @isClose = false
        @servers = []
        super()
    addServer:(host,port = 57611)->
        console.debug "add server"
        server = new HubServer(host,port)
        server.on "error",(err)=>
            console.error err
            server.close()
        server.on "node",(node)=>
            node.provider = this
            @emit "node",node
        maxReconnectInterval = 60 * 1000 * 30
        minReconnectInterval = 10 * 1000
        server.on "close",()=>
            console.log host,port
            connect = server.connect.bind(server)
            server.nextReconnectInterval = server.nextReconnectInterval and Math.min(server.nextReconnectInterval*2,maxReconnectInterval) or minReconnectInterval
            # there are no way to stop
            setTimeout connect,server.nextReconnectInterval
            console.debug "server close try reconnect after #{server.nextReconnectInterval}"
        server.on "ready",()=>
            console.debug "discover at server sybil-hub://#{server.host}:#{server.port} on ready"
            server.discover()
        server.connect()
        @servers.push server
        return server
    removeServer:(server)->
        for item,index in @servers
            if server is item
                server.removeAllListeners()
                server.close()
                @servers.splice(index,1)
                return true
        
    addressIsConnect:(address)->
        if not @testAddress(address)
            return false
        address = HubVirtualAddress.parse(address)
        found = @servers.some (server)->
            if server.host is address.host and server.port is address.port and server.routes[address.virtualIndex]
                return true
        return found
    testAddress:(address)->
        return HubVirtualAddress.test address
    discoverAt:(address = "",callback = ()->)->
        urlModule = require("url")
        urlObject = urlModule.parse(address.toString())
        if not urlObject.hostname or urlObject.port
            callback new Error "invalid address"
            return
        if urlObject.protocol isnt "sybil-hub:"
            callback new Error "invalid protocol"
            return
        urlObject.path = urlObject.path or ""
         
        virtualIndex = urlObject.path.replace("/").trim()
        if not virtualIndex
            callback new Error "invalid virtual index"
            return
        for server in @servers
            if server.hsot is host and server.port is port
                # server may not be ready but I won't connect it
                # because the server may at broken state and may be waiting
                # for another scheduled reconnect. so just consider the server
                # broken and return error here
                server.createNode virtualIndex,(err,node)->
                    callback err,node
                return
        server = @addServer(host,port)
        server.once "ready",()->
            server.createNode virtualIndex,(err,node)->
                callback err,node
    discover:(callback = ()->true)->
        console.log "discover with servers",@servers.length
        async.each @servers,((server,done)->
            server.discover ()->
                done()
            ),()->
                callback()
    close:()->
        if @isClose
            return
        @isClose = true
        @servers.slice(0).forEach (server)=>
            @removeServer(server)
        @emit "close"
NodeProvider.HubProvider = HubProvider
NodeProvider.DirectConnectionProvider = DirectConnectionProvider