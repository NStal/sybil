App = require "/app"
HintStack = require "/hintStack"
class SubscribeAdapterTerminal extends HintStack.HintStackItem
    constructor:(candidate)->
        super App.templates["subscribe-adapter-terminal"]
        console.debug candidate,"from termional"
        @candidate = candidate
        @Data.mode = "accepter"
        @register()
        @Data.subscribeHint = @candidate.subscribeHint or "Would you like to subscribe #{@candidate.uri}"
        if @candidate.needAuth
            @requireAuth()
        @show()
    register:()->
        console.debug "register #{@candidate.cid}"
        App.messageCenter.listenBy this,"event/candidate/requireAuth",@handlePossibleCandidateAuth
        App.messageCenter.listenBy this,"event/source",@handlePossibleSourceArrive
    requireAuth:()->
        @Data.mode = "authenticator"
        @Data.authHint = @candidate.authHint or "Please enter you authorization info for #{@candidate.uri}"
    handlePossibleCandidateAuth:(candidate)->
        console.debug "possible auth",candidate
        if candidate.cid is @candidate.cid
            @candidate = candidate
            @requireAuth()
        return
    handlePossibleCandidatePinCode:(candidate)->
        console.debug "possible pincode",candidate
        if candidate.cid is @candidate.cid
            @Data.mode = "pin-recognizer"
        return
    handlePossibleSourceArrive:(source)->
        if source.uri is @candidate.uri
            @release()
            @hide()
    onKeydownUsername:(e)->
        if e.which is Leaf.Key.enter
            @UI.secret$.focus()
    onKeydownSecret:(e)->
        if e.which is Leaf.Key.enter
            @onClickAuthorize()
    onClickAccept:()->
        @accept ()=>
            @hint "Waiting..."
    onClickDecline:()->
        @decline ()=>
            @hide()
    onClickAuthorize:()->
        username = @UI.username.value
        secret = @UI.secret.value
        @auth username,secret,()=>
            @hint "authorizing"
    onClickRefuse:()->
        @decline ()=>
            @hide()
    hint:(word)->
        @Data.mode = "hinter"
        @Data.hint = word
    release:()->
        App.messageCenter.stopListenBy this
    auth:(username,secret,callback = ()->)->
        console.log "authCandidate",{cid:@candidate.cid,username:username,secret:secret}
        @accept ()=>
            App.messageCenter.invoke "authCandidate",{cid:@candidate.cid,username:username,secret:secret},(err)=>
                callback err
    accept:(callback = ()->)->
        App.messageCenter.invoke "acceptCandidate",@candidate.cid,(err)=>
            @accepted = true
            callback(err)
    decline:(callback = ()->)->
        App.messageCenter.invoke "declineCandidate",@candidate.cid,(err)=>
            callback(err)
    error:(error)->
        return
module.exports = SubscribeAdapterTerminal
