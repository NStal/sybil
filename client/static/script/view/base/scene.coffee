App = require "/app"
class Scene extends Leaf.Widget
    @scenes = []
    constructor:(template,name)->
        super template
        @name = name
        Scene.scenes.push this
        @isShow = true
    show:()->
        if @isShow
            return
        @isShow = true
        @node$.show()
        @emit "show"
    hide:()->
        if not @isShow
            return
        @isShow = false
        @node$.hide()
        @emit "hide"
module.exports  = Scene
