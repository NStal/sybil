info = {"strict":false,"Index":0,"containerPath":"BODY > DIV.z > DIV.large.left > DIV.z-l.f-list > DIV#list_bangumi_dynamic.vidbox > DIV.bgmbox > UL","childrenPathes":["BODY > DIV.z > DIV.large.left > DIV.z-l.f-list > DIV#list_bangumi_dynamic.vidbox > DIV.bgmbox > UL > LI.new","BODY > DIV.z > DIV.large.left > DIV.z-l.f-list > DIV#list_bangumi_dynamic.vidbox > DIV.bgmbox > UL > LI"],"url":"http://www.bilibili.tv/video/bangumi.html"}
uri = "rwp://JTdCJTIyc3RyaWN0JTIyJTNBZmFsc2UlMkMlMjJJbmRleCUyMiUzQTAlMkMlMjJjb250YWluZXJQYXRoJTIyJTNBJTIyQk9EWSUyMCUzRSUyMERJVi56JTIwJTNFJTIwRElWLmxhcmdlLmxlZnQlMjAlM0UlMjBESVYuei1sLmYtbGlzdCUyMCUzRSUyMERJViUyM2xpc3RfYmFuZ3VtaV9keW5hbWljLnZpZGJveCUyMCUzRSUyMERJVi5iZ21ib3glMjAlM0UlMjBVTCUyMiUyQyUyMmNoaWxkcmVuUGF0aGVzJTIyJTNBJTVCJTIyQk9EWSUyMCUzRSUyMERJVi56JTIwJTNFJTIwRElWLmxhcmdlLmxlZnQlMjAlM0UlMjBESVYuei1sLmYtbGlzdCUyMCUzRSUyMERJViUyM2xpc3RfYmFuZ3VtaV9keW5hbWljLnZpZGJveCUyMCUzRSUyMERJVi5iZ21ib3glMjAlM0UlMjBVTCUyMCUzRSUyMExJLm5ldyUyMiUyQyUyMkJPRFklMjAlM0UlMjBESVYueiUyMCUzRSUyMERJVi5sYXJnZS5sZWZ0JTIwJTNFJTIwRElWLnotbC5mLWxpc3QlMjAlM0UlMjBESVYlMjNsaXN0X2Jhbmd1bWlfZHluYW1pYy52aWRib3glMjAlM0UlMjBESVYuYmdtYm94JTIwJTNFJTIwVUwlMjAlM0UlMjBMSSUyMiU1RCUyQyUyMnVybCUyMiUzQSUyMmh0dHAlM0EvL3d3dy5iaWxpYmlsaS50di92aWRlby9iYW5ndW1pLmh0bWwlMjIlN0Q="
sybilSettings = require("../settings.coffee")
sybilSettings.dbName = "sybil-test"
PageWatcher = (require "../collector/pageWatcher.coffee")
collector = new PageWatcher.Collector("pageWatcher")
manager = new PageWatcher.Manager(collector)
manager.on "archive",(archive)=>
    console.log archive
manager.on "ready",()=>
    console.log "ready"
    manager.testURI uri,(err)=>
        if err
            throw err
            return
        manager.subscribe uri,(err,source)=>
            console.log "subscribe source",err,source
#watcher = new PageWatcher(uri)
#watcher.fetch (err,updates,problem)->
#    console.log err,updates,problem
   