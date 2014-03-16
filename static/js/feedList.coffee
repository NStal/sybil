class FeedList extends Leaf.Widget
    constructor:()->
        super(sybil.templates["feed-list"])
        @type = ""
        @count = 10
        @items = []
        @node$.scroll ()=>
            @onScroll()
    goto:(id)->
        sybil.rssList.focus(id)
        sybil.rssList.getRssById id,(err,rss)=>
            if err
                return
            @clear()
            @UI.title$.text(rss.title)
            @currentRss = rss
            @undrain()
            @more()
    clear:()->
        @items.length = 0;
        @UI.listContainer$.empty()
    ListItem:class FeedListItem extends Leaf.Widget
        constructor:(data)->
            super sybil.templates["feed-list-item"]
            @init data
        init:(@data)->
            @UI.title$.text data.title
            @UI.content$.html sanitizer.sanitize(data.description or "")
            @UI.title$.attr "href",data.link or "#"
            @UI.date$.text moment(data.date).format("L")
            @UI.content$.find("img").each ()->
                # modify relative link
                if !this.getAttribute("src")
                    return
                if this.getAttribute("src").indexOf("http") != 0
                    console.log "resolve"
                    this.setAttribute "src",(sybil.common.resolve data.source,this.getAttribute("src"))
                    console.log "resolved",
            if not data.read
                @node$.addClass "unread"
            else
                @node$.removeClass "unread"
        onClickNode:()->
            @markAsRead()
        markAsRead:()->
            if @data.read
                return
            API.read @data.id
            @node$.removeClass "unread" 
            @emit "read"
            
    appendFeed:(data)->
        rss = @currentRss
        setTimeout (()=>
            feed = new FeedListItem(data)
            feed.appendTo @UI.listContainer
            feed.on "read",()->
                item = sybil.rssList.getListItemById rss.id
                item.data.unreadCount--
                if item.data.unreadCount < 0
                    item.data.unreadCount = 0
                item.init(item.data)
                console.log "~~!!!"
                    
            @items.push feed
        ),0
    onClickMarkAllAsReadButton:()->
        if not confirm("sure mark all as read?")
            return
        if not @currentRss then return
        API.markAllAsRead(@currentRss.source)
            .success ()=>
                sybil.hint "done"
                @emit "markAllAsRead"
                item = sybil.rssList.getListItemById @currentRss.id
                item.data.unreadCount = 0 
                item.init(item.data)
                for item in @items
                    item.markAsRead()
            .fail ()->
                sybil.error "fail to mark all as read"
    onClickMoreButton:()->
        if not @currentRss or not @currentRss.source
            return
        API.feed(@currentRss.source,@count,@items.length,@type) 
            .success (data)=>
                if data.drain
                    @drain()
                for item in data.feeds
                    item.rss = @currentRss
                    @appendFeed(item)
            .fail (error)=>
                sybil.error error
                console.error error
    onClickUnsubscribeButton:()->
        if not @currentRss
            # fail silently since it's not like
            # to happen when everything goes well
            return
        API.unsubscribe(@currentRss.source)
            .success (data)=>
                sybil.hint "done unsubscribe #{@currentRss.source}"
            .fail (data)=>
                sybil.error "fail to unsubscribe #{@currentRss.source}"
        
    onScroll:()->
        
    more:()->
        id = @currentRss.id
        if @isDrain
            return
        if not @currentRss
            return
        API.feed(@currentRss.source,@count,@items.length,@type)
            .success (data)=>
                if id isnt @currentRss.id
                    # change to an new rss
                    return
                if @items.length is 0
                    @UI.listContainer$.empty()
                if data.drain
                    @drain()
                for item in data.feeds
                    item.rss = @currentRss
                    @appendFeed(item)
            .fail (err)->
                console.error err
                console.error "fail to load feeds",@currentRss.source
    feedInView:(feed)->
    drain:()->
        @isDrain = true
        console.log @items.length
        if @items.length is 0
            @UI.listContainer$.text("no more")
    undrain:()->
        @isDrain = false
        
window.FeedList = FeedList