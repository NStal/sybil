class ServerConnection extends Leaf.EventEmitter
    constructor:()->
        super()
        @connectState = "close"
    connect:(address)-> 
        if @connectState is "connecting"
            return false
        @address = address or @address
        @connectState = "connecting"
        @websocket = new WebSocket(@address)
        @websocket.onopen = ()=>
            @connectState = "connected"
            @emit "connect"
            @emit "ready"
        @websocket.onclose = ()=>
            @close() 
        @websocket.onerror = (err)=>
            @close()
            
        @websocket.onmessage = (message)=>
            @emit "message",message.data
    reconnect:()->
        @connect(@address)
    send:(msg)->
        @websocket.send msg
    ready:(callback)->
        if @connectState is "connected"
            callback()
        @once "ready",callback
    close:()->
        if @connectState is "close"
            return
        @connectState = "close"
        if @websocket
            @websocket.close()
        @websocket = null
        @emit "disconnect"
            
module.exports = ServerConnection