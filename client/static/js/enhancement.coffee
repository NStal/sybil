App.on "structureReady",()->
    lastViewName = App.userConfig.get("lastView") or "source view"
    App.viewSwitcher.on "viewChange",(view)->
        App.userConfig.set "lastView",view.name
    try
        App.viewSwitcher.switchTo lastViewName
    catch e
        App.viewSwitcher.switchTo "source view"
        