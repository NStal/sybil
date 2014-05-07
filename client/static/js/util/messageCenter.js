// Generated by CoffeeScript 1.7.1
(function() {
  var Buffer, EventEmitter, MessageCenter, ReadableStream, WritableStream,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  Buffer = Buffer || Array;

  EventEmitter = Leaf.EventEmitter;

  MessageCenter = (function(_super) {
    __extends(MessageCenter, _super);

    MessageCenter.stringify = function(obj) {
      return JSON.stringify(this.normalize(obj));
    };

    MessageCenter.normalize = function(obj) {
      var item, prop, _;
      if (typeof obj !== "object") {
        return obj;
      }
      if (obj instanceof Array) {
        return (function() {
          var _i, _len, _results;
          _results = [];
          for (_i = 0, _len = obj.length; _i < _len; _i++) {
            item = obj[_i];
            _results.push(this.normalize(item));
          }
          return _results;
        }).call(this);
      }
      if (obj === null) {
        return null;
      } else if (obj instanceof Buffer) {
        return {
          __mc_type: "buffer",
          value: obj.toString("base64")
        };
      } else if (obj instanceof Date) {
        return {
          __mc_type: "date",
          value: obj.getTime()
        };
      } else if (obj instanceof WritableStream) {
        return {
          __mc_type: "stream",
          id: obj.id
        };
      } else {
        _ = {};
        for (prop in obj) {
          _[prop] = this.normalize(obj[prop]);
        }
        return _;
      }
    };

    MessageCenter.denormalize = function(obj, option) {
      var item, prop, _;
      if (option == null) {
        option = {};
      }
      if (typeof obj !== "object") {
        return obj;
      }
      if (obj === null) {
        return null;
      }
      if (obj instanceof Array) {
        return (function() {
          var _i, _len, _results;
          _results = [];
          for (_i = 0, _len = obj.length; _i < _len; _i++) {
            item = obj[_i];
            _results.push(this.denormalize(item, option));
          }
          return _results;
        }).call(this);
      } else if (obj.__mc_type === "buffer") {
        return new Buffer(obj.value, "base64");
      } else if (obj.__mc_type === "date") {
        return new Date(obj.value);
      } else if (obj.__mc_type === "stream") {
        return new ReadableStream(option.owner);
      } else {
        _ = {};
        for (prop in obj) {
          _[prop] = this.denormalize(obj[prop], option);
        }
        return _;
      }
    };

    MessageCenter.parse = function(str, option) {
      var json, _;
      json = JSON.parse(str);
      _ = this.denormalize(json, option);
      return _;
    };

    function MessageCenter() {
      this.idPool = 1000;
      this.invokeWaiters = [];
      this.apis = [];
      this.timeout = 1000 * 60;
      this.streams = [];
      MessageCenter.__super__.constructor.call(this);
    }

    MessageCenter.prototype.stringify = function(data) {
      return MessageCenter.stringify(data);
    };

    MessageCenter.prototype.getInvokeId = function() {
      return this.idPool++;
    };

    MessageCenter.prototype.registerApi = function(name, handler, overwrite) {
      var api, index, _i, _len, _ref;
      name = name.trim();
      if (!handler) {
        throw new Error("need handler to work");
      }
      _ref = this.apis;
      for (index = _i = 0, _len = _ref.length; _i < _len; index = ++_i) {
        api = _ref[index];
        if (api.name === name) {
          if (!overwrite) {
            throw new Error("duplicated api name " + name);
          } else {
            this.apis[index] = null;
          }
        }
      }
      this.apis = this.apis.filter(function(api) {
        return api;
      });
      return this.apis.push({
        name: name,
        handler: handler
      });
    };

    MessageCenter.prototype.setConnection = function(connection) {
      this.connection = connection;
      this._handler = (function(_this) {
        return function(message) {
          if (_this.connection !== connection) {
            return;
          }
          return _this.handleMessage(message);
        };
      })(this);
      return this.connection.on("message", this._handler);
    };

    MessageCenter.prototype.unsetConnection = function() {
      var stream, _i, _len, _ref;
      if (this.connection) {
        this.connection.removeListener("message", this._handler);
      }
      this._handler = null;
      this.connection = null;
      _ref = this.streams.slice();
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        stream = _ref[_i];
        stream.close();
      }
      this.emit("unsetConnection");
      return this.clearAll();
    };

    MessageCenter.prototype.response = function(id, err, data) {
      var e, message;
      message = this.stringify({
        id: id,
        type: "response",
        data: data,
        error: err
      });
      if (!this.connection) {
        return;
      }
      try {
        return this.connection.send(message);
      } catch (_error) {
        e = _error;
      }
    };

    MessageCenter.prototype.invoke = function(name, data, callback) {
      var controller, e, message, req, waiter;
      callback = callback || function() {
        return true;
      };
      req = {
        type: "invoke",
        id: this.getInvokeId(),
        name: name,
        data: data
      };
      waiter = {
        request: req,
        id: req.id,
        callback: callback,
        date: new Date
      };
      this.invokeWaiters.push(waiter);
      message = this.stringify(req);
      controller = {
        _timer: null,
        waiter: waiter,
        timeout: function(value) {
          if (this._timer) {
            clearTimeout(this._timer);
          }
          return this._timer = setTimeout(controller.clear, value);
        },
        clear: (function(_this) {
          return function(error) {
            return _this.clearInvokeWaiter(waiter.id, error || new Error("timeout"));
          };
        })(this)
      };
      waiter.controller = controller;
      controller.timeout(this.timeout);
      if (this.connection) {
        try {
          this.connection.send(message);
        } catch (_error) {
          e = _error;
          controller.clear(e);
          return;
        }
      } else {
        controller.clear(new Error("connection not set"));
      }
      return controller;
    };

    MessageCenter.prototype.fireEvent = function(name, data) {
      var e, message;
      message = this.stringify({
        type: "event",
        name: name,
        data: data
      });
      if (this.connection) {
        try {
          this.connection.send(message);
        } catch (_error) {
          e = _error;
          return message;
        }
      }
      return message;
    };

    MessageCenter.prototype.handleMessage = function(message) {
      var e, info, _ref;
      try {
        info = MessageCenter.parse(message, {
          owner: this
        });
      } catch (_error) {
        e = _error;
        this.emit("error", new Error("invalid message " + message));
        return;
      }
      if (!info.type || ((_ref = info.type) !== "invoke" && _ref !== "event" && _ref !== "response" && _ref !== "stream")) {
        this.emit("error", new Error("invalid message " + message + " invalid info type"));
        return;
      }
      if (info.type === "stream") {
        return this.handleStreamData(info);
      } else if (info.type === "response") {
        return this.handleResponse(info);
      } else if (info.type === "invoke") {
        return this.handleInvoke(info);
      } else if (info.type === "event") {
        return this.handleEvent(info);
      } else {
        return this.emit("error", new Error("invalid message"));
      }
    };

    MessageCenter.prototype.handleEvent = function(info) {
      if (!info.name) {
        this.emit("error", new Error("invalid message " + (JSON.stringify(info))));
      }
      return this.emit("event/" + info.name, info.data);
    };

    MessageCenter.prototype.handleResponse = function(info) {
      var found;
      if (!info.id) {
        this.emit("error", new Error("invalid message " + (JSON.stringify(info))));
      }
      found = this.invokeWaiters.some((function(_this) {
        return function(waiter, index) {
          if (waiter.id === info.id) {
            _this.clearInvokeWaiter(info.id, null);
            waiter.callback(info.error, info.data);
            return true;
          }
          return false;
        };
      })(this));
      return found;
    };

    MessageCenter.prototype.clearInvokeWaiter = function(id, error) {
      return this.invokeWaiters = this.invokeWaiters.filter(function(waiter) {
        if (waiter.id === id) {
          if (waiter.controller && waiter.controller._timer) {
            clearTimeout(waiter.controller._timer);
          }
          if (error) {
            waiter.callback(error);
          }
          return false;
        }
        return true;
      });
    };

    MessageCenter.prototype.handleInvoke = function(info) {
      var api, target, _i, _len, _ref;
      if (!info.id || !info.name) {
        this.emit("error", new Error("invalid message " + (JSON.stringify(info))));
      }
      target = null;
      _ref = this.apis;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        api = _ref[_i];
        if (api.name === info.name) {
          target = api;
          break;
        }
      }
      if (!target) {
        return this.response(info.id, {
          message: "" + info.name + " api not found",
          code: "ERRNOTFOUND"
        });
      }
      return target.handler(info.data, (function(_this) {
        return function(err, data) {
          return _this.response(info.id, err, data);
        };
      })(this));
    };

    MessageCenter.prototype.clearAll = function() {
      var waiter, _results;
      _results = [];
      while (this.invokeWaiters[0]) {
        waiter = this.invokeWaiters[0];
        _results.push(this.clearInvokeWaiter(waiter.id, new Error("abort")));
      }
      return _results;
    };

    MessageCenter.prototype.createStream = function() {
      var stream;
      stream = new WritableStream(this);
      return stream;
    };

    MessageCenter.prototype.handleStreamData = function(info) {
      if (!info.id) {
        this.emit("error", new Error("invalid stream data " + (JSON.stringify(info))));
      }
      return this.streams.some(function(stream) {
        if (stream.id === info.id) {
          if (info.end) {
            stream.close();
          } else {
            stream.emit("data", info.data);
          }
          return true;
        }
      });
    };

    MessageCenter.prototype.transferStream = function(stream) {
      var data, e, _results;
      if (this.connection) {
        try {
          if (stream.isEnd) {
            return;
          }
          _results = [];
          while (stream.buffers.length > 0) {
            data = stream.buffers.shift();
            _results.push(this.connection.send(data));
          }
          return _results;
        } catch (_error) {
          e = _error;
        }
      }
    };

    MessageCenter.prototype.endStream = function(stream) {
      var e;
      this.transferStream(stream);
      if (this.connection) {
        try {
          this.connection.send(JSON.stringify({
            id: stream.id,
            end: true,
            type: "stream"
          }));
          return stream.isEnd = true;
        } catch (_error) {
          e = _error;
        }
      }
    };

    MessageCenter.prototype.addStream = function(stream) {
      if (__indexOf.call(this.streams, stream) < 0) {
        return this.streams.push(stream);
      }
    };

    MessageCenter.prototype.removeStream = function(stream) {
      var index;
      index = this.streams.indexOf(stream);
      if (index < 0) {
        return;
      }
      return this.streams.splice(index, 1);
    };

    MessageCenter.isReadableStream = function(stream) {
      return stream instanceof ReadableStream;
    };

    MessageCenter.isWritableStream = function(stream) {
      return stream instanceof WritableStream;
    };

    return MessageCenter;

  })(EventEmitter);

  ReadableStream = (function(_super) {
    __extends(ReadableStream, _super);

    ReadableStream.id = 1000;

    function ReadableStream(messageCenter) {
      this.messageCenter = messageCenter;
      this.id = ReadableStream.id++;
      this.messageCenter.addStream(this);
    }

    ReadableStream.prototype.close = function() {
      if (this.isClose) {
        return;
      }
      this.isClose = true;
      this.emit("end");
      return this.messageCenter.removeStream(this);
    };

    return ReadableStream;

  })(EventEmitter);

  WritableStream = (function(_super) {
    __extends(WritableStream, _super);

    WritableStream.id = 1000;

    function WritableStream(messageCenter) {
      this.messageCenter = messageCenter;
      this.buffers = [];
      this.index = 0;
      this.id = WritableStream.id++;
      this.messageCenter.once("unsetConnection", (function(_this) {
        return function() {
          return _this.isEnd = true;
        };
      })(this));
    }

    WritableStream.prototype.write = function(data) {
      if (this.isEnd) {
        throw new Error("stream already end");
      }
      if (!data) {
        return;
      }
      this.buffers.push(this.messageCenter.stringify({
        id: this.id,
        index: this.index++,
        data: data,
        type: "stream"
      }));
      return this.messageCenter.transferStream(this);
    };

    WritableStream.prototype.end = function(data) {
      if (this.isEnd) {
        throw new Error("stream already end");
      }
      this.write(data);
      this.messageCenter.endStream(this);
      if (process && process.nextTick) {
        return process.nextTick((function(_this) {
          return function() {
            return _this.emit("finish");
          };
        })(this));
      } else {
        return setTimeout(((function(_this) {
          return function() {
            return _this.emit("finish");
          };
        })(this)), 0);
      }
    };

    return WritableStream;

  })(EventEmitter);

  module.exports = MessageCenter;

  module.exports.MessageCenter = MessageCenter;

}).call(this);
