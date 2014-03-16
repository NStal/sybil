phantom = require "phantom"
async = require "async"

# option
# @url: url to open
# @scripts: array of scripts to preload
#
# callback
# (err,info,clean)
# @err is err
# @info container the page information
# @clean is the callback after page is useless
exports.init = (callback)->
    if exports.instance
        callback exports.instance
        return
    if @isInit
        setTimeout (()->
            exports.init(callback)),10
        return
    @isInit = true
    phantom.create (instance)=>
        if exports.instance
            exports.instance.exit()
        exports.instance = instance
        @isInit = false
        callback(instance)
exports.clean = ()->
    if exports.instance
        exports.instance.exit()
exports.open = (option,callback)=>
    if not option.url
        callback "url not specified"
    work = (instance) ->       
        instance.createPage (page)->
            page.open option.url,(status)->
                option.scripts = option.scripts or []
                async.each option.scripts,((script,done)->
                    page.includeJs script,()->
                        done()
                    ),(err)->
                        callback null,{page:page,status:status},()->
                        page.close()
    if exports.instance
        work exports.instance
    else
        exports.init work
exports.pageQueue = async.queue(((info,done)->
    exports.open {url:info.url,scripts:info.scripts or []},(err,result,clean)->
        info.callback err,result,()->
            clean()
            done()
    ),1)
exports.html = (url,callback)=>
    exports.pageQueue.push {url:url,scripts:['http://ajax.googleapis.com/ajax/libs/jquery/1.8.2/jquery.min.js'],callback:((err,info,clean)->
        if err
            callback err
            return
        info.page.evaluate (()->
            $("html")[0].outerHTML
            ),(html)->
                clean()
                callback null,html
    )}
exports.init ()->true