EventEmitter = (require "events").EventEmitter
async = require "async"
SybilInterface = require("sybil-interface")
readline = require "readline"
rl = readline.createInterface({
    input:process.stdin
    ,output:process.stdout
})
class SubscribeTester
    constructor:()->
        @inf = new SybilInterface(3006,"localhost")
        @candidates = []
        @inf.ready ()=>
            @start()
        @serverEvent = new EventEmitter()
        @interactQueue = async.queue(@handleInteractQueue.bind(this),1)
    start:()->
        mc = @inf.messageCenter
        mc.on "event/source",(source)=>
            @serverEvent.emit "subscribe/#{source.uri}",source
        mc.on "event/candidate/requireAuth",(candidate)=>
            @serverEvent.emit "auth/#{candidate.cid}",candidate
        mc.invoke "detectStream","http://weibo.com/",(err,stream)=>
            if err
                throw err
                return
            stream.on "data",(candidate)=>
                console.log "get candidate",candidate
                @serverEvent.once "pinCode/#{candidate.cid}",(data)=>
                    @interactQueue.push {type:"pinCode",detail:data,candidate:candidate}
                @serverEvent.once "auth/#{candidate.cid}",(data)=>
                    @interactQueue.push {type:"auth",detail:data,candidate:candidate}
                if candidate.uri and candidate.uri.indexOf("comment") > 0
                    invokeName = "declineCandidate"
                else
                    invokeName = "acceptCandidate"
                mc.invoke invokeName,candidate.cid,(err,result)=>
                    if err
                        console.error err
                        throw err
                        return
                    if invokeName is "declineCandidate"
                        return
                    @serverEvent.once "subscribe/#{candidate.uri}",(source)=>
                        console.log "subscribe",source.uri,"done!"
                @candidates.push candidate
            stream.on "end",()=>
                console.log "all sent"
    handleInteractQueue:(data,done)->
        console.log "queue",data,done
        if data.type is "auth"
            console.log "require candidates",data.candidate.cid,"authes"
            rl.question "user and password(u:p):",(answer)=>
                console.log {cid:data.candidate.cid,username:"lsnascc01_a21s@163.com",secret:"QWERTY"}
                @inf.messageCenter.invoke "authCandidate",{cid:data.candidate.cid,username:"lsnascc01_a21s@163.com",secret:"QWERTY"},(err)->
                    console.error err,"???"
                    done()
new SubscribeTester()