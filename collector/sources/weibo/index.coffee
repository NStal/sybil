Source = require "../../source/source.coffee"
urlModule = require "url"
EventEmitter = (require "events").EventEmitter
http = require "http"
httpUtil = global.env.httpUtil
weiboUtil = require "./weiboUtil.coffee"
console = env.logger.create __filename
class Weibo extends Source
    @detectStream = (uri)->
        match = (new RegExp("weibo.com","i")).test uri
        if not match
            return null
        stream = new EventEmitter()
        process.nextTick ()->
            stream.emit "data", new Weibo({uri:uri})
            stream.emit "end"
        return stream
    @create = (info)->
        return new Weibo(info)
    constructor:(info = {})->
        super(info)
        @type = "weibo"
    
class Updater extends Source::Updater
    constructor:(@source)->
        super(@source)
        @minFetchInterval = 30 * 1000
    fetchAttempt:()->
        console.debug "try fetching #{@source.guid} at #{@nextFetchInterval}"
        if not @source.authorizer.authorizeInfo.cookie
            @error new Source.Errors.AuthorizationFailed("weibo updater need authorize")
            return
        weiboUtil.fetch {cookie:@source.authorizer.authorizeInfo.cookie},(err,result)=>
            if err
                if err instanceof Source.Errors.Timeout
                    err = new Source.Errors.NetworkError("timeout",{via:err})
                @error err
                return
            @rawFetchedArchives = result
            @setState "fetchAttempted"
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
            ,authorName:raw.user.screen_name
            ,authorAvatar:raw.user.profile_image_url
            ,authorLink:"http://weibo.com#{raw.user.profile_url}"
            ,originalLink:"http://weibo.com/#{raw.user.id}/#{raw.bid}"
            ,sourceName:@source.name
            ,sourceUrl:"http://weibo.com/"
            ,sourceGuid:@source.guid
            ,title:title
            ,content:content
            ,displayContent:displayContent
            ,contentType:"html"
            ,attachments:[]
            ,meta:{
                raw:raw
            }
        }
            
class Initializer extends Source::Initializer
    constructor:(@source)->
        super(@source)
    atInitializing:()->
        if not @source.authorizer.cookie
            console.debug "need auth???ASDASD"
            @error new Source.Errors.AuthorizationFailed("initialize weibo need auth")
            return
        requestUrl = "http://m.weibo.cn/scriptConfig?online=1&t=#{Date.now()}"
        env.httpUtil.httpGet {
            url:requestUrl
            ,headers:{
                Cookie:@source.authorizer.authorizeInfo.cookie
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
            @source.guid = "weibo_#{result.id}"
            @source.name = "#{result.name}'s Weibo Timeline"
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

class Authorizer extends Source::Authorizer
    constructor:(@source)->
        super(@source)
        @jar = new CookieJar()
        @userAgent = "Mozilla/5.0 (Linux; Android 4.2.1; en-us; Nexus 5 Build/JOP40D) AppleWebKit/535.19 (KHTML, like Gecko) Chrome/18.0.1025.166 Mobile Safari/535.19"
        @timeout = 1000 * 10
        @on "state",(state)->
            console.debug "WEIBO:::change state",state
    prelogin:()->
        @requirePinCode = false
        url = "https://m.weibo.cn/login?ns=1&backURL=http%3A%2F%2Fm.weibo.cn%2F&backTitle=%CE%A2%B2%A9&vt=4&"
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
            # maybe get pin code here
            if err
                @error new Source.Errors.NetworkError()
                return
            @setState "prelogined"
    loginAttempt:()->
        postData = {
            uname:@username
            ,pwd:@secret
            ,check:1
            ,backUrl:"http://m.weibo.cn"
        }
        loginUrl = "https://m.weibo.cn/login?ns=1&backURL=http%3A%2F%2Fm.weibo.cn%2F&backTitle=%CE%A2%B2%A9&vt=4"
        option = {}
        option.url = loginUrl
        option.data = postData
        option.method = "POST"
        option.jar = @jar
        option.headers = {
            "Referer":loginUrl
            ,"User-Agent":@userAgent
        }
        option.timeout = @timeout
        httpUtil.httpPost option,(err,res,content)=>
            
            if err
                @error new Source.Errors.NetworkError("fail to login due to netweork error",{via:err})
                return
            @mobileRedirectLoginLocation = res.headers["location"]
            console.log err,res.headers,content.toString()
            @checkLogin()
    checkLogin:()->
        try
            info = urlModule.parse @mobileRedirectLoginLocation,true
        catch e
            info = {query:{}}
        gsid = info.query.g
        if gsid
            @authorized = true
            @loginError = null
            @cookie = "gsid_CTandWM=#{gsid}; expires=Sat, 27-Apr-2024 01:38:02 GMT; path=/; domain=.weibo.cn; httponly"
            @authorizeInfo = {@cookie}

            #configString = "TTT_USER_CONFIG_H5=%7B%22ShowMblogPic%22%3A1%2C%22ShowUserInfo%22%3A1%2C%22MBlogPageSize%22%3A%2250%22%2C%22ShowPortrait%22%3A1%2C%22CssType%22%3A0%2C%22Lang%22%3A1%7D; expires=Sat, 27-Apr-2024 01:38:02 GMT; path=/; domain=.weibo.cn; httponly"
            #@jar.setCookieSync cookieString,"http://weibo.cn/"
            #@jar.setCookieSync configString,"http://weibo.cn/"
            @setState "authorized"
        else
            @error new Source.Errors.AuthorizationFailed("fail to authorize")
Weibo::Updater = Updater
Weibo::Initializer = Initializer
Weibo::Authorizer = Authorizer

module.exports = Weibo
