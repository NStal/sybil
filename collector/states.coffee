# States
#
# How it works
# 1. states should start from "void", there should be no atVoid handler.
# 2. by calling @error current state and error will be saved
#    and we will turn the state into "panic".
# 3. at "panic" states, state machine won't turn unless you call @recover()
#    or setState to "void" manually.
#    Latter one won't reset @panicError and @panicState.
# 4. you should do the error recovering in atPanic handler, or just emit "panic"
#    event to the parent.
# 5. all the local data should be store on @data, so we can easily recover
#    from the previous shutdown.
# 6. should be rebust against invalid states jump
# 7. we have a default atPanit state handler to just emit a "panic" event
#    so the parent of this state machine should come to rescue
#    but in case we know how to recover from the current state, we may over
#    write atPanic handler to suppress the panic event
EventEmitter = (require "events").EventEmitter
Errors = (require "error-doc").create()
    .define("AlreadyDestroyed")
    .define("InvalidState")
    .generate()
class States extends EventEmitter
    @Errors = Errors
    constructor:()->
        @state = "void"
        @lastException = null
        @states = {}
        @data = {}
        super()
    declare:(states...)->
        for state in states
            @states[state] = state
    destroy:()->
        if @isDestroyed
            return;
        @emit "destroy"
        @isDestroyed = true
        @emit = ()->
        @on = ()->
        @once = ()->
        @removeAllListeners()
    setState:(state)->
        if not state
            throw new Errors.InvalidState "Can't set invalid states #{state}"
        if @state is "panic" and state isnt "void"
            return
        if @isDestroyed
            return
        @state = state
        @emit "state",state
        @emit "state/#{state}"
        stateHandler = "at"+state[0].toUpperCase()+state.substring(1)
        if this[stateHandler]
            this[stateHandler]()
    error:(error)->
        @panicError = error
        @panicState = @state
        @setState "panic"
    recover:()->
        @panicError = null
        @panicState = null
        @setState "void"
    give:(name,items...)->
        if @_waitingGiveName is name
            handler = @_waitingGiveHandler
            @_waitingGiveName = null
            @_waitingGiveHandler = null
            handler.apply this,items
        return
    stopWaiting:(name)->
        if name
            if @_waitingGiveName is name
                @_waitingGiveName = null
                @_waitingGiveHandler = null
            else
                throw new Error "not waiting for #{name}"
        else
            @_waitingGiveName = null
            @_waitingGiveHandler = null
    isWaitingFor:(name)->
        if not name and @_waitingGiveName
            return true
        if name is @_waitingGiveName
            return true
        return false
    waitFor:(name,handler)->
        if @_waitingGiveName
            throw new Error "already waiting for #{@_waitingGiveName} and can't wait for #{name} now"
        @_waitingGiveName = name
        @_waitingGiveHandler = handler
        @emit "wait/#{name}"
    atPanic:()->
        @emit "panic",@panicError,@panicState
module.exports = States