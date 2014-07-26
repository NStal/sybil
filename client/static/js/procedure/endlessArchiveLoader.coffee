Model = require "../model"
class EndlessArchiveLoader extends Leaf.EventEmitter
    constructor:()->
        super()
        @archives = []
        @reset()
    reset:(option = {})->
        @archives = []
        @guids = []
        @viewRead = option.viewRead or false
        @sort = option.sort or "latest"
        @count = option.count or 10
        @query = option.query or {}
    _load:(option,callback)->
        option.query = @query or {}
        Model.Archive.getByCustom option,callback
    more:(callback = ()-> true)->
        if @isLoading
            callback "isLoading"
            return
        if @noMore
            callback "noMore"
            return
        if @archives.length > 0
            offset = @archives[@archives.length-1].guid
        else
            offset = null
        @isLoading = true
        @emit "startLoading"
        @_load {@viewRead,@sort,@count,offset},(err,archives)=>
            @emit "endLoading"
            @isLoading = false
            if err
                callback err
                return
            for archive in archives
                if archive.guid in @guids
                    continue
                @guids.push archive.guid
                @archives.push archive
                @emit "archive",archive
            if archives.length < @count
                @emit "noMore"
                @noMore = true
            callback null,archives
    destroy:()->
        super()
module.exports = EndlessArchiveLoader;
