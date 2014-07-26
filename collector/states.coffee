EventEmitter = (require "events").EventEmitter

Errors = (require "error-doc").create()
    .define "AlreadyDestroyed"
    .define "InvalidState"
    .generate()
class States extends EventEmitter
    @Errors = Errors
    constructor:()->
        @state = null
        @lastException = null
        @states = {}
        super()
    declare:(states...)->
        for state in states
            @states[state] = state
    destroy:()->
        if @isDestroyed
            return;
        @isDestroyed = true
        @emit = ()->
        @on = ()->
        @once = ()->
        @removeAllListeners()
    setState:(state)->
        if not state
            throw new Errors.InvalidState "Can't set invalid states #{state}"
        if @isDestroyed
            @emit "exception",new Errors.AlreadyDestroyed()
            return
        @state = state
        @emit "state",state
        @emit "state/#{state}"
        stateHandler = "at"+state[0].toUpperCase()+state.substring(1)
        if this[stateHandler]
            this[stateHandler]()
    exception:(error)->
        @emit "exception",error
        @lastException = error
    give:(name,items...)->
        if @_waitingGiveName is name
            @_waitingGiveName = null
            @_waitingGiveHandler = null
            handler = @_waitingGiveHandler
            handler.apply this,items
        return
    waitFor:(name,handler)->
        @_waitingGiveName = name
        @_waitingGiveHandler = handler
        
module.exports = States