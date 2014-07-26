sources = ["weibo","rss","twitter"].filter (item)->return item[0] isnt "#"
exports.Map = do ()->
    result = {}
    sources.forEach (source)->
        result[source] = require "./sources/#{source}"
    return result
exports.List = (exports.Map[name] for name of exports.Map)