# This module is currently not used
async = require "async"
fs = require "fs"
class HookCenter extends (require "events").EventEmitter
    constructor:()->
        @hooksFolder = "./hooks/"
    loadHooks:(callback)->
        if not fs.existsSync @hooksFolder
            callback null
            return
        fs.readdir @hooksFolder,(err,files)=>
            files = files.filter (item)=>
                reg = /.*hook\.coffee/
                reg.test item
            async.forEachSeries files,((filename,done)=>
                @loadHookFile (require "path").join(@hooksFolder,filename),done
                ),(err)->
                    callback err

    loadHookFile:(filepath,callback)->
        try
            (require "./"+filepath).register(this)
        catch e
            console.error e
            process.exit(1)
            callback e
            return
        callback null
    hook:(name,callback)->
        @on "hook/#{name}",callback

exports.HookCenter = HookCenter
