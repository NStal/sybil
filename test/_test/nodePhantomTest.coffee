phantom = require "phantom"
phantom.create (instance)=>
    instance.createPage (page)=>
        url = "http://www.bilibili.tv/video/bangumi.html"
        page.open url,(status)->
            console.log "open"
#        page.onLoadFinished = ()->
#            console.log "finished"
            page.includeJs "jquery.js", ()->
                console.log "include js"
                html = page.evaluate (()->
                    $("html")[0].outerHTML
                ),(value)->
                    console.log value
                    instance.exit()
        
    