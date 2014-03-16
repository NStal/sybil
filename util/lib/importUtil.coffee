ws = require "ws"
WebSocket = ws
MessageCenter = (require "message-center").MessageCenter;
class Folder
    constructor:(data)->
        if typeof data is "string"
            @data = {name:data,children:[]}
        else
            @data = data
        if not data
            throw "folder data can't be undefined"
        @children = []
        for child in (@data.children or [])
            @children.push new Source(child)
        @name = @data.name
        @type = "folder"
        @collapse = @data.collapse or true
    toJSON:()->
        return {name:@name,children:(@children.map (child)->child.toJSON()),type:"folder",collapse:@collapse}
    add:(source)->
        if not (source instanceof Source)
            throw "invalid source add to folder"
        @children.push source
        source.parent = this
class Source
    constructor:(sourceInfo)->
        if not sourceInfo
            throw "invalid source info"
        @data = sourceInfo
        @guid = sourceInfo.guid
    toJSON:()->
        return @data

class WebApiInterface extends require("events").EventEmitter
    constructor:(port = 3007,host = "localhost")->
        @messageCenter = new MessageCenter()
        @port = port
        @host = host
        @isClose = true
    connect:(port = @port,host = @host)->
        if @connection
            @connection.close()
        @connection = new ws("ws://#{@host}:#{@port}/")
        @connection.on "open",()=>
            @messageCenter.setConnection @connection
            @emit "ready"
            @isClose = false
        @connection.on "error",()=>
            @close()
        @connection.on "close",()=>
            @close()
    close:()->
        if @isClose
            return
        @isClose = true
        if @connection
            @connection.removeAllListeners()
        @messageCenter.unsetConnection()
        @connection.close()
        @connection = null
        @emit "close"
exports.WebApiInterface = WebApiInterface
exports.Source = Source
exports.Folder = Folder
if not module.parent
    inf = new WebApiInterface(3007)
    inf.connect()
    inf.on "ready",()->
        inf.messageCenter.invoke "getConfig","sourceFolderConfig",(err,sources)->
            console.log err,sources