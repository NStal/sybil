class ListView extends View
    constructor:()->
        @list = new List()
        @archives = new ArchiveList()
        @archiveDisplayer = new ListArchiveDisplayer()
        console.debug @archiveDisplayer.node,@archiveDisplayer,"!!!"
        @list.on "select",(archiveList)=>
            @archives.load archiveList.archiveList
        @archives.on "select",(archiveListItem)=>
            @archiveDisplayer.display archiveListItem.archive
            if @currentArchiveListItem
                @currentArchiveListItem.deselect()
            @currentArchiveListItem = archiveListItem
        super $(".list-view")[0],"list view"
        @list.appendTo @node
        @archives.appendTo @node
        @archiveDisplayer.appendTo @node

        # mobile
        @node.ontouchstart = (e)=>
            @lastStartDate = Date.now()
            @lastStartEvent = e
        @node.ontouchmove = (e)=>
            @lastMoveEvent = e
            if not @lastMoveEvent or not @lastStartEvent
                return
            #alert Math.abs(@lastStartEvent.touches[0].clientX - @lastMoveEvent.touches[0].clientX) > 50
            if Math.abs(@lastStartEvent.touches[0].clientY - @lastMoveEvent.touches[0].clientY) > Math.abs( @lastStartEvent.touches[0].clientY - @lastMoveEvent.touches[0].clientY)
                @lastStartEvent.preventDefault()
                @lastMoveEvent.preventDefault()
        
        Hammer(@node).on "swiperight",(ev)=>
            ev.preventDefault()
            @previousSlide()
        Hammer(@node).on "swipeleft",(ev)=>
            ev.preventDefault()
            @nextSlide();
        @currentSlide = 0
    nextSlide:()->
        if @currentSlide > 1
            return
        @currentSlide++
        @applySlide()
    previousSlide:()->
        if @currentSlide <= 0
            return
        @currentSlide--
        @applySlide()
    applySlide:()->
        if @currentSlide is 0
            @node$.removeClass("slide-col2").removeClass("slide-col3")
        else if @currentSlide is 1
            @node$.addClass("slide-col2").removeClass("slide-col3")
        else
            @node$.addClass("slide-col2").addClass("slide-col3")
        

class List extends Leaf.Widget
    constructor:()->
        super App.templates["list-view-list"]
        @lists = Leaf.Widget.makeList(@UI.container)
        for list in Model.ArchiveList.lists
            @lists.push new ListItem(list)
        Model.on "archiveList/add",(list)=>
            @lists.push new ListItem(list)
        # refactor here
        # done add onClickNode method here
        # make it inside constructor
        @lists.on "child/add",(list)=>
            list.on "select",()=>
                @emit "select",list
                if @current
                    @current.node$.removeClass("select");
                @current = list
            # select the first list
            if @lists.length is 1
                list.onClickNode()
class ListItem extends Leaf.Widget
    constructor:(@archiveList)->
        super App.templates["list-view-list-item"]
        @archiveList.on "add",(archive)=>
            @render()
        @archiveList.on "remove",(archive)=>
            @render()
        @archiveList.on "change",()=>
            @render()
        @render()
    render:()->
        @UI.name$.text @archiveList.name
        console.debug @archiveList
        @UI.unreadCounter$.text @archiveList.count
        @name = @archiveList.name
    onClickNode:()=>
        @emit "select",this
        @node$.addClass("select");
class ArchiveList extends Leaf.Widget.List
    constructor:()->
        super App.templates["list-view-archive-list"]
        @addArchive = @addArchive.bind(this)
        @removeArchive = @removeArchive.bind(this)
        @on "child/add",(archiveListItem)=>
            archiveListItem.listName = @currentList.name
            archiveListItem.on "select",()=>
                @emit "select",archiveListItem
    load:(list)->
        if @currentList
            @currentList.removeListener "add",@addArchive
            @currentList.removeListener "remove",@removeArchive
        @currentList = list
        @currentList.getArchives (err,archives)=>
            @length  = 0
            for archive in archives
                @push new ArchiveListItem(archive)
            @[0].select()
        list = @currentList
        @currentList.on "add",@addArchive
        @currentList.on "remove",@removeArchive
    addArchive:(archive)->
        for item in this
            if item.archive.guid is archive.guid
                if item.isDone
                    item.isDone = false
                    item.render()
                
                return
        @push new ArchiveListItem(archive)
    removeArchive:(archive)->
        for item,index in this
            if item.archive.guid is archive.guid
                if not item.isDone
                    item.isDone = true
                    item.render()
                    return
class ArchiveListItem extends Leaf.Widget
    constructor:(@archive)->
        super App.templates["list-view-archive-list-item"]
        @render()
        @isDone = false
    onClickNode:()->
        @select()
    select:()->
        @emit "select",this
        @node$.addClass("select")
    deselect:()->
        @node$.removeClass("select")
    render:()->
        @UI.title$.text @archive.title
        #@UI.via$.text "via "+ parseUri(@archive.originalLink).host
        @UI.content$.text @genPreview @archive.content
        @UI.date$.text moment(@archive.createDate).format("YYYY-MM-DD")
        if not @isDone
            @node$.removeClass("clear")
        else
            @node$.addClass("clear")
    markAsDone:()->
        if @isDone
            return
        @archive.changeList null,(err)=>
            @isDone = true
            @render()
    markAsUndone:()->
        if not @isDone
            return
        console.debug "mark as undone",@listName
        @archive.changeList @listName,(err)=>
            @isDone = false
            @render()
    onClickDone:()->
        if @isDone
            @markAsUndone()
        else
            @markAsDone()
    genPreview:(content)->
        container = document.createElement("div")
        container.innerHTML = content
        result = $(container).text().trim().substring(0,80)
        if result.length is 80
            result += "..."
        else if result.length is 0
            result = "( empty )"
        return result

    
class ListArchiveDisplayer extends ArchiveDisplayer
    constructor:()->
        # share template with search view
        super App.templates["archive-displayer"]
        @node$.addClass("no-article")
    display:(archive)->
        @node$.removeClass("no-article")
        @setArchive(archive)
        @render()
        
window.ListView = ListView