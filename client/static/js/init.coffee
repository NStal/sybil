loader = new LeafRequire.BestPractice({
    localStoragePrefix:"SybilLeafRequire"
    ,config:"./require.json"
    ,showDebugInfo:true
    ,debug:window.location.toString().indexOf("debug")>0
    # the first module to run after load
    ,entry:"main"
})
loader.run()
window.SybilMainContext = loader.context
