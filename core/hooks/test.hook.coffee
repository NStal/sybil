exports.register = (hookCenter)->
    hookCenter.hook "readLater",(archive)->
        console.log "read later hooks hook: #{archive.guid}"