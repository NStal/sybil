EventEmitter = (require "events").EventEmitter;
MessageCenter = require("message-center");
class Connection extends EventEmitter
    # Event: error(option),close,message (no open event)
    #  message:string (json string that match message center protocol)
    constructor:()->
        super()
        @createDate = new Date()
        
class Node extends EventEmitter
    @idleId = 1000000
    constructor:(connection)->
        # connection given should be opened
        super()
        @id = Node.idleId++
        @provider = null
        @reset()
        @data = {}
        @connection = connection
        @close = @close.bind(this);
        @connection.on "error",@close
        @connection.on "close",@close
        @address = @connection.address
        @messageCenter = new MessageCenter()
        @messageCenter.setConnection(@connection)
        @isClose = false
    getAddress:()->
        if @connection
            return @connection.address.toString()
        return null
    matchAddress:(address)->
        if @connection and @connection.address.toString() is address.toString()
            return true
        return false
    reset:()->
        # any domain that make use of the node should retain it
        # and should release it after end of use
        # node which has 0 refer will be cleanup when I reach any limit
        # like connection limit or memory limit
        @_referCounter = 0
        
        @publicKey = null
        @isAuthed = false
        @isClose = true
    retain:()->
        @_referCounter++
    release:()->
        @_referCounter--
    close:()->
        if @isClose
            return
        @isClose = true
        @messageCenter.unsetConnection()
        @connection.close()
        @connection.removeListener("error",@close)
        @connection.removeListener("close",@close)
        @connection = null
        @emit "close"
        @removeAllListeners()
    setInfo:(key,value)->
        @data[key] = value
        return value
    getInfo:(key,defaultValue)->
        if typeof @data[key] is "undefined"
            return defaultValue
        return @data[key]
module.exports = Node
Node.Connection = Connection