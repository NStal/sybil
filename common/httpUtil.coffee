# httpUtil.httpGet(option,callback)
# option {
#    url        : url to fetch
#    proxy      : what kind of proxy to use string like phttp://localhost:3223/
#    timeout    : timeout
#    headers    : custom headers
#    useStream  : return a stream instead of downloaded content
#    maxRedirect: max redirect for 30X status code
#    acceptCache: return Object {cache:true} when recieve not modified
#    noQueue    : send request event the queue is full
#}
#
# callback(err,res,content)
# callback(err,res,stream)  if useStream is set
async = require "async"
ProxyAgent = require "proxy-agent"
urlModule = require "url"
zlib = require "zlib"
errorDoc = require "error-doc"
createError = require "create-error"
console = env.logger.create(__filename)
_ = require "underscore"
Errors = errorDoc.create()
    .use(errorDoc.Errors.IOError)
    .use(errorDoc.Errors.ProgrammerError)
    .use(errorDoc.Errors.Timeout)
    .define("IOError:MaxRedirect")
    .define("ProgrammerError:InvalidProtocol")
    .define("UnknownContentEncoding")
    .define("ConnectionRefused")
    .generate()
exports.Errors = Errors

httpGetQueue = async.queue ((job,done)->
    console.debug "httpGetQueueLength solve #{job.option.url} at waiting",httpGetQueue.length(),"with proxy #{job.option.proxy}"
    exports._httpGet job.option,(err)->
        job.done = true
        job.callback.apply {},arguments
        done()
    ),20

exports.httpGet = (option,callback)->
    if option.noQueue
        console.debug "instant http request for #{option.url}, proxy #{option.proxy or 'None'}"
        exports._httpGet option,callback
        return
    httpGetQueue.push {option:option,callback:callback}

exports._httpGet = (option,callback)->
    url = option.url
    proxy = option.proxy or null
    useStream = option.useStream or false
    jar = option.jar or null
    if typeof option.maxRedirect isnt "number"
        option.maxRedirect = 3
    else
        if option.maxRedirect < 0
            callback new Errors.MaxRedirect "max redirect #{option.maxRedirect} reach"
            return
    timeout = option.timeout or 1000 * 30

    _callback = callback
    callback = (err,res,data)->

        _callback err,res,data
        # call callback twice don't throw error
        _callback = ()->
    scheme = exports._prepareScheme(option)
    if not scheme
        callback new Errors.InvalidProtocol "fail to parse scheme with url:#{option.url}"
        return
    agent = exports._prepareAgent(option)
    headers = option.headers or {}
    if not headers["user-agent"]
        headers["user-agent"] = exports.defaultAgent
    if not headers["cookie"] and jar
        headers["cookie"] = (jar.getCookieStringSync url) or ""
    _urlObject = urlModule.parse(url)
    requestOption = {}
    requestOption.path = _urlObject.path
    requestOption.hostname = _urlObject.hostname
    requestOption.port = _urlObject.port
    requestOption.method = "GET"
    requestOption.headers = headers
#2015-03-07 12:37:13 ERROR:[events.js:107:17] [Error: "name" and "value" are required for setHeader().] [EOL]
#2015-03-07 12:37:13 ERROR:[events.js:107:17] Error: "name" and "value" are required for setHeader().
#  at ClientRequest.OutgoingMessage.setHeader (_http_outgoing.js:333:11)
#  at new ClientRequest (_http_client.js:101:14)
#  at Object.exports.request (http.js:49:10)
#  at Object.exports._httpGet (/home/wuminghan/sybil/common/httpUtil.coffee:86:18)
#  at ClientRequest.<anonymous> (/home/wuminghan/sybil/common/httpUtil.coffee:112:21)
#  at ClientRequest.g (events.js:199:16)
#  at ClientRequest.emit (events.js:107:17)
#  at HTTPParser.parserOnIncomingClient [as onIncoming] (_http_client.js:419:21)
#  at HTTPParser.parserOnHeadersComplete (_http_common.js:111:23)
#  at Socket.socketOnData (_http_client.js:310:20)
#  at Socket.emit (events.js:107:17)
#  at readableAddChunk (_stream_readable.js:163:16)
#  at Socket.Readable.push (_stream_readable.js:126:10)
#  at TCP.onread (net.js:529:20)

#    console.debug requestOption.headers,"I recieve a set Header failure"
    requestOption.agent = agent
    req = scheme.request requestOption,(res)=>
        if req.initialTimeout
            clearTimeout req.initialTimeout
            req.initialTimeout = null
        if jar
            cookie = res.headers["set-cookie"]
            if cookie instanceof Array
                rawCookie = cookie
            else if not cookie
                rawCookie = []
            else
                rawCookie = [cookie]
            rawCookie.forEach (rc)=>
                try
                    jar.setCookieSync rc,option.url
                catch e
                    # broken server set cookie
                    # fail silently
                    true
        if res.headers["location"] and not option.noAutoRedirect
            newUrl = require("url").resolve(url,res.headers["location"])
            ro = _.clone(option)
            ro.headers = ro.headers or {}
            if res.headers["set-cookie"]
                ro.headers["Cookie"] = res.headers["set-cookie"]
            ro.url = newUrl
            ro.maxRedirect -= 1
            exports._httpGet ro,callback
            return
        if res.headers["content-encoding"]
            _enc = res.headers["content-encoding"].toLowerCase().trim()
            if _enc is "gzip"
                pipeline = (require "zlib").createGunzip()
            else if _enc is "deflate"
                pipeline = (require "zlib").createInflate()
            else
                res.close()
                callback new Errors.UnkownContentEncoding "unknown content-encoding header #{_enc}"
                return
            res.pipe(pipeline)
        else
            pipeline = res
        if useStream
            callback null,res,pipeline
            return

        buffers = []
        pipeline.on "readable",()->
            while data = pipeline.read()
                buffers.push data
        pipeline.on "error",(err)->
            callback new Errors.IOError("Pipeline error",{via:err})
        pipeline.on "end",()->
            buffer = Buffer.concat buffers
            callback null,res,buffer
    req.hasTimeout = false
    req.on "error",(err)->
        # Note:
        # errer after recieve header but useStream
        # will fail silently
        # which means you are responsible for completeness check
        # also when timeout it error will be ECONNRESET when not content recieved
        # the ECONNRESET will also be suppressed by timeout
        console.debug "http error",err
        if req.hasTimeout
            return
        callback new Errors.IOError("request error",{via:err})
    # this is for initial timeout
    req.initialTimeout = setTimeout (()->
        console.debug "reach initial timeout #{url}"
        req.hasTimeout = true
        req.abort()
        callback new Errors.Timeout("maximum time #{timeout} exists")
        ),timeout
    # this is for TCP timeout
    req.setTimeout timeout,()->
        req.hasTimeout = true
        req.abort()
        callback new Errors.Timeout("maximum time #{timeout} exists")
    req.end()
