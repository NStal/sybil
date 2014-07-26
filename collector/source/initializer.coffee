States = require "../states.coffee"
createError = require "create-error"
# Overview:
# Initialize is a one time business
# if not success than it's failed.
# 
# Event
# fail:
#     when failed
# initialized:
#     at initialized, complete all missing property of model,
#     and at least tried to fetch archive once, there may be
#     some duplication of the logic. it's worth it.
# initializing():
#     do the initializing job and switch state to initilaized if success or
#     just set state to fail
# initialize():
#     set source.name
#     set source.guid
#     set source.properties
#     set @source.updater.prefetchArchiveBuffer to first available archivesb
#     set @initialzied = true
#     Note: it's important that only set guid when successfully
#     AND REMEMBER TO BLOCK duplicate initialze call
#     initialized
# failed
class Initializer extends States
    constructor:(@source)->
        super()
        @setState "void"
        # we may gain some archive at initialize state
        # we can buffer them here
        # and emit "archive" when source is ready and confirmed
        @source.updater.prefetchArchiveBuffer = []
        @initialized = false
    start:()->
        @reset()
        @initialize()
    initialize:()->
        if @state is "initializing"
            return false
        @setState "initializing"
        return true
    reset:()->
        @setState "void"
    atFailed:()->
        @emit "fail"
    atInitialized:()->
        @emit "initialized"
module.exports = Initializer
