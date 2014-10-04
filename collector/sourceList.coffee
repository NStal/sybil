fs = require("fs")
pathModule = require("path")
blacklist = []
files = fs.readdirSync pathModule.join __dirname,"./sources"

sources = files.filter (file)->
    return file not in blacklist and file.indexOf(".") < 0
    
exports.Map = do ()->
    result = {}
    sources.forEach (source)->
        result[source] = require "./sources/#{source}"
    return result

exports.List = (exports.Map[name] for name of exports.Map)

