cheerio = require "cheerio"
Source = require "../../source/source.coffee"
urlModule = require "url"
EventEmitter = (require "events").EventEmitter
http = require "http"
twitterUtil = require "./twitterUtil.coffee"
ErrorDoc = require "error-doc"
Errors =  Source.Errors

console = console = env.logger.create __filename

class Twitter extends Source
    constructor:(info = {})->
        super info
        @type = "twitter"
        @client = new twitterUtil.TwitterRequestClient()
    @test = (uri)->
        return uri is "twitter" or (new RegExp("twitter.com/?$","i")).test uri

class TwitterUpdater extends Source::Updater
    constructor:(@source)->
        super(@source)
        @timeout = 60 * 1000
        @minFetchInterval = 10 * 1000
        @userAgent = "Mozilla/5.0 (Linux; Android 4.2.1; en-us; Nexus 5 Build/JOP40D) AppleWebKit/535.19 (KHTML, like Gecko) Chrome/18.0.1025.166 Mobile Safari/535.19"
    atFetching:(sole)->
        if not @data.authorizeInfo or not @data.authorizeInfo.cookie
            @error new Errors.AuthorizationFailed("twitter require authorization")
            return
        requestUrl = "https://mobile.twitter.com/"
        option = {
            url:requestUrl
            ,headers:{

                "cookie":@data.authorizeInfo.cookie
                ,"user-agent":@userAgent
            }
            ,timeout:@timeout
        }
        @source.client.request option,(err,res,content)=>
            @_fetchHasCheckSole = true
            if not @checkSole sole
                return
            if err
                @error new Errors.NetworkError("fail to fetch")
                return
            content = content.toString()
            if res.headers["location"] or content.length < 3 * 1024
                @error new Errors.AuthorizationFailed("recieve redirect or content too less likely to be")
                return

            $ = cheerio.load content.toString()
            try
                data = JSON.parse $("#launchdata").html()
            catch e
                data = null
            if not data
                @error new Errors.ParseError("fail to parse launchdata")
                return
            if not data.twitter_objects
                @error new Errors.ParseError "invalid twitter response #{JSON.stringify data}"
                return
            users = data.twitter_objects.users
            @data.rawFetchedArchives = ({archive:data.twitter_objects["tweets"][id],users:users} for id of data.twitter_objects["tweets"])
            @setState "fetched"
    parseRawArchive:(data)->
        raw = data.archive
        users = data.users
        user = users[raw.userId] or {}
        originalLink = "https://twitter.com/#{user.screen_name}/status/#{raw.id}"
        title = user.screen_name
        content = twitterUtil.renderDisplayContent(data)
        displayContent = content
        result =  {
            guid:"#{@source.type}_#{originalLink}"
            ,collectorName:@source.type
            ,type:@source.type
            ,createDate:new Date(raw.created_at)
            ,fetchDate:new Date()
            ,author:{
                name:user.screen_name
                ,avatar:user.profile_image_url
                ,link:user.profile_url
            }
            ,originalLink:originalLink
            ,sourceName:@source.name
            ,sourceUrl:"https://twitter.com/"
            ,sourceGuid:@source.guid
            ,title:title
            ,content:content
            ,displayContent:displayContent
            ,contentType:"html"
            ,attachments:[]
            ,meta:{
                raw:JSON.stringify({raw:raw,user:user})
            }
        }
        return result

