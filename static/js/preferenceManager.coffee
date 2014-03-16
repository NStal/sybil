class PreferenceManager extends Leaf.EventEmitter
    constructor:()->
        @localStorage = window.localStorage
        @prefix = "preference_"
        @watchers = []
    toggle:(key)->
        if @get(key)
            @set(key,false)
        else
            @set(key,true)
    set:(key,value)->
        wrapper = {}
        wrapper.value = value
        
        @localStorage.setItem @prefix+key,JSON.stringify(wrapper)
        for watcher in @watchers
            if watcher.key is key
                watcher.callback value
    get:(key)->
        wrapper = @localStorage.getItem @prefix+key
        if not wrapper
            return null
        wrapper = JSON.parse(wrapper)
        return wrapper.value
    watch:(key,callback)->
        console.log "when calling watch it will actually trigger once."
        console.assert callback
        @watchers.push {key,callback}
        value = @get(key)
        callback(value)
window.PreferenceManager = PreferenceManager;