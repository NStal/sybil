ContextMenu = require "/widget/contextMenu"
DragContext = require "/util/dragContext"
SourceAuthorizeTerminal = require "/sourceUtil/sourceAuthorizeTerminal"
App = require "/app"
Model = require "/model"
async = require "/lib/async"
tm = require "/templateManager"

class SourceListItemBase extends Leaf.Widget
    constructor:(template)->
        super template
    active:()->
        if @node
            @node.classList.add "active"
        @isActive = true
    deactive:()->
        if @node
            @node.classList.remove "active"
        @isActive = false
class SourceListFolderContextMenu extends ContextMenu
    constructor:(@folder)->
        @selections = [
                {
                    name:"remove folder"
                    ,callback:@remove.bind(this)
                },{
                    name:"unsubscribe all"
                    ,callback:@unsubscribeAll.bind(this)
                },{
                    name:"rename folder"
                    ,callback:@rename.bind(this)
                }
            ];
        super(@selections)
    rename:()->
        name = prompt("folder name",@folder.model.name)
        if name and name.trim()
            @folder.rename name
        else
            return
    unsubscribeAll:()->
        if not confirm("unsubscribe all in this folder #{@folder.model.name}?")
            return
        @folder.unsubscribeAll()
    remove:()->
        if not confirm("remove this folder #{@folder.model.name}?")
            return
        @folder.remove()

# Events
# change:  some children add/remove or other general change
# child/add (child):  a child was added
# child/remove (child): a child was removed
# select (child or folder): a child was selected or the folder it's self is selected.
# remove:  I want to remove my self who ever is my parent just remove me and pull all my children out
tm.use "sourceView/sourceListFolder"
class SourceListFolder extends SourceListItemBase
    constructor:(model = "untitled folder")->
        super App.templates.sourceView.sourceListFolder
        # setup initial model
        if typeof model is "string"
            @model = new Model.SourceFolder({name:string})
        else if model instanceof Model
            @model = model
        else
            throw new Error "invalid source list folder parameter"
        @model.defaults {collapse:true,children:[]}

        # setup list and children
        @children = Leaf.Widget.makeList @UI.container
        @children.on "child/add",(child)=>
            @_attachChild child
        @children.on "child/remove",(child)=>
            @_detachChild child

        @_initChildren @model.children
        # bubble child/add&remove so sourceList can listen"
        # attach drag/drop event at one place
        @bubble @children,"child/add"
        @bubble @children,"child/remove"
        @bubble @model,"change"
        @bubble @model,"change/name"
        @bubble @model,"change/collapse"

        #rerender on change
        @model.listenBy this,"change",@render

        # setup context menu
        @UI.title.oncontextmenu = (e)=>
            e.preventDefault()
            e.stopImmediatePropagation()
            if not @contextMenu
                @contextMenu = new SourceListFolderContextMenu this
            @contextMenu.show(e)
        @render()

    _attachChild:(child)->
        @bubble child,"select"
        child.listenBy this,"destroy",()=>
            @updateModel()
            @emit "child/destroy"
        child.listenBy this,"remove",()=>
            @removeChild child
        child.folder = this
        # watch for unread count of child and render the total count
        child.listenBy this,"change",@render
    _detachChild:(child)->
        @stopBubble child
        if child.folder is this
            child.folder = null
    _initChildren:(sources)->
        @children.length = 0
        for source in sources or []
            child = new SourceListItem(source)
            @children.push child

    addChild:(child,index = @children.length )->
        @children.splice index,0,child
        @updateModel()
    removeChild:(child)->
        @children.removeItem child
        @updateModel()
    # force an update on children (since it's an array).
    updateModel:()->
        @model.set "children",(child.source for child in @children)
        return @model
    unsubscribeAll:()->
        for item in @children
            item.unsubscribe()
    rename:(name)->
        @model.name = name
    remove:()->
        # oh my parent list please remove me.
        @emit "remove",this
    delayRender:()->
        if @_delayRenderTimer
            clearTimeout @_delayRenderTimer
        @_delayRenderTimer = setTimeout @render.bind(this),10
    render:()->
        unreadCount = 0
        (unreadCount += child.source.unreadCount or 0 for child in @children)
        @renderData.name = @model.name
        @renderData.unreadCount = unreadCount

        style = "no-update"
        if parseInt(unreadCount) > 0
            style = "has-update"
        if parseInt(unreadCount) >= 20
            style = "many-update"
        @renderData.statusStyle = style
        console.debug style,"!!!"
        if not @model.collapse
            @renderData.collapseClass = ""
            @renderData.iconClass = "fa-folder"
        else
            @renderData.collapseClass = "collapse"
            @renderData.iconClass = "fa-folder-open"
    onClickTitle:()->
        @emit "select",this
    onClickFolderIcon:(e)->
        e.stopPropagation()
        @toggleCollapse()
    toggleCollapse:(e)->
        @model.collapse = not @model.collapse
    toJSON:()->
        json = @model.toJSON()
        json.type = "folder"
        return json
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

