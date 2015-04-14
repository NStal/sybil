server = null
exports.register = (deps,callback)->
    sybil = require "../../core/sybil"
    server = new (require "./webApi").WebApiServer(sybil,deps.settings)
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
