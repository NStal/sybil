# be careful not conflict with nodejs event emitter domain.
EventEmitter = require("eventex").EventEmitter
class Domain extends EventEmitter
    constructor:()->
        super()
        @nodes = []
    setLord:(lord)->
        @lord = lord
    unsetLord:()->
        @lord = null
    addNode:(node)->
        @nodes.push node
    removeNode:(node)->
        @nodes = @nodes.filter (item)->
            return item isnt node
    handleNode:(node)->
        return false
module.exports = Domain
