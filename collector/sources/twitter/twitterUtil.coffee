async = require "async"
States = require "../../"
ErrorDoc = require "error-doc"
tough = require "tough-cookie"
loadash = require "lodash"
Cookie = tough.Cookie
CookieJar = tough.CookieJar

exports.Errors = Errors = ErrorDoc.create()
    .define "ConnectionNotAvailable"
    .define "Timeout"
    .generate()
exports.getAvailableProxy = (callback)->
    proxies = exports.proxies.slice(0)
    proxies.unshift(null)
    async.eachSeries proxies,((proxy,done)=>
        complete = (info)->
            done(info)
            complete = ()->
        setTimeout (()->complete()),1000 * 10
        httpUtil.httpGet {url:"https://twitter.com",proxy},(err,res)->
            if not err
                exports.lastAvailableProxy = proxy
                complete("done")
                callback null,proxy
            else
                complete()
        ),(result)=>
            if result is "done"
                return
            callback new Error("Not proxy available")
exports.setPossibleProxies = (proxies or [])->
    @proxies = proxies.slice(0)
exports.setPossibleProxies(global.env.settings.proxies)

# states
# void
# proxyAttemped
class exports.TwitterRequestClient extends States
    constructor:()->
        super()
        @proxy = exports.lastAvailableProxy or null
        # available states
        # void,success,fail
        @setState "void"
        @lastRequestState = "void"
    prepare:()->
        if @states is "prepareing" or @state is "prepared"
            return
        if @lastRequestState isnt "success"
            @setState "preparing"
        else
            @setState "prepared"
    atPreparing:()->
        exports.getAvailableProxy (err,proxy)=>
            if err
                @lastError = new Errors.ConnectionNotAvailable
                @lastRequestState = "fail"
                @setState "notAvailable"
                return
            else
                @proxy = proxy
                @setState "prepared"
    atPrepared:()->
        @emit "ready"
    atNotAvailable:()->
        @emit "exception",@lastError
        @emit "notAvailable"
    request:(option,callback)->
        if @states is "prepared"
            @_request option,callback
            return
        timeout = option.timeout or 15 * 1000
        hasTimeout = false
        timer = setTimeout (()->
            hasTimeout = true
            callback new Errors.Timeout()
            callback = ()->
            ),timeout
        @once "ready",()=>
            if not hasTimeout
                clearTimeout timer
                @_request option,callback
        @prepare()
    _request:(option = {},callback)->
        if @states isnt "prepared"
            @prepare()
            callback new Errors.ConnectionNotAvailable("proxy not ready")
            return
        option.method = option.method or "GET"
        option.headers = option.headers or {}
        option.headers["user-agent"] = option.headers["user-agent"] or @userAgent
        if option.method is "GET"
            method = "httpGet"
        else
            method = "httpPost"
        httpUtil[method] option,(err,res,body)->
            if err
                @lastRequestState = "fail"
                @lastError = err
                @setState "notAvailable"
                callback err
                return
            @lastRequestState = "success"
            callback(null,res,body)
