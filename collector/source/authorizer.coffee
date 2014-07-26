States = require "../states.coffee"
createError = require "create-error"
Errors = require "./errors.coffee"
# Event
# requireHumanRecognition:{data,type,format}
#     data may be a path or buffer depend on the type
#     format is a like png/gif to indicates the real format
# requireLocalAuth:
#     please get username and secret and the call localAuth
#     with them.
# authorized:
#     greate! we are authorized now. You may access userful
#     @authorizeInfo for latter use.
#
# Require Implements
#
# prelogin:()
#     Check if we need pinCode and fetch some important data 
#     that we need to do the authorization and finally set state
#     to "prelogined".
# 
#     set @requirePinCode = true, if need pin code
#     set any required data to this for custom login process
#     setState "prelogined"
# 
# getPinCode:()
#     fetch the remote pinCode.
#
#     set @pinCodeBuffer = binary
#     set @pinCodeType "buffer"
#     set @pinCodeFormat = "png")
#     setState "pinCodeReady"
# 
# loginAttempt:()
#     try using the existing info the do the authorization
#     and set @loginError to error if any.
#
#     set @authorized = true is successful
#     set @authorizeInfo = data for latter use
#     setState "loginAttempted"
class Authorizer extends States
    constructor:(@source)->
        super()
        @reset()
        @setState "void"
        @authorized = @source.info.authorized
        @authorizeInfo = @source.info.authorizeInfo
        console.log "ALLL",@state
    start:()->
        console.log "start???"
        if not @authorized
            if not @username
                console.log "requireLocalAuth?"
                @emit "requireLocalAuth"
            else
                @setState "localAuthed"
        else
            @emit "authorized"
    reset:()->
        @requirePinCode = false
        @authorized = false
        @authorizeInfo = {}
        @networkErrorRetry = 0
        @pinCode = null
        @pinCodeBuffer = null
        @pinCodeType = "buffer"
        @pinCodeFormat = "png"
    localAuth:(username,secret)->
        @username = username
        @secret = secret
        @setState "localAuthed"
    atLocalAuthed:()->
        @prelogin()
    prelogin:()->
        @setState "prelogined"
    atPrelogined:()->
        if @requirePinCode
            @getPinCode()
            return
        @setState "prepared"
    getPinCode:()->
        @setState "pinCodeReady"
    atPinCodeReady:()->
        @emit "requireHumanRecognition",{
            data:@pinCodeBuffer
            ,type:@pinCodeType
            ,format:@pinCodeFormat
        }
    setPinCode:(code)->
        @pinCode = code
        @setState "prepared"
    atPrepared:()->
        @loginAttempt()
    loginAttempt:()->
        @setState "loginAttempted"
    atLoginAttempted:()->
        @checkLogin()
    checkLogin:()->
        @setState "loginChecked"
    atLoginChecked:()->
        if @authorized
            @setState "authed"
            return
        # if not authorized than must there be some error
        if @loginError instanceof Errors.AuthorizationFailed
            @emit "exception",@loginError
            @emit "requireLocalAuth"
        else if @loginError instanceof Errors.NetworkError or @loginError instanceof Errors.TimeoutError
            @emit "exception",@loginError
            if not @networkErrorRetry
                @networkErrorRetry = 1
                if @networkErrorRetry > @maxNetworkErrorRetry
                    @emit "exception",new Errors.NetworkError("Give up after #{@maxNetworkErrorRetry} retries caused by network error")
                    @setState "void"
                else
                    @loginAttempt()
        else if @loginError instanceof Errors.InvalidPinCode
            @prelogin()
        else
            @emit "exception",@loginError
            @emit "exception",new Error "Unkown error at login"
            @setState "void"
    atAuthed:()->
        @emit "authorized"
module.exports = Authorizer
    