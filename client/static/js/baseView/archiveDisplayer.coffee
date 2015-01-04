i18n = require "/i18n"
moment = require "/lib/moment"
App = require "/app"
Model = require "/model"
tm = require "/templateManager"
class ArchiveDisplayer extends Leaf.Widget
    constructor:(template)->
        super template
        @useDisplayContent = true
    setArchive:(archive)->
        if @archive
            @archive.stopListenBy this
            @stopBubble @archive
        @archive = archive
        @bubble @archive,"change"
        @archive.listenBy this,"change",@render
        @render()
    focus:()->
        @node$.addClass "focus"
    blur:()->
        @node$.removeClass "focus"
    _renderShareInfo:(profile,howmany)->
        if howmany is 0
            @UI.shareInfo$.text ""
            return true
        if not profile
            @UI.shareInfo$.text i18n.thisManyPeopleHasShareIt_i howmany
            return true
        if profile
            html = "<img src='http://www.gravatar.com/avatar/#{profile.hash}?s=12&d=identicon'></img>"
            if howmany > 1
                words = i18n.andThisMorePeopleHasShareIt_i howmany-1
            else
                words = profile.nickname+" "+i18n.sharesIt()
            @UI.shareInfo$.html(html+words)

    render:()->
        @UI.title$.text(@archive.title)
        if @archive.originalLink
            @UI.title$.attr("href",@archive.originalLink)
        if @archive.like
            @UI.like$.addClass("active")
        else
            @UI.like$.removeClass("active")
        maybeList = @archive.listName or @maybeList or App.userConfig.get("#{@archive.sourceGuid}/maybeList") or "read later"
        @UI.readLater$.text maybeList
        if @archive.listName is maybeList
            @UI.readLater$.addClass("active")
        else
            @UI.readLater$.removeClass("active")
        if @archive.listName
            @VM.listText = "list (#{@archive.listName})"
        else
            @VM.listText = "list"
        if @archive.createDate
            @UI.date$.text moment(@archive.createDate).format(i18n.fullDateFormatString())
        if @archive.share
            @UI.share$.addClass("active")
        else
            @UI.share$.removeClass("active")
        shareRecords = @archive.meta.shareRecords
        if shareRecords
            profile = @archive.getFirstValidProfile()
            @_renderShareInfo(profile,shareRecords.length)
        @UI.sourceName$.text @archive.sourceName
        originalLink = @archive.originalLink or ""

        if @useDisplayContent
            toDisplay = @archive.displayContent or @archive.content

        else
            toDisplay = @archive.content
        if @currentContent isnt toDisplay
            @currentContent = toDisplay
            if !@currentContent
                @UI.content$.text("")
                return
            # try have resource proxy set.
            forceProxy = App.userConfig.get "enableResourceProxy/#{@archive.sourceGuid}"
            if App.userConfig.get("enableResourceProxy") or forceProxy
                if not App.userConfig.get("useResourceProxyByDefault") and not forceProxy
                    # replace on error
                    @UI.content$.html (sanitizer.sanitize(toDisplay))
                    @UI.content$.find("img").each ()->
                        @useProxy = false
                        @onerror = ()=>
                            if @userProxy
                                return
                            @useProxy = true
                            url = @getAttribute "src"
                            if url.indexOf("/remoteResource")>=0
                                return
                            if url.indexOf("file://") >= 0
                                return
                            $(this).attr("src","/remoteResource?url=#{encodeURIComponent(url)}&referer=#{originalLink}")
                else
                    content = document.createElement("div")
                    content.innerHTML = (sanitizer.sanitize(toDisplay))
                    $(content).find("img").each ()->
                        url = @getAttribute "src"
                        $(this).attr("src","/remoteResource?url=#{encodeURIComponent(url)}&referer=#{originalLink}")
                    @UI.content$.html content.innerHTML
            else
                @UI.content$.html(sanitizer.sanitize(toDisplay))
            @UI.content$.find("a").each ()->
                this.setAttribute "target","_blank"

    onClickShare:()->
        if not @archive.share
            console.log @archive
            @archive.markAsShare (err)=>
                @render()
        else
            @archive.markAsUnshare (err)=>
                @render()
    onClickReadLater:()->
        # the read later button now has a different feature
        # we may choose a default list for a source as a read later list
        maybeList = App.userConfig.get("#{@archive.sourceGuid}/maybeList") or "read later"
        if not @archive.listName
            @archive.changeList maybeList,(err)=>
                if err then console.error err
                @render()
        else
            @archive.changeList null,(err)=>
                if err then console.error err
                @render()
    onClickLike:()->
        if not @archive.like
            @archive.likeArchive (err)=>
                if err then console.error err
                @render()
        else
            @archive.unlikeArchive (err)=>
                if err then console.error err
                @render()
    onClickList:(e)->
        if not @listSelector
            @listSelector = new ArchiveDisplayerListSelector()
            @listSelector.listenBy this,"select",(listModel)=>
                @archive.changeList listModel.name,(err)=>
                    App.userConfig.set "#{@archive.sourceGuid}/maybeList",listModel.name
                    @listSelector.active listModel.name
                    @listSelector.hide()
                    @render()
        @listSelector.updateState()
        @listSelector.show(e)
        if @archive.listName
            @listSelector.active @archive.listName
    markAsLike:()->
        if not @archive.like
            @archive.likeArchive () -> @render()
    markAsUnlike:()->
        if not @archive.like
            @archive.unlikeArchive () => @render()

Popup = require "/widget/popup"
tm.use "baseView/archiveDisplayerListSelector"
class ArchiveDisplayerListSelector extends Popup
    constructor:()->
        super App.templates.baseView.archiveDisplayerListSelector
        @lists = Leaf.Widget.makeList @UI.lists
        @lists.on "child/add",(item)=>
            item.listenBy this,"select",@select
        @lists.on "child/remove",(item)=>
            item.stopListenBy this
    updateState:()->
        @lists.length = 0
        for list in Model.ArchiveList.lists.models
            @lists.push new ArchiveDisplayerListSelectorItem list
    show:(e)->
        super()
        if not e
            return
        if Leaf.Util.isMobile()
            return
        @node$.width(300)
        height = @node$.height()
        @node$.css({position:"absolute",top:e.clientY+15-height,left:e.clientX-10})
    select:(item)->
        @emit "select",item.list
    active:(name)->
        if not name
            return
        for item in @lists
            item.deactive()
            if item.list.name is name
                item.active()
    onClickCloseButton:()->
        @hide()
class ArchiveDisplayerListSelectorItem extends Leaf.Widget
    constructor:(@list)->
        super "<li data-text='name'></li>"
        @VM.name = @list.name
    onClickNode:()->
        @emit "select",this
    active:()->
        @VM.name = "(current) "+@list.name
    deactive:()->
        @VM.name = @list.name
#window.ArchiveDisplayer = ArchiveDisplayer
module.exports = ArchiveDisplayer