# Events
# change: I have changed maybe name, maybe unreadCount
# remove: I'm done if you are my parent just remove me.
# select: I'm selected.
#
tm.use "sourceView/sourceListItem"
class SourceListItem extends SourceListItemBase
    constructor:(source)->
        super App.templates.sourceView.sourceListItem
        if source not instanceof Model.Source
            throw new Error "invalid source"
        @source = source
        @node.oncontextmenu = (e)=>
            e.preventDefault()
            e.stopImmediatePropagation()
            if not @contextMenu
                @contextMenu  = new SourceListItemContextMenu(this)
            @contextMenu.show(e)
        # unsubscribe will destroy the source model
        # then destroy the source list item
        # then force Widget.List to remove the item
        @source.listenBy this,"destroy",@destroy
        @source.listenBy this,"change",@render
        @bubble @source,"change"
        @bubble @source,"change/name"
        @render()
    showSourceDetail:()->
        App.sourceView.sourceDetail.setSource @source
        App.sourceView.sourceDetail.show()
    unsubscribe:(callback = ()=>true)->
        @source.unsubscribe callback
    render:()->
        @renderData.name = @source.name
        @renderData.guid = @source.guid
        @renderData.unreadCount = (parseInt(@source.unreadCount) >= 0) and parseInt(@source.unreadCount).toString() or "?"

        style = "no-update"
        if parseInt(@source.unreadCount) > 0
            style = "has-update"
        if parseInt(@source.unreadCount) >= 20
            style = "many-update"
        @renderData.statusStyle = style
        # only rerender the image when src changed
        # it just works for now, but may broken in future
        # don't change the src if it's loaded
        @renderData.state = "ok"
        if @source.lastError
            @renderData.state = "warn"
        if @source.requireLocalAuth
            @renderData.state = "error"
        if not @iconLoaded
            url = "//www.google.com/s2/favicons?domain=#{@source.uri}&alt=feed"
            @renderData.sourceIcon = url
            @UI.sourceIcon.onerror = ()->
                this.src = "/image/favicon-default.png"
            self = this
            @UI.sourceIcon.onload = ()->
                this.style.display = "inline"
                self.iconLoaded = true
    onClickNode:(e)->
        e.capture()
        @select()
    remove:()->
        @emit "remove",this
    select:()->
        if @source.requireLocalAuth

            if @source.authorizeTerminal
                @source.authorizeTerminal.hide()
            @source.authorizeTerminal = new SourceAuthorizeTerminal(@source)
        @emit "select",this
    destroy:()->
        # parent please remove me! I'm about to destroy!
        @emit "remove"
    toJSON:()->
        json = @source.toJSON({fields:["name","guid","uri","type"]})
        json.type = "source"
        return json
