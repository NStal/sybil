Errors = require "/common/errors"
class CoreData extends Leaf.EventEmitter
    constructor:(@name)->
        super()
        @reset()
    reset:()->
        @data = null
    load:(callback = ()->)->
        if @data
            callback new Errors.Duplication("data already exists")
            return
        App.messageCenter.invoke "getConfig",@name,(err,data)=>

            if @data
                callback new Errors.Duplication("data already exists")
                return
            @data = data
            if not @isReady
                @isReady = true
                @emit "ready"
            callback()
    get:(key)->
        @check()
        return @data[key]
    set:(key,value)->
        @check()
        @data[key] = value
        @delaySave()
    check:()->
        if not @data
            throw new Errors.NotReady "The CoreData #{@name} are not init yet"
    save:(callback = ()->)->
        App.messageCenter.invoke "saveConfig",{@name,@data},(err)=>
            callback err
    delaySave:(time)->
        delay = @delayTime or 300
        clearTimeout @saveTimer
        @saveTimer = setTimeout @save.bind(this),delay
module.exports = CoreData
