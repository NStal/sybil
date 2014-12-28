Model = require "/model"
App = require "/app"
tm = require "/templateManager"
tm.use "sourceUtil/sourceAuthorizeTerminal"
class SourceAuthorizeTerminal extends Leaf.Widget
    constructor:(@source)->
        super App.templates.sourceUtil.sourceAuthorizeTerminal
        if not @source.requireLocalAuth
            setTimeout (()=>
                @emit "authorized"
                @hide()
                ),100
            return
        document.body.appendChild @node
        App.hintStack.push this
        App.modelSyncManager.listenBy this,"source/authorized",(source)=>
            if source is @source
                @emit "authorized"
                @clear()

        @Data.mode = "authenticator"
        App.modelSyncManager.listenBy this,"source/requireLocalAuth",(source)=>
            if source is @source
                @hint "authorization failed, please try again"
                @emit "requireLocalAuth"
                @Data.mode = "authenticator"
    auth:(username,secret,callback = ()-> )->
        @hint "authorizing"
        console.log
        App.messageCenter.invoke "authSource",{
            guid:@source.guid
            ,username:@UI.username$.val().trim()
            ,secret:@UI.secret$.val()
        },(err,result)->
            callback(err,result)
    hint:(message)->
        @Data.mode = "hinter"
        @Data.hint = message
    hide:()->
        @emit "hide",this
#        if @node.parentElement
#            @node.parentElement.removeChild @node
    clear:()->
        App.modelSyncManager.stopListenBy this
        @hide()
    onKeydownUsername:(e)->
        if e.which is Leaf.Key.enter
            @UI.secret$.focus()
    onKeydownSecret:(e)->
        if e.which is Leaf.Key.enter
            @onClickAuthorize()
    onClickAuthorize:()->
        username = @UI.username.value
        secret = @UI.secret.value
        @auth username,secret,()=>
            @hint "authorizing"
    onClickRefuse:()->
        @hide()


module.exports = SourceAuthorizeTerminal
