# be careful not conflict with nodejs event emitter domain.
EventEmitter = require("eventex").EventEmitter;
class Domain extends EventEmitter
    constructor:()->
        super()
    setLord:(lord)->
        @lord = lord
    unsetLord:()->
        @lord = null
    handleNode:(node)->
        return false
module.exports = Domain