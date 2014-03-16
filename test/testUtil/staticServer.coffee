express = require("express")
app = express()
app.use "/",express.static(__dirname+"/asset/")
exports.listen = (port = 9019)->
    app.listen(port)

if not module.parent
    exports.listen(9019)