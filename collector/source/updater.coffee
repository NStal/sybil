States = require "../states.coffee"
Errors = require "./errors.coffee"
console = global.env.logger.create(__filename)
# Events
# exception: any none fatal error
# requireAuth: please auth the Source.Authorizer than call start
# archive: has a new archive arrived
# update: has updates
#
# Require Implements
# fetchAttempt()         : set @fetchError, set rawFetchedArchives
# parseRawArchive(raw)   : return standard archive by what fetch attempt set
class Updater extends States
    constructor:(@source)->
        super()
        @setState "void"
        @nextFetchInterval = @source.info.nextFetchInterval or 1
        @maxFetchInterval = @maxFetchInterval or 1000 * 60 * 60 * 12
        @minFetchInterval = @minFetchInterval or 1000 * 30
        @lastFetchedArchiveGuids = []
        @rawFetchedArchives = []
#        @nextFetchInterval = Math.min(Math.max(@minFetchInterval,@nextFetchInterval),@maxFetchInterval)
         # see @atWait method for detail explaination
        @lastFetch = (@source.info.lastFetch or new Date)
        if @lastFetch.getTime
            @lastFetch = @lastFetch.getTime()
        now = Date.now()
        console.debug @nextFetchInterval,now,@lastFetch,now-@lastFetch
        @leftInterval = @nextFetchInterval - (now - @lastFetch)
        
        if @leftInterval <= 0
            console.debug "left interval too small: #{@leftInterval}. set to 1"
            @leftInterval = 1
        console.log @leftInterval,@nextFetchInterval,"updater interval"
        @standBy()
    standBy:()->
        @waitFor "startSignal",()=>
            @start()
    start:()->
        if @state is not "void"
            console.error "can't start when not at void"
            return
        @isStopped = false
        if @prefetchArchiveBuffer and @prefetchArchiveBuffer.length > 0
            for raw in @prefetchArchiveBuffer
                @emit "archive",@parseRawArchive raw
            @prefetchArchiveBuffer = []
        @setState "wait"

    later:(factor)->
        @nextFetchInterval = @nextFetchInterval * (factor or 1.4)
        @nextFetchInterval = Math.min(@nextFetchInterval,@maxFetchInterval)
        @nextFetchInterval = Math.max(@nextFetchInterval,@minFetchInterval)
        console.debug "delay #{@source.guid} to #{@nextFetchInterval}"
    sooner:(factor)->
        @nextFetchInterval = @nextFetchInterval / (factor or 1.4)
        @nextFetchInterval = Math.max(@nextFetchInterval,@minFetchInterval)
        @nextFetchInterval = Math.min(@nextFetchInterval,@maxFetchInterval)
        console.debug "shift #{@source.guid} to #{@nextFetchInterval} ealier"
    resetInterval:()->
        @nextFetchInterval = 0
    stop:()->
        @isStopped = true
    requireAuth:()->
        @setState "waitAuth"
        @emit "requireAuth"
    atWait:()->
        if @isStopped
            @setState "void"
            return
        # if we just cover from last restart
        # we may won't recalculate the retry time
        # for example: we update at +1000ms with nextInterval == 2000ms
        # and we close the sybil and restart it at +1800ms
        # so we should use s temperory @leftInterval = 1200ms at first update
        # if in the same situation we restart at +4000ms then we should start
        # update immediately. so the leftInterval will be 1
        clearTimeout @nextTimer
        console.debug "updater #{@source.guid} waiting at #{@leftInterval or @nextFetchInterval}"
        @nextTimer = setTimeout (()=>
            @setState "fetching"
        ),(@leftInterval or @nextFetchInterval)
        if @leftInterval
            console.debug "#{@source.guid} adjust start at left interval,#{@leftInterval}"
        @leftInterval = null
    atFetching:()->
        @lastFetch = new Date()
        @fetchAttempt()
    fetchAttempt:()->
        @setState "fetchAttempted"
    parseRawArchive:(raw)->
        return raw
    atFetchAttempted:()->
        guids = []
        hasUpdate = false
        @rawFetchedArchives.forEach (raw)=>
            try
                archive = @parseRawArchive raw
            catch e
                @error new Errors.ParseError("fail to parse archive",{raw:raw})
                return
            guids.push archive.guid
            if archive.guid not in @lastFetchedArchiveGuids
                @emit "archive",archive
                # probably has update
                # but I don't restore the last guids before the shutdown.
                # so it may not actually has update if it's the first fetch.
                # since it's not abig problem I will leave it there
                hasUpdate = true
        @rawFetchedArchives = []
        @lastFetchedArchiveGuids = guids
        
        if hasUpdate
            @emit "update"
            @sooner()
        else
            @later()
        @emit "fetch"
        @emit "modify"
        @setState "wait"
        return
module.exports = Updater
