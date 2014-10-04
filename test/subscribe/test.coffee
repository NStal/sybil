EventEmitter = (require "events").EventEmitter
async = require "async"
SybilInterface = require("sybil-interface")
class SubscribeTester
    constructor:()->
        @inf = new SybilInterface(3006,"localhost")
        @candidates = []
        @inf.ready ()=>
            @start()
        @serverEvent = new EventEmitter()
        @interactQueue = async.queue(@handleInteractQueue.bind(this),1)
    start:()->
        console.log "start"
        mc = @inf.messageCenter
        mc.on "source",(source)=>
            @serverEvent.emit "subscribe/#{source.uri}"
        mc.invoke "detectStream","http://bitinn.net/",(err,stream)=>
            if err
                throw err
                return
            console.log "stream returns"
            stream.on "data",(candidate)=>
                console.log "get candidate",candidate
                @serverEvent.once "pinCode/#{candidate.cid}",(data)=>
                    @interactQueue.push {type:"pinCode",detail:data,candidate:candidate}
                @serverEvent.once "auth/#{candidate.cid}",(data)=>
                    @interactQueue.push {type:"auth",detail:data,candidate:candidate}
                console.log candidate.uri
                if candidate.uri.indexOf("comment") > 0
                    invokeName = "declineCandidate"
                else
                    invokeName = "acceptCandidate"
                mc.invoke invokeName,candidate.cid,(err,result)=>
                    if err
                        console.error err
                        throw err
                        return
                    console.log invokeName,candidate.cid
                    if invokeName is "declineCandidate"
                        console.log "decline",candidate
                        return
                    @serverEvent.once "subscribe/#{candidate.uri}",(source)=>
                        console.log "subscribe",source.uri,"done!"
                @candidates.push candidate
            stream.on "end",()=>
                console.log "all sent"
    handleInteractQueue:(data)->
        
new SubscribeTester()