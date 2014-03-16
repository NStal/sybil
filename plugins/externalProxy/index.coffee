MessageCenter = require("message-center").MessageCenter
ws = require "ws"
httpUtil = require "../../common/httpUtil.coffee"
WebSocket = ws
MC = new MessageCenter();
host = "puff"
port = 3007
username = "nstal"
secret = "hello"
connection = null
sybilHttpPort = 3006

exports.requires = ["webApi"]
exports.register = (_,callback)->
    sybil = require("../../core/sybil.coffee")
    sybilHttpPort = sybil.settings.webApiPort or 3006
    connection = new CenterServerConnection()
    connection.connect()
    callback(null,connection)
class CenterServerConnection
    constructor:()->
        @messageCenter = new MessageCenter()
        @reconnectInterval = 1000
        @setupProtocol()
    log:(args...)->
        args.unshift "External Proxy: "
        console.log.apply console,args
    connect:()->
        if @reconnectTimer
            clearTimeout @reconnectTimer
            @reconnectTimer = null
            
        @log "connect..."
        @connection = new WebSocket("ws://#{host}:#{port}")
        @connection.on "error",(err)=>
            @log "fail to connect to server",err
            @reconnectTimer = setTimeout @connect.bind(this),@reconnectInterval
        @connection.on "open",()=>
            @log "open connection"
            @messageCenter.setConnection(@connection)
            @messageCenter.invoke "auth",{username:username,secret:secret},()=>
                @isReady = true
            @connection.on "close",()=>
                if @isReady
                    @isReady = false
                @reconnectTimer = setTimeout @connect.bind(this),@reconnectInterval
    connectSybil:(callback)=>
        if @sybilConnection
            old = @sybilConnection
            @sybilConnection = null
            old.close()
        conn = new WebSocket("ws://localhost:#{sybilHttpPort}")
        @sybilConnection = conn
        hasConnect = null
        console.log "connect just"
        @sybilConnection.on "open",()=>
            @log "~~~open"
            hasConnect = true
            callback()
        @sybilConnection.on "error",(err)=>
            @log err
            if hasConnect
                callback err
                return
            @messageCenter.fireEvent "error",err
        @sybilConnection.on "close",()=>
            if conn is @sybilConnection
                @sybilConnection = null
        @sybilConnection.on "message",(message)=>
            @messageCenter.fireEvent "proxyData",message
    disconnectSybil:(callback)=>
        if @sybilConnection
            old = @sybilConnection
            @sybilConnection = null
            old.close()
            callback()
        callback("not connected")
    setupProtocol:()=>
        @messageCenter.registerApi "connect",(_,callback)=>
            @log "connect required"
            if @sybilConnection
                callback "already connect"
                return
            @connectSybil (err)=>
                callback err
        @messageCenter.registerApi "disconnect",(_,callback)=>
            @log "disconnect required"
            if not @sybilConnection
                callback "not connected"
                return
            @disconnectSybil (err)=>
                callback err
        @messageCenter.on "event/proxyData",(data)=>
            if @sybilConnection
                @sybilConnection.send data
                return
            #@messageCenter.fireEvent "error","not connected"
        @messageCenter.registerApi "httpGet",(query,callback)=>
            httpUtil.httpGet {url:"http://localhost:#{sybilHttpPort}/#{query.path}",noQueue:true},(err,res,data)=>
                callback null,{headers:res.headers,content:data}
        