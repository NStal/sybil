async = require "async"
States = sybilRequire "common/states.coffee"
ErrorDoc = require "error-doc"
tough = require "tough-cookie"
Source = require "../../source/source"
loadash = require "lodash"
httpUtil = global.env.httpUtil
Cookie = tough.Cookie
CookieJar = tough.CookieJar
console = console = env.logger.create __filename
cheerio = require "cheerio"
exports.Errors = Errors = Source.Errors
exports.getAvailableProxy = (callback)->
    proxies = exports.proxies.slice(0)
    proxies.unshift(null)
    if exports.lastAvailableProxy in proxies
        proxies = proxies.filter (item)->item isnt exports.lastAvailableProxy
        proxies.unshift exports.lastAvailableProxy
    timeout = 20 * 1000
    async.each proxies,((proxy,done)=>
        complete = (info)->
            done(info)
            complete = ()->
        setTimeout (()->complete()),timeout
        console.debug "test proxy",proxy
        httpUtil.httpGet {url:"https://twitter.com",proxy,timeout},(err,res)->
            if not err
                exports.lastAvailableProxy = proxy
                console.debug "pick proxy",proxy
                complete("done")
                callback null,proxy
            else
                console.debug "test proxy #{proxy} with err",err
                complete()
        ),(result)=>
            if result is "done"

                return
            callback new Error("Not proxy available")
exports.setPossibleProxies = (proxies = [])->
    @proxies = proxies.slice(0)
exports.setPossibleProxies(global.env.settings.proxies)

exports.renderDisplayContent = (data)->
    entities = data.archive.extended_entities or data.archive.entities or {}
    medias = entities.media or []
    images = []
    if medias instanceof Array
        for media in medias
            images.push media.media_url
    $content = cheerio.load "<div class='tweet'>#{data.archive.text}</div>"
    for image in images
        $content(".tweet").append "<img src='#{image}:large'/>"
    return $content.html()
# states
# void
# proxyAttemped
class exports.TwitterRequestClient extends States
    constructor:(option = {})->
        super()
        @jar = option.jar
        @userAgent = "Mozilla/5.0 (Linux; Android 4.2.1; en-us; Nexus 5 Build/JOP40D) AppleWebKit/535.19 (KHTML, like Gecko) Chrome/18.0.1025.166 Mobile Safari/535.19"
        @proxy = exports.lastAvailableProxy or null
        # available states
        # void,success,fail
        @setState "void"
        @lastRequestState = "void"
    getCSRFToken:(url,callback)->
        @request {
            url:url
        },(err,res,content)=>
            if err
                callback new Errors.NetworkError("fail to get csrf token due to network error",{via:err})
                return
            $ = cheerio.load content.toString()
            try
                code = $("[name='csrf_id']").attr("content").toString().trim()
            catch e
                console.error "twitter content",content
                console.error "fail to get twitter CSRF code"
                code = null
            if not code
                console.debug "Invalid code",content.toString()
                callback new Errors.ParseError("invalid code",{code:code})
                return
            callback null,code

    prepare:()->
        if @state is "prepareing" or @state is "prepared"
            return
        if @lastRequestState isnt "success"
            @setState "preparing"
        else
            @setState "prepared"
    atPreparing:()->
        exports.getAvailableProxy (err,proxy)=>
            if err
                @lastError = new Errors.NotReady("fail to get available proxy")
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
    request:(option = {},callback)->
        if @state is "prepared"
            @_request option,callback
            return
        option.jar ?= @jar
        timeout = option.timeout or 20 * 1000
        hasTimeout = false
        timer = setTimeout (()->
            hasTimeout = true
            callback new Errors.Timeout()
            callback = ()->
            ),timeout
        @once "ready",()=>
            if hasTimeout
                return
            clearTimeout timer
            @_request option,callback
        @prepare()
    _request:(option = {},callback)->
        if @state isnt "prepared"
            @prepare()
            callback new Errors.NotReady("proxy not ready")
            return
        option.method = option.method or "GET"
        option.headers = option.headers or {}
        option.headers["user-agent"] ?= @userAgent
        option.jar ?= @jar
        option.proxy = @proxy
#        option.headers["user-agent"] = option.headers["user-agent"] or @userAgent
        if option.method is "GET"
            method = "httpGet"
        else
            method = "httpPost"
        httpUtil[method] option,(err,res,body)=>
            if err
                @lastRequestState = "fail"
                @lastError = err
                @setState "notAvailable"
                callback err
                return
            @lastRequestState = "success"
            callback(null,res,body)
