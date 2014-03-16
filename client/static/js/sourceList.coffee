class SourceListFolder extends Leaf.Widget
    constructor:(@name)->
        super App.templates["source-list-folder"]
        @children = Leaf.Widget.makeList @UI.container
        @isCollapse = true
        @render()
        @children.on "child/add",(child)=>
            @render()
            child.parent = this
            @emit "childAdd",child
            @emit "change"
            child.on "change",()=>
                @render()
            child.on "select",()=>
                @emit "select",child
            child.on "delete",()=>
                @children.removeItem child
                @render()
        @children.on "child/remove",(child)=>
            if child.parent is this
                child.parent = null
            child.removeAllListeners()
            @render()
            @emit "childRemove",child
            @emit "change"
        @UI.title.oncontextmenu = (e)=>
            e.preventDefault()
            selections = [
                {
                    name:"delete folder"
                    ,callback:()=>
                        if not confirm("remove this folder #{@name}?")
                            return
                        @delete()
                },{
                    name:"unsubscribe all"
                    ,callback:()=>
                        if not confirm("unsubscribe all in this folder #{@name}?")
                            return
                        @unsubscribeAll()
                },{
                    name:"rename folder"
                    ,callback:()=>
                        name = prompt("folder name",@name)
                        if name
                            @name = name.trim()
                        else
                            return
                        @render()
                        @emit "change"
                }
            ]
            ContextMenu.showByEvent e,selections
    initChildren:(children)->
        @children.length = 0
        for child in children or []
            # get or create but not update
            # because the folderData are not the latest the data
            source = Model.Source.getOrCreate(child)
            child = new SourceListItem(source)
            @children.push child
            child.parent = this
        @render()
    unsubscribeAll:()->
        for item in @children
            item.unsubscribe()
    onClickTitle:()->
        @emit "select",this
    active:()->
        @node$.addClass "active"
        @isActive = true
    deactive:()->
        @node$.removeClass "active"
        @isActive = false
    toJSON:()->
        return {
            children:(child.toJSON() for child in @children)
            ,name:@name
            ,type:"folder"
            ,collapse:@isCollapse
        }
    render:()->
        @UI.name$.text @name
        unreadCount = 0
        (unreadCount+= child.source.unreadCount or 0 for child in @children)
        @UI.unreadCounter$.text unreadCount
        if not @isCollapse
            @node$.removeClass("collapse")
            @UI.folderIcon$.removeClass("fa-folder-open")
            @UI.folderIcon$.addClass("fa-folder")
        else
            @UI.folderIcon$.removeClass("fa-folder")
            @UI.folderIcon$.addClass("fa-folder-open")
            @node$.addClass("collapse")
    onClickFolderIcon:(e)->
        @isCollapse = not @isCollapse
        @render()
        e.stopPropagation()
        @emit "change"
    delete:()->
        console.log "delete this #{@name}"
        @emit "delete",this
class SourceListItem extends Leaf.Widget
    constructor:(source)->
        super(App.templates["source-list-item"])
        @set(source)
        @render()
        @node.oncontextmenu = (e)=>
            e.preventDefault()
            selections = [
                {
                    name:"unsubscribe"
                    ,callback:()=>
                        
                        if not confirm("unsubscribe item #{@source.name}?")
                            return
                        @unsubscribe()
                }
            ]
            ContextMenu.showByEvent e,selections
    unsubscribe:(callback = ()=>true)->
        @source.unsubscribe callback
    set:(@source)->
        @source.on "remove",()=>
            @delete()
        @source.on "change",()=>
            @render()
            @emit "change"
    delete:()->
        @emit "delete"
    render:()->
        @UI.name$.text @source.name
        @UI.name.title = @source.guid
        @UI.name.setAttribute("alt",@source.guid)
        @UI.unreadCounter$.text((parseInt(@source.unreadCount) >= 0) and parseInt(@source.unreadCount).toString() or "?")
        # only rerender the image when src changed
        # it just works for now, but may broken in future
        # don't change the src if it's loaded
        if @iconLoaded
            return
        url = "http://www.google.com/s2/favicons?domain=#{@source.uri}&alt=feed"
        console.log @source
#        url = encodeURIComponent(url)
        @UI.sourceIcon$.attr("src",url)
#        @UI.sourceIcon$.attr("src","/remoteResource?url=#{url}&cache=yes")
        @UI.sourceIcon.onerror = ()->
            #this.style.display = "none"
            this.src = "/image/favicon-default.png"
            console.debug "load default"
        self = this
        @UI.sourceIcon.onload = ()->
            this.style.display = "inline"
            self.iconLoaded = true
    onClickName:()->
        @emit "select",this
        return false
    active:()->
        @node$.addClass "active"
        @isActive = true
    deactive:()->
        @node$.removeClass "active"
        @isActive = false
    toJSON:()->
        json = @source.toJSON()
        json.type = "source"
        return json

