
class ServerConnection extends Leaf.EventEmitter
    constructor:()->
        super()
    connect:(path)->
        @websocket = new WebSocket(path)
        @websocket.onopen = ()=>
            @isReady = true
            @emit "ready"
        @websocket.onclose = ()=>
            @emit "close"
            @isReady = false
        @websocket.onmessage = (message)=>
            @emit "message",message.data
    send:(msg)->
        @websocket.send msg
    ready:(callback)->
        if @isReady
            callback()
        @on "ready",callback

window.ServerConnection = ServerConnection