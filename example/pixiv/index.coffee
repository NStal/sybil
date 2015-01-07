Source = sybilRequire "collector/source/source.coffee"
tough = require "tough-cookie"
urlModule = require "url"
httpUtil = global.env.httpUtil
cheerio = require "cheerio"
EventEmitter = (require "events").EventEmitter
class Pixiv extends Source
    @detectStream = (uri = "")->
        stream = new EventEmitter()
        process.nextTick ()->
            if uri.toString().toLowerCase() is "pixiv" or new RegExp("pixiv.net","i").test(uri)
                stream.emit "data",new Pixiv({uri:"http://pixiv.net/"})
            stream.emit "end"
        return stream
    constructor:(info)->
        @type = "pixiv"
        super(info)

class PixivInitializer extends Source::Initializer
    atInitializing:(sole)->
        if not @data.authorizeInfo or not @data.authorizeInfo.cookie
            @error new Source.Errors.AuthorizationFailed("Pixiv require authorize")
            return
        # get authorize info try authorize
        # we do the validation by check the username exists
        option = {
            url:"http://www.pixiv.net/mypage.php"
            headers:{
                cookie:@data.authorizeInfo.cookie
            }
        }
        # more information for httpUtil please checkout /common/httpUtil.coffee
        httpUtil.httpGet option,(err,res,content)=>
            if not @checkSole sole
                return
            if err
                @error new Source.Errors.NetworkError("Fail to initialize due to network",{via:err})
                return
            # I use cheerio to do the DOM parsing.
            # https://github.com/cheeriojs/cheerio
            $ = cheerio.load content.toString()
            name = $("#page-mypage > div.ui-layout-west > section._unit.my-profile-unit > a > h1").text() or ""
            name = name.trim()
            if not name
                @error new Source.Errors.AuthorizationFailed("No username found likely due to network error")
                return
            # If you don't set guid, the default guid
            # for the source will be "#{@source.type}_#{@source.uri}"
            @data.guid = "pixiv_fav_#{name}"
            # Name that will be seen by user in GUI.
            @data.name = "#{name}'s favorate pixiv"
            # finally..
            @setState "initialized"

class PixivAuthorizer extends Source::Authorizer
    constructor:(@source)->
        super(@source)
        @jar = new tough.CookieJar()
        @timeout = 1000 * 10
    # Very lucky pixiv don't check csrf token or captcha at login
    # so we do not need a prelogin here you can skip it.
    # If your source need a captcha or a CSRF token, you can checkout
    # /collector/source/authorizer.coffee
    # Authorizer::atPrelogin/Authorizer::atPrelogined
    atLogining:(sole)->
        if not @data.username or not @data.secret
            @error new Source.Errors.AuthorizationFailed("Pixiv authentication requires a valid username and password")
            return
        loginUrl = "http://www.pixiv.net/login.php"
        params = {
            mode:"login"
            return_to:"/"
            pixiv_id:@data.username
            pass:@data.secret
            skip:1
        }
        # Set cookie jar
        # We use tough-cookie, hope you like it
        # https://github.com/goinstant/tough-cookie
        # By pass the jar as option, httpUtil
        # will automatically update cookies in the jar
        option = {
            url:loginUrl
            jar:@jar
            headers:{
                "Referer":"http://www.pixiv.net/"
                "Origin":"http://www.pixiv.net"
                "User-Agent":@UA
                "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8"
            }
            data:params
            timeout:@timeout
        }
        # You can use nodejs builtin http module as well.
        # Here we using the sybil builin httpUtil.
        httpUtil.httpPost option,(err,res,content)=>
            if not @checkSole sole
                return
            if err
                @error new Source.Errors.NetworkError("net work error at login",{via:err})
                return
            if not res.headers["set-cookie"]
                @error new Source.Errors.AuthorizationFailed("No cookie set, likely invalid username or password")
                return
            cookie = @jar.getCookieStringSync loginUrl
            # set authorize info here so `Pixiv` may pass it
            # to other modules that need it.
            @data.authorizeInfo = {cookie:cookie}
            @setState "authorized"

class PixivUpdater extends Source::Updater
    atFetching:(sole)->
        if not @data.authorizeInfo or not @data.authorizeInfo.cookie
            @error new Source.Errors.AuthorizationFailed("pixiv updater require authorize")
            return
        index = 1
        favUrl = "http://www.pixiv.net/bookmark_new_illust.php?p=#{index}"
        option = {
            url:favUrl
            headers:{
                cookie:@data.authorizeInfo.cookie
            }
        }
        httpUtil.httpGet option,(err,res,content)=>
            @_fetchHasCheckSole = true
            if not @checkSole sole
                return
            if err
                @error new Source.Errors.NetworkError("fail to get fav image due to network error",{via:err})
                return
            $ = cheerio.load content.toString()
            $images = $("#wrapper > div.layout-body > div > ul > li")
            results = []
            try
                $images.each ()->
                    node$  = $ this
                    title = node$.find("a.work > h1").text()
                    src = node$.find("a.work > div > img").attr("src")
                    if src
                        src = src.replace("150x150","600x600")
                    user$ = node$.find "a.user.ui-profile-popup"
                    username = user$.attr("data-user_name")
                    userId = user$.attr("data-user_id")
                    userLink = user$.attr("href")
                    link = node$.find("a.work").attr("href")
                    urlData = urlModule.parse(link,true)
                    results.push {
                        title:title
                        link:link
                        illustId:urlData.query.illust_id
                        preview:src
                        username:username
                        userId:userId
                        userLink:userLink
                    }
            catch e
                @error new Source.Errors.ParseError "parse error after update",{via:e}
                return
            results = results.filter (item)->
                return item.illustId
            @data.rawFetchedArchives = results
            @setState "fetched"
    parseRawArchive:(archive)->
        # I will sanitize every thing at frontend by my best.
        # So you may not worry about XSS or something like that.

        siteUrl = "http://www.pixiv.net/"
        # resolve relative links

        if archive.link
            archive.link = urlModule.resolve siteUrl,archive.link
        if archive.userLink
            archive.userLink = urlModule.resolve siteUrl,archive.userLink

        content = "<a href='#{archive.link}'><img src='#{archive.preview}'/></a>"
        return {
            guid:"#{@source.type}_#{archive.link}"
            type:@source.type
            createDate:new Date()
            fetchDate:new Date()
            author:{
                name:archive.username
                link:archive.userLink
            }
            originalLink:archive.link
            sourceName:@source.name
            sourceUrl:@source.uri
            sourceGuid:@source.guid
            title:archive.username
            content:content
            contentType:"text/html"
            attachments:[]
            meta:{
                raw:archive
            }
        }
Pixiv::Initializer = PixivInitializer
Pixiv::Authorizer = PixivAuthorizer
Pixiv::Updater = PixivUpdater

module.exports = Pixiv
