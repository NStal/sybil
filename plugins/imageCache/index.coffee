httpUtil = require "../../common/httpUtil"
urlModule = require "url"
pathModule = require "path"

# This file is a mess.
# I will refactor it later or never.

exports.requires = ["webApi"]
exports.register = (dep,callback)->
    if not dep.webApi
        callback "need webApi to implement"
        return
    settings = require("../../settings")
    server = dep.webApi.app
    server.get "/imageCache",(req,res)->
        url = req.param("url")
        res.redirect(url)
fixHeaderFilename = (url,remoteRes)->
