class UserConfig extends Leaf.EventEmitter
    constructor:(name = "userConfig")->
        super()
        @name = name
        if not localStorage
            @data = {}
            return
        @data = JSON.parse(localStorage.getItem(@name) or "{}")
    get:(key,value)->
        if typeof @data[key] is "undefined"
            return value
        return @data[key]
    set:(key,value)->
        @emit "change/#{key}",value
        @data[key] = value
        if localStorage
            localStorage.setItem(@name,JSON.stringify(@data))
    init:(key,value)->
        if typeof @data[key] isnt "undefined"
            return
        @set(key,value)

module.exports = UserConfig