class SourceList extends Leaf.Widget
    constructor:()->
        @folderConfig = Model.Config.getConfig("sourceFolderConfig")
        Model.on "config/ready",()=>
            clearTimeout @buildTimer
            @buildFolderData()
        Model.on "source/add",(source)=>
            # if the add source not exists in the list
            # then we prepend it at top of the list
            @tryAddSource(source,true) #  reveser = true, prepend at top for new source
        super(App.templates["source-list"])
        @children = Leaf.Widget.makeList(@UI.container)
        @dragContext = new DragContext()
        @dragContext.on "start",(e)=>
            shadow = document.createElement("span")
            shadow.innerHTML = e.draggable.innerText
            @dragContext.addDraggingShadow(shadow)
        @dragContext.on "drop",(e)=>
            @moveListItem(e.draggable.widget,e.droppable.widget,e)
            @save()
            @UI.cursor$.hide()
        @dragContext.on "hover",(e)=>
            @hintMovePosition(e.draggable.widget,e.droppable.widget,e)
        @dragContext.on "release",(e)=>
            @UI.cursor$.hide()
        @dragContext.on "move",(e)=>
            if not e.dragHover
                @UI.cursor$.hide()
        @children.on "child/add",@_attach.bind(this)
        @children.on "child/remove",@_detach.bind(this)
    buildFolderData:()->
        folders = @folderConfig.get("folders",[])
        console.log folders
#        # in case the source load first
#        # we should remove those those child already belongs to some folder
#        # and readd them back when folder is ready
#        # readd will check duplicate and merge them
#        oldChildren = @children.toArray()
#        @children.length = 0
        for child in folders
            #console.log "folder data",child
            if child.type is "folder"
                folder = new SourceListFolder(child.name)
                # push folder to the children list of sourceList
                # so I know when folder add or remove a child
                # then init the children of the folder
                # so when any source add here will have me informed
                # on "add" event of the children
                # then I can check and remove the same source outside of that folder
                @children.push folder
                folder.isCollapse = child.collapse
                console.log "init #{folder.name} with",child.children
                folder.initChildren child.children
            else if child.type is "source"
                # only get or create not update because the data 
                # from folder config are not the latest data
                # and we force an add source here
                # so if an source exists in the list
                # it will be removed and add a new one here
                # so every thing is at folder data order
                @addSource Model.Source.getOrCreate(child)
    _attach:(item)->
        if item.hasAttach
            throw new Error "Programmer Error"
        item.hasAttach = true
        item.on "select",(who)=>
            @select who
        item.on "delete",()=>
            if item instanceof SourceListFolder
                children = item.children.toArray()
                item.children.length = 0
                index = @children.indexOf(item)
                @children.splice(index,1,children...)
            else
                @children.removeItem(item)
            @save()
        
        @_attachDrag(item)
        if item instanceof SourceListFolder
            folder = item
            folder.on "change",(who)=>
                @save()
            folder.on "childAdd",(who)=>
                # double make sure it's draggable
                @_attachDrag(who)
                for child in @children
                    if child.source and child.source.guid is who.source.guid
                        @children.removeItem(child)
                        break
    _attachDrag:(item)->
        if item._hasDragContext
            return
        if item instanceof SourceListFolder
            @dragContext.addDraggable(item.UI.title)
            @dragContext.addDroppable(item.UI.title)
            for subChild in item.children
                # NOTE: we won't be able to remove the draggable if it's subchildren
                # It's not a big memory leak, but it is one.
                @dragContext.addDraggable(subChild.node)
                @dragContext.addDroppable(subChild.node)
        else
            @dragContext.addDraggable(item.node)
            @dragContext.addDroppable(item.node)
        item._hasDragContext = true
    _detach:(child)->
        console.log "detach..."
        child.hasAttach = false
        child.removeAllListeners()
        @_detachDrag(child)
    _detachDrag:(item)->
        if not item._hasDragContext
            return
        if item instanceof SourceListFolder
            @dragContext.removeDraggable(item.UI.title)
            @dragContext.removeDroppable(item.UI.title)
        else
            @dragContext.addDraggable(item.node)
            @dragContext.addDroppable(item.node)
        item._hasDragContext = false
    moveListItem:(from,to,event)->
        towards = @getMovePosition(from,to,event)
        if not towards
            return
        if towards is "inside"
            if @hintActiveFolder
                @hintActiveFolder.deactive()
                @hintActiveFolder = null
            from.parentList.removeItem(from)
            to.children.splice(0,0,from)
            return
        if towards is "after"
            offset = 1
        else
            offset = 0
        from.parentList.removeItem(from)
        index = to.parentList.indexOf(to)
        to.parentList.splice(index+offset,0,from)
        @save()
    hintMovePosition:(from,to,event)->
        towards = @getMovePosition(from,to,event)
        @UI.cursor$.show()
        if @hintActiveFolder
            @hintActiveFolder.deactive()
            @hintActiveFolder = null
        if towards is "inside"
            @hintActiveFolder = to
            to.active()
        else
            if @hintActiveFolder
                @hintActiveFolder.deactive()
            @hintActiveFolder = null
            
        if towards is "after"
            @UI.cursor$.insertAfter(to.node)
        else if towards is "before"
            @UI.cursor$.insertBefore(to.node)
        else
            @UI.cursor$.hide()
    getMovePosition:(from,to,e)->
        if not from or not to or not event
            throw "invalid move ment"
        if from instanceof SourceListFolder and to instanceof SourceListItem
            # to is inside a folder
            # than we can't do this
            # because we don't allow nested folder
            if to.parent instanceof SourceListFolder
                return null
        if to instanceof SourceListFolder and from instanceof SourceListItem
            if (to.node$.height()*3/4)  > e.offsetY and e.offsetY  > (to.node$.height()/3)
                return "inside"
        if e.offsetY > to.node$.height()/2
            return "after"
        else
            return "before"
    
    addSource:(source,reverse = false)->
        #console.log "force add source",source.name,reverse
        #console.debug "before",@children.length
        for child in @children
            if child instanceof SourceListFolder
                for subChild in child.children
                    if subChild.source.guid is source.guid
                        subChild.delete()
                        break
            else if child instanceof SourceListItem
                if child.source.guid is source.guid
        #            console.debug "remove dup",source.name
                    child.delete()
                    break
            else
                throw new Error "unknown list item"
        child = new SourceListItem(source)
        if reverse
            @children.unshift child
        else
            @children.push child
        #console.debug "after",@children.length
    tryAddSource:(source,reverse = true)->
        # add to top (if reverse = false) of the list
        # iff no source present in the source list for any of the folder list
        for child in @children
            if child instanceof SourceListFolder
                for subChild in child.children
                    if subChild.source.guid is source.guid
                        return
            else if child instanceof SourceListItem
                if child.source.guid is source.guid
                    return
            else
                throw new Error "unknown list item"
        #console.log "add source",source.name,reverse
        child = new SourceListItem(source)
        if reverse
            @children.unshift child
        else
            @children.push child
    select:(who)->
        console.log "select",who
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
            info.name = who.name
            info.hash = info.type
        else
            info.type = "source"
            info.sourceGuids = [who.source.guid]
            info.name = who.source.name
        @emit "select",info
    save:()->
        if @_saveTimer
            clearTimeout @_saveTimer
        _save = ()->
            console.debug @children.length,"total folder length"
            folders = (child.toJSON() for child in @children)
            names = (item.name or item.source.name for item in folders)
            q = []
            while x = names.pop()
                if x in q
                    throw "conflict names!"
                q.push x
                
            #console.log "save as",(folder.name or folder.source.name for folder in folders).join("\n")
            @folderConfig.set "folders",folders
        @_saveTimer = setTimeout _save.bind(this),@_saveDelay or 100
    onClickAddSourceButton:()->
        App.addSourcePopup.show()
    onClickAddFolderButton:()->
        name = prompt("name","untitled").trim()
        if not name
            return
        child = new SourceListFolder(name)
        @children.unshift child
        @save()

            

