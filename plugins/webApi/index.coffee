server = null
exports.register = (deps,callback)->
    sybil = require "../../core/sybil.coffee"
    server = new (require "./webApi.coffee").WebApiServer(sybil,deps.settings)
    callback null,server
exports.requires = []
exports.settings = {
    host:{
        default:null
    }
    port:{
        type:"int"
        default:null
    }
}
