class CustomSourceList extends Leaf.Widget
    constructor:()->
        super App.templates["custom-source-list"]
        @selector = new WorkspaceSelector(@UI.selector)
        @selector.on "select",(workspace)=>
            @switchTo workspace
        @selector.on "sync",()=>
            if Workspace.workspaces.length isnt 0 and not @currentWorkspace
                @switchTo Workspace.workspaces[0]
        @listItems = []
    switchTo:(workspace)->
        @currentWorkspace = workspace
        @syncWorkspace()
    select:(item)->
        @currentItem = item
        @customArchiveList.setSelector item.member
    syncWorkspace:()->
        workspace = @currentWorkspace
        if not workspace
            return
        for item in @listItems
            item.__match = "not match"
        for member in workspace.members
            has = false
            for item in @listItems
                if item.member is member
                    item.__match = "match"
                    has = true
                    break
            if not has
                @add CustomListItem.create(member)
        for item,index in @listItems
            if item.__match is "not match"
                @listItems[item] = null
                item.remove()
        @listItems = @listItems.filter (item)->item
    save:()->
        @currentWorkspace.members = (item.member for item in @listItems)
        @currentWorkspace.save()
    add:(item)->
        item.appendTo @UI.container
        item.on "change",()=>
            @save()
        item.on "select",(who)=>
            @select who
        @listItems.push item
        @save()
    onClickAddGroup:()->
        group = WorkspaceMember.fromJSON({type:"group",items:[],name:"new group"})
        @currentWorkspace.add group
        item = new CustomGroupItem(group)
        @add item
        item.startEdit()
    onClickAddSource:()->
        App.sourceSelector.select (err,sources)=>
            if err or not sources
                return
            for source in sources
                sourceMember = WorkspaceMember.fromJSON({type:"source",name:source.name,guid:source.guid})
                @currentWorkspace.add sourceMember
                item = new CustomSourceItem(sourceMember)
                @add item

    onClickAddTag:()->
        App.tagSelector.select (err,tags)=>
            if err or not tags
                return
            for tag in tags
                tagMember = WorkspaceMember.fromJSON({type:"tag",tagName:tag.name})
                @currentWorkspace.add tagMember
                item = new CustomTagItem(tagMember)
                @add item
    onClickClearAll:()->
        console.log "not implemented yet"
    
class CustomListItem extends Leaf.Widget
    @create = (item)->
        if item.type is "group"
            return new CustomGroupItem(item)
        if item.type is "source"
            return new CustomSourceItem(item)
        if item.type is "tag"
            return new CustomTagItem(item)
        throw "unknown custom item type #{item.type}"
    constructor:(template)->
        super template
    onClickNode:(e)->
        @emit "select",this
        e.stopPropagation()
        return false
class CustomGroupItem extends CustomListItem
    constructor:(@member)->
        super App.templates["custom-group-item"]
        @slideSpeed = 100
        @listItems = []
        @render()
        for item in @member.items
            item = CustomListItem.create(item)
            @add item
        console.log @onClickNode
        @UI.name.oncontextmenu = (e)=>
            e.preventDefault()
            @startEdit()
    add:(item)->
        if item instanceof CustomGroupItem
            throw "invalid group data that contains other group"
        @listItems.push item
        item.appendTo @UI.container
        item.on "change",()=>
            @emit "change"
        item.on "select",(who)=>
            @emit "select",who
        @emit "change"
    onClickEditToggler:()->
        if @isEdit
            @endEdit()
        else
            @startEdit()
    onKeydownNameInput:(e)->
        if e.which is Leaf.Key.enter
            @endEdit()
    onClickFolderIcon:(e)->
        if @isExpand
            @hideContents()
        else
            @showContents()
        e.stopPropagation()
        return false
    showContents:()->
        @UI.actions$.slideDown(@slideSpeed)
        @UI.container$.slideDown(@slideSpeed)
        @UI.folderIcon$.removeClass("fa-folder-o")
        @UI.folderIcon$.addClass("fa-folder-open-o")
        @isExpand = true
    hideContents:()->
        @UI.actions$.slideUp(@slideSpeed)
        @UI.container$.slideUp(@slideSpeed)
        @UI.folderIcon$.removeClass("fa-folder-open-o")
        @UI.folderIcon$.addClass("fa-folder-o")
        @isExpand = false
    render:()->
        @UI.name$.text @member.name
    save:()->
        @member.items = (item.member for item in @items)
    startEdit:()->
        @isEdit = true
        @UI.nameInput$.show()
        @UI.name$.hide()
        @UI.nameInput$.focus()
        @UI.nameInput.value = @member.name or "no name"
    endEdit:()->
        @isEdit = false
        value = @UI.nameInput.value.trim()
        if @member.name isnt value
            @member.name = value
            @emit "change"
            @render()
        @UI.nameInput$.hide()
        @UI.name$.show()
    onClickAddSource:()->
        App.sourceSelector.select (err,sources)=>
            if err or not sources
                return
            for source in sources
                sourceMember = WorkspaceMember.fromJSON({type:"source",name:source.name,guid:source.guid})
                @member.add sourceMember
                item = new CustomSourceItem sourceMember
                @add item
    onClickAddTag:()->
        App.tagSelector.select (err,tags)=>
            if err or not tags
                return
            for tag in tags
                tagMember = WorkspaceMember.fromJSON({type:"tag",tagName:tag.name})
                @member.add tagMember
                item = new CustomTagItem(tagMember)
                @add item
class CustomSourceItem extends CustomListItem
    constructor:(@member)->
        super App.templates["custom-source-item"]
        @UI.name$.text @member.name
class CustomTagItem extends CustomListItem
    constructor:(@member)->
        super App.templates["custom-tag-item"]
        @UI.name$.text @member.tagName
class WorkspaceSelectorItem extends Leaf.Widget
    constructor:(@workspace)->
        super("<span></span>")
        @node$.text @workspace.name
class WorkspaceSelector extends Leaf.Widget
    constructor:(template)->
        super template
        @items = []
        Model.on "workspace/sync",()=>
            @sync()
            console.log "synced",Workspace.workspaces
    sync:()->
        for item in @items
            item.__match = "not match"
        for workspace in Workspace.workspaces
            has = false
            for item in @items
                if item.name is workspace.name
                    item.__match = "match"
                    has = true
                    break
            if not has
                @addWorkspace workspace
        for item,index in @items
            if item.__match is "not match"
                item.remove()
                @items[index] = null
        @items = @items.filter (item)->item
        @emit "sync"
    addWorkspace:(workspace)->
        selector = new WorkspaceSelectorItem(workspace)
        @items.push selector
        selector.onClickNode = ()=>
            @emit "select",selector.workspace
        selector.appendTo @node
    
window.CustomSourceList = CustomSourceList