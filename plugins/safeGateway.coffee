EventEmitter = require("events").EventEmitter
http = require("http")
ws = require "ws"
WebSocket = ws
express = require("express")
settings = require("../settings.coffee")
httpUtil = require("../common/httpUtil.coffee")

exports.requires = ["webApi"]
exports.register = (dep,callback)->
    gateway = new SafeGateway()
    gateway.on "ready",()->
        # it's ok to remove error here
        # because error event should only listened by this
        # register script
        gateway.removeAllListeners "error"
        callback null,gateway
    gateway.once "error",(err)->
        callback err
    gateway.setup()

class WebApiInterface extends EventEmitter
    constructor:()->
        super()
        @buffers = []
        @host = settings.webApiHost or "localhost"
        @port = settings.webApiPort or 3107
        @connection = new WebSocket("ws://#{@host}:#{@port}")
        @connection.on "open",()=>
            @connection.isReady = true
            for message in @buffers
                @connection.send message
            @buffers = []
        @connection.on "error",()=>
            @close()
        @connection.on "close",()=>
            @close()
        @connection.on "message",(msg)=>
            @emit "message",msg
    close:()->
        if @isClose
            return
        @isClose = true
        if @connection
            @connection.close()
        @connection.removeAllListeners()
        @connection = null
        @emit "close"
    send:(message)->
        if @connection and @connection.isReady
            @connection.send message
        else
            @buffers.push message
    @getRequest = (path,callback)->
        @host = settings.webApiHost or "localhost"
        @port = settings.webApiPort or 3107
        httpUtil.httpGet {
            noQueue:true
            ,url:"http://#{@host}:#{@port}#{path}"
            ,useStream:true
            },(err,res,stream)=>
                callback err,res,stream
class SafeGateway extends EventEmitter
    constructor:()->
        super()
        @username = settings.safeGatewayUsername or "sybil"
        @password = settings.safeGatewayPassword or "libys"
    checkBasicAuthHeader:(value)->
        if not value
            return false
        kv = value.split(/\s/ig)
        if kv[0].toLowerCase() isnt "basic"
            return false
        if new Buffer(kv[1],"base64").toString().trim() is "#{@username}:#{@password}"
            return true
        return false
        
        
    setup:()->
        @host = @_getExternalIp()
        #todo check port availability
        @port = settings.webApiPort or 3107
        if not @host
            @emit "error","No valid external host"
        @app = express()
        @httpServer = http.createServer(@app)
        @websocketServer = new ws.Server({server:@httpServer})
        @websocketServer.on "connection",(connection)=>
            @setupConnection(connection)
        @app.use express.cookieParser()
        @app.get "*",(req,res)=>
            if not @checkBasicAuthHeader req.headers["authorization"]
                res.status(401)
                res.setHeader "WWW-Authenticate",'Basic realm="your username and password"'
                res.end("Authorization required!")
                return
                
            WebApiInterface.getRequest req.path,(err,apiRes,stream)->
                if err
                    res.status(503)
                    res.end("server error")
                    return
                
                if not req.cookies.basicAuth
                    res.cookie("basicAuth",req.headers["authorization"])
                res.writeHead apiRes.statusCode,apiRes.headers
                stream.pipe(res)
        
        @httpServer.listen @port,@host,()=>
            @emit "ready"
    setupConnection:(connection)->
        req = connection.upgradeReq
        cookies = require("cookie").parse(req.headers.cookie)
        if not @checkBasicAuthHeader cookies.basicAuth
            connection.close()
            return
        inf = new WebApiInterface()
        connection.inf = inf
        inf.on "message",(message)->
            try
                connection.send message
            catch e
                inf.close()
        inf.on "close",()->
            connection.close()
        connection.on "message",(message)->
            try
                inf.send message
            catch e
                connection.close()
                inf.close()
        connection.on "close",()->
            inf.close()
            connection.inf = null
    _getExternalIp:()->
        ip = settings.safeGatewayIp or null
        if ip and ip isnt "auto"
            return ip
        infs = require("os").networkInterfaces()
        for name of infs
            inf = infs[name]
            for address in inf
                if not address.internal and address.family.toLowerCase() is "ipv4"
                    return address.address
        return null

            