EventEmitter = require("eventex").EventEmitter
MessageCenter = require("message-center")
# Event:
# destroy: Channel is shutdown and all connection to node are lost
# 
class Node extends EventEmitter
    constructor:(@lord,@key,option = {})->
        super()
        # how many domain are interest about this node
        @_ref = 0
        @createDate = new Date()
        @channel = new Channel(this,option.connections or [])
        @bubble @channel,"close"
        # used to store domainInfos
        # every domain should use it's own namespace like
        # @domainInfo.kad.kadNode
        @domainInfo = {}
        @__defineGetter__ "state",()=>
            if @channel.isClose
                return "close"
            else
                return "open"
    close:()->
        @Channel.close()
    retain:()->
        @_ref += 1
    release:()->
        @_ref -= 1
    forceAddConnection:(connection)->
        # dont' check state
        # so this will force node to be open
        @channel.addConnection connection
    mergeConnection:(connection)->
        if @state is "close"
            return
        @channel.addConnection connection
        
class Channel extends EventEmitter
    constructor:(@node,connections)->
        super()
        @channelEventListeners = []
        @connections = connections
        @_updateChannelState()
    addConnection:(connection)->
        @connections.push connection
        @_attachConnection(connection)
        @_updateChannelState()
    removeConnection:(connection)->
        for item,index in @connections
            if item is connection
                @connections.splice index,1
                @_detachConnection(connection)
                @_updateChannelState()
                return
    _attachConnection:(connection)->
        connection.listenBy this,"close",@removeConnection
        connection.channel = this
        connection.node = @node
        for handler in @channelEventListeners
            connection.messageCenter.listenBy this,"event/"+handler.event,handler.callback
        for api in @channelApis
            connection.messageCenter.registerApi api.name,api.callback
    _detachConnection:(connection)->
        connection.messageCenter.stopListenBy this
        for api in @channelApis
            # monkey patch here
            # because current message center don't support unregisterApi
            if not connection.messageCenter.unregisterApi
                continue
            connection.messageCenter.unregisterApi api.name
        connection.stopListenBy this
        connection.channel = null
        connection.node = null
    _updateChannelState:()->
        if @connections.length is 0
            @close()
        else
            @isClose = false
    close:()->
        if @isClose
            return
        @isClose = true
        for connection in @connections
            connection.close()
        @connections = []
        @emit "close"
    getAddresses:()->
        results = []
        for connection in @connections
            if connection.addressString
                results.push connection.addressString
            else if connection.address
                results.push connection.address.toString()
            else
                continue
        return results
    pickAvailableConnection:()->
        # general strategy
        # * private connection won't be pickup
        # * passive connection will be choosed when no initiative connection available
        #   because initiative connection are more reliable since we may have chance to 
        #   recover
        # * earlier connection is prefered, since longer live time
        #   suggest that it will still remain alive which means more stable
        # 
        result = null
        for connection in @connections
            if connection.private
                continue
            if connection.isPassive and not result
                result = connection
            if not connection.isPassive
                return connection
        return result
    listenChannelEvent:(event,callback)->
        @channelEventListeners.push {event,callback}
        for connection in @connections
            connection.messageCenter.listenBy this,"event/"+event,callback
    registerApi:(name,callback)->
        @channelApis.push {name,callback}
        for connection in @connections
            connection.messageCenter.registerApi name,callback
module.exports = Node