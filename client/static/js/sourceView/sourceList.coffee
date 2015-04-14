tm = require "/templateManager"
CoreData = require "/coreData"
DragContext = require "/util/dragContext"
ContextMenu = require "/widget/contextMenu"
SourceAuthorizeTerminal = require "/sourceUtil/sourceAuthorizeTerminal"
Model = require "/model"
SmartImage = require "/widget/smartImage"
tm.use "sourceView/sourceList"

class SourceListManager extends Leaf.States
    constructor:(@context)->
        super()
        @debug()
        @folderCoreData = new CoreData("sourceFolderConfig")
        @reset()
    reset:()->
        @data.structures = []
        @data.flatStructures = []
    init:()->
        if @state is not "void"
            return
        @setState "prepareCoreData"
    save:()->
        clearTimeout @timer
        @timer = setTimeout @_save.bind(this),500

    _save:()->
        folders = []
        for item in @data.flatStructures
            if item.type is "folder"
                folders.push {
                    name:item.model.name
                    type:"folder"
                    children:[]
                    collapse:item.model.collapse
                }
            else if item.type is "source"
                if item.parent
                    for p in folders
                        if p.name is item.parent.model.name
                            p.children.push {
                                name:item.model.name
                                guid:item.model.guid
                                type:"source"
                            }
                            break
                else
                    folders.push {
                        name:item.model.name
                        guid:item.model.guid
                        type:"source"
                    }
        @folderCoreData.set "folders",folders
    packAt:(index)->
        return @data.flatStructures[index]
    logicPackAfter:(index)->
        item = @packAt(index)
        if not item
            return null
        if item.type is "source" and not item.parent
            return @packAt(index+1)
        else if item.type is "source" and item.parent
            while true
                index++
                next = @packAt(index)
                if not next
                    return null
                if next.parent is item.parent
                    continue
                return next
        else if item.type is "folder"
            while true
                index++
                next = @packAt(index)
                if not next
                    return null
                if next.parent is item
                    continue
                return next
        return null
    updatePackDimension:()->
        posIndex = 0
        for item,index in @data.flatStructures
            item.flatIndex = index
            hidden = false
            if item.parent
                if not item.parent.model.collapse
                    hidden = true
                    item.hide = true
                else
                    hidden = false
                    item.hide = false
                item.indent = 1
            else
                item.indent = 0
            item.position = posIndex
            if item.type is "folder" and item.model.collapse
                item.expand = item.model.children.length + 1
            else
                item.expand = null
            if not hidden
                posIndex += 1
        @save()
    addFolder:(name)->
        if name instanceof Model.SourceFolder
            folder = name
        else
            folder = new Model.SourceFolder({name:name.toString(),collapse:true,type:"folder",children:[]})
        for item in @data.flatStructures
            if item.type is "folder" and item.name is folder.name
                console.error "can't create duplicate folder"
                return
        info = {
            type:"folder"
            model:folder
            name:name
            parent:null
        }
        @data.flatStructures.unshift(info)
        @updatePackDimension()
        @context.children.push new SourceListFolder info,@context
        return
    addSource:(source)->
        info = {
            type:"source"
            model:source
            name:name
            parent:null
        }
        @data.flatStructures.unshift(info)
        @updatePackDimension()
        @context.children.push new SourceListItem info,@context
        return
    removeSource:(pack)->
        if pack.type isnt "source"
            return
        for item,index in @data.flatStructures
            if item is pack
                if pack.parent
                    for child,cindex in pack.parent.model.children
                        if child is pack.model
                            pack.parent.model.children.splice(cindex,1)
                            break
                @data.flatStructures.splice(index,1)
                break
        @updatePackDimension()
    removeFolder:(pack)->
        if pack.type isnt "folder"
            return
        for item,index in @data.flatStructures
            if item is pack
                target = index
            else if item.parent is pack
                item.parent = null
        if typeof target is "number"
            @data.flatStructures.splice(target,1)
        console.debug "remove folder",pack,@data.flatStructures
        @updatePackDimension()
    _move:(pack,position)->
        if not position?
            # +1 than the last one
            position = @data.flatStructures.length
        # only move flat structure
        # no parent relation ensured
        #
        # we only allow move item to item/folder position
        # and allow move folder to folder/orphanItem position
        target = @data.flatStructures[position]
        # not allowed to move folder into a folder
        if target and target.parent and pack.type is "folder"
            return
        # not allowed to folder into it's self
        if target and pack is target.parent
            return
        if pack.type is "folder"
            count = pack.model.children.length + 1
        else
            count = 1
        insertion = @data.flatStructures.splice(pack.flatIndex,count) or []
        if pack.flatIndex < position
            position -= count
        if position < 0
            position = 0
        if position < @data.flatStructures.length
            @data.flatStructures.splice(position,0,insertion...)
        else
            @data.flatStructures.push insertion...
        @updatePackDimension()
    _setParent:(pack,parentPack)->
        # only set parent
        # no flat structure reflow
        # caller should make sure that
        if pack.parent is parentPack
            return
        if pack.parent
            folder = pack.parent.model
            folder.children = folder.children.filter (item)->item isnt pack.model
            pack.parent = null
        if parentPack
            pack.parent = parentPack
            parentPack.model.children.push pack.model
