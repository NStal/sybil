# SubscribeAssistant will try to detect stream from the uri.
# open and SubscribeAdapterTerminal for each detect stream data
# and auto accept if only one uri detected from the stream
App = require "/app"
AdapterTerminal = require "./adapterTerminal"
class SubscribeAssistant extends Leaf.EventEmitter
    constructor:(@uri)->
        super()
        @terminals = []
        App.messageCenter.invoke "detectStream",@uri,(err,stream)=>
            console.debug "get stream",err,stream
            if err
                @emit "error",err
                return
            stream.on "data",(candidate)=>
                console.debug "get candidate",candidate 
                @spawnAdapterTerminal candidate
            stream.on "end",()=>
                console.debug "end stream"
                console.debug @terminals.length,@terminals.map (item)->item.candidate
                if @terminals.length is 0
                    @emit "none"
                else if @terminals.length is 1
                    @terminals[0].accept()
    spawnAdapterTerminal:(candidate)->
        terminal = new AdapterTerminal(candidate)
        @terminals.push terminal
        terminal.once "complete",()=>
            for terminal in @terminals
                if not terminal.isDone
                    return
            @emit "done"

module.exports = SubscribeAssistant