EventEmitter = require("events").EventEmitter;
async = require("async")
console = require("../common/logger.coffee").create("PluginCenter")
class PluginCenter extends EventEmitter
    constructor:(sybil)->
        @sybil = sybil
    loadPlugins:(names,callback)->
        @pluginAvailable = []
        @pluginMap = {}
        @dependencies = new Dependencies()
        names = names.filter (item)->item
        names = names.map (item)->item.trim()
        names.forEach (name)=>
            if name[0] is "#"
                return
            
            plugin = {name:name,provide:null,modulePath:"../plugins/#{name}"}
            try
                plugin.module = require plugin.modulePath
            catch e
                console.error e
                throw new Error "fail to load plugin #{name}"
            plugin.requires = plugin.module.requires
            @pluginAvailable.push plugin
            @dependencies.add plugin
            
        @pluginAvailable = @pluginAvailable.filter (plugin)=>
            try
                plugin.dependencies = @dependencies.get(plugin.name).flatten()
                console.debug plugin.name,"dependencies:",plugin.dependencies
            catch e
                console.debug e
                console.debug "plugin dependencies unmet",plugin.name
                console.debug "disable it"
                return false 
            @pluginMap[plugin.name] = plugin
            return true
        async.forEachSeries @pluginAvailable,((plugin,done)=>
            @_loadPlugin plugin,done
            ),(err)->
                if err
                    console.error "fail to load plugin"
                    callback err
                    return
                callback null
    prepareSetting:(plugin,callback)->
        name = plugin.name
        module = plugin.module
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
                callback err,settings
    _loadPlugin:(plugin,callback)->
        #console.debug @pluginMap
        name = plugin.name
        depends = plugin.dependencies
        console.debug "load plugin #{name} dependencies: #{depends.join(',')}"
        dependsMap = {}
        current = plugin
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
                current.module = require(current.modulePath)
                current.requires = current.module.requires or []
                @prepareSetting plugin,(err,settings)=>
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