exports._prepareScheme = (option)->
    scheme = null
    url = option.url
    if not url
        return null
    if url.indexOf("https") is 0
        scheme = require "https"
    else if url.indexOf("http") is 0
        scheme = require "http"
    else if url.indexOf("feed://") is 0
        scheme = require "http"
    # for proxied request we all use http scheme and others are left to agents
    return scheme

exports.httpPost = (option,callback)->
    url = option.url
    proxy = option.proxy or null
    jar = option.jar or null

    useStream = option.useStream or false
    timeout = option.timeout or 1000 * 30
    postContent = option.data or ""
    if not Buffer.isBuffer(postContent) and not (typeof postContent is "string")
        postContent = require("querystring").stringify(postContent)
    _callback = callback
    callback = (err,res,data)->

        _callback err,res,data
        # call callback twice don't throw error
        _callback = ()->
    scheme = exports._prepareScheme(option)
    if not scheme
        callback new Errors.InvalidProtocol "fail to parse scheme with url:#{option.url}"
        return
    agent = exports._prepareAgent(option)
    headers = option.headers or {}
    if not headers["user-agent"]
        headers["user-agent"] = exports.defaultAgent
    if not headers["cookie"] and jar
        headers["cookie"] = (jar.getCookieStringSync url) or ""
    if not headers["content-type"]
        headers["content-type"] = "application/x-www-form-urlencoded"
    headers["content-length"] = postContent.length
    _urlObject = urlModule.parse(url)
    requestOption = {}
    requestOption.path = _urlObject.path
    requestOption.hostname = _urlObject.hostname
    requestOption.port = _urlObject.port
    requestOption.method = "POST"
    requestOption.headers = headers
    requestOption.agent = agent
    req = scheme.request requestOption,(res)=>
        if jar
            cookie = res.headers["set-cookie"]
            if cookie instanceof Array
                rawCookie = cookie
            else if not cookie
                rawCookie = []
            else
                rawCookie = [cookie]
            rawCookie.forEach (rc)=>
                try
#                    console.log "set cookie or",option.url,rc
                    jar.setCookieSync rc,option.url
                catch e
                    true
                    # broken server set cookie
                    # fail silently

        if res.headers["content-encoding"]
            _enc = res.headers["content-encoding"].toLowerCase().trim()
            if _enc is "gzip"
                pipeline = (require "zlib").createGunzip()
            else if _enc is "deflate"
                pipeline = (require "zlib").createInflate()
            else
                res.close()
                callback new Errors.UnkownContentEncoding "unknown content-encoding header #{_enc}"
                return
            res.pipe(pipeline)
        else
            pipeline = res
        if useStream
            callback null,res,pipeline
            return

        buffers = []
        pipeline.on "readable",()->
            while data = pipeline.read()
                buffers.push data
        pipeline.on "error",(err)->
            callback new Errors.IOError("Pipeline error",{via:err})
        pipeline.on "end",()->
            buffer = Buffer.concat buffers
            callback null,res,buffer
    req.hasTimeout = false
    req.on "error",(err)->
        # Note:
        # errer after recieve header but useStream
        # will fail silently
        # which means you are responsible for completeness check
        # also when timeout it error will be ECONNRESET when not content recieved
        # the ECONNRESET will also be suppressed by timeout
        if req.hasTimeout
            return
        callback new Errors.IOError("request error",{via:err})
    # note unlike get request we don't have initial timeout for post
    # request we maybe posting something very large, initial timeout is not reasonable
    req.setTimeout timeout,()->
        req.hasTimeout = true
        req.abort()
        callback new Errors.Timeout("maximum time #{timeout} exists")
    req.end(postContent)
exports._prepareAgent = (option)->
    if not option.proxy
        return null
    if option.proxy.indexOf("phttp://") is 0
        return require("./phttp-proxy-agent")(option.proxy,option.url)
    proxy = urlModule.parse option.proxy
    url = urlModule.parse option.url
    if proxy.protocol is "socks5:"
        if url.protocol is "https:"
            Agent = require("socks5-https-client/lib/Agent")
        else
            Agent = require("socks5-http-client/lib/Agent")
        return new Agent {
            socksHost:proxy.hostname
            socksPort:proxy.port
        }
    try
        if option.url.indexOf "https" is 0
            return ProxyAgent(option.proxy,true)
        return ProxyAgent(option.proxy,false)
    catch e
        return null

exports.defaultAgent = "Sybil Reader/0.0.1"
