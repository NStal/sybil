httpUtil = require "../../common/httpUtil"
urlModule = require "url"
pathModule = require "path"
States = sybilRequire "common/states"
crypto = require "crypto"
fs = require "fs"
# This file is a mess.
# I will refactor it later or never.
Errors = require("error-doc").create()
.define("FileError")
.define("NetworkError")
.define("FetchError")
.define("FatalError")
.define("ServerError")
.generate()

exports.requires = ["webApi"]
exports.register = (dep,callback)->
    class IconResponser extends States
        @resourceFolder = pathModule.resolve dep.resourceFolder
        @defaultIconPath = pathModule.resolve @resourceFolder,"default-icon.ico"
        @tempFolder = dep.tempFolder
        constructor:(@req,@res)->
            super()
            @url = @req.param("url")
            @iconUrl = urlModule.resolve @url,"/favicon.ico"
            @fileName = crypto.createHash("md5").update(@iconUrl).digest("hex") + ".icon"
            @filePath = pathModule.resolve IconResponser.tempFolder,@fileName
            @waitFor "responseSignal",@atCheckCache.bind(this)
            @proxies = dep.settings.proxies or global.env.settings.proxies or []
            @data.proxyIndex = -1
            @rescue "fetchIcon",Errors.NetworkError,(error)=>
                if @proxies[@data.proxyIndex+1]
                    @data.proxyIndex += 1
                    @setState "fetchIcon"
                else
                    @setState "returnDefaultIcon"
            @rescue "fetchIcon",Errors.FetchError,(error)=> @setState "returnDefaultIcon"
            @rescue "updateCache",Errors.FileError,(error)=> @setState "returnDefaultIcon"
            @rescue "returnDefaultIcon",Errors.FileError,(error)=>
                @data.serverError = error
                @setState "returnServerError"
            @rescue "returnCache",Errors.FileError,(error)=>@setState "returnDefaultError"
        _responseIconBinary:(buffer)->
            @res.end(buffer)
        atPanic:()->
            @emit "error",new Errors.FatalError "fatal error",via:@panicError
        atCheckCache:(sole)->
            fs.exists @filePath,(exists)=>
                if @stale sole
                    return
                if exists
                    @setState "returnCache"
                else
                    @setState "fetchIcon"
        atFetchIcon:(sole)->
            httpUtil.httpGet {url:@iconUrl,timeout:5000,proxy:@proxies[@data.proxyIndex] or null,noQueue:true},(err,res,buffer)=>
                if @stale sole
                    return
                if err
                    @error new Errors.NetworkError
                    return
                if res.statusCode is 200
                    @data.iconBinary = buffer
                    @setState "updateCache"
                else
                    @error new Errors.FetchError("icon response isnt 200")
        atUpdateCache:(sole)->
            fs.writeFile @filePath,@data.iconBinary,(err)=>
                if @stale sole
                    return
                if err
                    @error new Errors.FileError "fail to update cache #{@filePath}",{via:err}
                    return
                @setState "returnIconBinary"
        atReturnDefaultIcon:(sole)->
            if IconResponser.defaultIconBuffer
                @data.iconBinary = IconResponser.defaultIconBuffer
                @setState "returnIconBinary"
            else
                fs.readFile IconResponser.defaultIconPath,(err,buffer)=>
                    if @stale sole
                        return
                    if err
                        @error new Errors.FileError "fail to get read default icon",{via:err}
                        return
                    @data.iconBinary = buffer
                    @setState "returnIconBinary"
                    return
        atReturnCache:(sole)->
            fs.readFile @filePath,(err,buffer)=>
                if @stale sole
                    return
                if err
                    @error new Errors.FileError "fail to read cache #{@filePath}",{via:err}
                    return
                @data.iconBinary = buffer
                @setState "returnIconBinary"
        atReturnIconBinary:(sole)->
            DAY = 1000 * 60 * 60 * 24
            @res.setHeader "Expires", new Date(Date.now() + DAY * 7).toGMTString()
            @res.end @data.iconBinary
            @emit "done"
        atReturnServerError:()->
            @res.statusCode = "503"
            @res.end JSON.stringify new Errors.ServerError "server error fatal",{via:@data.serverError}
            @emit "done"
    if not dep.webApi
        callback "need webApi to implement"
        return
    server = dep.webApi.app
    server.get "/plugins/iconProxy",(req,res)->
        iconer = new IconResponser(req,res)
        iconer.give "responseSignal"
        iconer.on "error",(err)->
            console.error "fatal error",err
            res.statusCode = 503
            res.end()
    callback null,{}