#        for item,index in @data.flatStructures
#            if item is pack
#                @data.flatStructures.splice index,1
#                break
#        for item,index in @data.flatStructures
#            if item is parentPack
#                @data.flatStructures.splice index+1,0,pack
#                break
    atPrepareCoreData:(sole)->
        @folderCoreData.load (err)=>
            if @stale sole
                return
            if err
                @error err
                return
            @setState "syncSources"
    atSyncSources:(sole)->
        Model.Source.sources.sync ()=>
            @setState "buildStructure"

    atBuildStructure:()->
        @data.structures = []
        contains = []
        items = (@folderCoreData.get "folders") or []
        for item in items
            if item.type is "folder"
                folder = new Model.SourceFolder({name:item.name,type:"folder",collapse:item.collapse})
                folder.children ?= []
                for child in (item.children or [])
                    if child.guid in contains
                        continue
                    source = Model.Source.sources.findOne {guid:child.guid}
                    contains.push child.guid
                    if source
                        folder.children.push source
                @data.structures.push folder
            else if item.type is "source"
                if item.guid in contains
                    continue
                source = Model.Source.sources.findOne {guid:item.guid}
                contains.push source.guid
                if source
                    @data.structures.push source
        for source in Model.Source.sources.models
            if source.guid not in contains
                @data.structures.push source
        @setState "buildFlatStructures"
    atBuildFlatStructures:()->
        for item in @data.structures
            if item instanceof Model.SourceFolder
                pindex = @data.flatStructures.length
                folder = {
                    name:item.name
                    type:"folder"
                    parent:null
                    flatIndex:pindex
                    model:item
                }
                @data.flatStructures.push folder
                for source,childIndex in item.children
                    cindex = @data.flatStructures.length
                    @data.flatStructures.push {
                        name:source.name
                        type:"source"
                        parent:folder
                        flatIndex:cindex
                        model:source
                    }
            else
                index = @data.flatStructures.length
                @data.flatStructures.push {
                    name:item.name
                    type:"source"
                    parent:null
                    flatIndex:index
                    model:item
                }
        @updatePackDimension()
        @setState "fillSourceList"
    atFillSourceList:()->
        @context.children.length = 0
        for item in @data.flatStructures
            if item.type is "folder"
                child = new SourceListFolder(item,@context)
            else if item.type is "source"
                child = new SourceListItem(item,@context)
            else
                continue
            @context.children.push child
        @context.reflow()
        @setState "wait"
    atWait:()->
        App.modelSyncManager.listenBy this,"source",(source)=>
            @addSource source
            @context.reflow()
            return
        return
class SourceList extends Leaf.Widget
    constructor:()->
        super App.templates.sourceView.sourceList
        @children = Leaf.Widget.makeList @UI.container
        @relations = []
        @manager = new SourceListManager this
        @dragController = new SourceListDragController(this)
        App.afterInitialLoad ()=>
            @manager.init()
    updateItemHeight:()->
        for item in @children
            if item.pack.type is "source" and not item.isHide
                @itemHeight = item.node$.height()
                return
        @itemHeight = 36

    reflow:()->
        @updateItemHeight()
        for item in @children
            if item.pack.hide
                item.hide()
            else
                item.show()
            item.indent(item.pack.indent or 0)
            item.node$.css {transform:"translateY(#{item.pack.position * @itemHeight}px)",zIndex:item.pack.position + 1}
            if item.pack.expand
                item.node$.css {height:item.pack.expand * @itemHeight}
            else
                item.node$.css {height:"auto"}
    onClickAddSourceButton:()->
        App.addSourcePopup.show()
    onClickAddFolderButton:()->
        name = (prompt("name","untitled") or "").trim()
        if not name
            return
        @manager.addFolder name
        @reflow()
class SourceListItemBase extends Leaf.Widget
    constructor:(template,pack)->
        super template
    active:()->
        if @context
            for item in @context.children
                item.deactive()
        @node.classList.add "active"
        @isActive = true
    deactive:()->
        @node.classList.remove "active"
        @isActive = false
    indent:(level)->
        if @indentLevel is level
            return
        if level is 0
            @node$.removeClass "indent"
        else
            @node$.addClass "indent"
        @indentLevel = level
    hide:()->
        if @isHide
            return
        @isHide = true
        @node$.addClass "hide"
    show:()->
        if not @isHide
            return
        @isHide = false
        @node$.removeClass "hide"
