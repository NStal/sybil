class ArchiveDisplayer extends Leaf.Widget
    constructor:(template)->
        super template
    setArchive:(archive)->
        @archive = archive
        @render()
        @useDisplayContent = true
    _renderShareInfo:(profile,howmany)->
        if howmany is 0 
            @UI.shareInfo$.text ""
            return true
        if not profile
            @UI.shareInfo$.text App.textFormat App.Language.thisManyPeopleHasShareIt_i,howmany
            return true
        if profile
            html = "<img src='http://www.gravatar.com/avatar/#{profile.hash}?s=12&d=identicon'></img>"
            if howmany > 1
                words = App.textFormat App.Language.andThisMorePeopleHasShareIt_i,howmany-1
            else
                words = profile.nickname+" "+App.Language.sharesIt
            @UI.shareInfo$.html(html+words)
            
    render:()->
        @UI.title$.text(@archive.title)
        if @archive.originalLink
            @UI.title$.attr("href",@archive.originalLink)
        if @archive.like
            @UI.like$.addClass("active")
        else
            @UI.like$.removeClass("active")
        if @archive.listName is "read later"
            @UI.readLater$.addClass("active")
        else
            @UI.readLater$.removeClass("active") 
        if @archive.createDate
            @UI.date$.text(moment(@archive.createDate).format(App.Language.fullDateFormatString))
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
            
            if App.userConfig.get("enableResourceProxy")
                if not App.userConfig.get("useResourceProxyByDefault")
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
        console.log "HI ~~"
        if not @archive.share
            console.log @archive
            @archive.markAsShare (err)=>
                @render()
        else
            @archive.markAsUnshare (err)=>
                @render()
    onClickReadLater:()->
        if @archive.listName isnt "read later"
            @archive.readLaterArchive (err)=>
                if err then console.error err
                @render()
        else
            @archive.unreadLaterArchive (err)=>
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
    markAsLike:()->
        if not @archive.like
            @archive.likeArchive () -> @render()
    markAsUnlike:()->
        if not @archive.like
            @archive.unlikeArchive () => @render()
    

window.ArchiveDisplayer = ArchiveDisplayer
