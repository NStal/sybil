App = require("main.js")
async = require("lib/async.js")
# A module to save or load persistent frontend config from backend
# frontend config are not really mean frontend config
class PersistDataStoreManager
    constructor:()->
        @indexes = []
    syncIndex:(callback = ()->true)->
        App.messageCenter.invoke "getConfig","configIndex",(err,indexes)=>
            if err
                callback err
                return
            if not (indexes instanceof Array)
                @indexes = []
            else
                @indexes = indexes.map (name)->{name:name}
            callback null
    saveIndex:()->
        
    load:(name,callback = ()->true )->
        if not @indexes
            throw new Error "can load config before sync indexes"
        config = null
        found = @indexes.some (index)->
            if index.name is name
                if index.config
                    config = index.config
                return true
            return false
        if not found
            config = new Config(name)
            @indexes.push {name:name,config:config}
            # since even if save indexes fails
            # There are just nothing I can do...
            # It may cost some config index lost
            # but it's ok. since index are just for inital preload
            @saveIndex()
            callback null,config
            return
        config = config or new Config(name)
        config.load (err)->
            callback err,config
class PersistDataStore extends Leaf.EventEmitter
    @configs = []
    @load = (callback)->
        # get all available configs
        App.messageCenter.invoke "getConfig","configIndex",(err,configs)=>
            if err
                throw err
            if not (configs instanceof Array)
                configs = []
            async.map configs,((name,done)=>
                App.messageCenter.invoke "getConfig",name,(err,data)=>
                    if err
                        done err
                    else
                        #  sync db config with local config
                        data = data or {}
                        for item in @configs
                            if item.name is name
                                for prop of data
                                    item.data[prop] = data[prop]
                                return done(null,null)
                        done(null,new Config(name,data))
                ),(err,configs)=>
                    if err
                        if callback
                            callback err
                        else
                            throw err
                    @isReady = true
                    configs = configs.filter (item)->item
                    @configs.push.apply @configs,configs
                    Model.emit "config/ready"
                    if @_saveOnLoad
                        @_saveIndex ()=>
                            @save()
    @save = (name,callback)->
        if not @isReady
            console.debug "won't save #{name} when config not load yet"
            return
        if name
            configsToSave = @configs.filter (item)->item.name is name
        else
            configsToSave = @configs
        # use this tricky logic to save for all or a single config
        # with the same logic (both as array)
        async.each configsToSave,((config,done)=>
            App.messageCenter.invoke "saveConfig",{name:config.name,data:config.toJSON()},(err)->
                done err
            ),(err)=>
                if err
                    if callback
                        callback err
                    else
                        throw err
    @getConfig = (name,defaultConfig)->
        for item in @configs
            if item.name is name
                return item
        if defaultConfig and typeof defaultConfig isnt "object"
            throw "invalid defaultConfig"
        if not @isReady
            @_saveOnLoad = true
        return @createConfig(name,defaultConfig and defaultConfig or {})
    @createConfig = (name,data,callback)->
        if not name
            err = "config need a name"
            if callback
                callback err
            else
                throw err
        if name is "configName"
            err = "invalid config name, conflict with 'configName'"
            if callback
                callback err
            else
                throw err
            return
        for item in @configs
            if item.name is name
                err =  "already exists"
                if callback
                    callback err
                else
                    throw err
                return
        config = new Config(name,data)
        @configs.push config
        @_saveIndex (err)=>
            if err
                if callback
                    callback err
            @save config.name,callback
        return config
    @_saveIndex = (callback)->
        if not @isReady
            if callback
                callback "config not ready"
            return
        App.messageCenter.invoke "saveConfig",{name:"configIndex",data:(item.name for item in @configs)},(err)->
            callback err
            
    constructor:(name,@data = {})->
        @name = name
    toJSON:()->
        return @data
    save:(callback)->
        Config.save @name,callback
    set:(key,value)->
        @data[key] = _.cloneDeep value
        @save()
    get:(key,defaultValue)->
        return (_.cloneDeep @data[key]) or defaultValue
exports.Store = PersistDataStore
exports.Manager = PersistDataStoreManager