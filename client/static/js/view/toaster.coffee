tm = require "/templateManager"
tm.use "toaster"
App = require "/app"
class Toaster extends Leaf.Widget
    constructor:()->
        super App.templates.toaster
        @showInterval = 3000
    show:(content)->
        @content = content
        @UI.content$.text content
        @node$.addClass "show"
        @node$.css {zIndex:99999}
        clearTimeout @hideTimer
        @hideTimer = setTimeout ()=>
            @hide()
        ,@showInterval
    hide:()->
        @node$.removeClass "show"

module.exports = Toaster
