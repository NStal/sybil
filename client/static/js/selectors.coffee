class TagItem extends Leaf.Widget
    constructor:(@tag)->
        super "<span></span>"
        @node$.text @tag.name
    onClickNode:()->
        if @isSelect
            @unselect()
        else
            @select()
    select:()->
        @isSelect = true
        @emit "select"
        @node$.addClass "select"
    unselect:()->
        @isSelect = false
        @emit "unselect"
        @node$.removeClass "select"
class TagSelector extends Leaf.Widget
    constructor:()->
        super App.templates["tag-selector"]
        @tags = []
    select:(callback)->
        if @_callback
            callback "previous select not done"
            return
        @selectedTags = []
        @_callback = callback
        @show()
    onClickConfirm:()->
        @hide()
        @_callback null,@selectedTags
        # don't manually call this function
        @_callback = null
    onClickCancel:()->
        @hide()
        @_callback "cancel"
        # don't manually call this function
        @_callback = null
    onClickClearAll:()->
        for tag in @tags
            tag.unselect()
        @selectedTags.length = 0
    buildTags:()->
        for tag in @tags
            tag.remove()
        @tags.length = 0
        for tag in Tag.tags
            tagItem = new TagItem(tag)
            @tags.push tagItem
            @addTagItem(tagItem)
    addTagItem:(item)->
        item.on "select",()=>
            for tag in @selectedTags
                if tag is item.tag
                    return
            @selectedTags.push item.tag
        item.on "unselect",()=>
            for tag,index in @selectedTags
                if tag is item.tag
                    @selectedTags.splice(index,1)
                    return
        console.log "append tag item",item
        item.appendTo @UI.tags
    show:()->
        @buildTags()
        @node$.show()
    hide:()->
        @node$.hide()

class SourceItem extends Leaf.Widget
    constructor:(@source)->
        super "<span></span>"
        @node$.text @source.name or @source.guid
    onClickNode:()->
        if @isSelect
            @unselect()
        else
            @select()
    select:()->
        @isSelect = true
        @emit "select"
        @node$.addClass "select"
    unselect:()->
        @isSelect = false
        @emit "unselect"
        @node$.removeClass "select"
class SourceSelector extends Leaf.Widget
    constructor:()->
        super App.templates["source-selector"]
        @sources = []
    select:(callback)->
        if @_callback
            callback "previous select not done"
            return
        @selectedSources = []
        @show()
        @_callback = callback
    onClickConfirm:()->
        @hide()
        @_callback null,@selectedSources
        # don't manually call this function
        @_callback = null
    onClickCancel:()->
        @hide()
        @_callback "cancel"
        # don't manually call this function
        @_callback = null
    onClickClearAll:()->
        for source in @sources
            source.unselect()
        @selectedSources.length = 0
    buildSources:()->
        for source in @sources
            source.remove()
        @sources.length  = 0 
        for source in Source.sources
            sourceItem = new SourceItem(source)
            @sources.push sourceItem
            @addSourceItem(sourceItem)
    addSourceItem:(item)->
        item.on "select",()=>
            for source in @selectedSources
                if source is item.source
                    return
            @selectedSources.push item.source
        item.on "unselect",()=>
            for source,index in @selectedSources
                if source is item.source
                    @selectedSources.splice(index,1)
                    return
        item.appendTo @UI.sources
    show:()->
        @buildSources()
        @node$.show()
    hide:()->
        @node$.hide()
        

window.TagSelector = TagSelector
window.SourceSelector = SourceSelector