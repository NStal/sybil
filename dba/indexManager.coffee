# THIS file is not complete
# Note: this file can only be called indepently
# Note2: this file can be called to ensure the indexed db states


if module.parent
    throw new Error "dba module can only be running standalone"
fs = require "fs"
async = require "async"
require "../core/env"
pathModule = require "path"
configPath = pathModule.join __dirname,"../settings.user.json"
env.settings.parseConfig configPath
mongodb = require "mongodb"
MongoClient = mongodb.MongoClient
MongoClient.connect "mongodb://127.0.0.1:#{env.settings.dbPort}/#{env.settings.dbName}",(err,db)->
    async.eachSeries indexes,(index,done)->
        col = db.collection(index.collection)
        # since 1.8.0 the ensureIndex deprecate the createIndex
        # createIndex is now the same as ensureIndex at 3.0.0 mongodb
        # and ensureIndex is likely deprecated by the createIndex...
        start = Date.now()
        console.log "start create index for",index
        col.createIndex index.fields,index.option or {},(err)->
            console.log "create result err:",err
            console.log "complete create index (#{Date.now() - start}ms)"
            done(err)
    ,()->
        console.log "done"
        db.close()

indexes = [
    {
        collection:"archive"
        fields:{
            "sourceGuid":1
            "createDate":-1
        }
    }
    {
        collection:"archive"
        fields:{
            "sourceGuid":1
            "createDate":1
        }
    }
    {
        collection:"archive"
        fields:{
            "listName":1
        }
        option:{
            sparse:true
        }
    }
]
