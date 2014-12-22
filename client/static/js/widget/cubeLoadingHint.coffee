App = require "/app"
tm = require "/templateManager"
tm.use "cube-loading-hint"
console.debug "use cube"
class CubeLoadingHint extends Leaf.Widget
    constructor:(elem,params = {})->
        super App.templates["cube-loading-hint"]
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