tm.use "sourceView/sourceList"
class SourceList extends Leaf.Widget
    constructor:()->
        super App.templates.sourceView.sourceList
        @children = Leaf.Widget.makeList(@UI.container)
        @dragController = new SourceListDragController(this)
        @children.on "child/add",@_attach.bind(this)
        @children.on "child/remove",@_detach.bind(this)
        @initialLoader =  new SourceListInitializer(this)
        @syncManager = new SourceListSyncManager(this)
    loadFolder:(callback = ()->true )->
        if @folderStore
            @folderStore.load (err)=>
                if err
                    callback err
                    return
                @buildFolderData @folderStore.get("folders") or []
                callback()
            return
        Model.SourceFolder.loadFolderStore (err,store)=>
            if err
                callback err
                return
            @folderStore = store
            # try load folder again
            @loadFolder callback
        return
    mergeFolder:(folderModel)->
        # remove children source that in the folder
        # and finally push the folder to the end of the list
        folderModel.children = folderModel.children.map (source)->
            if source instanceof Model.Source
                return source
            else
                return Model.Source.sources.findOne({guid:source.guid})
        folderModel.children = folderModel.children.filter (item)->item
        folder = new SourceListFolder(folderModel)
        guids = folder.children.map (item)->item.source.guid
        index = 0
        while index < @children.length
            child = @children[index]
            if child instanceof SourceListItem
                if child.source.guid in guids
                    child.remove()
                    continue
            else if child instanceof SourceListFolder
                for item in child.children
                    if item.source.guid in guids
                        console.debug "conflict source in folder",child.model.name,"and",folder.model.name,item.source.name
                        item.remove()
                        child.updateModel()
            index++
        @children.push folder
    mergeSource:(sourceModel,top)->
        for item in @children
            if item instanceof SourceListItem
                if item.source.guid is sourceModel.guid
                    # use the old source list item
                    # but push to the end/unshift to begin
                    @children.removeItem(item)
                    if top
                        @children.unshift item
                    else
                        @children.push item
                    return
                # logic next to continue is for folder
                continue
            for child in item.children
                if child.source.guid is sourceModel.guid
                    return
        if top
            @children.unshift new SourceListItem(sourceModel)
        else
            @children.push new SourceListItem(sourceModel)
    buildFolderData:(folders)->
        @currentFolderData = folders
        coherency = 100
        async.eachLimit folders,coherency,((item,done)=>
            setTimeout ( ()=>done() ),0
            if item.type is "folder"
                folder = new Model.SourceFolder(item)
                @mergeFolder folder
            else if item.type is "source"
                source = new Model.Source(item)
                @mergeSource source
        ),(err)=>
            if err
                console.error err
            return
    _attach:(item)->
        if item.hasAttach
            throw new Error "Programmer Error"
        item.hasAttach = true
        item.list = this

        item.listenBy this,"select",@select
        # unsubscribe will cause destroy on item and child/destroy on folder
        # either means a folder change need to save
        # duplicate save call are SAFE
        item.listenBy this,"change/collapse",@save
        item.listenBy this,"change/name",@save
        item.listenBy this,"destroy",@save
        item.listenBy this,"child/destroy",@save
        item.listenBy this,"remove",()=>
            if item instanceof SourceListFolder
                sources = item.children.toArray()
            else
                sources = []
            index = @children.indexOf item
            if index < 0
                return
            args = [].concat index,1,sources
            @children.splice.apply @children,args
            @save()
        # about drag
        @dragController.add item
        childrenHandler = (child)=>
            # also add/remove the child of the item(folder)
            # to the drag context
            @dragController.add child
            child.listenBy this,"remove",()=>
                @dragController.remove child
        item.listenBy this,"child",childrenHandler
        if item.children
            for child in item.children
                childrenHandler(child)
    _detach:(item)->
        item.hasAttach = false
        item.stopListenBy this
        if item.list is this
            item.list = null
        @dragController.remove item
    save:(callback = ()->true)->
        clearTimeout @_saveTimer
        _save = ()=>
            folders = (child.toJSON() for child in @children)
            if Leaf.Util.compare folders,@currentFolderData
                console.debug "no need to save"
                return
            console.debug "save folders",folders,JSON.stringify(folders).length
            if @folderStore
                @folderStore.set "folders",folders
            @currentFolderData = folders
        @_saveTimer = setTimeout _save.bind(this),@_saveDelay or 100
    select:(who)->
        if @currentItem
            @currentItem.deactive()
        @currentItem = who
        who.active()
        info = {}
        if who instanceof SourceListFolder
            if who.children.length is 0
                return
            info.type = "folder"
            info.sourceGuids = (child.source.guid for child in who.children)
            info.name = who.model.name
        else
            info.type = "source"
            info.sourceGuids = [who.source.guid]
            info.name = who.source.name
        @emit "select",info
    onClickAddSourceButton:()->
        App.addSourcePopup.show()
    onClickAddFolderButton:()->
        name = (prompt("name","untitled") or "").trim()
        if not name
            return
        child = new SourceListFolder(new Model.SourceFolder({name:name,children:[]}))
        @children.unshift child
        @save()
