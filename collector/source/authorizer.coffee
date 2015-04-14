States = sybilRequire "common/states"
createError = require "create-error"
Errors = require "./errors"
console = console = env.logger.create __filename

# Authorizer are responsible for authenticate the source if required.
class Authorizer extends States
    constructor:(@source)->
        super()
        @reset()
    standBy:()->
        @waitFor "startSignal",()=>
            @_start()
    start:()->
        @give "startSignal"
    _start:()->
        if not @data.authorized
            if not @data.username
                @setState "waitingLocalAuth"
            else
                @setState "localAuthed"
        else
            @setState "authorized"
    reset:()->
        super()
        @data.requireCaptcha = false
        @data.authorized = false
        @data.authorizeInfo = {}
        @data.networkRetry = 0
        @data.captcha = null
        @data.captchaBuffer = null
        @data.captchaType = "buffer"
        @data.captchaFormat = "jpg"
        @data.username = null
        @data.password = null
    atWaitingLocalAuth:()->
        @waitFor "localAuth",(username,secret)=>
            @data.username = username
            @data.secret = secret
            @setState "localAuthed"
    atLocalAuthed:()->
        @setState "prelogin"
    atPrelogin:()->
        @setState "prelogined"
    atPrelogined:()->
        if @data.requireCaptcha
            @setState "waitCaptcha"
            return
        @setState "prepared"
    getCaptchaInfo:()->
        if not @isWaitingFor "captcha"
            return null
        return {
            data:@data.captchaBuffer
            ,type:@data.captchaType
            ,format:@data.captchaFormat
        }
    atWaitCaptcha:(sole)->
        # `requireCaptcha` is a inner data
        # for outter user please use `@isWaitingFor 'captcha'`.
        @waitFor "captcha",(captcha)->
            if not @checkSole sole
                return
            @data.requireCaptcha = false
            @data.captcha = captcha
            @setState "prepared"
    atPrepared:()->
        @setState "logining"
    atLogining:(sole)->
        setTimeout (()=>
            if not @checkSole sole
                return
            @setState "authorized"
        ),0
    atAuthorized:()->
        @data.authorized = true
        @emit "authorized"
module.exports = Authorizer
