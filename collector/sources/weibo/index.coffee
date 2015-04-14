Source = require "../../source/source"
urlModule = require "url"
EventEmitter = (require "events").EventEmitter
http = require "http"
httpUtil = global.env.httpUtil
weiboUtil = require "./weiboUtil"
console = env.logger.create __filename
class Weibo extends Source
    @detectStream = (uri)->
        match = (new RegExp("weibo.com","i")).test uri
        if not match and uri isnt "weibo"
            return null
        if uri is "weibo"
            uri = "http://weibo.com"
        stream = new EventEmitter()
        process.nextTick ()->
            stream.emit "data", new Weibo({uri:uri})
            stream.emit "end"
        return stream
    @create = (info)->
        return new Weibo(info)
    constructor:(info = {})->
        super(info)
        @uri ?= "http://weibo.com"
        @type = "weibo"

class WeiboUpdater extends Source::Updater
    constructor:(@source)->
        super(@source)
        @minFetchInterval = 2 * 60 * 1000
    atFetching:(sole)->
        if not @data.authorizeInfo or not @data.authorizeInfo.cookie
            @error new Source.Errors.AuthorizationFailed("weibo updater need authorize")
            return
        weiboUtil.fetch {cookie:@data.authorizeInfo.cookie},(err,result)=>
            @_fetchHasCheckSole = true
            if not @checkSole sole
                return
            if err
                if err instanceof Source.Errors.Timeout
                    err = new Source.Errors.NetworkError("timeout",{via:err})
                    console.log err
                    {message:"timeout"
                    name:"NetworkError"
                    via:err}
                @error err
                return
            @data.rawFetchedArchives = result
            @setState "fetched"
    parseRawArchive:(raw)->
        originalLink = "http://weibo.com/#{raw.user.id}/#{raw.bid}"
        title = raw.user.screen_name
        content = weiboUtil.renderDisplayContent(raw)
        displayContent = weiboUtil.renderDisplayContent(raw)
        return {
            guid:"#{@source.type}_#{originalLink}"
            ,collectorName:@source.type
            ,type:@source.type
            ,createDate:new Date() # it's hard to parse
            ,fetchDate:new Date()
            ,author:{
                name:raw.user.screen_name
                ,avatar:raw.user.profile_image_url
                ,link:"http://weibo.com#{raw.user.profile_url}"
            }
            ,originalLink:"http://weibo.com/#{raw.user.id}/#{raw.bid}"
            ,sourceName:@source.name
            ,sourceUrl:"http://weibo.com/"
            ,sourceGuid:@source.guid
            ,title:title
            ,content:content
            ,displayContent:displayContent
            ,contentType:"text/html"
            ,attachments:[]
            ,meta:{
                raw:raw
            }
        }

class WeiboInitializer extends Source::Initializer
    constructor:(@source)->
        super(@source)
    atInitializing:()->
        if not @data.authorizeInfo or not @data.authorizeInfo.cookie
            @error new Source.Errors.AuthorizationFailed("initialize weibo need auth")
            return
        requestUrl = "http://m.weibo.cn/scriptConfig?online=1&t=#{Date.now()}"
        env.httpUtil.httpGet {
            url:requestUrl
            ,headers:{
                Cookie:@data.authorizeInfo.cookie
            }
            ,timeout:1000 * 10
        },(err,res,content)=>
            if err
                @error Source.Errors.NetworkError("fail to initailize weibo #{@source.uri} due to network error");
                return
            result = @parseInitContent content.toString()
            if not result
                @error Source.Errors.ParseError("fail to parse initial result",{raw:result})
                return
            @data.guid = "weibo_#{result.id}"
            @data.name = "#{result.name}'s Weibo Timeline"
            @setState "initialized"
    parseInitContent:(content)->
        match = content.match /userInfo = (\{[^}]+\})/i
        if not match
            return null
        try
            data = JSON.parse match[1]
        catch e
            return null
        return {
            name:data.name
            ,id:data.id
            ,avatar:data.profile_image_url
        }

# Authorizer should provide @cookie
# should stored to @source.properties.cookie
querystring = require "querystring"
createError = require "create-error"
tough = require "tough-cookie"
https = require "https"
http = require "http"
urlModule = require "url"
Cookie = tough.Cookie
CookieJar = tough.CookieJar

