ServerConnection = require("/component/serverConnection")
class ConnectionManager extends Leaf.EventEmitter
    constructor:(address)->
        super()
        @connectInterval = 1000
        @connection = new ServerConnection()
        @connection.on "connect",()=>
            @emit "connect"
        @connection.on "disconnect",()=>
            @emit "disconnect"
            console.debug "reconnect"
            setTimeout @connection.reconnect.bind(@connection),500
    ready:(args...)->
        @connection.ready.apply @connection,args
    start:()->
        if window.location.protocol is "https:"
            wsProtocol = "wss:"
        else
            wsProtocol = "ws:"
        console.debug "connect at","#{wsProtocol}//#{window.location.hostname}:#{window.location.port}#{window.location.pathname}"
        @connection.connect("#{wsProtocol}//#{window.location.hostname}:#{window.location.port}#{window.location.pathname}")

module.exports = ConnectionManager
