App = require "/app"
portal = require "/component/portal"
async = require "/component/async"
class PortalAdapter extends portal.Adapter
    constructor:()->
        super()
        # according to the /doc/design/serverClientCommunication.md
        # I should notify the parent the about the failure later
        @on "error",(err)=>
            console.error "portal error",err
        @observations = []
    isObserving:(path)->
        for item in @observations
            if item.path is path
                return true
        return false
    observe:(path,callback)->
        ob = {path,callback}
        @observations.push ob
        ob.isApplying = true
        @mc?.invoke "observe",path,(err,results)=>
            ob.isApplying = false
            if not err
                @emit "error",err
                return
            ob.init = true
            ob.callback null,results
    stopObserve:(path,callback)->
        @observations = @observations.filter (ob)->
            if ob.path is path
                @mc?.invoke "stopObserve",ob.path,()->null
                return false
            return true
    setMessageCenter:(mc)->
        @messageCenter = mc
        @mc = mc
        @mc.listenBy this,"event/observe/change",(info)=>@emit "change",info
        @mc.listenBy this,"event/observe/init",(info)=>@emit "init",info
        @mc.listenBy this,"event/observe/delete",(info)=>@emit "delete",info
        @applyObserve (err)->
            if err
                emit "error",err
    applyObserve:(callback = ()->)->
        hasError = false
        errors = []
        total = @observations.length
        async.each @observations,(ob,done)->
            if ob.isApplying
                done()
                return
            ob.isApplying = true
            @mc.invoke "observe",ob.path,(err,results)->
                ob.isApplying = true
                if err
                    hasError = true
                    errors.push err
                    done()
                    return
                if ob.init
                    @emit "gap",results
                else
                    ob.init = true
                    ob.callback?(null,results)
                done()
        ,()=>
            if hasError
                # I tried my best
                # but something wrong
                callback new App.Errors.ObserveFailure("apply observe fails",{errors:errors,total:total})
                return
            callback()
    unsetMessageCenter:()->
        @mc.stopListenBy this
        @messageCenter = null
        @mc = null

class ClientCoreState extends portal.ObservePortal
    constructor:()->
        super new PortalAdapter
        @adapter.on "error",()=>
            @adapter.unsetMessageCenter()
            @emit new Errors.NetworkError("observer network error")
    setMessageCenter:(mc)->
        @adapter.setMessageCenter(mc)
        @mc = mc
module.exports = ClientCoreState
