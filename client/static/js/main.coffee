# the general bootstrap processes are
# 1. Load required html template(or js if needed)
# 2. Build views and init  other componenets
# 3. Connect to the sybil websocket API
# 3.5 (app ready)
# 4. Sync the required data like source/list/nodes
#
    
window.App = new Leaf.EventEmitter()
App.messageCenter = new MessageCenter()
App.templateManager = new Leaf.TemplateManager()
App.templateManager.use "archive-list"
        ,"archive-list-item"
        ,"source-list"
        ,"source-list-folder"
        ,"source-list-item"
        ,"add-source-popup"
        ,"read-later-list"
        ,"read-later-list-item"
        ,"tag-list"
        ,"tag-list-item"
        ,"tag-archive-list"
        ,"custom-source-list"
        ,"custom-archive-list"
        ,"custom-group-item"
        ,"custom-source-item"
        ,"custom-tag-item"
        ,"tag-selector"
        ,"source-selector"
        ,"context-menu"
        ,"context-menu-item"
        ,"archive-filter"
        ,"archive-filter-condition"
        ,"search-list"
        ,"search-list-item"
        ,"archive-displayer"
        ,"list-view-list"
        ,"list-view-list-item"
        ,"list-view-archive-list"
        ,"list-view-archive-list-item"
        ,"p2p-node-item"
        ,"p2p-node-list-item"
        ,"p2p-list"
        ,"p2p-node-info-displayer"
        ,"source-detail"
        ,"int-entry"
        ,"string-entry"

$ ()->
    App.templateManager.start()
    App.templateManager.on "ready",(templates)->
        App.templates = templates
        App.init()
App.connect = ()->
    @connectManager.start()
    @connectManager.ready ()=>
        @emit "connect"
    @connectManager.on "connect",()=>
        @messageCenter.setConnection(@connectManager.connection)
    @connectManager.on "disconnect",()=>
        @messageCenter.unsetConnection()
App.init = ()->
    # public components
    App.userConfig = new UserConfig()
    
    App.connectManager = new ConnectManager()
    # views 
    App.addSourcePopup = new AddSourcePopup()
    App.addSourcePopup.appendTo document.body
    
    App.sourceView = new SourceView()
    #App.tagView = new TagView()
    #App.customView = new CustomView()
    App.listView = new ListView()
    App.searchView = new SearchView()
    App.p2pView = new P2pView()
    App.viewSwitcher = new ViewSwitcher()
    App.offlineHinter = new OfflineHinter()
    App.settingPanel = new SettingPanel()
    #App.tagSelector = new TagSelector()
    #App.sourceSelector = new SourceSelector()
    #App.tagSelector.appendTo document.body
    #App.sourceSelector.appendTo document.body
    
    # Should hide all view by default
    # The reason I don't do this in style sheet
    # is that some views need to be display:flex;
    # So if I set display:none in style sheet
    # I won't be able to know who need to be display:flex;
    Model.initEventListener()
    for view in View.views
        console.debug "view:::",view,View.views
        view.hide()
    
    App.viewSwitcher.switchTo "source view"
    App.emit "structureReady"
    App.connect()  
App.showHint = (str)->
    alert str
App.showError = (str)->
    alert str
App.confirm = (str,callback)->
    if confirm(str)
        callback true
    else
        callback false

# local user UI config to remember the user settings for thing like last view I used
# , should I use image proxy, should I expand archives or what ever that effects only the user UI.
# We don't save these data to database now, only preserved at front end.
class ConnectManager extends Leaf.EventEmitter
    constructor:(address)->
        super()
        @connectInterval = 1000
        @connection = new ServerConnection()
        @connection.on "connect",()=>
            @emit "connect"
        @connection.on "disconnect",()=>
            @emit "disconnect"
            console.debug "reconnect"
            setTimeout @connection.reconnect.bind(@connection),500
    ready:(args...)->
        @connection.ready.apply @connection,args
    start:()->
        if window.location.protocol is "https:"
            wsProtocol = "wss:"
        else
            wsProtocol = "ws:"

        @connection.connect("#{wsProtocol}//#{window.location.hostname}:#{window.location.port}#{window.location.pathname}")

class UserConfig extends Leaf.EventEmitter
    constructor:(name = "userConfig")->
        super()
        @name = name
        if not localStorage
            @data = {}
            return
        @data = JSON.parse(localStorage.getItem(@name) or "{}")
    get:(key,value)->
        if typeof @data[key] is "undefined"
            return value
        return @data[key]
    set:(key,value)->
        @emit "change/#{key}",value
        @data[key] = value
        if localStorage
            localStorage.setItem(@name,JSON.stringify(@data))
    init:(key,value)->
        if typeof @data[key] isnt "undefined"
            return
        @set(key,value)