#class SourceDetailPanel extends Leaf.Widget
#    constructor:()->
#        super(App.templates["source-detail-panel"])
#        @tags = []
#    setSource:(source)->
#        @source = source
#        @source.tags = @source.tags or []
#        @render()
#    render:()->
#        @UI.name$.text @source.name
#        tags = @source.tags or []
#        for tag in @tags
#            tag.remove()
#        @tags.length = 0
#        for tag in tags
#            @addTag new SourceDetailPanel.Tag(tag)
#    addTag:(tag)->
#        tag.appendTo @UI.tagContainer
#        tag.onClickNode = ()=>
#            @source.removeTag tag.name,(err)=>
#                if err
#                    console.error err
#                    return
#                @tags = @tags.filter (item)->item isnt tag
#                tag.remove()
#        @tags.push tag
#    
#    onClickAddTag:()->
#        @UI.addTag$.hide()
#        @UI.tagAddActions$.show()
#        @UI.addTagInput$.focus()
#    onClickConfirmAddTag:()->
#        name = @UI.addTagInput.value.trim().toLowerCase()
#        if not name
#            return
#        
#        for _ in @tags
#            if _.name is name
#                App.showHint "#{name} already exist."
#                return
#        @source.addTag name,(err)=>
#            if err
#                console.error err 
#                return
#            @addTag(new SourceDetailPanel.Tag(name))
#            @UI.addTagInput.value = ""
#    onClickCancelAddTag:()->
#        @UI.addTag$.show()
#        @UI.tagAddActions$.hide()
#    onKeydownAddTagInput:(e)->
#        if e.which is Leaf.Key.enter
#            @onClickConfirmAddTag()
#            return false
#        return true
#class SourceDetailPanel.Tag extends Leaf.Widget
#    constructor:(name)->
#        @name = name
#        super "<span class='tag'><span>"
#        @node$.text(name)

window.SourceList = SourceList