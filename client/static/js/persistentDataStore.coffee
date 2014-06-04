App = require("app")
async = require("lib/async")
_ = require("lib/lodash")
# A module to save or load persistentent datas
# in general is some data are browser/UI runtime irrelevant, and the amount is likely to be limited
# then use this module
# if it's UI relevant then it should just use userConfig which uses local storage
# in case it has unpredictable large amount and may need real time sync with backend
# I should build another backend model and sets of API for it.
class PersistentDataStoreManager
    constructor:()->
        @indexes = []
    syncIndex:(callback = ()->true)->
        App.messageCenter.invoke "getConfig","configIndex",(err,indexes)=>
            if err
                callback err
                return
            if (indexes instanceof Array)
                indexes = indexes.map (name)->{name:name}
                for index in indexes
                    if not (@indexes.some (old)->old.name is index.name)
                        @indexes.push index
            callback null
    saveIndex:(callback = ()->true )->
        App.messageCenter.invoke "saveConfig",{name:"configIndex",data:@indexes.map (index)->index.name},(err)->
            callback err
    load:(name,callback = ()->true )->
        if not @indexes
            throw new Error "can load store before sync indexes"
        store = null
        found = @indexes.some (index)->
            if index.name is name
                if index.store
                    store = index.store
                return true
            return false
        if not found
            store = new PersistentDataStore(name)
            @indexes.push {name:name,store:store}
            # since even if save indexes fails
            # There are just nothing I can do...
            # It may cost some store index lost
            # but it's ok. since index are just for the inital preload (or just useless).
            @saveIndex()
            callback null,store
            return
        store = store or new Store(name)
        store.load (err)->
            callback err,store
class PersistentDataStore extends Leaf.EventEmitter
    constructor:(@name,@data = {})->
        @_delaySaveCallbackes = []
        @delayTime = 100
    load:(callback = ()->true )->
        App.messageCenter.invoke "getConfig",@name,(err,data)=>
            if err
                callback err
                return
            data = data or {}
            @data = data
            callback()
    save:(callback = ()->true)->
        App.messageCenter.invoke "saveConfig",{name:@name,data:@data},(err)->
            callback err
    delaySave:(callback = ()->true)->
        @_delaySaveCallbackes.push callback
        clearTimeout @_delayTimer
        save = ()=>
            @save (err)=>
                callbacks = @_delaySaveCallbackes.splice(0)
                for callback in callbacks
                    callback err
        @_delayTimer = setTimeout save,@delayTime or 100
    set:(key,value)->
        @data[key] = _.cloneDeep value
        @delaySave()
    get:(key,defaultValue)->
        return (_.cloneDeep @data[key]) or defaultValue
exports.Store = PersistentDataStore
exports.Manager = PersistentDataStoreManager