class WeiboAuthorizer extends Source::Authorizer
    constructor:(@source)->
        super(@source)
        @jar = new CookieJar()
        @userAgent = "Mozilla/5.0 (Linux; Android 4.2.1; en-us; Nexus 5 Build/JOP40D) AppleWebKit/535.19 (KHTML, like Gecko) Chrome/18.0.1025.166 Mobile Safari/535.19"
        @timeout = 1000 * 10
    atPrelogin:(sole)->
        @data.requireCaptcha = false
        su = new Buffer(encodeURIComponent(@data.username)).toString("base64")
        callbackId = Date.now()
        url = "https://login.sina.com.cn/sso/prelogin.php?checkpin=1&entry=mweibo&su=#{su}&callback=jsonpcallback#{callbackId}"
        #"https://m.weibo.cn/login?ns=1&backURL=http%3A%2F%2Fm.weibo.cn%2F&backTitle=%CE%A2%B2%A9&vt=4&"
        option = {}
        option.method = "GET"
        option.headers = {
            Referer:url
            ,"User-Agent":@userAgent
            ,Cookie:@jar.getCookiesSync(url).join("; ")
        }
        option.url = url
        option.timeout = @timeout
        option.jar = @jar
        httpUtil.httpGet option,(err,res,content)=>
            if not @checkSole sole
                return
            # maybe get pin code here
            if err
                @error new Source.Errors.NetworkError()
                return
            @setState "prelogined"
    atLogining:(sole)->
#        postData = {
#            uname:@data.username
#            ,pwd:@data.secret
#            ,check:1
#            ,backUrl:"http://m.weibo.cn"
#        }
#        loginUrl = "https://m.weibo.cn/login?ns=1&backURL=http%3A%2F%2Fm.weibo.cn%2F&backTitle=%CE%A2%B2%A9&vt=4"

        loginUrl = "https://passport.weibo.cn/sso/login"
        referer = "https://passport.weibo.cn/signin/login?entry=mweibo&res=wel&wm=3349&r=http%3A%2F%2Fm.weibo.cn%2F"
        postData = {
            username:@data.username
            password:@data.secret
            savestate:1
            pagereferer:"https://passport.weibo.cn/signin/welcome"
            ec:0
            entry:"mweibo"
        }
        option = {}
        option.url = loginUrl
        option.data = postData
        option.method = "POST"
        option.jar = @jar
        option.headers = {
            "Referer":referer
            ,"User-Agent":@userAgent
        }

        option.timeout = @timeout
        httpUtil.httpPost option,(err,res,content)=>
            successRetcode = 20000000
            if not @checkSole sole
                return
            if err
                @error new Source.Errors.NetworkError("fail to login due to netweork error",{via:err})
                return
            try
                result = JSON.parse content.toString()
            catch e
                @error new Source.Errors.ParseError "fail to parse response at login",{raw:content.toString(),via:e}
                return
            if result.retcode isnt successRetcode
                @error new Source.Errors.AuthorizationFailed "authorization failed with retcode #{result.retcode}",{result:result}
                return
            result.data ?= {}
            domain = result.data.crossdomainlist or {}
            ticketUrl = domain["weibo.cn"]
            if not ticketUrl
                # latest weibo updates
                @data.authorized = true
                @data.authorizeInfo = {cookie:@jar.getCookieStringSync "http://m.weibo.cn"}
                @setState "authorized"
                return
            httpUtil.httpGet {
                url:"http:"+ticketUrl
                jar:@jar
                headers:{Referer:referer}
            },(err,res,content)=>
                if err
                    @error new Source.Errors.NetworkError("fail to get crossdomain cookie",via:err)
                    return
                if res.statusCode isnt 200
                    @error new Source.Errors.AuthorizationFailed "crossdomain ticket fail with status #{res.statusCode}",{result:result}
                    return
                @data.authorized = true
                @data.authorizeInfo = {cookie:@jar.getCookieStringSync "http://m.weibo.cn"}
                @setState "authorized"
        atState:(directLogin)->


Weibo::Updater = WeiboUpdater
Weibo::Initializer = WeiboInitializer
Weibo::Authorizer = WeiboAuthorizer

module.exports = Weibo
