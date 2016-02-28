// Generated by CoffeeScript 1.8.0
(function() {
  var App, ClientCoreState, PortalAdapter, async, portal,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  App = require("/app");

  portal = require("/component/portal");

  async = require("/component/async");

  PortalAdapter = (function(_super) {
    __extends(PortalAdapter, _super);

    function PortalAdapter() {
      PortalAdapter.__super__.constructor.call(this);
      this.on("error", (function(_this) {
        return function(err) {
          return console.error("portal error", err);
        };
      })(this));
      this.observations = [];
    }

    PortalAdapter.prototype.isObserving = function(path) {
      var item, _i, _len, _ref;
      _ref = this.observations;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        if (item.path === path) {
          return true;
        }
      }
      return false;
    };

    PortalAdapter.prototype.observe = function(path, callback) {
      var ob, _ref;
      ob = {
        path: path,
        callback: callback
      };
      this.observations.push(ob);
      ob.isApplying = true;
      return (_ref = this.mc) != null ? _ref.invoke("observe", path, (function(_this) {
        return function(err, results) {
          ob.isApplying = false;
          if (!err) {
            _this.emit("error", err);
            return;
          }
          ob.init = true;
          return ob.callback(null, results);
        };
      })(this)) : void 0;
    };

    PortalAdapter.prototype.stopObserve = function(path, callback) {
      return this.observations = this.observations.filter(function(ob) {
        var _ref;
        if (ob.path === path) {
          if ((_ref = this.mc) != null) {
            _ref.invoke("stopObserve", ob.path, function() {
              return null;
            });
          }
          return false;
        }
        return true;
      });
    };

    PortalAdapter.prototype.setMessageCenter = function(mc) {
      this.messageCenter = mc;
      this.mc = mc;
      this.mc.listenBy(this, "event/observe/change", (function(_this) {
        return function(info) {
          return _this.emit("change", info);
        };
      })(this));
      this.mc.listenBy(this, "event/observe/init", (function(_this) {
        return function(info) {
          return _this.emit("init", info);
        };
      })(this));
      this.mc.listenBy(this, "event/observe/delete", (function(_this) {
        return function(info) {
          return _this.emit("delete", info);
        };
      })(this));
      return this.applyObserve(function(err) {
        if (err) {
          return emit("error", err);
        }
      });
    };

    PortalAdapter.prototype.applyObserve = function(callback) {
      var errors, hasError, total;
      if (callback == null) {
        callback = function() {};
      }
      hasError = false;
      errors = [];
      total = this.observations.length;
      return async.each(this.observations, function(ob, done) {
        if (ob.isApplying) {
          done();
          return;
        }
        ob.isApplying = true;
        return this.mc.invoke("observe", ob.path, function(err, results) {
          ob.isApplying = true;
          if (err) {
            hasError = true;
            errors.push(err);
            done();
            return;
          }
          if (ob.init) {
            this.emit("gap", results);
          } else {
            ob.init = true;
            if (typeof ob.callback === "function") {
              ob.callback(null, results);
            }
          }
          return done();
        });
      }, (function(_this) {
        return function() {
          if (hasError) {
            callback(new App.Errors.ObserveFailure("apply observe fails", {
              errors: errors,
              total: total
            }));
            return;
          }
          return callback();
        };
      })(this));
    };

    PortalAdapter.prototype.unsetMessageCenter = function() {
      this.mc.stopListenBy(this);
      this.messageCenter = null;
      return this.mc = null;
    };

    return PortalAdapter;

  })(portal.Adapter);

  ClientCoreState = (function(_super) {
    __extends(ClientCoreState, _super);

    function ClientCoreState() {
      ClientCoreState.__super__.constructor.call(this, new PortalAdapter);
      this.adapter.on("error", (function(_this) {
        return function() {
          _this.adapter.unsetMessageCenter();
          return _this.emit(new Errors.NetworkError("observer network error"));
        };
      })(this));
    }

    ClientCoreState.prototype.setMessageCenter = function(mc) {
      this.adapter.setMessageCenter(mc);
      return this.mc = mc;
    };

    return ClientCoreState;

  })(portal.ObservePortal);

  module.exports = ClientCoreState;

}).call(this);