class DragContext extends Leaf.EventEmitter
    constructor:()-> 
        super()
        @droppables = []
        @draggables = []
        @mouseupListener = @mouseupListener.bind(this)
        @mousemoveListener = @mousemoveListener.bind(this)
        window.addEventListener("mouseup",@mouseupListener)
        window.addEventListener("mousemove",@mousemoveListener)
    addDraggable:(node)->
        draggable = new DraggableState(node,this)
        @draggables.push draggable
        draggable.on "start",(e)=>
            if @currentDraggableState
                throw "already dragging"
            @currentDraggableState = draggable
            @emit "start",e
    removeDraggable:(node)->
        @draggables = @draggables.filter (item)->
            if item.node is node
                item.destroy()
                return false
            return true
    removeDroppable:(node)->
        @droppables = @droppables.filter (item)->
            if item.node is node
                item.destroy()
                return false
            return true
        
    addDroppable:(node)->
        droppable = new DroppableState(node,this)
        @droppables.push droppable
        droppable.on "drop",(e)=>
            if not @currentDraggableState
                throw "drop on no draggable"
            if @draggingShadow and  @draggingShadow.parentElement
                @draggingShadow.parentElement.removeChild @draggingShadow
            @draggingShadow = null
            e.draggable = @currentDraggableState.node
            e.droppable = droppable.node
            e.stopPropagation()
            @currentDraggableState = null
            @emit "drop",e
        droppable.on "hover",(e)=>
            if not @currentDraggableState
                throw "drop on no draggable"
            e.draggable = @currentDraggableState.node
            e.droppable = droppable.node
            @hasHover = true
            @emit "hover",e
    mouseupListener:(e)->
        if @currentDraggableState
            document.body.classList.remove "no-select"
            e.draggable = @currentDraggableState.node
            @currentDraggableState = null
            if @draggingShadow and  @draggingShadow.parentElement
                @draggingShadow.parentElement.removeChild @draggingShadow
            @draggingShadow = null
            @emit "release",e
    mousemoveListener:(e)->
        if @currentDraggableState
            document.body.classList.add "no-select"
            e.draggable = @currentDraggableState.node
            e.preventDefault()
            if @hasHover
                @hasHover = false
                e.dragHover = true
            else
                e.dragHover = false
            @emit "move",e
            if @draggingShadow
                @draggingShadow.style.top = e.clientY+"px"
                @draggingShadow.style.left = e.clientX+"px"
    addDraggingShadow:(node)->
        @draggingShadow = node
        if DragContext.draggingShadow and DragContext.draggingShadow.parentElement
            DragContext.draggingShadow.parentElement.removeChild DragContext.draggingShadow
        DragContext.draggingShadow = node
        document.body.appendChild node
        node.style.position = "absolute"
        node.style.pointerEvents = "none"
class DroppableState extends Leaf.EventEmitter
    constructor:(@node,@parent)->
        super()
        @onMove = @_onMove.bind(this)
        @onUp = @_onUp.bind(this)
        @node.addEventListener "mousemove",@onMove
        @node.addEventListener "mouseup",@onUp
    _onMove:(e)->
        if @parent.currentDraggableState
            e.preventDefault()
            @emit "hover",e
            return false
    _onUp:(e)->
        if @parent.currentDraggableState and @parent.currentDraggableState.node isnt @node
            @emit "drop",e
            return false
    destroy:()->
        @node.removeEventListener "mousemove",@onMove
        @node.removeEventListener "mouseup",@onUp
        @node = null
        @parent = null
class DraggableState extends Leaf.EventEmitter
    constructor:(@node,@parent)->
        super()
        @onMove = @_onMove.bind(this)
        @onDown = @_onDown.bind(this)
        @node.onmousemove = @onMove
        @node.onmousedown = @onDown
        @node.addEventListener "mousemove",@onMove
        @node.addEventListener "mousedown",@onDown
    _onMove:(e)->
        return
        if @parent.currentDraggableState
            return
        @emit "move",e
    _onDown:(e)->
        if e.which isnt 1
            return
        e.draggable = this.node
        if @parent.currentDraggableState
            return
        @emit "start",e
    destroy:()->
        @node.removeEventListener "mousemove",@onMove
        @node.removeEventListener "mousedown",@onDown
        @node = null 
        @parent = null
window.DragContext = DragContext