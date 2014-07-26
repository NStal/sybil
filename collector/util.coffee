httpUtil = require "../httpUtil.coffee"
errorDoc = require "error-doc"
async = require "async"
# difference with httpUtil.httpGet
# 1. default use queue
# 2. default timeout 30s
# 4. only return downloaded content
# 5. check integrity if content length provided
# 
Errors = errorDoc.create()
    .inherit httpUtil.Error
    .generate()
exports.fetch = (url,option,callback)->
    proxies = global.env.settings.proxies
    retrys = [null].concat proxies
    success = null
    async.eachSeries proxies,(()->
        httpUtil.httpGet {
            url:url
            ,noQueue:true
            },
        