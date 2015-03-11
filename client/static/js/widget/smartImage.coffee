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
        @expose "on"
        @node.state = "void"
        for prop of @params
            @node[prop] = @params[prop]
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
        if @loadingSrc
            @UI.image.src = @loadingSrc
        @node.state = "loading"
        SmartImage.loader.cache src,(error)=>
            if error
                @node.state = "fail"
                if @errorSrc
                    @UI.image.src = @errorSrc
                return
            @node.state = "succuess"
            @UI.image.src = src
module.exports = SmartImage
