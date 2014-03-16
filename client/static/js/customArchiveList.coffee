class CustomArchiveList extends ArchiveList
    constructor:()->
        super(App.templates["custom-archive-list"])
    setSelector:(selector)->
        @node.scrollTop = 0
        @noMore = false
        @currentSelector = selector
        @UI.emptyHint$.show()
        @UI.currentArchiveTitle$.text selector.name
        for item in @archiveListItems
            item.remove()
        @archiveListItems.length = 0
        @moreArchive()
    moreArchive:()->
        if @noMore
            return
        if @isLoadingMore
            return
        if not @currentSelector
            return
        @isLoadingMore = true 
        last = @archiveListItems[@archiveListItems.length-1]
        if last
            @offset = last.archive.guid
        else
            @offset = null
        console.log({query:@currentSelector.toQuery(),viewRead:@viewRead,sort:@sort,offset:@offset,count:@count})
        Archive.getByCustom {query:@currentSelector.toQuery(),viewRead:@viewRead,sort:@sort,offset:@offset,count:@count},(err,archives)=>
            console.log "here"
            @isLoadingMore = false
            if err or not (archives instanceof Array)
                console.error err,archives,@currentSelector
                console.error err or "no archive!"
                console.trace()
                return
            if archives.length is 0
                @onNoMore()
                return
            for archive in archives
                archiveListItem = new ArchiveListItem(archive)
                @appendQueue.push (archiveListItem)
window.CustomArchiveList = CustomArchiveList
        
