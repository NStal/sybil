States = sybilRequire "common/states.coffee"
createError = require "create-error"
# Overview:
#
# Any implementer should implement atInitializing and do the initialization.
# Initialize is a one time business, every error lead to a source panic
# except AuthorizationFailed.
#
# Once initialized you may set @data.initializeInfo and @data.guid.
# They will be passed to updater.
# If @data.guid is not provided, we will use TYPE_URI as the guid
# , say rss_http://nstal.me/rss.xml.
# @data.initialzeInfo can left empty if you should updater will need
# nothing more than the source.uri.
#
# After the above initialize work done.
# @setState "initialized" to announce it.
# If any error occurs, call @error(err) and return.
#
# For authorization required source:
# You can access authorizeInfo at @data.authorizeInfo.
# Basicly a authorization required procedure would be
# 1. start initialize
# 2.1 initializer find no authorizeInfo provided or
# 2.2 initializer use empty or invalid authorizeInfo to initialize
#     (You make a decision, either is OK)
# 3. yield a AuthorizationFailed error.
# 4. upper system will handle the authorization failure.
# 5. after that, upper system will reset the initializer and try it again.
# 6. this time initializer will find a valid authorizeInfo or we repeat at 2.1/2.2
# 7. initialized!
#
# Any other error yielded will cause a source panic.
# And as a result, I will mark the subscribe action as failed.
# But feel free to do so. We will leave the retry mechanism
# to frontend or what ever user are directly interact with.

# EXTRA
# For some source we may get some archive at initialization.
# You can save them to @data.prefetchArchiveBuffer.
# So user may see the prefetched archive to decide wether to subscribe
# this source, or after subscribe, there will be some archive listed
# without waiting for first update.
#
# For some source like rss, a initialze process will just like a regular
# update procedure, which only validate the success of update as a proof
# of initialization.
#
class Initializer extends States
    constructor:(@source)->
        super()
        @reset()
    reset:()->
        super()
        @data.initialized = false
        @data.prefetchArchiveBuffer = []
    standBy:()->
        @waitFor "startSignal",@_initialize.bind(this)
    start:()->
        @give "startSignal"
    _initialize:()->
        @setState "initializing"
        return true
    atInitializing:(sole)->
        setTimeout (()=>
            if not @checkSole sole
                return
            @setState "initialized"
        ),0
    atInitialized:()->
        @data.initialized = true
        @emit "initialized"
module.exports = Initializer
