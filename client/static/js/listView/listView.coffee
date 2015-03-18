App = require "/app"
SwipeChecker = require("/util/swipeChecker")
Model = require "/model"
View = require "/view"
ArchiveDisplayer = require "/baseView/archiveDisplayer"
ScrollChecker = require "/util/scrollChecker"
CubeLoadingHint = require("/widget/cubeLoadingHint")
ContextMenu = require "/widget/contextMenu"
moment = require "/lib/moment"
tm = require "/templateManager"
# Refactor to use only a single class or two
class ListView extends View
    constructor:()->
        @list = new List(this)
        @archives = new ArchiveList(this)
        @archiveDisplayer = new ListArchiveDisplayer(this)
        @list.on "init",()=>
            if @isShow
                @show()
        @list.on "select",(list)=>
            @archives.load list.archiveList
            @slideTo(1)
            # enable auto slide after first slide
            # so we will still at left most position
            # when user first check in at list view
        @archives.on "archive",()=>
            console.debug "slide to 1"
            @slideTo(1)
        @archives.on "select",(archiveListItem)=>
            @archiveDisplayer.display archiveListItem.archive
            @archiveDisplayer.maybeList = archiveListItem.listName
            if @currentArchiveListItem
                @currentArchiveListItem.deselect()
            @currentArchiveListItem = archiveListItem
            @slideTo(2)
            @enableArchiveAutoSlide = true
        super $(".list-view")[0],"list view"
#        @list.appendTo @node
#        @archives.appendTo @node
#        @archiveDisplayer.appendTo @node
        # mobile
        checker = new SwipeChecker(@node);
        checker.on "swiperight",(ev)=>
            @previousSlide()
        checker.on "swipeleft",(ev)=>
            @nextSlide();
        @currentSlide = 0
    slideTo:(count)->
        if count < 0
            count = 0
        if count > 2
            count = 2
        @currentSlide = count
        @applySlide()
    nextSlide:()->
        @slideTo @currentSlide+1 or 2
    previousSlide:()->
        if @currentSlide <= 0
            return
        @slideTo @currentSlide-1 or 0
    applySlide:()->
        if @currentSlide is 0
            @node$.removeClass("slide-col2").removeClass("slide-col3")
        else if @currentSlide is 1
            @node$.addClass("slide-col2").removeClass("slide-col3")
        else if @currentSlide is 2
            if not @archiveDisplayer.archive
                return
            @node$.addClass("slide-col2").addClass("slide-col3")
    show:()->
        if not @list.current and @list.lists.length > 0
            @list.lists[0].select()
        super()

tm.use "listView/listViewList"
class List extends Leaf.Widget
    constructor:(@context)->
        super App.templates.listView.listViewList
        @lists = Leaf.Widget.makeList(@UI.container)
        App.afterInitialLoad ()=>
            Model.ArchiveList.sync ()=>
                @emit "init"
        # WARN: no add currently
        App.modelSyncManager.on "archiveList/remove",(list)=>
            for item,index in @lists
                if item.archiveList.name is list.name
                    @lists.splice(index,1)
                    break

        App.modelSyncManager.on "archiveList/add",(list)=>
            @lists.push new ListItem(list)
        # refactor here
        # done add onClickNode method here
        # make it inside constructor
        @lists.on "child/add",(list)=>
            @bubble list,"select",()->
                if @current
                    @current.node$.removeClass("select");
                @current = list
                return ["select",list]
    onClickAddListButton:()->
        name = prompt "enter you list name"
        if not name or not name.trim()
            return
        name = name.trim()
        Model.ArchiveList.create name,(err,list)=>
            console.debug "create list",err,list
            if err
                App.showError err
tm.use "listView/listViewListItem"
class ListItem extends Leaf.Widget
    constructor:(@archiveList)->
        super App.templates.listView.listViewListItem
        @archiveList.on "add",(archive)=>
            @render()
        @archiveList.on "remove",(archive)=>
            @render()
        @archiveList.on "change",()=>
            @render()
        @render()
        @node.oncontextmenu = (e)=>
            e.preventDefault()
            e.stopImmediatePropagation()
            @contextMenu ?= new ContextMenu [
                {
                    name:"remove list"
                    callback:@removeList.bind(this)
                }
            ]
            @contextMenu.show(e)
    removeList:()->
        @archiveList.delete ()->
            console.log "delete?"
    render:()->
        @UI.name$.text @archiveList.name
        @UI.unreadCounter$.text @archiveList.count
        @name = @archiveList.name
    select:()->
        @emit "select",this
        @node$.addClass("select");
    onClickNode:(e)=>
        @select()
