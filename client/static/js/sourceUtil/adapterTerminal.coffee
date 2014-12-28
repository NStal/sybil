App = require "/app"
HintStack = require "/hintStack"
CubeLoadingHint = require "/widget/cubeLoadingHint"
tm = require "/templateManager"
tm.use "sourceUtil/subscribeAdapterTerminal"

class SubscribeAdapterTerminal extends HintStack.HintStackItem
    constructor:(candidate)->
        @include CubeLoadingHint
        super App.templates.sourceUtil.subscribeAdapterTerminal
        console.debug candidate,"from termional"
        @candidate = candidate
        @Data.mode = "accepter"
        @register()
        @Data.subscribeHint = @candidate.subscribeHint or "Would you like to subscribe #{@candidate.uri}"
        console.debug @candidate.data,@candidate.requireLocalAuth,"~~",@candidate
        if @candidate.requireLocalAuth
            @requireAuth()
        @Data.hintTitle = @candidate.uri
        @Data.waitTitle = @candidate.uri
        if @candidate.panic
            @fail()
        @show()
    register:()->
        console.debug "register #{@candidate.cid}"
        App.messageCenter.listenBy this,"event/candidate/requireAuth",@handlePossibleCandidateAuth
        App.messageCenter.listenBy this,"event/candidate/subscribe",@handlePossibleCandidateSubscribe
        App.messageCenter.listenBy this,"event/candidate/fail",@handlePossibleCandidateFail
    requireAuth:()->
        @Data.mode = "authenticator"
        @Data.authHint = @candidate.authHint or "Please enter you authorization info for #{@candidate.uri}"
    fail:(panic)->
        @candidate.panic = panic or @candidate.panic
        @Data.mode = "failure"
        @Data.failureHint = "Subscribe failed due to #{JSON.stringify @candidate.panic}"
    handlePossibleCandidateAuth:(candidate)->
        if candidate.cid is @candidate.cid
            @candidate = candidate
            @requireAuth()
        return
    handlePossibleCandidateCaptcha:(candidate)->
        console.debug "possible captcha",candidate
        if candidate.cid is @candidate.cid
            @Data.mode = "pin-recognizer"
        return
    handlePossibleCandidateSubscribe:(info)->
        if info.cid is @candidate.cid
            @release()
            @hide()
    handlePossibleCandidateFail:(info)->
        console.debug "candidate fail",info,"!!!!"
        if info.cid is @candidate.cid and info.panic
            @fail(info.panic)
    onClickRetry:()->
        @wait "initializing..."
        @retry (err)=>
            true
    onClickCancel:()->
        @cancel (err)=>
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
            @wait "accepting..."
    onClickDecline:()->
        @decline ()=>
            @hide()
    onClickAuthorize:()->
        username = @UI.username.value
        secret = @UI.secret.value
        @auth username,secret,()=>
            @wait "authorizing..."
    onClickRefuse:()->
        @decline ()=>
            @hide()

    hint:(word)->
        @Data.mode = "hinter"
        @Data.hint = word
    wait:(word)->
        @Data.mode = "waiter"
        @UI.loadingHint.hint = word
    release:()->
        App.messageCenter.stopListenBy this
    auth:(username,secret,callback = ()->)->
        console.log "authCandidate",{cid:@candidate.cid,username:username,secret:secret}
        @accept ()=>
            App.messageCenter.invoke "authCandidate",{cid:@candidate.cid,username:username,secret:secret},(err)=>
                callback err
    retry:(callback = ()->)->
        App.messageCenter.invoke "retryCandidate",{cid:@candidate.cid,retry:true},(err)=>
            callback()
    cancel:(callback = ()->)->
        App.messageCenter.invoke "retryCandidate",{cid:@candidate.cid,retry:false},(err)=>
            callback()
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
