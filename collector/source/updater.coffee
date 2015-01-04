States = sybilRequire "common/states.coffee"
Errors = require "./errors.coffee"
console = global.env.logger.create(__filename)
# Events
#
# Require Implements
# fetched()         : set @fetchError, set rawFetchedArchives
# parseRawArchive(raw)   : return one standard archive what was fetched.

# You should always assign data to @data
# And you will benefit from the States sub class
class Updater extends States
    constructor:(@source)->
        super()
        @maxFetchInterval = @maxFetchInterval or 1000 * 60 * 60 * 12
        @minFetchInterval = @minFetchInterval or 1000 * 30
        @timeFactor = 1.4
        @reset()
        @standBy()
    reset:()->
        if @data.nextTimer
            clearTimeout @data.nextTimer
        super()
        @data.nextFetchInterval = 1
        @data.lastFetchedArchiveGuids = []
        @data.rawFetchedArchives = []
        @data.lastFetch = 0
        @data.leftInterval = 1
        @data.maxFetchInterval = @maxFetchInterval or 24 * 60 * 60 * 1000
        @data.minFetchInterval = @minFetchInterval or 30 * 1000
        @data.timeFactor = @timeFactor or 1.4

    standBy:()->
        @waitFor "startSignal",()=>
            @setState "start"
    atStart:()->
        if @state is not "void"
            console.error "can't start when not at void"
            return
        # some prefecth archive may be already supplied by
        # the initializer.
        if @data.prefetchArchiveBuffer instanceof Array
            archives = []
            for raw in @data.prefetchArchiveBuffer
                archive = @parseRawArchive raw
                if @state is "panic"
                    return
                archives.push archive
                @emit "archive",archive
            @data.prefetchArchiveBuffer = []
            @emit "init/archives",archives
        @setState "sleep"
    later:(factor = @data.timeFactor)->
        @data.nextFetchInterval = @data.nextFetchInterval * (factor or 1.4)
        @data.nextFetchInterval = Math.min(@data.nextFetchInterval,@data.maxFetchInterval)
        @data.nextFetchInterval = Math.max(@data.nextFetchInterval,@data.minFetchInterval)
        console.debug "delay #{@source.guid} to #{@data.nextFetchInterval}"
    sooner:(factor = @data.timeFactor)->
#        console.debug @data.nextFetchInterval,@data.minFetchInterval,@data.minFetchInterval
        @data.nextFetchInterval = @data.nextFetchInterval / (factor or 1.4)
        @data.nextFetchInterval = Math.max(@data.nextFetchInterval,@data.minFetchInterval)
        @data.nextFetchInterval = Math.min(@data.nextFetchInterval,@data.maxFetchInterval)

        console.debug "shift #{@source.guid} to #{@data.nextFetchInterval} ealier"
    resetInterval:()->
        @data.nextFetchInterval = 0
    stop:()->
        @reborn()
        @standBy()
    atSleep:(sole)->
        # if we just cover from last restart
        # we may won't recalculate the retry time
        # for example: we update at +1000ms with nextInterval == 2000ms
        # and we close the sybil and restart it at +1800ms
        # so we should use s temperory @leftInterval = 1200ms at first update
        # if in the same situation we restart at +4000ms then we should start
        # update immediately. so the leftInterval will be 1
        clearTimeout @data.nextTimer
        console.debug "#{@source.guid} sleep during  #{@data.leftInterval or @data.nextFetchInterval}"

        @data.nextTimer = setTimeout (()=>
            if not @checkSole sole
                return
            @setState "prepareFetch"
        ),(@data.leftInterval or @data.nextFetchInterval)
        @data.leftInterval = null
    atPrepareFetch:()->
        @data.lastFetch = Date.now()
        @setState "fetching"
    atFetching:(sole)->
        setTimeout (()=>
            if not @checkSole sole
                return
            @_fetchHasCheckSole = true
            @setState "fetched"
        ),0
    parseRawArchive:(raw)->
        return raw
    atFetched:()->
        guids = []
        hasUpdate = false
        if not @_fetchHasCheckSole
            # I hope
            throw new Error "You should call @checkSole(sole) at any async callback to prevent broken state machine. And as a proof of you acknoledgement, you should set @_fetchHashCheckSole to get rid of this error"
        hasError = @data.rawFetchedArchives.some (raw)=>
            try
                archive = @parseRawArchive raw
            catch e
                @error new Errors.ParseError("fail to parse archive",{raw:raw,via:e})
                return true
            if @state is "panic"
                return true
            guids.push archive.guid
            if archive.guid not in @data.lastFetchedArchiveGuids
                @emit "archive",archive
                # probably has update
                # but I don't restore the last guids before the shutdown.
                # so it may not actually has update if it's the first fetch.
                # since it's not abig problem I will leave it there
                hasUpdate = true
            return false
        if hasError
            return
        @data.rawFetchedArchives = []
        @data.lastFetchedArchiveGuids = guids
        if hasUpdate
            @data.lastUpdate = Date.now()
            @emit "update"
            @sooner()
        else
            @later()
        @emit "fetch"
        @emit "modify"
        @setState "sleep"
        return
module.exports = Updater
