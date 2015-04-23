App = require "/app"
App.on "structureReady",()->
    lastSceneName = App.userConfig.get("lastScene") or "source scene"
    App.sceneSwitcher.on "sceneChange",(scene)->
        App.userConfig.set "lastScene",scene.name
    try
        App.sceneSwitcher.switchTo lastSceneName
    catch e
        App.sceneSwitcher.switchTo "source scene"
