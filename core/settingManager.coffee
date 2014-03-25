EventEmitter = require("events").EventEmitter
pathModule = require("path")
SafeFileWriter = require("safe-file-writer");

# Sybil only has one SettingManager
# Every plugin can has it's own Settings or access globalsettings
# Every Settings can have many SettingEntry with a Validator
class SettingManager extends EventEmitter
    constructor:()->
        @path = pathModule.resolve(__dirname,"..","settings/")
        @settingGroup = []
    setDefaultSettingFolder:(path)->
        @path = path
    createSettings:(name,path)->
        settings = new Settings(name)
        settings.setPath path or pathModule.join(@path,"#{name}.confg.json")
        @settingGroup.push settings
        return settings
class Settings extends EventEmitter
    constructor:(@name)->
        @entrys = {}
        @dumpdata = {}
        @__defineGetter__ "length",()=>
            length = 0
            for prop of @entrys
                length++
            return length
    define:(name,type,validator,description = "")->
        entry = new SettingEntry(name,type,validator,description)
        @entrys[name] = entry
    setPath:(path)->
        @path = path
    restore:(callback = ()->true)->
        if not @path
            throw new Error "can restore without setPath() first"
        @writer = new SafeFileWriter(@path)
        @writer.restore (err,content)=>
            if err
                console.error "fail to restore settings"
                console.error err
                console.error "fallback to empty settings"
                data = {}
            else if not content
                # first time create
                data = {}
            else
                try
                    data = JSON.parse(content.toString())
                catch err
                    console.error "fail to restore settings"
                    console.error e
                    console.error "fallback to empty settings"
                    data = {}
            @_restoreFromJson(data)
            callback()
    get:(key,value)->
        if @entrys[key] and typeof @entrys[key].value isnt "undefined"
            return @entrys[key].value
        return value
    _set:(key,value)->
        @entrys[key].value = value
    set:(key,value)->
        if @entrys[key] && @entrys[key].test value
            @emit "change",key,value
            @emit "change/#{key}",value
            @save()
            @_set(key,value)
            return
        throw new Error "invalid setting set for #{key} of value #{value}"
    validate:(key,value)->
        return @entrys[key] and @entrys[key].validate(value) or {valid:false,error:"unkown setting entry"}
    test:(key,value)->
        return @entrys[key] and @entrys[key].test(value) or false
    save:(callback = ()->true)->
        # if not restore then throw
        # because it's likely to overwrite good settings
        if not @writer
            throw new Error "save settings need to restore it first"
        json = @toJSON()
        @writer.save JSON.stringify(json,null,4),(err)->
            if err
                console.error "fail to save settings"
                callback err
                return
            callback()
    _restoreFromJson:(data)->
        for key of data
            if @entrys[key] && @entrys[key].test data[key]
                @_set(key,data[key])
            else
                # if a data come from settings file are not valid
                # we should preserve it. When we are saving, we should check
                # if this invalid value are overwrite by the anyother value,
                # if overwrited then great, if not we write it back to file
                @dumpdata[key] = data[key]
                console.warn "fail to restore setting entry #{key}:#{data}"
                console.warn "ignore it"
    toValidJSON:()->
        # contain only validated data
        data = {}
        for name of @entrys
            if typeof @entrys[name].value isnt "undefined"
                data[name] = @entrys[name].value
        return data
    toJSON:()-> 
        # contain data that validated or from the restore
        validData = @toValidJSON()
        result = {}
        for prop of @dumpdata
            result[prop] = @dumpdata[prop]
        for prop of validData
            result[prop] = validData[prop]
        return result
        
class SettingEntry
    @Type = {string:"string"
        ,int:"int"
        ,bool:"bool"
        ,object:"object"
        ,any:"any"
    }
    constructor:(@name,@type,@validator)->
        if @type is "int"
            @validator = @validator or Validator.intValidator
        else
            @validator = @validator or Validator.bypassValidator
    test:(value)->
        return @validator.test(value)
    validate:(value)->
        return @validator.validate(value)

class Validator
    @bypassValidator = new Validator()
    @intValidator = new Validator (value)->
        value = value or ""
        console.log "test",value.toString().trim()
        if /^\d+$/.test value.toString().trim()
            return parseInt(value.toString().trim())
        throw new Error "need to be an integer"
    constructor:(@checker,@option = {})->
        # checker should pass the value if it's correct
        # or modify the value to make it correct
        # or just throw an Error to ensure it's not correct
        @checker = @checker or (value)->value
    validate:(value)->
        try
            validValue = @checker(value)
        catch e
            return {
                valid:false
                ,error:e.message
            }
        return {
            valid:true
            ,value:validValue
            ,modified:value is validValue
        }
    test:(value)->
        return @validate(value).valid
module.exports = SettingManager
module.exports.Validator = Validator
module.exports.SettingManager = SettingManager