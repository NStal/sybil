// Generated by CoffeeScript 1.8.0
(function() {
  var App, BufferedEndlessArchiveLoader, Errors, Model,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  App = require("/app");

  Model = App.Model;

  Errors = require("/common/errors");

  BufferedEndlessArchiveLoader = (function(_super) {
    __extends(BufferedEndlessArchiveLoader, _super);

    function BufferedEndlessArchiveLoader() {
      BufferedEndlessArchiveLoader.__super__.constructor.call(this);
      this.on("state", (function(_this) {
        return function(state) {
          if (_this.data.lastState !== "loading" && state === "loading") {
            return _this.emit("startLoading");
          } else if (_this.data.lastState === "loading" && state !== "loading") {
            return _this.emit("endLoading");
          }
        };
      })(this));
    }

    BufferedEndlessArchiveLoader.prototype.reset = function() {
      this.emit("endLoading");
      BufferedEndlessArchiveLoader.__super__.reset.call(this);
      this.data.lastState = null;
      this.data.archives = [];
      this.data.guids = [];
      this.data.cursor = 0;
      return this.data.drain = false;
    };

    BufferedEndlessArchiveLoader.prototype.init = function(option) {
      if (option == null) {
        option = {};
      }
      if (this.state !== "void") {
        throw new Error("State isnt void, can init loader when already running.");
      }
      this.reset();
      this.viewRead = option.viewRead || false;
      this.sort = option.sort || "latest";
      this.bufferSize = option.bufferSize || 20;
      this.querySize = option.querySize || option.bufferSize || 10;
      return this.query = option.query || {};
    };

    BufferedEndlessArchiveLoader.prototype.more = function(count, callback) {
      var archives, start;
      if (count > this.bufferSize) {
        count = this.bufferSize;
      }
      if (this.data.archives.length - this.data.cursor < count && !this.data.drain) {
        this._bufferMore((function(_this) {
          return function(err) {
            if (err) {
              callback(err);
              return;
            }
            return _this.more(count, callback);
          };
        })(this));
        return;
      }
      start = this.data.cursor;
      this.data.cursor += count;
      archives = this.data.archives.slice(start, start + count);
      if (this.data.archives.length - this.data.cursor < this.bufferSize) {
        this._ensureLoadingState();
      }
      callback(null, archives);
      if (this.isDrain()) {
        return this.emit("drain");
      }
    };

    BufferedEndlessArchiveLoader.prototype.oneMore = function(callback) {
      return this.more(1, function(err, archives) {
        if (err) {
          callback(err);
          return;
        }
        if (!archives || archives.length === 0) {
          callback(null, null);
          return;
        }
        return callback(null, archives[0]);
      });
    };

    BufferedEndlessArchiveLoader.prototype.isDrain = function() {
      return this.data.drain && this.data.cursor >= this.data.archives.length;
    };

    BufferedEndlessArchiveLoader.prototype._bufferMore = function(callback) {
      if (callback == null) {
        callback = function() {};
      }
      if (this.data.archives.length - this.data.cursor > this.bufferSize) {
        callback();
        return;
      }
      this._ensureLoadingState();
      if (this.state === "drain") {
        callback();
        return;
      }
      return this.once("loadend", (function(_this) {
        return function(err) {
          if (err instanceof Errors.Drained) {
            callback();
            return;
          }
          return callback(err);
        };
      })(this));
    };

    BufferedEndlessArchiveLoader.prototype._ensureLoadingState = function() {
      if (this.state === "panic") {
        this.recover();
        return this.setState("loading");
      } else if (this.state === "pause") {
        return this.give("continue");
      } else if (this.state === "void") {
        return this.setState("loading");
      } else if (this.state === "loading") {
        return true;
      }
    };

    BufferedEndlessArchiveLoader.prototype.atPanic = function() {
      if (this.panicState === "loading") {
        return this.emit("loadend");
      }
    };

    BufferedEndlessArchiveLoader.prototype.atLoading = function(sole) {
      var option, prop;
      option = {
        sort: this.sort,
        count: this.querySize,
        viewRead: this.viewRead,
        splitter: this.data.splitter || null
      };
      for (prop in this.query || {}) {
        option[prop] = this.query[prop];
      }
      return Model.Archive.getByCustom(option, (function(_this) {
        return function(err, archives) {
          var archive, _i, _len, _ref, _ref1;
          if (_this.stale(sole)) {
            return;
          }
          if (err) {
            _this.error(err);
            return;
          }
          _this.data.splitter = (archives != null ? (_ref = archives[(archives != null ? archives.length : void 0) - 1]) != null ? _ref.guid : void 0 : void 0) || null;
          for (_i = 0, _len = archives.length; _i < _len; _i++) {
            archive = archives[_i];
            if (_ref1 = archive.guid, __indexOf.call(_this.data.guids, _ref1) >= 0) {
              continue;
            }
            _this.data.guids.push(archive.guid);
            _this.data.archives.push(archive);
          }
          if (archives.length > 0) {
            _this.emit("loadend");
          }
          if (archives.length < _this.querySize) {
            _this.data.drain = true;
            return _this.setState("drained");
          } else if (_this.data.archives.length - _this.data.cursor < _this.bufferSize) {
            return _this.setState("loading");
          } else {
            return _this.setState("pause");
          }
        };
      })(this));
    };

    BufferedEndlessArchiveLoader.prototype.atPause = function(sole) {
      return this.waitFor("continue", (function(_this) {
        return function() {
          if (_this.stale(sole)) {
            return;
          }
          return _this.setState("loading");
        };
      })(this));
    };

    BufferedEndlessArchiveLoader.prototype.atDrained = function() {
      this.emit("loadend", new Errors.Drained("drained"));
      this.emit("endLoading");
    };

    return BufferedEndlessArchiveLoader;

  })(Leaf.States);

  module.exports = BufferedEndlessArchiveLoader;

}).call(this);
