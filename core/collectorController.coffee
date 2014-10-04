EventEmitter = (require "events").EventEmitter
Errors = require "./errors.coffee"
Database = require "./db.coffee"
async = require "async"
console = global.env.logger.create(__filename)
# save source info to db
# restore source via info from db
# subscribe test/subscribe sources
# Initiative Interactions
# 1. accept done
# 2. decline done
# 3. detect done
# 4. auth done
# 5. setPinCode done
# 6. unsubscribe
# 
# Passive Interactions
# 1. "requireAuth" done => candidate/subscribe done
# 2. "requirePinCode" => candidate/requireAuth done
# 3. "subscribe" => candidate/subscribe done
# 4. "archive" => "archive" done
# 5. "fail" => candidate/fail done
# 
class CollectorController extends EventEmitter
    constructor:(@collector)->
        super()
        
        @collector.on "subscribe",(source)=>
            Database.saveSource source,(err,source)=>
                if err
                    console.error err
                    return
                console.log source.unreadCount,"?"
                @emit "subscribe",source
        ssm = @collector.sourceSubscribeManager
        ssm.on "requireLocalAuth",(info)=>
            console.log "SSM require auth",info
            @emit "candidate/requireAuth",info
        ssm.on "requirePinCode",(info)=>
            @emit "candidate/requirePinCode",info
        ssm.on "fail",(info)=>
            @emit "candidate/fail"
        @collector.sourceManager.on "archive",(archive)=>
            @emit "archive",archive
        @collector.sourceManager.on "source/modify",(source)=>
            Database.updateSource source,()=>
                @emit "source/modify",source
        @collector.sourceManager.on "source/requireLocalAuth",(source)=>
            @emit "source/requireLocalAuth",source
        @collector.sourceManager.on "source/authorized",(source)=>
            @emit "source/authorized",source
        
        return
    initCollector:(callback = ()-> )->
        console.log "start sync unread count"
        @syncUnreadCount (err)=>
            console.log "done sync unread count"
            if err
                callback err
                return
            console.log "start init source"
            @initLoadSource (err)=>
                console.log "done init source"
                
                if err
                    callback err
                callback
                
    unsubscribe:(guid,callback)->
        @removeSource guid,callback
    removeSource:(guid,callback = ()->)->
        source = @collector.removeSource guid
        if source
            Database.removeSource guid,(err)=>
                console.log "remove source",guid
                @emit "unsubscribe",source
                callback err
        else
            callback new Errors.NotFound()
    initLoadSource:(callback = ()-> )->
        Database.getSources (err,sourceInfos)=>
            if err
                callback err
                return
            for info in sourceInfos
                @collector.loadSource info
            callback null
    syncUnreadCount:(callback = ()-> )->
        Database.updateUnreadCount {},(err)->
            callback err
    detectStream:(uri)->
        return @collector.sourceSubscribeManager.detectStream(uri)
    authCandidate:(cid,username,secret,callback)->
        @collector.sourceSubscribeManager.setAdapterLocalAuth cid,username,secret,callback
    setCandidatePinCode:(cid,pinCode,callback)->
        @collector.sourceSubscribeManager.setAdapterPinCode cid,pinCode,callback
    acceptCandidate:(cid,callback)->
        @collector.sourceSubscribeManager.accept cid,callback
    declineCandidate:(cid,callback)->
        @collector.sourceSubscribeManager.decline cid,callback
    authSource:(guid,username,secret,callback)->
        @collector.sourceManager.setSourceLocalAuth guid,username,secret,callback
    forceUpdateSource:(guid,callback)->
        @collector.sourceManager.forceUpdateSource guid,callback
module.exports = CollectorController


