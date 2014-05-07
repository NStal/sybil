EventEmitter = require("eventex").EventEmitter;
class Manager extends EventEmitter
    constructor:(@lord)->
        super()
        @connections = []
        @providers = []
    addConnectionProvider:(provider)->
        @providers.push provider
        provider.listenBy this,"connection",(connection)=>
            @emit "connection/incoming",connection
    removeConnectionProvider:(provider)->
        return @providers.some (target,index)=>
            if target is provider
                provider.stopListenBy this
                @providers.splice(index,1)
                return true
            return false
    getConnectionProviderByAddress:(address)->
        for provider in @providers
            if provider.testAddress address
                return provider
        return null
    createConnection:(address,callback)->
        provider = @getConnectionProviderByAddress address
        if not provider
            callback new Error "invalid address"
            return
        provider.createConnection address,callback
module.exports = Manager;