class TwitterInitializer extends Source::Initializer
    constructor:(@source)->
        super(@source)
        @userAgent = "Mozilla/5.0 (Linux; Android 4.2.1; en-us; Nexus 5 Build/JOP40D) AppleWebKit/535.19 (KHTML, like Gecko) Chrome/18.0.1025.166 Mobile Safari/535.19"
    atInitializing:(sole)->
        if not @data.authorizeInfo or not @data.authorizeInfo.cookie
            @error new Errors.AuthorizationFailed("twitter initialize need authorize")
            return
        requestUrl = "https://mobile.twitter.com/"
        option = {
            url:requestUrl
            ,headers:{
                "cookie":@data.authorizeInfo.cookie
                ,"user-agent":@userAgent
            }
            ,timeout:15 * 1000
            ,method:"GET"
        }
        @source.client.request option,(err,res,content)=>
            if not @checkSole sole
                return
            if err
                @error new Errors.NetworkError("fail to initialize",{via:err})
                return
            content = content.toString()
            if res.headers["location"] or content.length < 2 * 1024
                @error new Errors.AuthorizationFailed("recieve redirect to too less content");
                return
            result = @parseInitContent content
            if not result
                @error new Errors.ParseError "fail to parse init content"
                return
            @data.guid = "twitter_#{result.id}"
            @data.name = "#{result.name}'s Twitter Timeline"
            @data.prefetchArchiveBuffer = result.archives
            @setState "initialized"
    parseInitContent:(content)->
        $ = cheerio.load content.toString()
        try
            data = JSON.parse $("#launchdata").html()
        catch e
            console.debug e
            return null

        users = data.twitter_objects.users
        return {
            name:data.profile.name
            ,id:data.profile.id
            ,avatar:data.profile.profile_image_url
            ,archives:({archive:data.twitter_objects["tweets"][id],users:users} for id of data.twitter_objects["tweets"])
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
httpUtil = global.env.httpUtil
class TwitterAuthorizer extends Source::Authorizer
    constructor:(@source)->
        super(@source)
        @jar = new CookieJar()
        @timeout = 1000 * 60
    atPrelogin:(sole)->
        @data.requireCaptcha = false
        preLoginUrl = "https://twitter.com/"
        option = {}
        option.url = preLoginUrl
        option.method = "GET"
        option.timeout = @timeout
        option.jar = @jar
        option.headers = {
            Referer:preLoginUrl
            ,"user-agent":null
            ,Cookie:@jar.getCookieStringSync(preLoginUrl)
        }
        @source.client.request option,(err,res,content)=>
            if not @checkSole sole
                return
            if err
                @error new Errors.NetworkError("fail to prelogin",{via:err})
                return
            content = content.toString()
            $ = cheerio.load content
            try
                data = JSON.parse $("#init-data").attr("value")
            catch e

                data = {}
            if not data.formAuthenticityToken
                @error new Errors.UnkownError("fail to get prelogin data")
                return
                # check pin code in fureture here
            @data.preloginData = data
            @setState "prelogined"
    atLogining:(sole)->
        postData = {
            "session[username_or_email]":@data.username
            ,"session[password]":@data.secret
            ,remember_me:1
            ,return_to_ssl:"true"
            ,redirect_after_login:"/"
            ,authenticity_token:@data.preloginData.formAuthenticityToken
        }
        loginUrl = "https://twitter.com/sessions"
        option = {url:loginUrl}
        option.method = "POST"
        option.data = postData
        option.headers = {
            "Referer":loginUrl
            ,"User-Agent":""
            ,"Cookie":@jar.getCookieStringSync(loginUrl)
            ,"Content-Type":"application/x-www-form-urlencoded"
        }
        option.jar = @jar
        @source.client.request option,(err,res,content)=>
            if not @checkSole sole
                return
            if err
                @error new Errors.NetworkError("fail to conduct login attempt due to network error");
                return
            content = content.toString()
            @data.postSessionResult = content
            buffers = []
            @_checkLogin()
    _checkLogin:()->
        if @data.postSessionResult.indexOf("error") > 0
            @data.authorized = false
            @error new Errors.AuthorizationFailed("invalid authentication info")
            return
        @data.authorized = true
        @data.cookie = @jar.getCookieStringSync("https://twitter.com")
        @data.authorizeInfo = {cookie:@data.cookie}
        @setState "authorized"
Twitter::Updater = TwitterUpdater
Twitter::Initializer = TwitterInitializer
Twitter::Authorizer = TwitterAuthorizer

module.exports = Twitter
