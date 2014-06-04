# the general bootstrap processes are
# 1. Load required html template(or js if needed)
# 2. Build views and init  other componenets
# 3. Connect to the sybil websocket API
# 3.5 (app ready)
# 4. Sync the required data like source/list/nodes
#
View = require "view"
ViewSwitcher = View.ViewSwitcher
AddSourcePopup = require "addSourcePopup"
SourceView = require "sourceView"
ListView = require "listView"
SearchView = require "searchView"
OfflineHinter = require "offlineHinter"
SettingPanel = require "settingPanel"
App = require("./app")


require "enhancement"

App.connect = ()->
    @messageCenter.on "error",(e)=>
        console.error e
        console.error e.stack
    @connectionManager.start()
    @connectionManager.ready ()=>
        App.initialLoaded = true
        @emit "connect"
        setTimeout (()=>
            $(".landing").addClass("hide");
        ),200
        setTimeout (()=>
            $(".landing").hide()
        ),1000
    @connectionManager.on "connect",()=>
        @messageCenter.setConnection(@connectionManager.connection)
    @connectionManager.on "disconnect",()=>
        @messageCenter.unsetConnection()
App.initialLoad = (callback)->
    if @initialLoaded
        callback()
    else
        @once "connect",callback
App.init = ()->
    # public components

    
    App.viewSwitcher = new ViewSwitcher()
    
    # views 
    App.addSourcePopup = new AddSourcePopup()
    App.addSourcePopup.appendTo document.body
    App.offlineHinter = new OfflineHinter()
    App.settingPanel = new SettingPanel()
            
    App.sourceView = new SourceView()
    App.listView = new ListView()
    App.searchView = new SearchView()
#    App.p2pView = new P2pView()
#    App.offlineHinter = new OfflineHinter()

    #App.tagSelector = new TagSelector()
    #App.sourceSelector = new SourceSelector()
    #App.tagSelector.appendTo document.body
    #App.sourceSelector.appendTo document.body
    
    # Should hide all view by default
    # The reason I don't do this in style sheet
    # is that some views need to be display:flex;
    # So if I set display:none in style sheet
    # I won't be able to know who need to be display:flex;
    for view in View.views
        view.hide()
    
    App.viewSwitcher.switchTo "source view"
    App.emit "structureReady"
    App.connect()
App.showHint = (str)->
    console.log "HINT:",str
    alert str
App.showError = (str)->
    console.error str
    return
    alert str
App.confirm = (str,callback)->
    if confirm(str)
        callback true
    else
        callback false

App.templateManager = require("templateManager")
App.messageCenter = new (require "util/messageCenter")
App.connectionManager = new (require "connectionManager")
App.persistentDataStoreManager = new (require "persistentDataStore").Manager()
App.userConfig = new (require "userConfig")
App.modelSyncManager = new (require "modelSyncManager")


$ ()->
    App.templateManager.start()
    App.templateManager.on "ready",(templates)->
        App.templates = templates
        App.init()
    
    require "test"