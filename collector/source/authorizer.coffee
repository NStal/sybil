States = require "../states.coffee"
createError = require "create-error"
Errors = require "./errors.coffee"
console = console = env.logger.create __filename

# Authorizer are responsible for authenticate the source if required.
# 1. Authorizer will panic on any unexpected state
# 2. We have several predefined states:
#    prelogined(->pinCodeReady)->Prepared->loginAttmpted->authorized
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
        @authorized = @source.info.authorized or false
        @authorizeInfo = @source.info.authorizeInfo or {}
        @on "panic",()=>
            @authorized = false
        @standBy()
    # One should better call give("startSignal") rather than
    # call start() directly
    standBy:()->
        @waitFor "startSignal",()=>
            @start()
    start:()->
        if not @authorized
            if not @username
                @setState "waitingLocalAuth"
            else
                @setState "localAuthed"
        else
            @emit "authorized"
    reset:()->
        @requirePinCode = false
        @authorized = false
        @authorizeInfo = {}
        @networkRetry = 0
        @pinCode = null
        @pinCodeBuffer = null
        @pinCodeType = "buffer"
        @pinCodeFormat = "png"
        @setState "void"
        @username = null
        @password = null
    reAuth:(callback)->
        @reset()
        @tryStartAuth(callback)
    
    tryStartAuth:(callback)->
        handler = ()=> 
            @removeListener "authorized",handler
            callback()
        @once "authorized",handler
        @give "startSignal"
    atWaitingLocalAuth:()->
        console.debug "wait for localAuth"
        @waitFor "localAuth",(username,secret)=>
            console.debug "local auth recieved"
            @username = username
            @secret = secret
            @setState "localAuthed"
        @emit "requireLocalAuth"
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
        @setState "authorized"
    atAuthorized:()->
        @emit "authorized"
module.exports = Authorizer
    