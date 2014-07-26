Source = require "../../source/source.coffee"
urlModule = require "url"
EventEmitter = (require "events").EventEmitter
http = require "http"
twitterUtil = require "./twitterUtil.coffee"
ErrorDoc = require "error-doc"
console = console = env.logger.create __filename
Errors = exports.Errors = ErrorDoc.create()
    .define "UnkownError"
    .define "NetworkError"
    .generate()
class Twitter extends Source
    @detectStream = (uri)->
        match = (new RegExp("twitter.com/$","i")).test uri
        if not match
            return null
        stream = new EventEmitter()
        process.nextTick ()->
            stream.emit "data", new Twitter({uri:uri})
            stream.emit "end"
        return stream
    constructor:(info = {})->
        super info
        @type = "twitter"
        @client = new twitterUtil.TwitterRequestClient()
class Updater extends Source::Updater
    constructor:(@source)->
        super(@source)
        @minFetchInterval = 30 * 1000
    fetchAttempt:()->
        console.debug "try fetching #{@source.guid} at #{@nextFetchInterval}"
        if not @source.authorizer.authorizeInfo.cookie
            @emit "requireAuth"
            return
        weiboUtil.fetch {cookie:@source.authorizer.authorizeInfo.cookie},(err,result)=>
            if err
                @fetchError = err
                return
            @fetchError = null
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
        if not @source.authorizer.authorizeInfo.cookie
            console.log "require Auth by twitter"
            @reset()
            @emit "requireAuth"
            return
        requestUrl = "http://mobile.twitter.com/"
        option = {
            url:requestUrl
            ,headers:{
                "cookie":@source.authorizer.authorizeInfo.cookie
            }
            ,timeout:15 * 1000
        }
        @source.client.request option,(err,res,content)=>
            if err
                @lastError = err
                @emit "exception",new Errors.NetworkError("fail to initialize",{via:err})
                return
            content = content.toString()
            if res.headers["location"] or content.length < 10 * 1024
                @emit "requireAuth"
                return
            result = @parseInitContent content
            if not result
                @setState "fail"
                return
            @source.guid = "twitter_#{result.id}"
            @source.name = "#{result.name}'s Twitter Timeline"
            @setState "initialized"
    parseInitContent:(content)->
        cheerio = require "cheerio"
        $ = cheerio.load content.toString()
        JSON.parse $("#init-data").val()
        return {
            name:data.name
            ,id:data.id
            ,avatar:data.profile_image_url
        }
                
# Authorizer should provide @cookie
# should stored to @source.properties.cookie
querystring = require "querystring"
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
        @timeout = 1000 * 15
    prelogin:()->
        @requirePinCode = false
        url = "https://mobile.twitter.com/"
        option = urlModule.parse url
        option.method = "GET"
        option.headers = {
            Referer:url
            ,"user-agent":@userAgent
            ,Cookie:@jar.getCookiesSync(url).join("; ")
        }
        @source.client.request option,(err,res,content)->
            if err
                @emit "exception",new Errors.NetworkError("fail to prelogin",{via:err})
                return
            content = content.toString()
            rawCookie = []
            cookie = res.headers["set-cookie"]
            if cookie instanceof Array
                rawCookie = cookie
            else if not cookie
                rawCookie = []
            else
                rawCookie = [cookie]
            rawCookie.forEach (rc)=>
                @jar.setCookieSync rc,url
            $ = cheerio.load content
            value = $("#init-data").attr("value")
            if not value
                @emit "exception",new Errors.UnkownError()
                return
                # check pin code in fureture here
                @setState "prelogined"
        req.end()
    loginAttempt:()->
        postData = {
            uname:@username
            ,pwd:@secret
            ,check:1
            ,backUrl:"http://m.weibo.cn"
        }
        postString = querystring.stringify postData
        loginUrl = "https://m.weibo.cn/login?ns=1&backURL=http%3A%2F%2Fm.weibo.cn%2F&backTitle=%CE%A2%B2%A9&vt=4"
        option = urlModule.parse loginUrl
        option.method = "POST"
        option.headers = {
            "Referer":loginUrl
            ,"Content-Length":postString.length
            ,"User-Agent":@userAgent
            ,"Cookie":@jar.getCookiesSync(loginUrl).join("; ")
            ,"Content-Type":"application/x-www-form-urlencoded"
        }
        req = https.request option,(res)=>
            rawCookie = []
            cookie = res.headers["set-cookie"]
            if cookie instanceof Array
                rawCookie = cookie
            else if not cookie
                rawCookie = []
            else
                rawCookie = [cookie]
            rawCookie.forEach (rc)=>
                @jar.setCookieSync rc,loginUrl
            buffers = []
            res.on "data",(data)=>
                buffers.push data
            res.on "end",()=>
                result = (Buffer.concat buffers).toString()
                @mobileRedirectLoginLocation = res.headers["location"]
                @checkLogin()
        req.end(postString)
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
        else
            @authorized = false
            console.log Source.Errors
            @loginError = new Source.Errors.AuthorizationFailed()
        @setState "loginChecked"
Twitter::Updater = Updater
Twitter::Initializer = Initializer
Twitter::Authorizer = Authorizer

module.exports = Twitter
