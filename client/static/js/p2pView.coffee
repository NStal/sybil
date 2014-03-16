class P2pView extends View
    constructor:()-> 
        console.debug "@#"
        @p2pList = new P2pList()
        @p2pNodeInfoDisplayer = new P2pNodeInfoDisplayer()
        @p2pFriendInfoDisplayer = new P2pFriendInfoDisplayer()
        @p2pNodeInfoDisplayer.hide()
        @p2pFriendInfoDisplayer.hide()
        super($(".p2p-view")[0],"p2p view")
        @p2pList.on "select",(node)=>
            if node instanceof Model.P2pNode
                @p2pNodeInfoDisplayer.setNode(node)
                @p2pNodeInfoDisplayer.show()
                @p2pFriendInfoDisplayer.hide()
            else if node instanceof Model.Friend
                @p2pFriendInfoDisplayer.setNode(node)
                @p2pNodeInfoDisplayer.hide()
                @p2pFriendInfoDisplayer.show()
        
class P2pList extends Leaf.Widget
    constructor:()->
        super App.templates["p2p-list"]
        @friendList = Leaf.Widget.makeList @UI.friendList
        @nodeList = Leaf.Widget.makeList @UI.nodeList
        Model.on "node/add",(node)=>
            @nodeList.push new P2pNodeListItem(node)
        Model.on "friend/add",(friend)=>
            @friendList.push new P2pFriendListItem(friend)
        @friendList.on "child/add",(friend)=>
            @attachFriend friend
        @nodeList.on "child/add",(node)=>
            @attachNode node
    attachFriend:(friend)->
        friend.on "select",()=>
            if @currentSelect
                @currentSelect.node$.removeClass "select"
            @currentSelect = friend
            @currentSelect.node$.addClass "select"
            @emit "select",friend.friend
        friend.on "remove",()=>
            @friendList.removeItem friend
    attachNode:(node)->
        node.on "select",()=>
            if @currentSelect
                @currentSelect.node$.removeClass "select"
            @currentSelect = node
            @currentSelect.node$.addClass "select"
            @emit "select",node.p2pNode
        node.on "remove",()=>
            @nodeList.removeItem node
            
class P2pNodeListItem extends Leaf.Widget
    constructor:(@p2pNode)->
        super App.templates["p2p-node-list-item"]
        @render()
        @contextSelections = [
            {
                name:"add friend"
                ,callback:()=>
                    if not confirm("add as friend")
                        return
                    Model.Friend.addFriendFromNode(@p2pNode)
            }
        ]

        @node.oncontextmenu = (e)=>
            e.preventDefault()
            ContextMenu.showByEvent e,@contextSelections
        @p2pNode.on "delete",()=>
            @emit "remove"
    onClickNode:()->
        @emit "select",@p2pNode
    render:()->
        avatar = "http://www.gravatar.com/avatar/#{@p2pNode.profile.emailHash}?s=18"
        if @UI.avatar$.attr("src") isnt avatar
            @UI.avatar$.attr("src",avatar)
        @UI.nickname$.text(@p2pNode.profile.nickname or "Unknown")
    
class P2pFriendListItem extends Leaf.Widget
    constructor:(@friend)->
        super App.templates["p2p-node-list-item"]
        @render()
        @contextSelections = [
            {
                name:"remove friend"
                ,callback:()=>
                    if not confirm "remove the friend"
                        return
                    @friend.remove (err)=>
                        if err
                            console.error err
                            return
                        @emit "remove"
            }
        ]
        @friend.on "online",@render.bind(this)
        @friend.on "offline",@render.bind(this)

        @node.oncontextmenu = (e)=>
            e.preventDefault()
            ContextMenu.showByEvent e,@contextSelections
    onClickNode:()->
        @emit "select",@friend
    render:()->
        avatar = "http://www.gravatar.com/avatar/#{@friend.emailHash}?s=18"
        if @UI.avatar$.attr("src") isnt avatar
            @UI.avatar$.attr("src",avatar)
        @UI.nickname$.text(@friend.nickname or "Unknown")
class InfoDisplayer extends Leaf.Widget
    constructor:()->
        super App.templates["p2p-node-info-displayer"]
        @archiveList = Leaf.Widget.makeList @UI.archiveList
        @archiveOffset = 0
        @archiveCount = 0
    setNode:(node)->
        @p2pNode = node
        @hash = node.keyHash or node.hash
        @render()
        @archiveOffset = 0
        @archiveCount = 0
        @clearArchive()
        @updateNodeArchive()
    clearArchive:()->
        @archiveList.length = 0
    updateNodeArchive:()->
        Model.Archive.getByShareHashes {hashes:[@hash],count:@archiveCount,offset:@archiveOffset},(err,archives)=>
            console.debug err,archives
            for archive in archives
                console.debug archive
                @archiveList.push new P2pArchiveListItem(archive)
    show:()->
        @node$.show()
    hide:()->
        @node$.hide()
class P2pNodeInfoDisplayer extends InfoDisplayer 
    constructor:()->
        super()
    render:()->
        @UI.publicKey$.text "public key:"+@p2pNode.publicKey.replace(/---.*---/ig,"")
class P2pFriendInfoDisplayer extends InfoDisplayer
    constructor:()->
        super()
    setNode:(node)->
        super(node)
        node.on "online",@render.bind this
        node.on "offline",@render.bind this
    render:()->
        avatar = "http://www.gravatar.com/avatar/#{@p2pNode.emailHash}?s=72"
        if @UI.avatar$.attr("src") isnt avatar
            @UI.avatar$.attr("src",avatar)
        @UI.publicKey$.text "public key: "+@p2pNode.publicKey.replace(/---.*---/ig,"")
        @UI.email$.text  "email: "+@p2pNode.email
        @UI.nickname$.text  "nickname: "+@p2pNode.nickname
        console.log "rendering!"
        @UI.status$.text "status: "+(@p2pNode.status or "offline")
    
class P2pArchiveListItem extends ArchiveListItem
    constructor:(@archive)->
        super @archive
        @setArchive @archive

window.P2pView = P2pView