i18n = require "/i18n"
moment = require "/lib/moment"
App = require "/app"
Model = require "/model"
SmartImage = require "/widget/smartImage"
ContentImage = require "/widget/contentImage"
tm = require "/templateManager"
class ArchiveDisplayer extends Leaf.Widget
    constructor:(template)->
        @include ContentImage
        @include SmartImage
        super template
        @useDisplayContent = true
    setArchive:(archive)->
        if @archive
            @archive.stopListenBy this
            @stopBubble @archive
        @archive = archive
        @bubble @archive,"change"
        @archive.listenBy this,"change",@render
        if @richContent
            @richContent.destroy()
        @richContent = new RichContent @archive
        @render()
    unsetArchive:()->
        if @archive
            @archive.stopListenBy this
        @richContent?.destroy()
        @richContent = null
        @archive = null
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
        if @UI.avatar and @archive.author and @archive.author.avatar
            @UI.avatar$.addClass "show"
            @UI.avatar.src = @archive.author.avatar
#            @UI.avatar.errorSrc = "/image/author-avatar-default.png"
#            @UI.avatar.loadingSrc = "/image/author-avatar-default.png"
        else
            @UI.avatar$.removeClass "show"
        if @archive.originalLink
            @UI.title$.attr("href",@archive.originalLink)
        if @archive.like
            @UI.like$.addClass("active")
        else
            @UI.like$.removeClass("active")
        maybeList = @archive.listName or @maybeList or App.userConfig.get("#{@archive.sourceGuid}/maybeList") or "read later"
        @VM.listName = maybeList
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
        if @UI.content.children[0] isnt @richContent.container
            @UI.content.innerHTML = ""
            @UI.content.appendChild @richContent.container
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

    destroy:()->
        super()
        @richContent?.destroy()
        @unsetArchive()
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
        top = e.clientY+15-height
        left = e.clientX-10
        top = top > 0 and top or 0
        left = left > 0 and left or 0
        @node$.css({position:"absolute",top,left})
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
class RichContent extends Leaf.EventEmitter
    constructor:(@archive)->
        @container = document.createElement "div"
        @container.classList.add "rich-content"
        @archive.sanitizedContent ?= sanitizer.sanitize @archive.displayContent or @archive.content
        @container.innerHTML = @archive.sanitizedContent
        @images = []
        imgs = []
        links = []
        @useResourceProxy = (App.userConfig.get "enableResourceProxy/#{@archive.sourceGuid}") and true or false
        for el in @container.querySelectorAll("img,a")
            if el.tagName.toLowerCase() is "img"
                insideLink = false
                p = el.parentElement
                while p
                    if p.tagName is "A"
                        insideLink = true
                    p = p.parentElement
                if not insideLink
                    imgs.push el
            else if el.tagName is "A"
                links.push el
        for img in imgs
            src = @decorateImageUrl img.getAttribute("src") or img.getAttribute("data-raw-src")
            params = {
                thumbSrc:@decorateImageUrl img.getAttribute("data-thumbnail-src")
                originalSrc:@decorateImageUrl img.getAttribute("data-raw-src") or src
                mediumSrc:@decorateImageUrl img.getAttribute("data-medium-src")
            }
            si = new ContentImage img,params
            si.ownerContent = this
            @images.push si
            if img.parentElement
                img.parentElement.replaceChild si.node,img
            img.removeAttribute "src"
        for link in links
            link.setAttribute "target","_blank"
    decorateImageUrl:(url)->
        if @useResourceProxy
            return "/remoteResource?url=#{encodeURIComponent(url)}&referer=#{@archive.originalLink}"
        return url

    destroy:()->
        for si in @images
            si.destroy()
        @container = null


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
