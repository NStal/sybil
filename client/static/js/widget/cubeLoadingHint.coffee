App = require "/app"
tm = require "/templateManager"
tm.use "widget/cubeLoadingHint"
class CubeLoadingHint extends Leaf.Widget
    constructor:(elem,params = {})->
        super App.templates.widget.cubeLoadingHint
        @UI.hint$.text params.hint or ""
        @expose "show"
        @expose "hide"
        @expose "hint"
    onSetHint:(hint)->
        console.debug "on set hint",hint
        @UI.hint$.text hint or ""
    show:()->
        @node$.css {display:"block"}
    hide:()->
        @node$.css {display:"none"}

module.exports = CubeLoadingHint
