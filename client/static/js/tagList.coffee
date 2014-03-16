class TagList extends Leaf.Widget
    constructor:(sourceList)->
        super(SybilWebUI.templates["tag-list"])
        @listItems = []
        Model.on "tag/change",()=>
            if @buildTimer
                clearTimeout @buildTimer 
            @buildTimer = setTimeout((()=>
                @buildTagList()
                @buildTimer = null
            ),10)
    select:(tag)->
        target = null
        for item in @listItems
            if item.name is tag
                target = item
                break
        if not target
            console.error "source guid #{guid} not found"
            return
        @tagArchiveList.setTag(target)
        if @currentActive
            @currentActive.deactive()
        target.active()
        @currentActive = target
    buildTagList:()->
        for item in @listItems
            item.__match = "notmatch"
        console.log Tag.tags
        for tag in Tag.tags
            found = false
            for item in @listItems
                if item.tag.name is tag.name
                    found = true
                    item.__match = "match"
                    break
            if not found
                @addTag tag
        for item,index in @listItems
            if item.__match is "notmatch"
                item.remove()
                @listItems[index] = null
        
        @listItems = @listItems.filter (item)->item
            
    addTag:(tag)->
        tag = new TagListItem(tag)
        @listItems.push tag
        tag.appendTo @UI.container
        tag.parent = this;
        return tag
class TagListItem extends Leaf.Widget
    constructor:(@tag)->
        super(SybilWebUI.templates["source-list-item"])
        @name = @tag.name
        @sources = @tag.sources
        @render()
        @tag.on "change",()=>
            @render()
    render:()->
        @unreadCount = 0
        for source in @sources
            if source.unreadCount > 0
                @unreadCount += source.unreadCount
        @UI.name.innerText = "#{@name}(#{@sources.length})"
        @UI.unreadCounter$.text((parseInt(@unreadCount) >= 0) and parseInt(@unreadCount).toString() or "?")
    onClickName:()->
        @parent.select(@name)
        return false
    active:()->
        @node$.addClass "active"
        @isActive = true
    deactive:()->
        @node$.removeClass "active"
        @isActive = false
class TagDetailPanel extends Leaf.Widget
    constructor:()->
        super(SybilWebUI.templates["source-detail-panel"])
        @tags = []
    setSource:(source)->
        @data = source
        @render()
    render:()->
        @UI.name$.text @data.name
        tags = @data.tags or []
        for tag in @tags
            tag.remove()
        
        @tags.length = 0
        for tag in tags
            @addTag new TagDetailPanel.Tag(tag)
    addTag:(tag)->
        tag.appendTo @UI.tagContainer
        guid = @data.guid
        tag.onClickNode = ()=>
            SybilWebUI.messageCenter.invoke "removeTagFromSource",{guid:guid,name:tag.name},(err)=>
                if err
                    console.error err
                    return
                @tags = @tags.filter (_)->
                    if _.name is tag.name
                        _.remove()
                        return false
                    return true
                @data.tags = (@data.tags or []).filter (item)->item isnt tag.name
        @tags.push tag
    onClickAddTag:()->
        @UI.addTag$.hide()
        @UI.tagAddActions$.show()
        @UI.addTagInput$.focus()
    onClickConfirmAddTag:()->
        name = @UI.addTagInput.value.trim().toLowerCase()
        if not name
            return
        
        for _ in @tags
            if _.name is name
                SybilWebUI.showHint "#{name} already exist."
                return
        SybilWebUI.messageCenter.invoke "addTagToSource",{guid:@data.guid,name:name},(err,source)=>
            if err
                console.error
                return
            @addTag(new TagDetailPanel.Tag(name))
            @UI.addTagInput.value = ""
            @data.tags = @data.tags or []
            @data.tags.push name
    onClickCancelAddTag:()->
        @UI.addTag$.show()
        @UI.tagAddActions$.hide()
    onKeydownAddTagInput:(e)->
        if e.which is Leaf.Key.enter
            @onClickConfirmAddTag()
            return false
        return true
class TagDetailPanel.Tag extends Leaf.Widget
    constructor:(name)->
        @name = name
        super "<span class='tag'><span>"
        @node$.text(name)
        
window.TagList = TagList