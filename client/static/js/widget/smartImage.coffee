App = require "/app"
tm = require "/templateManager"
tm.use "widget/smartImage"

class SmartImage extends Leaf.Widget
    @setLoader = (loader)->
        @loader = loader
    constructor:(el,params = {})->
        super App.templates.widget.smartImage
        @expose "src"
        @expose "loadingSrc"
        @expose "errorSrc"
        @expose "fallbackSrcs"
        @expose "on"
        @node.state = "void"
        @fallbacks = []
        for prop of @params
            @node[prop] = @params[prop]
    onSetFallbackSrcs:(fallbacks = [])->
        if typeof fallbacks is "string"
            fallbacks = fallbacks.split(",")
        else if fallbacks instanceof Array
            fallbacks = fallbacks.filter (item)->typeof item is "string"
        @fallbacks = fallbacks
    onSetState:(state)->
        @state = state
        @emit "state",state
    onSetLoadingSrc:(src)->
        if src is @loadingSrc
            return
        @loadingSrc = src
        if @node.state is "loading"
            @UI.image.src = src
    onSetErrorSrc:(src)->
        if src is @errorSrc
            return
        @errorSrc = src
        if @node.state is "fail"
            @UI.image.src = src
    onSetSrc:(src)->
        if src is @src
            return
        @src = src
        @trySrc src
    trySrc:(src)->
        if @loadingSrc
            @UI.image.src = @loadingSrc
        @node.state = "loading"
        SmartImage.loader.cache src,(error)=>
            if error
                if @fallbacks.length > 0
                    @node.state = "fallback"
                    @trySrc @fallbacks.shift()
                    return
                @node.state = "fail"
                if @errorSrc
                    @UI.image.src = @errorSrc
                return
            @node.state = "succuess"
            @UI.image.src = src

module.exports = SmartImage
