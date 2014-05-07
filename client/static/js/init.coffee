context = new LeafRequire({root:"./js/"})
context.debug = true
context.enableCache = true
context.version = "0.0.1"
# disable caches for debug mode
if window.location.toString().indexOf("?debug")>0
    context.debug = true
    context.enableCache = false
    context.clearCache()
# third party library
context.use "lib/async.js"
    ,"lib/lodash.js"
    ,"lib/moment.js"
# common utils
context.use "util/messageCenter.js"
    ,"util/serverConnection.js"
    ,"util/dragContext.js"
    ,"util/swipeChecker.js"
    ,"util/scrollChecker.js"
# global
context.use "app.js"
    ,"main.js"
    ,"templateManager.js"
    ,"connectionManager.js"
# procedures
context.use "procedure/endlessArchiveLoader.js"
    ,"procedure/endlessSearchArchiveLoader.js"
# base widget
context.use "view.js"
    ,"widget/contextMenu.js"
    ,"widget/popup.js"
# widget 
context.use "userConfig.js"
    ,"persistentDataStore.js"
    ,"addSourcePopup.js"
    ,"sourceView.js"
    ,"sourceList.js"
    ,"archiveList.js"
    ,"sourceDetail.js"
    ,"archiveDisplayer.js"
    ,"listView.js"
    ,"searchView.js"
    ,"offlineHinter.js" 
    ,"settingPanel.js"
    ,"enhancement.js"
# datas
context.use "model.js"
    ,"modelSyncManager.js"
    ,"i18n.js"

# tests
context.use "test.js"
context.load ()->
    console.log "loaded"
    context.require "main"