App = require "/app"
class HintStack extends Leaf.Widget
    constructor:()->
        super "<div class='hint-stack'></div>"
        @node$.css {
            position:"absolute"
            ,bottom:0
            ,right:0
            ,width:"100%"
        }
        @list = Leaf.Widget.makeList @node
        document.body.appendChild @node
    push:(widget)->
        console.debug "push",widget
        @list.push widget
        widget.listenBy this,"hide",@remove
        widget.listenBy this,"show",@display
    remove:(widget)->
        console.debug "remove",widget
        @list.removeItem widget
        widget.stopListenBy this
    display:(widget)->
        widget.node$.show()
        
class HintStack.HintStackItem extends Leaf.Widget
    constructor:(template)->
        super template
        if not App.hintStack
            App.hintStack = new HintStack()
        App.hintStack.push this 
    show:()->
        @emit "show",this
    hide:()->
        @node$.slideUp(300)
        setTimeout (()=>
            @emit "hide",this
            ),500
    attract:()->
        @node$.animate({bottom:10})
        @node$.animate({bottom:0})
        
module.exports = HintStack
