tm = require "/templateManager"
tm.use "widget/contextMenu"
App = require("/app")
class ContextMenu extends Leaf.Widget
    constructor:(selections)->
        super(App.templates.widget.contextMenu)
        @selections = selections
        @children = Leaf.Widget.makeList @UI.container
        @node.oncontextmenu = ()->
            return false
        for item in @selections
            @addSelection(item)
    addSelection:(selection)->
        child = new ContextMenuItem(selection.name)
        child.onClickNode = ()=>
            @hide()
            setTimeout selection.callback,0
        @children.push child
    show:(e)->
        e.stopImmediatePropagation()
        e.preventDefault()
        ContextMenu.show(this)
        @node$.show()
        X = e.clientX or 0
        Y = e.clientY or 0
        if X < 20
            X = 20
        if Y < 20
            Y = 20

        @node$.css({top:Y-15,left:X-10})
    hide:()->
        @node$.hide()
        @emit "hide"
ContextMenu.show = (who)->
    if @menu
        @menu.remove()
    @mask.show()
    @mask.once "hide",()=>
        @mask.hide()
        @menu.hide()
    @menu = who
    @menu.appendTo document.body
    @menu.once "hide",()=>
        @mask.hide()
ContextMenu.showByEvent = (e,selections)->
    if @menu
        @menu.remove()
    @mask.show()
    @mask.on "hide",()=>
        @mask.hide()
        menu.hide()
    menu = new ContextMenu(selections)
    menu.show(e)
    menu.appendTo document.body
    menu.on "hide",()=>
        @mask.hide()
    @menu = menu
class Mask extends Leaf.Widget
    constructor:()->
        super("<div></div>")
        @node$.css({"position":"absolute",height:"100%",width:"100%",top:0,left:"0","background-color":"rgba(0,0,0,0)","z-index":"1"})
        @node.oncontextmenu = (e)=>
            @emit "hide"
            e.preventDefault()
            e.stopPropagation()
            return false
    onClickNode:()->
        @emit "hide"
    show:()->
        @appendTo document.body
    hide:()->
        @remove()
ContextMenu.mask = new Mask()
tm.use "widget/contextMenuItem"
class ContextMenuItem extends Leaf.Widget
    constructor:(word)->
        super App.templates.widget.contextMenuItem
        @node$.text word
    onClickNode:()->
        @emit "fire",this
module.exports = ContextMenu
