SybilInterface = require "sybil-interface"
xml2js = require "xml2js"
fs = require "fs"
async = require "async"

inf = new SybilInterface parseInt(process.env.SI_PORT),process.env.SI_HOST,{username:process.env.SI_USR,password:process.env.SI_SEC}

opmlPath = process.argv[2]
sourceDetectTimeout = 1000 * 60 * 2# min
xml2js.parseString (fs.readFileSync opmlPath).toString(),(err,json)->
    items = json.opml.body[0].outline
    rsses = []
    folders = []
    for item in items
        info = item.$
        if info.type is "rss"
            rsses.push {uri:info.xmlUrl,parent:null}
        else
            console.log "folder",info.title
            if info.title not in folders
                folders.push {name:info.title,children:[]}
            for _item in item.outline
                rsses.push {uri:_item.$.xmlUrl,parent:info.title}
    console.log "I'm going to:"
    for folder in folders
        console.log "create folder",folder.name

    for rss in rsses
        if rss.parent
            console.log "add rss #{rss.uri} in #{rss.parent}"
        else
            console.log "add rss #{rss.uri}"
    inf.connect()
    sources = []
    fails = []
    rsses = rsses.slice(10,20)
    inf.ready ()=>
        async.eachLimit rsses,30
        ,(rss,done)->
            hasDone = false
            _done = (err)->
                if hasDone
                    return
                if err is "Timeout"
                    console.log "detect #{rss.uri} timeout, skip."
                    fails.push rss
                hasDone = true
                done()
            setTimeout ()->
                _done()
            ,sourceDetectTimeout

            inf.subscribe {uri:rss.uri},(err,results = [])->
                # For timeout
                # We only make it none blocking, not cancel.
                # We may still get here, but don't call done().
                # As long as it return before we entering the foldering
                # process, it may still take effect.
                # Event it fail to return but actually running at sybil,
                # user may still see this source but not in any folder,
                # this behavior is acceptable.
                console.log "detect #{results.length} sources from #{rss.uri}"
                if results.length is 0
                    fails.push rss
                for item in results
                    if rss.parent
                        item.folderName = rss.parent
                    sources.push item
                _done()
        ,()->
            updateFolders(sources)
updateFolders = (sources)->
    inf.getFolders (err,folders)->
        if err
            throw err
        builder = new SybilInterface.FolderBuilder(folders)
        for source in sources
            if not source.folderName
                continue
                return
            builder.moveSourceToFolder source,source.folderName
            console.log "move source #{source.uri} to folder #{source.folderName}"
        inf.setFolders builder.toJson(),(err)->
            console.log "folders added"
            console.log "subscribe #{sources.length} source total"
            inf.close()
