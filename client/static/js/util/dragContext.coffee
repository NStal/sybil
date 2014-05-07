# adding node to drag context as draggable or droppable or both
# "start"   : then drag the node will emit a "start" event on drag context
# "drop"    : drop the node at a droppable will emit a "drop" event on drag context
# "release" : release mouse when it's not on a droppable will emit a "release" event instead
# "hover    : "hover at a droppable when dragging will emit a "hover" event on drag context
# "move"    : when dragging the "move" will always been emitted when mouse moved
# if addDraggingShadow is called, the shadow element will always follow the mouse
# when the dragging continues

class DragContext extends Leaf.EventEmitter
    constructor:()-> 
        super()
        @droppables = []
        @draggables = []
        @mouseupListener = @mouseupListener.bind(this)
        @mousemoveListener = @mousemoveListener.bind(this)
        window.addEventListener("mouseup",@mouseupListener)
        window.addEventListener("mousemove",@mousemoveListener)
    # add an element to mark it as draggable and droppable
    addContext:(node)->
        @addDraggable(node)
        @addDroppable(node)
    # mark as draggable and attach a draggable state on it
    addDraggable:(node)->
        # check if already is the draggable
        for item in @draggables
            if item.node is node
                return
        draggable = new DraggableState(node,this)
        @draggables.push draggable
        # the element is being dragged
        # the context emit a start event
        draggable.on "start",(e)=>
            if @currentDraggableState
                throw new Error "already dragging"
            @currentDraggableState = draggable
            @emit "start",e
    # mark as droppable and attach a droppable state on it
    addDroppable:(node)->
        # checkif already is droppable
        for item in @droppables
            if item.node is node
                return
        droppable = new DroppableState(node,this)
        
        @droppables.push droppable
        droppable.on "drop",(e)=>
            if not @currentDraggableState
                throw new Error "drop with no draggable"
            # remove dragging shadow
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
    clearContext:(node)->
        @removeDraggable(node)
        @removeDroppable(node)

    mouseupListener:(e)->
        if not @currentDraggableState
            return
        document.body.classList.remove "no-select"
        e.draggable = @currentDraggableState.node
        @currentDraggableState = null
        if @draggingShadow and  @draggingShadow.parentElement
            @draggingShadow.parentElement.removeChild @draggingShadow
        @draggingShadow = null
        @emit "release",e
    mousemoveListener:(e)->
        if not @currentDraggableState
            return
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
        if @parent.currentDraggableState
            return true
        @emit "move",e
    _onDown:(e)->
        if e.which isnt 1
            return
        e.draggable = this.node
        if @parent.currentDraggableState
            return
        e.stopImmediatePropagation()
        e.preventDefault()
        @emit "start",e
    destroy:()->
        @node.removeEventListener "mousemove",@onMove
        @node.removeEventListener "mousedown",@onDown
        @node = null 
        @parent = null
        
module.exports = DragContext