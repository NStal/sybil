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
        @maxFetchInterval = 1000 * 60 * 60 * 12
        @minFetchInterval = 2#1000 * 60
        @lastFetchedArchiveGuids = []
        @rawFetchedArchives = []

        # see @atWait method for detail explaination
        lastFetch = (@source.info.lastFetch or new Date).getTime()
        now = Date.now()
        @leftInterval = @nextFetchInterval - (now - lastFetch)
        if @leftInterval <= 0
            @leftInterval = 1
    later:(factor)->
        @nextFetchInterval = @nextFetchInterval * (factor or 1.4)
        @nextFetchInterval = Math.min(@nextFetchInterval,@maxFetchInterval)
        @nextFetchInterval = Math.max(@nextFetchInterval,@minFetchInterval)
    sooner:(factor)->
        @nextFetchInterval = @nextFetchInterval / (factor or 1.4)
        @nextFetchInterval = Math.max(@nextFetchInterval,@minFetchInterval)
        @nextFetchInterval = Math.min(@nextFetchInterval,@maxFetchInterval)
        
    resetInterval:()->
        @nextFetchInterval = 0
    wait:()->
        @setState "wait"
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
        @nextTimer = setTimeout @fetchAttempt.bind(this),@leftInterval or @nextFetchInterval
        if @leftInterval
            console.debug "Ajdust start at left interval,#{@leftInterval}"
        @leftInterval = null
    fetchAttempt:()->
        @setState "fetchAttempted"
    parseRawArchive:(raw)->
        return raw
    atFetchAttempted:()->
        @lastFetch = new Date()
        if not @fetchError
            guids = []
            hasUpdate = false
            @rawFetchedArchives.forEach (raw)=>
                try
                    archive = @parseRawArchive raw
                catch e
                    console.error "fail to parse archive",archive
                    console.error e
                    @emit "exception",e
                    return
                guids.push archive.guid
                if archive.guid not in @lastFetchedArchiveGuids
                    @emit "archive",archive
                    hasUpdate = true
            @rawFetchedArchives = []
            @lastFetchedArchiveGuids = guids
            if hasUpdate
                @emit "update"
                @sooner()
            else
                @later()
            @emit "modify"
            @wait()
            return
        
        @emit "exception",@fetchError
        if @fetchError instanceof Errors.PermissionDenied
            @requireAuth()
        else 
            @later()
            @wait()
        @emit "modify"
        return
        
module.exports = Updater
        