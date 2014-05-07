EventEmitter = require("eventex").EventEmitter
MessageCenter = require("message-center")
# base class for connection providers
class Provider extends EventEmitter
    constructor:()->
        super()
    createConnection:(address,callback)->
        # Accept an specific URI can try to create a connection
        # from that URI, callback with an opened connection if
        # everything goes well, or an error.
        return
    testAddress:(address)->
        # Test if a address string can be used by this providers
        # in general, all provider should have they own scheme
        # in the <scheme:>//<auth>/<path> design.
        return false
    discover:()->
        # Try to open some random connections to expand the topology
        # discover will return error when we are already discovering things.
        # Discovered connections will be emit via 'incoming/connection' event.
        # 'incoming' hints that the connections are not build for specific reason

# base class for all address
# 
class Provider.Address
    # Accept a string of the address.
    # Return boolean to indicates weather the string can be parse
    # into the current address format.
    @test = (str)->
        return false
    # Accept a string and return a Address instance of current address
    # return null if an invalid string
    @parse = (str)->
        return null
    constructor:()->
        return
    # return a string the curren address object
    toString:()->
        throw new Error "not implemented"
        return

# Events
# 'message'
# 'close'
# 'error'
#
# there are not open message because any valid connection
# should be open at beginning and can be reconnection, but create
# from the provider by feeding the address again.
class Provider.Connection extends EventEmitter
    constructor:()->
        super()
        # if the connection is passive
        # if the connection is not passive
        # we should be able to have a this.addressString
        # and this.address accessible.
        @isPassive = true
        @address = null
        @addressString = null
        @messageCenter = new MessageCenter()
    send:(message)->
        # message should be string
        throw new Error "not implemented"
        return
    close:()->
        if @isClose
            return
        @isClose = true
        if @cleanup
            @cleanup()
        @emit "close",this
        return
    cleanup:()->
        throw new Error "not implemented"
        # cleanup underlying resource
        return
module.exports = Provider