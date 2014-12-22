httpUtil = require "../../common/httpUtil.coffee"
urlModule = require "url"
pathModule = require "path"

# This file is a mess.
# I will refactor it later or never.

exports.requires = ["webApi"]
exports.register = (dep,callback)->
    if not dep.webApi
        callback "need webApi to implement"
        return
    settings = require("../../settings.coffee")
    server = dep.webApi.app
    server.get "/remoteResource",(req,res)->
        url = req.param("url","").trim()
        referer = req.param("referer","").trim()
        if url.indexOf "https://" is 0
            scheme = require "https"
        if url.indexOf "http://" is 0
            scheme = require "http"
        if not scheme
            res.status(591)
            res.end("unknown protocol")
            return
        proxy = settings.get("proxy")
        requestHeaders = {}
        if not url
            res.status(404)
            res.end("invalid url #{url}")
            return
        if referer
            requestHeaders["Referer"] = referer
        option = {url:url,headers:requestHeaders,noQueue:true,useStream:true}
        forceProxy = false
        if req.param("proxy") is "yes"
            forceProxy = true
        if forceProxy
            option.proxy = proxy
            httpUtil.httpGet option,(err,remoteRes,stream)->
                if err
                    res.status(591)
                    res.end("unreachable with force proxy")
                    return
                fixHeaderFilename url,remoteRes
                res.writeHead(remoteRes.statusCode or 503,remoteRes.headers)
                stream.pipe(res)
        else
            option.proxy = null
            httpUtil.httpGet option,(err,remoteRes,stream)->
                if err
                    option.proxy = proxy
                    httpUtil.httpGet option,(err,remoteRes,stream)->
                        if err
                            res.status(591)
                            res.end("unreachable with both direct and proxy")
                            return
                        fixHeaderFilename url,remoteRes
                        res.writeHead(remoteRes.statusCode or 503,remoteRes.headers)
                        stream.pipe(res)
                    return
                fixHeaderFilename url,remoteRes
                res.writeHead(remoteRes.statusCode or 503,remoteRes.headers)
                stream.pipe(res)
    callback null,{}

fixHeaderFilename = (url,remoteRes)->
    obj = urlModule.parse(url)
    name = pathModule.basename obj.pathname
    if name and not remoteRes.headers["content-disposition"]
        remoteRes.headers["content-disposition"] = "attachment; filename=#{name}"
