class RssList extends Leaf.Widget
    constructor:()->
        super sybil.templates["rss-list"]
        @items = []
        sybil.preferenceManager.watch "hideEmptyRss",(value)=>
            if value 
                @node$.addClass("hide-empty-rss")
            else
                @node$.removeClass("hide-empty-rss")
    toggleEmptyRss:()->
        sybil.preferenceManager.toggle("hideEmptyRss")
    focus:(id)->
        for item in @items
            if item.data.id is id
                item.focus()
                return
    ListItem:class RssListItem extends Leaf.Widget
        constructor:(data,parent)->
            super(sybil.templates["rss-list-item"])
            @parent = parent
            @init(data);
            @appendTo @parent.UI.listContainer
        init:(data)->
            @data = data
            @UI.name$.text(data.title or "anonymous")
            @UI.count$.text data.unreadCount or 0
            if data.unreadCount is 0
                @node$.addClass "empty"
        remove:()->
            super()
            @parent.items = @parent.item.filter (item)=>item!= this
        onClickNode:()->
            sybil.router.goto "/rss/#{@data.id.escapeBase64()}"
        focus:()->
            for item in @parent.items
                item.unfocus()
            @node$.addClass("focus")
            @parent.currentFocusedItem = this
        unfocus:()->
            @node$.removeClass("focus")
    landing:()->
        @sync ()=>
            @emit "firstSync"
    addRss:(data)->
        @items.push new RssListItem data,this
    getListItemById:(id)->
        for item in @items
            if item.data.id == id
                return item
        return null
    getRssById:(id,callback)->
        for item in @items
            if item.data.id == id
                return callback null,item.data
        
        # may be we should use a sync flag(date)
        # to check if we need to update
        @sync (err)=>
            if err
                callback new Error "not found"
            for item in @items
                if item.data.id == id
                    return callback null,item.data
            callback new Error "not found"
        return 
    onClickSubscribeButton:()->
        rssUrl = @UI.rssInput.value
        API.subscribe(rssUrl)
            .success (data)=>
                sybil.hint "done"
                @sync()
    gotoNextUnreadRss:()->
        if not @currentFocusedItem
            start = -1
        else
            start = @items.indexOf @currentFocusedItem
        for item,index in @items
            if index > start and item.data.unreadCount > 0
                item.onClickNode()
                break
                
    sync:(callback)->
        @syncCallbacks = @syncCallbacks or []
        if callback
            @syncCallbacks.push callback
        API.rss()
            .success (rsses)=>
                for item in rsses
                    @addRss item
                if not sybil.feedList.currentRss and @items[0]
                    sybil.router.goto "/rss/#{@items[0].data.id.escapeBase64()}"
                    for _callback in @syncCallbacks
                        _callback(null,rsses)
            .fail (err)->
                console.error err
                console.error "fail to get rss list"
                callback err
window.RssList = RssList