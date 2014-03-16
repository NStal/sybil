server = null
exports.register = (_,callback)->
    sybil = require "../../core/sybil.coffee"
    server = new (require "./webApi.coffee").WebApiServer(sybil)
    callback null,server
exports.requires = []
