# state
# init: nothing has done will try ask user secret
# localAuthed: username and secret is given try prelogin
# prelogined: prelogin data fetched
# prepared: after prelogin no captcha is needed or already go throught the pin code recognize process, next step is post login
# pinReady: pin code image is downloaded and
# posted: login posted, check success or retcode to do the correct things

Source = require "../../source/source"
EventEmitter = (require "events").EventEmitter
querystring = require "querystring"
createError = require "create-error"
tough = require "tough-cookie"
httpUtil = global.env.httpUtil
urlModule = require "url"
cheerio = require "cheerio"
Cookie = tough.Cookie
CookieJar = tough.CookieJar
ErrorDoc = require "error-doc"
Errors = exports.Errors = Source.Errors
exports.fetch = (info = {},callback)->
    cookie = info.cookie
    timeout = info.timeout or 30 * 1000
    url = "http://m.weibo.cn/searchs/searchFeed?&feature=0&uicode=20000060&rl=1&ext=plt%3A490&page=1"
    option = {
        url:url
        headers:{
            cookie:cookie
        }
        maxRedirect:0
    }
    httpUtil.httpGet option,(err,res,content = "")->
        if err
            if err instanceof httpUtil.Errors.MaxRedirect
                callback new Errors.AuthorizationFailed "fetch recieve redirect, likely due to session outdated.",{via:err}
                return
            else
                callback new Errors.NetworkError "fail to fetch weibo content"
                return
            return

        content = content.toString()
        try
            result = JSON.parse content
        catch e
            callback new Errors.ParseError("fail to parse result via #{e}",{via:e,statusCode:res.statusCode,raw:content})
            return
        if result.ok is 0
            callback null,[]
        if result.ok isnt 1
            callback new Errors.AuthorizationFailed("result.ok isnt 1 result is #{JSON.stringify result}")
            return
        callback null,result.mblogList or []


exports.renderDisplayContent = (raw)=>
    $text = cheerio.load "<div class='tweet'>#{raw.text}</div>"
    $text("a").each ()->
        href = $text(this).attr("href")
        $text(this).attr("href",urlModule.resolve("http://weibo.com/",href))
    pics = raw.pic_ids or []
    pics.forEach (id)->
        $text(".tweet").append "<img src='http://ww1.sinaimg.cn/large/#{id}' data-medium-src='http://ww1.sinaimg.cn/mw1024/#{id}' data-raw-src='http://ww1.sinaimg.cn/large/#{id}' data-thumbnail-src='http://ww2.sinaimg.cn/thumbnail/#{id}'/>"
    if raw.retweeted_status
        retweet = exports.renderDisplayContent raw.retweeted_status
        $text(".tweet").append retweet
    return $text.html()
exports.gb2utf8 = (buffer)->
    Iconv = (require "iconv").Iconv
    data = (new Iconv("gb2312","utf-8//TRANSLIT//IGNORE")).convert(buffer)
    return data
