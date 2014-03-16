phantom = require "../collector/phantom.coffee"
async = require "async"
urls = ["http://www.bilibili.tv/video/bangumi.html"
    ,"http://www.bilibili.tv/video/bangumi.html"
    ,"http://www.bilibili.tv/video/bangumi.html"
]
async.map urls,((url,done)->
    phantom.html url,(err,html)->
        console.log "done url #{url} length#{html.length}"
        done err,{url:url,html:html}
    ),(err,results)->
        console.log "done"
        console.log err,results.length
    