settings = require("../../settings")
settings.parseConfig()
db = require("../../core/db")
fs = require "fs"
sourceStream = fs.createWriteStream("./backup.source.json")
archiveStream = fs.createWriteStream("./backup.archive.json")
db.init()
db.ready ()->
    console.log "ready"
    db.getSources (err,sources)->
        console.log "get source!"
        for source in sources
            sourceStream.write(JSON.stringify(new db.Source(source)))
            sourceStream.write("\n")
        sourceStream.end()
        console.log "source end",sources.length
        db.getArchiveStream (err,stream)->
            stream.on "data",(data)->
                archiveStream.write(JSON.stringify(new db.Archive(data)))
                archiveStream.write("\n")
            stream.on "close",()->
                archiveStream.end()
                process.exit(0)
