App = require "/app"
ImageLoader = require "/component/imageLoader"
tm = require "/common/templateManager"
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
        @expose "state"
        @node.state = "void"
        @fallbacks = []
        for prop of params
            @node[prop] = params[prop]
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
        else
            # Disable the last src cache any way.
            # So the change of SmartImage.src will not show the last src
            # , when src is not fully loaded.
            @UI.image.removeAttribute "src"
        @node.state = "loading"
        @currentLoadingSrc = src
        SmartImage.loader.cache src,(error)=>
            @currentLoadingSrc = null
            if error
                if error instanceof ImageLoader.Errors.Abort
                    console.debug "manually abort smart image loading",src
                    return
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
    destroy:()->
        @isDestroyed = true
        if @currentLoadingSrc
            SmartImage.loader.stop @currentLoadingSrc
            @currentLoadingSrc = null
module.exports = SmartImage
