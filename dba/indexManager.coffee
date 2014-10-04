# THIS file is not complete
# Note: this file can only be called indepently
# Note2: this file can be called to ensure the indexed db states

if module.parent
    throw new Error "dba module can only be running standalone"
fs = require "fs"
pathModule = require "path"
configPath = pathModule.join __dirname,"../settings.user.json"
config = JSON.parse fs.readFileSync configPath,"utf8"
mongodb = require "mongodb"
MongoClient = mongodb.MongoClient
MongoClient.connect "mongodb://127.0.0.1:#{config.dbPort}/#{config.dbName}",(err,db)->
    if err
        throw err
    console.log "connected"
    archiveCollection = db.collection("archive")
#    for prop of archiveCollection
#        console.log prop,typeof archiveCollection[prop]
    archiveCollection.ensureIndex "sourceGuid",(err,d1,d2)->
        console.log "ensure index",d1,d2
        archiveCollection.indexes (err,d1,d2)->
            console.log err,d1,d1
            process.exit(0)
    