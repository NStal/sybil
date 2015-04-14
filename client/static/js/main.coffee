# the general bootstrap processes are
# 1. Load required html template(or js if needed)
# 2. Build views and init  other componenets
# 3. Connect to the sybil websocket API
# 3.5 (app ready)
# 4. Sync the required data like source/list/nodes

App = require("./app")
App.lastVersion = window.localStorage.getItem("sybilVersion") or "0.0.0"
if App.lastVersion isnt window.SybilMainContext.version
    App.requireUpdate = true
    App.lastVersion = window.SybilMainContext.version
    window.localStorage.setItem("sybilVersion",App.lastVersion or "0.0.0")

window.App = App


ImageLoader = require "/util/imageLoader"
SmartImage = require "/widget/smartImage"

View = require "view"
ViewSwitcher = View.ViewSwitcher
AddSourcePopup = require "sourceUtil/addSourcePopup"
SourceView = require "sourceView/sourceView"
ListView = require "listView/listView"
SearchView = require "searchView/searchView"
OfflineHinter = require "offlineHinter"
SettingPanel = require "settingPanel"
HintStack = require "hintStack"
Toaster = require "/view/toaster"



require "/enhancement"

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
App.afterInitialLoad = (callback)->
    if @initialLoaded
        callback()
    else
        @once "connect",callback
App.init = ()->
    # public components
    App.viewSwitcher = new ViewSwitcher()
    App.imageLoader = new ImageLoader()
    SmartImage.setLoader App.imageLoader

    # views
    App.addSourcePopup = new AddSourcePopup()
    App.addSourcePopup.appendTo document.body
    App.offlineHinter = new OfflineHinter()
#    App.settingPanel = new SettingPanel()

    App.sourceView = new SourceView()
    App.listView = new ListView()
    App.searchView = new SearchView()
    App.hintStack = new HintStack()
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

App.toast = (str)->
    if not @toaster
        @toaster = new Toaster()
        @toaster.appendTo document.body
    @toaster.show str



App.confirm = (str,callback)->
    if confirm(str)
        callback true
    else
        callback false

App.templateManager = require("templateManager")
App.tm = App.templateManager
App.messageCenter = new (require "util/messageCenter")
App.mc = App.messageCenter
App.connectionManager = new (require "connectionManager")
App.persistentDataStoreManager = new (require "persistentDataStore").Manager()
App.userConfig = new (require "userConfig")
App.modelSyncManager = new (require "modelSyncManager")


$ ()->
    if $(window).width() < 700
        App.isMobile = true
    console.log "script load complete version #{window.SybilMainContext.version}"
    App.templateManager.start()
    console.debug "start tm"
    App.templateManager.on "ready",(templates)->
        App.templates = templates
        App.init()
    require "test"