class SourceListDragController extends Leaf.EventEmitter
    constructor:(list)->
        @list = list
        @dragContext = new DragContext()
        @cursor$ = $('<div data-id="cursor" class="cursor">')
        @dragContext.on "start",(e)=>
            # maybe a more beautiful shadow in future
            shadow = document.createElement("span")
            shadow.style.color = "white"
            shadow.classList.add "no-interaction"
            shadow.innerHTML = e.draggable.innerText.trim().substring(0,30)
            @dragContext.addDraggingShadow(shadow)
        @dragContext.on "drop",(e)=>
            @move(e.draggable.widget,e.droppable.widget,e)
            @list.save()
            @cursor$.hide()
        @dragContext.on "hover",(e)=>
            @hint(e.draggable.widget,e.droppable.widget,e)
        @dragContext.on "release",(e)=>
            @cursor$.hide()
        @dragContext.on "move",(e)=>
            if not e.dragHover
                @cursor$.hide()
    add:(item)->
        if item instanceof SourceListItem
            @dragContext.addContext item.node
        else if item instanceof SourceListFolder
            @dragContext.addContext item.UI.title
        else
            throw new Error "add invalid drag item"
    remove:(item)->
        if item instanceof SourceListItem
            @dragContext.addContext item.node
        else if item instanceof SourceListFolder
            @dragContext.addContext item.UI.title
    # apply what getMovePosition returns
    move:(from,to,event)->
        console.debug "moveing at",from,to,event
        move = @getMovePosition(from,to,event)
        if move.position is "inside"
            if @hintFolder
                if @hintFolder isnt @list.currentItem
                    @hintFolder.deactive()
                @hintFolder = null
            console.assert from instanceof SourceListItem
            from.remove()
            move.target.children.splice(0,0,from)
            move.target.updateModel()
            @list.save()
            @cursor$.hide()
            return
        if move.position is "after"
            offset = 1
        else
            offset = 0

        parent = move.target.folder or move.target.list
        if not parent
            console.debug move.target
            throw new Error "can move to orphan item"
        from.remove()
        console.assert not from.list
        console.assert not from.folder
        index = parent.children.indexOf move.target
        parent.children.splice(index+offset,0,from)
        # for folder we need to sync UI with models
        if parent.updateModel
            parent.updateModel()
        @list.save()
        @cursor$.hide()
    # show hint from the data of getMovePosition
    hint:(from,to,event)->
        move = @getMovePosition(from,to,event)
        @cursor$.show()
        if @hintFolder
            @hintFolder.deactive()
            @hintFolder = null
        if move.position is "inside"
            console.assert move.target instanceof SourceListFolder,"can only move inside folders"
            @hintFolder = move.target
            @hintFolder.active()

        if move.position is "after"
            @cursor$.insertAfter(move.target.node)
        else if move.position is "before"
            @cursor$.insertBefore(move.target.node)
        else
            @cursor$.remove()
    # get what the current drop should act
    getMovePosition:(from,to,e)->
        # Note: move may change the "to"
        # from which widget is dragged?
        # to which widget is dropped?
        # e where the event happens
        if from instanceof SourceListFolder and to instanceof SourceListItem
            # drag a folder to an item
            if not (to.folder instanceof SourceListFolder)
                # item is an element without parent folder
                # so judge by position
                if e.offsetY > to.node$.height()/2
                    return {target:to,position:"after"}
                else
                    return {target:to,position:"before"}
            else
                # item is a item in side a folder
                # we don't allow nexted list
                # just move next to the folder
                return {target:to.folder,position:"after"}
        # if the to folder is not collapsed
        # this judgement will likely to make it judge like it's an element
        # if the to folder is collapsed
        # thie judgement will always likely to make it at before
        if from instanceof SourceListFolder and to instanceof SourceListFolder
            if e.offsetY > to.node$.height()/2
                return {target:to,position:"after"}
            else
                return {target:to,position:"before"}
        # to an folder(title)
        if to instanceof SourceListFolder and from instanceof SourceListItem
            if (to.node$.height()*3/4)  > e.offsetY and e.offsetY  > (to.node$.height()/3)
                return {target:to,position:"inside"}
        if e.offsetY > to.node$.height()/2
            return {target:to,position:"after"}
        else
            return {target:to,position:"before"}

# do the initial load at first connection
class SourceListInitializer extends Leaf.EventEmitter
    constructor:(@list)->
        super()
        App.afterInitialLoad ()=>
            @loadSources ()=>
                @loadFolder()
    loadSources:(callback = ()->true )->
        Model.Source.sources.sync ()=>
            for source in Model.Source.sources.models
                @list.mergeSource source
            callback()
    loadFolder:()->
        @list.loadFolder ()=>
            @emit "done"

# handle server pushed events
class SourceListSyncManager extends Leaf.EventEmitter
    constructor:(@list)->
        super()
        App.afterInitialLoad ()=>
            # new source: add to list if not exists
            App.modelSyncManager.on "source",(sourceModel)=>
                @list.mergeSource sourceModel,true
module.exports = SourceList