tm.use "sourceView/sourceListItem"
class SourceListItem extends SourceListItemBase
    class SourceListItemContextMenu extends ContextMenu
        constructor:(@item)->
            @selections = [
                {
                    name:"source detail"
                    ,callback:@showSourceDetail.bind(this)
                }
                ,{
                    name:"unsubscribe"
                    ,callback:@unsubscribe.bind(this)
                }
            ]
            super @selections

        ,showSourceDetail:()->
            @item.showSourceDetail()

        ,unsubscribe:()->
            if not confirm("unsubscribe item #{@item.source.name}?")
                return
            @item.unsubscribe()

    constructor:(@pack,@context)->
        @include SmartImage
        super App.templates.sourceView.sourceListItem
        @source = @pack.model
        @source.on "change",@render.bind(this)
        @node.oncontextmenu = (e)=>
            e.preventDefault()
            e.stopImmediatePropagation()
            if not @contextMenu
                @contextMenu  = new SourceListItemContextMenu(this)
            @contextMenu.show(e)
        @render()
    render:()->
        @VM.name = @source.name
        @VM.guid = @source.guid
        @VM.unreadCount = (parseInt(@source.unreadCount) >= 0) and parseInt(@source.unreadCount).toString() or "?"
        style = "no-update"
        if parseInt(@source.unreadCount) > 0
            style = "has-update"
        if parseInt(@source.unreadCount) >= 20
            style = "many-update"
        @VM.statusStyle = style
        # only rerender the image when src changed
        # it just works for now, but may broken in future
        # don't change the src if it's loaded
        @VM.state = "ok"

        # error for 2 day
        # day
        smallErrorTime = 1000 * 60 * 60
        bigErrorTime = 1000 * 60 * 60 * 24 * 2
#        if not @source.lastError
#            @source.lastErrorDate = Date.now() - 100
#            @source.lastError = new Error("hehe")
        if @source.lastError
            if @source.lastErrorDate
                lastErrorDate = (Date.now() - new Date(@source.lastErrorDate).getTime()) or 0
            else
                lastErrorDate = -1

            if lastErrorDate < 0
                @VM.state = "warn"
            else if lastErrorDate < smallErrorTime
                @VM.state = "unhealthy"
            else if lastErrorDate < bigErrorTime
                @VM.state = "warn"
            else
                @VM.state = "error"

        if @source.requireLocalAuth
            @VM.state = "error"
        @UI.sourceIcon.loadingSrc = "/image/favicon-default.png"
        @UI.sourceIcon.errorSrc = "/image/favicon-default.png"
        @UI.sourceIcon.src = "plugins/iconProxy?url=#{encodeURIComponent @source.uri}"
    unsubscribe:(callback)->
#        @source.unsubscribe ()=>
        @context.children.removeItem this
        @context.manager.removeSource @pack
        @context.reflow()
    showSourceDetail:()->
        App.sourceView.sourceDetail.setSource @source
        App.sourceView.sourceDetail.show()
    onClickNode:(e)->
        console.debug "hehe"
        e.capture()
        @active()
        if @source.requireLocalAuth
            if @source.authorizeTerminal
                @source.authorizeTerminal.hide()
            @source.authorizeTerminal = new SourceAuthorizeTerminal(@source)

        @context.emit "select",{
            type:"source"
            sourceGuids:[@source.guid]
            name:@source.name
        }

