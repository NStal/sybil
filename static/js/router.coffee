class Router extends Leaf.Router
    constructor:()->
        super()
        @monitorHash()
        @add "/rss/:id",(info)->
            sybil.feedList.goto info.params.id.unescapeBase64()
        @stack = []
    goto:(hash)->
        @stack.push window.location.hash
        window.location.hash = hash
    goback:()->
        @window.location.hash = @stack.pop()
window.Router = Router