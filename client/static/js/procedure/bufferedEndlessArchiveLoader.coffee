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
        @bufferSize = option.buffer or 30
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
    _bufferMore:(callback)->
        if @data.archives.length - @data.cursor >  @bufferSize
            callback()
            return
        if @state is "drain"
            callback()
            return
#        if @state in ["loading","pause"]
#            @emit "startLoading"
        if @state is "pause"
            @give "continue"
        else if @state is "void"
            @setState "loading"
        else if @state is "loading"
            # do nothing
            true

        @once "state",(state)=>
            if state is "panic"
                callback @panicError
            else if state is "pause"
                callback()
            else if state is "drain"
                callback()
            else if state is "void"
                callback(new Errors.Abort("abort"))
            else
                callback(new Errors.UnkownError("buffer state change to unexpected",{state:state}))
    atLoading:(sole)->
        if @data.archives.length > 0
            offset = @data.archives[@data.archives.length-1].guid
        else
            offset = null
        @emit "startLoading"
        console.log @query,"???"
        Model.Archive.getByCustom {
            query:@query or {}
            sort:@sort
            count:@bufferSize
            viewRead:@viewRead
            offset:offset
        },(err,archives)=>
            if @stale sole
                return
            @emit "endLoading"
            if err
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
    atPause:()->
        @waitFor "continue",()=>
            @setState "loading"
    atDrained:()->
        return
module.exports = BufferedEndlessArchiveLoader