tm.use "sourceView/sourceListFolder"
class SourceListFolder extends SourceListItemBase
    class SourceListFolderContextMenu extends ContextMenu
        constructor:(@folder)->
            @selections = [
                    {
                        name:"remove folder"
                        ,callback:@delete.bind(this)
                    },{
                        name:"rename folder"
                        ,callback:@rename.bind(this)
                    }
                ];
            super(@selections)
        rename:()->
            name = prompt("folder name",@folder.model.name)
            if name and name.trim()
                @folder.model.name = name
                @folder.pack.name = name
                @folder.context.manager.save()
        delete:()->
            if not confirm("remove this folder #{@folder.model.name}(source will be kept)?")
                return
            @folder.removeFolder()

    constructor:(@pack,@context)->
        super App.templates.sourceView.sourceListFolder
        @model = @pack.model
        @model.listenBy this,"change",@render.bind(this)
        @node.oncontextmenu = (e)=>
            e.preventDefault()
            e.stopImmediatePropagation()
            if not @contextMenu
                @contextMenu = new SourceListFolderContextMenu this
            @contextMenu.show(e)

        @render()
    onClickFolderIcon:(e)->
        e.capture()
        @model.collapse = not @model.collapse
        @render()
    onClickNode:()->
        @active()
        @context.emit "select",{
            type:"folder"
            sourceGuids:(child.guid for child in @model.children)
            name:@model.name
        }
    removeFolder:()->
        @context.children.removeItem this
        @context.manager.removeFolder(@pack)
        @context.reflow()
    render:()->
        unreadCount = 0
        for item in @model.children
            if typeof item.unreadCount is "number"
                unreadCount += item.unreadCount
        @VM.name = @model.name
        @VM.unreadCount = unreadCount
        if @VM.collapse isnt @model.collapse
            @VM.collapse = @model.collapse
            @context.manager.updatePackDimension()
            @context.reflow()
        style = "no-update"
        if parseInt(unreadCount) > 0
            style = "has-update"
        if parseInt(unreadCount) >= 20
            style = "many-update"
        @VM.statusStyle = style

        if not @model.collapse
            @VM.iconClass = "fa-folder"
        else
            @VM.iconClass = "fa-folder-open"
    toggleCollapse:(e)->
        @model.collapse = not @model.collapse
class SourceListDragController extends Leaf.EventEmitter
    constructor:(@context)->
        @dragContext = new DragContext()
        @dragContext.on "start",(e)=>
            # maybe a more beautiful shadow in future
            shadow = document.createElement("span")
            shadow.style.color = "white"
            shadow.classList.add "no-interaction"
            shadow.innerHTML = e.draggable.innerText.trim().substring(0,30)
            @dragContext.addDraggingShadow(shadow)
        @dragContext.on "drop",(e)=>
            @drop(e.draggable.widget,e.droppable.widget,e)
        @dragContext.on "hover",(e)=>
            @drop(e.draggable.widget,e.droppable.widget,e)
        @context.children.on "child/add",@addToContext.bind(this)
        @context.children.on "child/remove",@removeFromContext.bind(this)
    addToContext:(item)->
        if item instanceof SourceListItem
            @dragContext.addContext item.node
        else if item instanceof SourceListFolder
            @dragContext.addContext item.UI.title
        else
            throw new Error "add invalid drag item"
    removeFromContext:(item)->
        if item instanceof SourceListItem
            @dragContext.addContext item.node
        else if item instanceof SourceListFolder
            @dragContext.addContext item.UI.title
    getDropType:(from,to,e)->
        e = e.offsetY
        if to.pack.type is "folder"
            height = to.UI.title$.height()
        else
            height = to.node$.height()
        if e > height/2
            return "after"
        else
            return "before"
    drop:(from,to,e)->
        if from is to
            return
        dropType = @getDropType(from,to,e)
        fromPack = from.pack
        toPack = to.pack
        if fromPack.type is "folder" and toPack.parent
            next = @context.manager.packAt toPack.flatIndex + 1
            # not allow move folder to parent item
            # but only after the last item of a folder.
            # In this case we just move it after the item parent
            if next and next.parent isnt toPack.parent
                @context.manager._move fromPack,next.flatIndex
            # still not allow to move parented item
        else if fromPack.type is "folder" and toPack.type is "folder"
            if dropType is "before"
                @context.manager._move fromPack,toPack.flatIndex
            else
                next = @context.manager.logicPackAfter(toPack.flatIndex)
                if not next
                    @context.manager._move fromPack,null
                else
                    @context.manager._move fromPack,next.flatIndex
        else if fromPack.type is "folder" and toPack.type is "source" and not toPack.parent
            if dropType is "before"
                @context.manager._move fromPack,toPack.flatIndex
            else
                @context.manager._move fromPack,toPack.flatIndex + 1

        else if fromPack.type is "source" and toPack.type is "source"
            if toPack.parent
                @context.manager._setParent fromPack,toPack.parent
            else
                @context.manager._setParent fromPack,null
            if dropType is "before"
                @context.manager._move fromPack,toPack.flatIndex
            else if dropType is "after"
                @context.manager._move fromPack,toPack.flatIndex+1
        else if fromPack.type is "source" and toPack.type is "folder"
            if dropType is "before"
                @context.manager._setParent fromPack,null
                @context.manager._move fromPack,toPack.flatIndex
            else
                @context.manager._setParent fromPack,toPack
                @context.manager._move fromPack,toPack.flatIndex + 1
        if not fromPack.parent or fromPack.parent and fromPack.parent.model.collapse
            fromPack.hide = false
        @context.reflow()
    # apply what getMovePosition returns
module.exports = SourceList
