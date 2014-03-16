class TagArchiveList extends ArchiveList
    constructor:()->
        super(App.templates["tag-archive-list"])
    setTag:(tag)->
        @node.scrollTop = 0
        @noMore = false
        @currentTag = tag
        @UI.emptyHint$.show()
        @UI.currentArchiveTitle$.text tag.name
        for item in @archiveListItems
            item.remove()
        @archiveListItems.length = 0
        
        @moreArchive()        
    moreArchive:()->
        console.log "....more"
        if @noMore
            return
        if @isLoadingMore
            return
        if not @currentTag
            return
        @isLoadingMore = true
        
        last = @archiveListItems[@archiveListItems.length-1]
        if last
            @offset = last.archive.guid
        else
            @offset = null
        Archive.getByTag {name:@currentTag.name,viewRead:@viewRead,sort:@sort,offset:@offset,count:@count},(err,archives)=>
            console.log "here"
            @isLoadingMore = false
            if err or not (archives instanceof Array)
                console.error err,archives,@currentTag.name
                console.error err or "no archive!"
                console.trace()
                return
            if archives.length is 0
                @onNoMore()
                return
            for archive in archives
                archiveListItem = new ArchiveListItem(archive)
                @appendQueue.push (archiveListItem)

window.TagArchiveList = TagArchiveList