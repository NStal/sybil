SafeFileWriter = require("safe-file-writer")
LRU = require("lru-cache")
class NodeInfoStore
    constructor:(@option = {})->
        @storageFilePath = @option.path or "./nodeInfos.json"
        @cache = new LRU {
            max:option.max or 500
        }
        @writer = new SafeFileWriter @storageFilePath
        @maxSaveInterval = 1000
    add:(node)->
        if not node or not node.publicKey or not node.channel
            return
        addresses = node.channel.getAddresses()
        hash = node.publicKey.getHash("hex")
        @cache.set hash,{
            hash:hash
            ,publicKey:node.publicKey.toString()
            ,addresses:addresses
        }
        return
    delaySave:()->
        clearTimeout @_saveTimer
        @_saveTimer = setTimeout @_save.bind(this),@maxSaveInterval
    save:(callback = ()->true )->
        @writer.save JSON.stringify(@cache.values),(err)->
            callback err
        return
    restore:(callback = ()-> true)->
        @writer.restore (err,value)=>
            if err or not value
                value = "[]"
            infos = JSON.parse(value)
            if not (infos instanceof Array)
                infos = []
            infos.forEach (value)=>
                @cache.set value.hash,value
            callback null,infos
module.exports = NodeInfoStore