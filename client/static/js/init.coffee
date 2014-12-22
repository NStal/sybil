
context = new LeafRequire()
context.setConfig "./require.json",(err)->
    if err
        throw err
    if window.location.toString().indexOf("?debug") > 0
        context.debug = true
        context.enableCache = false
    context.load ()->
        console.log "sybil loaded at version #{context.version}"
window.SybilMainContext = context
                
#context.debug = true
#context.enableCache = false
#context.version = "0.0.3"
#if context.version isnt context.getLastVersion()
#    console.debug "version update from",context.getLastVersion(),"to",context.version
#    console.debug "clear caches"
#    requireUpdate = true
#    context.clearCache()
## disable caches for debug mode
#if window.location.toString().indexOf("?debug")>0
#    context.debug = true
#    context.enableCache = false
#    context.clearCache()
## third party library
#context.use "lib/async.js"
#    ,"lib/lodash.js"
#    ,"lib/moment.js"
## common utils
#context.use "util/messageCenter.js"
#    ,"util/serverConnection.js"
#    ,"util/dragContext.js"
#    ,"util/swipeChecker.js"
#    ,"util/scrollChecker.js"
## global
#context.use "app.js"
#    ,"main.js"
#    ,"templateManager.js"
#    ,"connectionManager.js"
## procedures
#context.use "procedure/endlessArchiveLoader.js"
#    ,"procedure/endlessSearchArchiveLoader.js"
## base widget
#context.use "view.js"
#    ,"widget/contextMenu.js"
#    ,"widget/popup.js"
## widget 
#context.use "userConfig.js"
#    ,"persistentDataStore.js"
#    ,"addSourcePopup.js"
#    ,"sourceView.js"
#    ,"sourceList.js"
#    ,"archiveList.js"
#    ,"sourceDetail.js"
#    ,"archiveDisplayer.js"
#    ,"listView.js"
#    ,"searchView.js"
#    ,"offlineHinter.js"
#    ,"settingPanel.js"
#    ,"enhancement.js"
#    ,"sourceUtil/subscribeAssistant.js"
#    ,"sourceUtil/adapterTerminal.js"
#    ,"sourceUtil/sourceAuthorizeTerminal.js"
#    ,"hintStack.js"
## datas
#context.use "model.js"
#    ,"modelSyncManager.js"
#    ,"i18n.js"
#
## tests
#context.use "test.js"
#
#context.load ()->
#    console.log "loaded"
#    App = context.require("app")
#    App.requireUpdate = requireUpdate
#    context.require "main
