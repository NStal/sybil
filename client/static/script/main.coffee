# the general bootstrap processes are
# 1. Load required html template(or js if needed)
# 2. Build scenes and init  other componenets
# 3. Connect to the sybil websocket API
# 3.5 (app ready)
# 4. Sync the required data like source/list/nodes

App = require("/app")
window.App = App
App.Errors = require "/common/errors"
App.Model = require "/common/model"

ImageLoader = require "/component/imageLoader"

Scene = require "/view/base/scene"
SceneSwitcher = require "/view/sceneSwitcher"
AddSourcePopup = require "/view/sourceUtil/addSourcePopup"
SourceScene = require "/view/sourceScene/scene"
ListScene = require "/view/listScene/scene"
OfflineHinter = require "/view/offlineHinter"
SmartImage = require "/widget/smartImage"
HintStack = require "/view/hintStack"
Toaster = require "/view/toaster"
ImageDisplayer = require "/view/imageDisplayer"
History = require "/common/history"
BackButtonChecker = require "/component/backButtonChecker"

require "/etc/enhancement"

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
            $(".landing").remove()
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

App.history = new History({debug:true})
App.backButton = new BackButtonChecker(App.history)
App.imageLoader = new ImageLoader()
SmartImage.setLoader App.imageLoader
App.init = ()->
    # public components
    App.history.active()
    App.history.goto(window.location.toString())
    App.sceneSwitcher = new SceneSwitcher()
    App.sceneSwitcher.prependTo document.body
    App.imageDisplayer = new ImageDisplayer()

    # scenes
    App.addSourcePopup = new AddSourcePopup()
    App.addSourcePopup.appendTo document.body
    App.offlineHinter = new OfflineHinter()
    App.sourceScene = new SourceScene()
    App.listScene = new ListScene()
    App.hintStack = new HintStack()

    # Should hide all scene by default
    # The reason I don't do this in style sheet
    # is that some scenes need to be display:flex;
    # So if I set display:none in style sheet
    # I won't be able to know who need to be display:flex;
    for scene in Scene.scenes
        scene.hide()

    App.sceneSwitcher.switchTo "source scene"
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

App.templateManager = require("/common/templateManager")
App.tm = App.templateManager
App.messageCenter = new (require "/component/messageCenter")
App.mc = App.messageCenter
App.connectionManager = new (require "/facility/connectionManager")
App.userConfig = new (require "/facility/userConfig")
App.modelSyncManager = new (require "/facility/modelSyncManager")


$ ()->
    if $(window).width() < 700
        App.isMobile = true
    console.log "script load complete version #{window.SybilMainContext.version}"
    App.templateManager.start()
    console.debug "start tm"
    App.templateManager.on "ready",(templates)->
        App.templates = templates
        App.init()
    require "/etc/test"