tm.use "listView/listViewArchiveList"
class ArchiveList extends Leaf.Widget
    constructor:(@context)->
        @include CubeLoadingHint
        super App.templates.listView.listViewArchiveList
        @archives = Leaf.Widget.makeList @UI.archives
        @archives.on "child/add",(archiveListItem)=>
            archiveListItem.listName = @currentList.name
            archiveListItem.listenBy this,"select",()=>
                @emit "select",archiveListItem
        @archives.on "child/remove",(item)=>
            # we don't remove it instead we should display a delete dash at middle of it
            return
            #item.destroy()
        @scrollChecker = new ScrollChecker(@node)
        @scrollChecker.on "scrollBottom",()=>
            @more()
    render:()->
        if not @currentList
            return
        @sort ?= "latest"
        if @sort is "latest"
            @VM.orderName = "Latest"
            @VM.orderIcon = "fa-caret-up"
        else
            @VM.orderName = "Oldest"
            @VM.orderIcon = "fa-caret-down"

    load:(list)->
        if @currentList
            @currentList.stopListenBy this
        @currentList = list
        @currentList.listenBy this,"add",@prependArchive
        @currentList.listenBy this,"remove",@removeArchive
        @sort = (App.userConfig.get "listOrder/#{@currentList.name}") or "latest"
        @render()
        @archives.length  = 0
        @noMore = false
        @UI.loadingHint.hide()
        @more()
    onClickReorder:()->
        if not @currentList
            return
        @sort ?= "latest"
        if @sort is "latest"
            App.userConfig.set "listOrder/#{@currentList.name}","oldest"
        else
            App.userConfig.set "listOrder/#{@currentList.name}","latest"
        @load(@currentList)
    more:()->
        if @noMore
            return
        count = 20
        list = @currentList
        @UI.loadingHint.show()
        for item in @archives
            if item.archive.listName is @currentList.name
                lastGuid = item.guid
        splitter = lastGuid or null
        @currentList.getArchives {splitter,count,@sort},(err,archives)=>
            if @currentList isnt list
                return
            @UI.loadingHint.hide()
            for archive in archives
                @archives.push new ArchiveListItem(archive)
            if archives.length isnt count
                @noMore = true

    prependArchive:(archive)->
        for item in @archives
            if item.archive.guid is archive.guid
                if item.isDone
                    item.isDone = false
                    item.render()
                return
        @emit "archive"
        @archives.unshift new ArchiveListItem(archive)
    removeArchive:(archive)->
        for item,index in @archives
            if item.archive.guid is archive.guid
                if not item.isDone
                    item.isDone = true
                    item.render()
                    return
    onClickMoreButton:()->
        @more()
tm.use "listView/listViewArchiveListItem"
class ArchiveListItem extends Leaf.Widget
    constructor:(@archive)->
        super App.templates.listView.listViewArchiveListItem
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
#        @UI.date$.text moment(@archive.createDate).format("YYYY-MM-DD")
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
        @archive.changeList @listName,(err)=>
            @isDone = false
            @render()
    onClickDone:(e)->
        if e
            e.preventDefault()
            e.stopImmediatePropagation()
        if @isDone
            @markAsUndone()
        else
            @markAsDone()
    genPreview:(content)->
        container = document.createElement("div")
        container.innerHTML = content
        maxLength = 50
        result = $(container).text().trim().substring(0,maxLength)
        if result.length is maxLength
            result += "..."
        else if result.length is 0
            result = "( empty )"
        return result

tm.use "listView/archiveDisplayer"
class ListArchiveDisplayer extends ArchiveDisplayer
    constructor:(@context)->
        # share template with search view
        @archiveHelper = new ArchiveHelper(this)
        super App.templates.listView.archiveDisplayer
        @node$.addClass("no-article")
    display:(archive)->
        @node$.removeClass("no-article")
        @setArchive(archive)
        @node.scrollTop = 0
        @render()
tm.use "listView/archiveHelper"
Flag = require "/util/flag"
class ArchiveHelper extends Leaf.Widget
    constructor:(@archiveDisplayer)->
        super App.templates.listView.archiveHelper
        @context = @archiveDisplayer.context
        @showOptionFlag = new Flag().attach(@VM,"showOption").unset()
    render:()->
        archive = @archiveDisplayer.archive
        @Data.cleared = not archive.listName
    onClickExpandOption:()->
        @showOptionFlag.toggle()
    onClickClear:()->
        if @archiveDisplayer.archive.listName is @context.archives.currentList.name
            @archiveDisplayer.onClickReadLater()
        if @onClickNext()
            return
        else if @onClickPrevious()
            return
    goTop:()->
        @archiveDisplayer.UI.scrollable.scrollTop = 0
    goBottom:()->
        scrollable = @archiveDisplayer.UI.scrollable
        scrollable.scrollTop = scrollable.scrollHeight
    isTop:()->
        @archiveDisplayer.UI.scrollable.scrollTop < 2
    isBottom:()->
        return true
    onClickGoBottom:()->
        console.log "go bottom???"
        @goBottom()
    onClickNext:()->
        if not @isBottom()
            @goBottom()
        archives = @context.archives.archives
        for item,index in archives
            if item.archive is @archiveDisplayer.archive
                if archives[index+1]
                    archives[index+1].select()
                    @goTop()
                return true
        return false
    onClickPrevious:()->
        if not @isTop()
            @goTop()
            return
        archives = @context.archives.archives
        for item,index in archives
            if item.archive is @archiveDisplayer.archive
                if archives[index-1]
                    archives[index-1].select()
                    @goTop()
                return true
        return false
module.exports = ListView
