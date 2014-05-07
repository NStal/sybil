EndlessArchiveLoader = require "./endlessArchiveLoader"
Model = require "../model"
App = require "../app"
class EndlessSearchArchiveLoader extends EndlessArchiveLoader
    constructor:()->
        super()
    reset:(option = {})->
        super option
        @query = option.query or ""
    _load:(option,callback)->
        option.input = @query
        option.viewRead = true
        App.messageCenter.invoke "search",option,(err,archives = [])->
            if err
                callback err
                return
            callback null,archives.map (data)->
                return new Model.Archive(data)
    destroy:()->
        super()
module.exports = EndlessSearchArchiveLoader;