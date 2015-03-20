Model = require "../model"
Errors = require "/errors"
# I maintain a buffer, when unaccessed archives less than bufferSize
# I buffer more. This process is seperate with the archive consumer.
# Archive consumer just keep get archive from buffer, and request to
# buffer more if not enough archive in buffer available.
class BufferedEndlessArchiveLoader extends Leaf.States
    constructor:()->
        super()
    reset:()->
        @emit "endLoading"
        super()
        @data.archives = []
        @data.guids = []
        @data.cursor = 0
        @data.drain = false
    init:(option = {})->
        if @state isnt "void"
            throw new Error "State isnt void, can init loader when already running."
        @reset()
        @viewRead = option.viewRead or false
        @sort = option.sort or "latest"
        @bufferSize = option.bufferSize or 20
        @query = option.query or {}
    more:(count,callback)->
        # not enough item but has something
        if count > @bufferSize
            count = @bufferSize
        if @data.archives.length - @data.cursor < count and not @data.drain
            @_bufferMore (err)=>
                if err
                    callback err
                    return
                @more count,callback
            return
        start = @data.cursor
        @data.cursor += count
        archives = @data.archives.slice(start,start+count)
        if @data.archives.length - @data.cursor < @bufferSize
            @_ensureLoadingState()
        callback null,archives
        # though user can decide drain by herself.
        if @isDrain()
            @emit "drain"
    oneMore:(callback)->
        @more 1,(err,archives)->
            if err
                callback err
                return
            if not archives or archives.length is 0
                callback(null,null)
                return
            callback(null,archives[0])
    isDrain:()->
        return @data.drain and @data.cursor >= @data.archives.length
    _bufferMore:(callback = ()->)->
        if @data.archives.length - @data.cursor >  @bufferSize
            callback()
            return
        if @state in ["loading","pause","void"]
            @emit "startLoading"
        @_ensureLoadingState()
        if @state is "drain"
            @emit "endLoading"
            callback()
            return
        @once "loadend",(err)=>
            console.log "loadend",@data.archives
            if err instanceof Errors.Drained
                callback()
                return
            @emit "endLoading"
            callback err
    _ensureLoadingState:()->
        if @state is "panic"
            @recover()
            @setState "loading"
        else if @state is "pause"
            @give "continue"
        else if @state is "void"
            @setState "loading"
        else if @state is "loading"
            # do nothing
            true
    atPanic:()->
        if @panicState is "loading"
            @emit "loadend"
    atLoading:(sole)->
        if @data.archives.length > 0
            splitter = @data.archives[@data.archives.length-1].guid
        else
            splitter = null
        option = {
            sort:@sort
            count:@bufferSize
            viewRead:@viewRead
            splitter:splitter
        }
        for prop of @query or {}
            option[prop] = @query[prop]
        Model.Archive.getByCustom option,(err,archives)=>
            if @stale sole
                return
            if err
                @emit "loadend",err
                @error err
                return
            for archive in archives
                if archive.guid in @data.guids
                    continue
                @data.guids.push archive.guid
                @data.archives.push archive
            if archives.length < @bufferSize
                @data.drain = true
                @setState "drained"
            else
                @setState "pause"
    atPause:(sole)->
        @waitFor "continue",()=>
            if @stale sole
                return
            @setState "loading"
        @emit "loadend"
    atDrained:()->
        @emit "loadend",new Errors.Drained("drained")
        @emit "endLoading"
        return
module.exports = BufferedEndlessArchiveLoader
