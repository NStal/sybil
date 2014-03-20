EventEmitter = require("events").EventEmitter;
async = require("async")
console = require("../common/logger.coffee").create("PluginCenter")
class PluginCenter extends EventEmitter
    constructor:(sybil)->
        @sybil = sybil
        path = require "path"
        @loadAvailablePlugins()
        @pluginSettings = []
    loadAvailablePlugins:()->
        @pluginAvailable = []
        @pluginMap = {}
        @dependencies = new Dependencies()
        files = (require "fs").readdirSync require("path").join(__dirname,"../plugins/")
        files.forEach (name)=>
            reg = new RegExp "[a-z0-9]+(\.coffee)?(\.js)?$"
            if not reg.test name
                console.log "not pass",name
                return
            basename = (require "path").basename(name)
            extname = (require "path").extname(basename)
            pluginName = basename.substring(0,basename.length - extname.length)
            try
                module = require "../plugins/#{name}"
            catch e
                console.debug e
                console.debug e.stack
                console.debug "fail to init plugin #{name}"
                console.debug "skip it"
                return
            plugin = {name:pluginName,module:module,provide:null,requires:module.requires or []}
            @pluginAvailable.push plugin
            @dependencies.add plugin
        @pluginAvailable = @pluginAvailable.filter (plugin)=>
            try
                plugin.dependencies = @dependencies.get(plugin.name).flatten()
                console.debug plugin.dependencies,plugin.name,"deps"
            catch e
                console.debug e
                console.debug "remove invalid plugin",plugin.name
                return false 
            @pluginMap[plugin.name] = plugin
            return true
    loadPlugin:(names...)->
        loaded = []
        console.debug "LOAD~!!!",names
        async.forEachSeries names,((name,done)=>
            if name[0] is "#"
                console.debug "skip plugin #{name}"
                done()
                return
            @_loadPlugin name,(err)->
                if not err
                    loaded.push name
                done(err)
            ),(err)=>
                if err
                    console.error err
                    return
                console.debug "plugin loads: #{loaded.join(',')}"
    prepareSetting:(name,module,callback)->
        console.debug "prepare setting for module #{name}"
        settings = @sybil.settingManager.createSettings(name)
        defines = module.settings or {}
        for prop of defines
            if not defines[prop]
                settings.define(prop)
                continue
            settings.define(prop,defines[prop].type,defines[prop].validator,defines[prop].description)
            if typeof defines[prop].default isnt "undefined"
                console.log "define default",prop,defines[prop].default
                settings._set(prop,defines[prop].default)
        settings.restore (err)->
            settings.save ()->
                console.log "safe default yes!"
                callback err,settings
    _loadPlugin:(name,callback)->
        #console.debug @pluginMap
        depends = @pluginMap[name].dependencies
        console.debug "load plugin #{name} dependencies: #{depends.join(',')}"
        dependsMap = {}
        current = @pluginMap[name]
        if current.provide
            callback null,current.provide
            return
        # load childs of current
        async.eachSeries depends,((pluginName,done)=>
            if @pluginMap[pluginName].provide
                dependsMap[pluginName] = @pluginMap[pluginName].provide
                done()
                return
            @_loadPlugin pluginName,(err,item)->
                # save to dependsMap and latter pass to current.register
                dependsMap[pluginName] = item
                done(err)
            ),(err)=>
                if err
                    callback err
                    return
                @_assignGlobalModel(dependsMap)
                @prepareSetting name,current.module,(err,settings)=>
                    if err
                        callback err
                        return
                    dependsMap.settings = settings
                    current.module.register dependsMap,(err,me)->
                        if err
                            callback err
                            return
                        current.provide = me
                        callback err,me
    _assignGlobalModel:(map)->
        map.sybil = @sybil
        map.database = require("./db.coffee")
        
    
        

class Dependency
    constructor:(@name)->
        @dependencies = []
    addDirectDependency:(item)->
        parent = this
        name = item.name
        while parent
            if parent.name is item.name
                console.error "recursive dependencies #{@name} require #{name}"
                console.error "but #{@name} require is required by #{name}"
                throw new Error "recursive dependencies"
            parent = parent.parent
        item.parent = this
        @dependencies.push item
        console.log @name,"ADD dep",name
    flatten:(queue = [])->
        for child in @dependencies
            child.flatten(queue)
            if child.name not in queue
                queue.push child.name
        return queue
class Dependencies
    constructor:()->
        @items = {}
        @_state = 0
    add:(dep)->
        @_state++
        @items[dep.name] = dep
    get:(name)->
        target = @items[name]
        if not target
            return null
        return @getDependency(target)
    getDependency:(item,stack = [])->
        item.dependency = new Dependency(item.name)
        if item.name in stack
            throw new Error "recursive requires for #{item.name}"
        else
            stack.push item.name
        for child in item.requires or []
            if not @items[child]
                throw new Error "dependency #{child} not found"
            item.dependency.addDirectDependency(@getDependency(@items[child],stack.slice(0)))
        return item.dependency
        
exports.PluginCenter = PluginCenter
exports.Dependency = Dependency
exports.Dependencies = Dependencies