// Generated by CoffeeScript 1.8.0
(function() {
  var App, PersistDataStore, PersistDataStoreManager, async,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  App = require("main.js");

  async = require("lib/async.js");

  PersistDataStoreManager = (function() {
    function PersistDataStoreManager() {
      this.indexes = [];
    }

    PersistDataStoreManager.prototype.syncIndex = function(callback) {
      if (callback == null) {
        callback = function() {
          return true;
        };
      }
      return App.messageCenter.invoke("getConfig", "configIndex", (function(_this) {
        return function(err, indexes) {
          if (err) {
            callback(err);
            return;
          }
          if (!(indexes instanceof Array)) {
            _this.indexes = [];
          } else {
            _this.indexes = indexes.map(function(name) {
              return {
                name: name
              };
            });
          }
          return callback(null);
        };
      })(this));
    };

    PersistDataStoreManager.prototype.saveIndex = function() {};

    PersistDataStoreManager.prototype.load = function(name, callback) {
      var config, found;
      if (callback == null) {
        callback = function() {
          return true;
        };
      }
      if (!this.indexes) {
        throw new Error("can load config before sync indexes");
      }
      config = null;
      found = this.indexes.some(function(index) {
        if (index.name === name) {
          if (index.config) {
            config = index.config;
          }
          return true;
        }
        return false;
      });
      if (!found) {
        config = new Config(name);
        this.indexes.push({
          name: name,
          config: config
        });
        this.saveIndex();
        callback(null, config);
        return;
      }
      config = config || new Config(name);
      return config.load(function(err) {
        return callback(err, config);
      });
    };

    return PersistDataStoreManager;

  })();

  PersistDataStore = (function(_super) {
    __extends(PersistDataStore, _super);

    PersistDataStore.configs = [];

    PersistDataStore.load = function(callback) {
      return App.messageCenter.invoke("getConfig", "configIndex", (function(_this) {
        return function(err, configs) {
          if (err) {
            throw err;
          }
          if (!(configs instanceof Array)) {
            configs = [];
          }
          return async.map(configs, (function(name, done) {
            return App.messageCenter.invoke("getConfig", name, function(err, data) {
              var item, prop, _i, _len, _ref;
              if (err) {
                return done(err);
              } else {
                data = data || {};
                _ref = _this.configs;
                for (_i = 0, _len = _ref.length; _i < _len; _i++) {
                  item = _ref[_i];
                  if (item.name === name) {
                    for (prop in data) {
                      item.data[prop] = data[prop];
                    }
                    return done(null, null);
                  }
                }
                return done(null, new Config(name, data));
              }
            });
          }), function(err, configs) {
            if (err) {
              if (callback) {
                callback(err);
              } else {
                throw err;
              }
            }
            _this.isReady = true;
            configs = configs.filter(function(item) {
              return item;
            });
            _this.configs.push.apply(_this.configs, configs);
            Model.emit("config/ready");
            if (_this._saveOnLoad) {
              return _this._saveIndex(function() {
                return _this.save();
              });
            }
          });
        };
      })(this));
    };

    PersistDataStore.save = function(name, callback) {
      var configsToSave;
      if (!this.isReady) {
        console.debug("won't save " + name + " when config not load yet");
        return;
      }
      if (name) {
        configsToSave = this.configs.filter(function(item) {
          return item.name === name;
        });
      } else {
        configsToSave = this.configs;
      }
      return async.each(configsToSave, ((function(_this) {
        return function(config, done) {
          return App.messageCenter.invoke("saveConfig", {
            name: config.name,
            data: config.toJSON()
          }, function(err) {
            return done(err);
          });
        };
      })(this)), (function(_this) {
        return function(err) {
          if (err) {
            if (callback) {
              return callback(err);
            } else {
              throw err;
            }
          }
        };
      })(this));
    };

    PersistDataStore.getConfig = function(name, defaultConfig) {
      var item, _i, _len, _ref;
      _ref = this.configs;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        if (item.name === name) {
          return item;
        }
      }
      if (defaultConfig && typeof defaultConfig !== "object") {
        throw "invalid defaultConfig";
      }
      if (!this.isReady) {
        this._saveOnLoad = true;
      }
      return this.createConfig(name, defaultConfig && defaultConfig || {});
    };

    PersistDataStore.createConfig = function(name, data, callback) {
      var config, err, item, _i, _len, _ref;
      if (!name) {
        err = "config need a name";
        if (callback) {
          callback(err);
        } else {
          throw err;
        }
      }
      if (name === "configName") {
        err = "invalid config name, conflict with 'configName'";
        if (callback) {
          callback(err);
        } else {
          throw err;
        }
        return;
      }
      _ref = this.configs;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        if (item.name === name) {
          err = "already exists";
          if (callback) {
            callback(err);
          } else {
            throw err;
          }
          return;
        }
      }
      config = new Config(name, data);
      this.configs.push(config);
      this._saveIndex((function(_this) {
        return function(err) {
          if (err) {
            if (callback) {
              callback(err);
            }
          }
          return _this.save(config.name, callback);
        };
      })(this));
      return config;
    };

    PersistDataStore._saveIndex = function(callback) {
      var item;
      if (!this.isReady) {
        if (callback) {
          callback("config not ready");
        }
        return;
      }
      return App.messageCenter.invoke("saveConfig", {
        name: "configIndex",
        data: (function() {
          var _i, _len, _ref, _results;
          _ref = this.configs;
          _results = [];
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            item = _ref[_i];
            _results.push(item.name);
          }
          return _results;
        }).call(this)
      }, function(err) {
        return callback(err);
      });
    };

    function PersistDataStore(name, data) {
      this.data = data != null ? data : {};
      this.name = name;
    }

    PersistDataStore.prototype.toJSON = function() {
      return this.data;
    };

    PersistDataStore.prototype.save = function(callback) {
      return Config.save(this.name, callback);
    };

    PersistDataStore.prototype.set = function(key, value) {
      this.data[key] = _.cloneDeep(value);
      return this.save();
    };

    PersistDataStore.prototype.get = function(key, defaultValue) {
      return (_.cloneDeep(this.data[key])) || defaultValue;
    };

    return PersistDataStore;

  })(Leaf.EventEmitter);

  exports.Store = PersistDataStore;

  exports.Manager = PersistDataStoreManager;

}).call(this);
