fs = require("fs")
pathModule = require("path")
blacklist = []
source = []

# load local source.
exports.getLocalSource = ()->
    files = fs.readdirSync pathModule.join __dirname,"./sources"
    sources = files.filter (file)->
        return file not in blacklist and file.indexOf(".") < 0
    do ()->
        result = {}
        sources.forEach (source)->
            result[source] = require "./sources/#{source}"
        return result

registerMap = {}

# Load source from disk
exports.sync = ()->
    exports._SourceMap = {}
    localMap = @getLocalSource()
    for prop of localMap
        exports._SourceMap[prop] = localMap[prop]
    for prop of registerMap
        exports._SourceMap[prop] = registerMap[prop]
    @dirty = false

exports.register = (name,Source)->
    registerMap[name] = Source
    @dirty = true
exports.unregister = (name)->
    delete registerMap[name]
    @dirty = true


exports.getMap = ()->
    if not exports._SourceMap
        @sync()
    if @dirty
        @sync()
    return exports._SourceMap

exports.getList = ()->
    map = @getMap()
    (map[name] for name of map)

# load custom sources
exports.loadSourcesInFolder = (dir)->
    if not fs.existsSync dir
        return
    files = fs.readdirSync dir
    sources = files.filter (file)->
        return file not in blacklist and file.indexOf(".") < 0
    do ()->
        sources.forEach (sourceName)->
            exports.register sourceName,require(pathModule.join dir,sourceName)
