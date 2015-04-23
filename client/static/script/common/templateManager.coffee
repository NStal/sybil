tm = new Leaf.TemplateManager()
module.exports = tm
if window.location.toString().indexOf("?debug") > 0
    tm.enableCache = false
else
    tm.enableCache = true
#if App.requireUpdate
#    alert "clearAppTemplateCache"
#tm.clearCache()
