module.exports = class Flag extends Leaf.EventEmitter
    constructor:(@_turnOn,@_turnOff)->
        super()
        @_turnOn ?= ()->
        @_turnOff ?= ()->
        @value = null
        @yes = @set
        @no = @unset
    reverse:()->
        @_reverse = not @_reverse
    attach:(obj,name,good,bad)->
        @_turnOn = ()->
            obj[name] = good or true and not @_reverse
        @_turnOff = ()->
            obj[name] = bad or false or @_reverse and true
        return this
    bind:(context)->
        @context = context
        return this
    set:(turnOn)->
        if typeof turnOn is "function"
            @_turnOn = turnOn
            return
        if @value
            return this
        @value = true
        @_turnOn.call @context
        @emit "set"
        @emit "change"
        return this
    unset:(turnOff)->
        if typeof turnOff is "function"
            @_turnOff = turnOff
            return
        if not @value and @value isnt null
            return this
        @value = false
        @_turnOff.call @context
        @emit "unset"
        @emit "change"
        return this
    toggle:()->
        if @value
            return @no()
        else
            return @yes()
