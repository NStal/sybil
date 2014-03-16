exports.parse = (query)->
    if typeof query isnt "string"
        return {}
    queryWords = query.split(/\s+/).filter (item)->item
    queryObjects = []
    for word in queryWords
        if word.indexOf(":") >= 0
            kv = word.split(":")
            queryObjects.push {type:kv[0],value:kv[1]}
        else
            queryObjects.push {type:"keyword",value:word}
    return queryObjects