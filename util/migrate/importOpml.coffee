# a quick and dirty script to import OPML to sybil
xml2js = require "xml2js"
fs = require "fs"
async = require "async"
importUtil = require("../lib/importUtil.coffee")
WebApiInterface = importUtil.WebApiInterface
Source = importUtil.Source
Folder = importUtil.Folder
filePath = process.argv[2]
panic = (args...)->
    console.error.apply console.args
    process.exit(1)
addRsses = (folders,rsses,callback)->
    inf = new WebApiInterface(port,host)
    toSubscribe = []
    inf.connect()
    inf.on "ready",()->
        console.log "sybil web api connected."
        console.log "compare with the existing data"
        inf.messageCenter.invoke "getConfig","sourceFolderConfig",(err,folderConfig)->
            if err
                callback err
                return
            if not folderConfig
                folderConfig = {folders:[]}
                # make sure the config index contain the sourceFolderConfig
                inf.messageCenter.invoke "getConfig","configIndex",(err,configs)->
                    configs = configs or []
                    configs.push "sourceFolderConfig"
                    inf.messageCenter.invoke "saveConfig",{name:"configIndex",data:configs}
            if not folderConfig.folders
                folderConfig.folders = []
            folderConfig.folders = folderConfig.folders.map (item)->
                new Folder(item)
            folders.forEach (folder,index)->
                found = (folderConfig.folders.some (oldFolder)->
                    if oldFolder.name is folder.name
                        folders[index] = oldFolder
                        children = []
                        for child in oldFolder.children
                            children.push new Source(child)
                        oldFolder.children = children
                        return true
                    return false
                )
                if not found
                    folderConfig.folders.push new Folder(folder)
            # now db folders should contained all the folders
            console.log "folder synced"
            console.log "sync sources"
            inf.messageCenter.invoke "getSources",{},(err,sources)->
                rssToAdd = []
                rsses.forEach (rss)->
                    notExist = (sources.every (source)->
                        return source.uri isnt rss.url
                    )
                    if notExist
                        rssToAdd.push rss
                    else
                        console.log "rss #{rss.url} already exists skip it"
                subscribes rssToAdd,folderConfig.folders,(err,result)->
                    console.log err,result
    subscribes = (rsses,folders)->
        failed = []
        async.mapLimit rsses,20,((rss,done)->
            inf.messageCenter.invoke "getSourceHint",rss.url,(err,hints)->
                if err or hints.length is 0
                    console.error "fail to add rss url:#{rss.url}, fail to detect"
                    failed.push rss
                    done(null,rss)
                    return
                inf.messageCenter.invoke "subscribe",hints[0],(err,source)->
                    if err and err isnt "duplicate"
                        console.error "fail to subscribe #{hints[0].uri}",err
                        done(null,rss)
                        return
                    if err and err is "duplicate"
                        console.error rss.url,"dupli!"
                        #throw "shouldn't duplicate"
                    if rss.parent
                        console.log "rss.at parent",rss.parent
                        found =false
                        for folder in folders
                            if folder.name is rss.parent
                                folder.add new Source(source)
                                found = true
                                break
                        if not found
                            throw "#{rss.parent} not found"
                    else
                        folders.push new Source(source)
                    console.log "done subscribe #{rss.url}"
                    done(null)
            ),(err,results)->
                console.log "save folder info"
                #console.log "save",JSON.stringify(dbFolders,null,4)
                jsonFolders = (item.toJSON() for item in folders)
                console.log "save jsonFOlders",jsonFolders
                inf.messageCenter.invoke "saveConfig",{name:"sourceFolderConfig",data:jsonFolders},(err)->
                    if err
                        console.error err
                        console.error "fail to save folder config"
                        throw err
                    fails = results.filter (item)->item
                    inf.close()
                    callback null,fails


port = parseInt(process.argv[3]) or 3107
host = process.argv[4] or "localhost"
if not filePath
    console.log "usage coffee importReadOpml.coffee <subscription.xml path> [<port> [<host>]]"
    process.exit(1)
xml =  (fs.readFileSync filePath).toString()
xml2js.parseString xml,(err,json)->
    items = json.opml.body[0].outline
    rsses = []
    folders = []
    for item in items
        info = item.$
        if info.type is "rss"
            rsses.push {url:info.xmlUrl,parent:null}
        else
            console.log "folder",info.title
            if info.title not in folders
                folders.push {name:info.title,children:[]}
            for _item in item.outline
                rsses.push {url:_item.$.xmlUrl,parent:info.title}
    console.log "I'm going to:"
    for folder in folders
        console.log "create folder",folder.name
    for rss in rsses
        if rss.parent then console.log "at  #{rss.parent}"
        console.log "add rss #{rss.url}"
    addRsses folders,rsses,(err,fails)->
        if err
            console.error err
            panic("fatal error")
        console.log "every thing is done"
        console.error "thess sources are failed to add:"
        for item in fails
            console.log item.url