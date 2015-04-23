App = require "/app"
Model = App.Model
Errors = require "/common/errors"
# I maintain a buffer, when unaccessed archives less than bufferSize
# I buffer more. This process is seperate with the archive consumer.
# Archive consumer just keep get archive from buffer, and request to
# buffer more if not enough archive in buffer available.
class BufferedEndlessArchiveLoader extends Leaf.States
    constructor:()->
        super()
        @on "state",(state)=>
            if @data.lastState isnt "loading" and state is "loading"
                @emit "startLoading"
            else if @data.lastState is "loading" and state isnt "loading"
                @emit "endLoading"
    reset:()->
        @emit "endLoading"
        super()
        @data.lastState = null
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
        @querySize = option.querySize or option.bufferSize or 10
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
        @_ensureLoadingState()
        if @state is "drain"
            callback()
            return
        @once "loadend",(err)=>
#            console.log "loadend",@data.archives
            if err instanceof Errors.Drained
                callback()
                return
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
        option = {
            sort:@sort
            count:@querySize
            viewRead:@viewRead
            splitter:@data.splitter or null
        }
        for prop of @query or {}
            option[prop] = @query[prop]
        Model.Archive.getByCustom option,(err,archives)=>
            if @stale sole
                return

            if err
                @error err
                return
            # start from splitter
            @data.splitter = archives?[archives?.length-1]?.guid or null
            for archive in archives
                if archive.guid in @data.guids
                    continue
                @data.guids.push archive.guid
                @data.archives.push archive
            if archives.length > 0
                @emit "loadend"
            if archives.length < @querySize
                @data.drain = true
                @setState "drained"
            else if @data.archives.length - @data.cursor < @bufferSize
                # not enough load more!
                @setState "loading"
            else
                @setState "pause"
    atPause:(sole)->
        @waitFor "continue",()=>
            if @stale sole
                return
            @setState "loading"
    atDrained:()->
        @emit "loadend",new Errors.Drained("drained")
        @emit "endLoading"
        return
module.exports = BufferedEndlessArchiveLoader
