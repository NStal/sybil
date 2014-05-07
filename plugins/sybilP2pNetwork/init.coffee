Lord = require("./network/lord.coffee");
KadDomain = require("./network/kad/domain.coffee")
# this file will contains many hard code init and config
# intepreting logic, don't mind if code get nesty.
class SybilNetwork extends Lord
    constructor:(@key,option = {})->
        super @key
        @kadDomain = new KadDomain()
        @addDomain @kadDomain
        