Provider = require("./provider")

EventEmitter = require("eventex").EventEmitter;
urlModule = require("url")
WebSocket = require("ws")
async = require "async"
# StandardConnection are the most basic and stable connection in sybil network
# the underly transfer protocol are websocket.
# Create a standard connection are not easy. It requires both side have a external IP address and not filtered by the firewall.
class StandardConnection extends Provider.Connection
    constructor:(ws)->
        super()
        # ws should be an opened
        @ws = ws
        @ws.on "message",(data)=>
            @emit "message",data
        @ws.on "error",(err)=>
            @emit "error",err
        @ws.once "close",@close.bind(this)
    cleanup:()->
        if @ws
            # ws should only used by me!
            @ws.removeAllListeners()
            @ws = null
    send:(data,callback = ()->)->
        @ws.send data

class StandardConnectionAddress extends Provider.Address
    @test = (str)->
        urlObject = urlModule.parse(str.toString())
        return urlObject.protocol is "sybil:" and urlObject.hostname and urlObject.path is "/" and urlObject.port
    @parse = (str)->
        if not @test str
            return null
        urlObject = urlModule.parse(str.toString())
        return new StandardConnectionAddress(urlObject.hostname,urlObject.port)
    constructor:(host,port)->
        @host = host
        @port = port
    toString:()->
        # port must be provided
        # path must be /
        # so we may extend this protocol in future by changing the path
        return "sybil://#{@host}:#{@port}/"

class StandardConnectionProvider extends Provider
    @Address = StandardConnectionAddress
    constructor:(port,host)->
        super()
        # we may try to discover from this list
        @potentialAddresses = []
        @activeConnections = []
        @server = new StandardConnectionServer(port,host)
        @server.listenBy this,"connection",(connection)=>
            @_attachConnection(connection)
            @emit "connection",connection
        @createConnectionTimeout = 1000 * 10
    setAddress:(port,host)->
        @server.setAddress port,host
    startListening:()->
        @server.start()
    stopListening:()->
        @server.stop()
    createConnection:(address,callback)->
        if not (address instanceof StandardConnectionAddress)
            address = StandardConnectionAddress.parse(address)
        if not address
            callback new Error "invalid address"
            return
        ws = new WebSocket("ws://#{address.host}:#{address.port}/")
        connectTimer = setTimeout ws.close.bind(ws),@createConnectionTimeout
        ws.once "open",()=>
            # save the address so we may discover it in future
            @addPotentialAddress [address.toString()]
            ws.removeAllListeners()
            connection = new StandardConnection(ws)
            connection.isPassive = false
            connection.address = address
            connection.addressString = address.toString()
            clearTimeout connectTimer
            # emit connection instead of connection/incoming
            @_attachConnection connection
            callback null,connection
        hasClose = false
        ws.once "error",(err)=>
            if hasClose
                return
            hasClose = true
            callback err
        ws.on "close",()=>
            if hasClose
                return
            hasClose = true
            callback new Error "connection failed"
    _attachConnection:(connection)->
        @activeConnections.push connection
        connection.provider = this;
        connection.listenBy this,"close",()=>@_detachConnection(connection)
    _detachConnection:(connection)->
        for item,index in @activeConnections
            if item is connection
                connection.provider = null
                @activeConnections.splice(index,1)
                return
    testAddress:(str)->
        # not a strict test
        # but should be enough to against normal typo
        # (/sybil:\/\/[a-zA-Z1-9][a-zA-Z0-9.]+:[1-9][0-9]+\//ig).test str.toString()
        return StandardConnectionAddress.test str
    addPotentialAddress:(addresses)->
        for address in addresses
            if address not in @potentialAddresses
                @potentialAddresses.push address
    discover:(callback)->
        if @isDiscovering
            callback new Error "already discovering"
            return
        @isDiscovering = true
        invalidAddresses = []
        async.eachLimit @potentialAddresses,10,((address,done)=>
            @createConnection address,(err,connection)=>
                if err
                    invalidAddresses.push address
                    done()
                    return
                @emit "connection",connection
                done()
            ),(done)->

class StandardConnectionServer extends EventEmitter
    constructor:(port,host)->
        super()
        @port = port
        @host = host
    setAddress:(post,host)->
        @port = port
        @host = host
        if @wsServer
            @start()
            @stop()
    start:()->
        if @wsServer
            @stop()
        @wsServer = new (WebSocket.Server)({port:@port,host:@host})
        @wsServer.on "connection",(ws)=>
            connection = new StandardConnection(ws)
            @emit "connection",connection
    stop:()->
        if @wsServer
            @wsServer.close()
            @wsServer = null

module.exports = StandardConnectionProvider
module.exports.Connection = StandardConnection
module.exports.Address = StandardConnectionAddress
