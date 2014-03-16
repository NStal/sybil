window.exports = {}
String.prototype.escapeBase64 = ()->
    return this.replace(/\//,"*")
String.prototype.unescapeBase64 = ()->
    return this.replace(/\*/,"/")
$ ->
    window.sybil = new Sybil;
window.Plugins = []
class Sybil extends Leaf.Widget
    constructor:()->
        @rssArr = []
        @feeds = {}
        @plugins = []
        @km = new Leaf.KeyEventManager()
        @km.attachTo window
        @km.master()
        @km.on "keydown",(e)=>
            if e.which is Leaf.Key.n and e.altKey
                @rssList.gotoNextUnreadRss()
                e.capture()
                return
            if e.which is Leaf.Key.h and e.altKey
                @rssList.toggleEmptyRss()
                e.capture()
                return
        window.TemplateManager = new Leaf.TemplateManager()
        window.TemplateManager.use "rss-list","rss-list-item","feed-list","feed-list-item"
        window.TemplateManager.on "ready",(templates)=>
            @templates = templates
            @init()
            super(document.body)
            @loadPlugins()
            
            @router.applyRouteByHash()
        window.TemplateManager.start()
    init:()->
        
        @preferenceManager = new PreferenceManager()
        @router = new Router()
        @rssList = new RssList()
        @feedList = new FeedList()
        @rssList.landing()
        @common = exports
    loadPlugins:()->
        for plugin in Plugins
            p = new plugin()
            if p.load then p.load()
            @plugins.push p
            
    unloadPlugins:()->
        for plugin in @plugins
            if plugin.unload
                plugin.unload()
    hint:(text)->
        alert text