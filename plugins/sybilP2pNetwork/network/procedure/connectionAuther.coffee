# RPCs:
# getAuthToken {key:publick pem} return {code:code to sign}
# auth         {signature:signed buffer}
#
EventEmitter = require("eventex").EventEmitter
PublicKey = require("../key").PublicKey
class ConnectionAuther extends EventEmitter
    # auth connection and setup verifed publickeys for the connection
    constructor:(@lord,@connection,option = {})->
        super()
        @key = @lord.key
        @confirmed = false
        @acknowledged = false
        @connection.listenBy this,"close",@disconnect
        @connection.messageCenter.registerApi "getAuthToken",@getAuthToken.bind(this)
        @connection.messageCenter.registerApi "auth",@auth.bind(this)
        @disconnectTime = option.timeout or 1000 * 30
        @_disconnectTimer = setTimeout @disconnect.bind(this),@disconnectTime
        # if the connection is private and should't share with
        @private = false
        # code to verify by remote
        @code = null
        @isReady = false
    _checkState:()->
        if @confirmed and @acknowledged and not @_done
            @isReady = true
            @_done = true
            @emit "auth",@connection
            @end()
    gainTrust:(callback = ()->true )->
        @key.getPublicPEM (err,pem)=>
            if err
                @lastError = err
                callback err
                return
            @connection.messageCenter.invoke "getAuthToken",{key:pem,private:@private},(err,info)=>
                if err
                    @lastError = err
                    callback err
                    @disconnect()
                    return
                @key.sign new Buffer(info.code),(err,buffer)=>
                    if err
                        @lastError = err
                        callback err
                        @disconnect()
                        return
                    @connection.messageCenter.invoke "auth",{signature:buffer,private:@private},(err)=>
                        if err
                            @lastError = err
                            callback err
                            @disconnect()
                            return
                        @acknowledged = true
                        @_checkState()
    auth:(info = {},callback)->
        if @confirmed
            callback()
            return
        if not @code or not @unverifiedPublicKey
            callback "no publick and code"
            @disconnect()
            return
        if not info.signature or not Buffer.isBuffer info.signature
            callback "invalid request"
            @disconnect()
            return
        @unverifiedPublicKey.verify new Buffer(@code),info.signature,(err,result)=>
            if err or not result
                callback "invalid signature"
                @disconnect()
                return
            @confirmed = true
            # now verified
            @connection.private = info.private or false
            @connection.publicKey = @unverifiedPublicKey
            @_checkState()
            callback()

    getAuthToken:(info = {},callback)->
        if @confirmed
            callback "authed"
            @disconnect()
            return
        if not info.key
            callback "invalid public key"
            @disconnect()
            return
        if not @code
            @code = Math.random().toString().substring(2)
        PublicKey.fromPEM info.key,(err,puk)=>
            if err
                callback "invalid public key"
                return
            @unverifiedPublicKey = puk
            @key.getPublicKey (err,myPuk)=>
                if err
                    callback "server error"
                    @disconnect()
                    return
                if myPuk.equal puk
                    callback "self"
                    @disconnect()
                    return
                callback null,{code:@code}
    disconnect:()->
        if @isDisconnect
            return
        @isDisconnect = true
        @connection.close()
        @end()
    end:()->
        if @isEnd
            return

        @isEnd = true
        @emit "end"
        if @connection
            @connection.stopListenBy this
        clearTimeout @_disconnectTimer
module.exports = ConnectionAuther
