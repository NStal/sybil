// Generated by CoffeeScript 1.8.0
(function() {
  var AllArchiveListCollection, AllSourceCollection, App, Archive, ArchiveList, Model, Source, SourceFolder, async,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  App = require("app");

  async = require("lib/async");

  Model = (function(_super) {
    __extends(Model, _super);

    function Model() {
      Model.__super__.constructor.call(this);
    }

    return Model;

  })(Leaf.Model);

  Leaf.EventEmitter.mixin(Model);

  AllSourceCollection = (function(_super) {
    __extends(AllSourceCollection, _super);

    function AllSourceCollection() {
      AllSourceCollection.__super__.constructor.call(this);
      this.setId("guid");
    }

    AllSourceCollection.prototype.sync = function(callback) {
      if (callback == null) {
        callback = function() {
          return true;
        };
      }
      return App.messageCenter.invoke("getSources", {}, (function(_this) {
        return function(err, sources) {
          var source, _i, _len;
          if (sources == null) {
            sources = [];
          }
          if (err) {
            console.error(err);
            callback(err);
            return;
          }
          for (_i = 0, _len = sources.length; _i < _len; _i++) {
            source = sources[_i];
            _this.add(new Source(source));
          }
          return callback();
        };
      })(this));
    };

    return AllSourceCollection;

  })(Leaf.Collection);

  Source = (function(_super) {
    __extends(Source, _super);

    Source.sources = new AllSourceCollection();

    Source.prototype.fields = ["name", "guid", "unreadCount", "tags", "uri", "collectorName", "description", "totalArchive", "statistic", "type", "lastError", "lastErrorDate", "lastErrorDescription", "requireLocalAuth", "requireCaptcha", "captcha", "lastUpdate", "lastFetch", "panic", "nextFetchInterval"];

    function Source(data) {
      Source.__super__.constructor.call(this);
      this.declare;
      this.data = data || {};
      this.data.type = "source";
      return Source.sources.add(this);
    }

    Source.prototype.markAllAsRead = function(callback) {
      if (callback == null) {
        callback = function() {
          return true;
        };
      }
      return App.messageCenter.invoke("markAllArchiveAsRead", this.data.guid, (function(_this) {
        return function(err) {
          return callback(err);
        };
      })(this));
    };

    Source.prototype.queryStatisticInfo = function(callback) {
      if (callback == null) {
        callback = function() {
          return true;
        };
      }
      if (this.data.statistic) {
        callback();
        return;
      }
      return App.messageCenter.invoke("getSourceStatistic", this.guid, (function(_this) {
        return function(err, info) {
          if (err) {
            callback(err);
            return;
          }
          _this.data = {
            totalArchive: info.totalArchive || [],
            statistic: info.statistic || []
          };
          return callback(null);
        };
      })(this));
    };

    Source.prototype.unsubscribe = function(callback) {
      if (callback == null) {
        callback = function() {
          return true;
        };
      }
      return App.messageCenter.invoke("unsubscribe", this.guid, (function(_this) {
        return function(err) {
          if (err) {
            console.error("fail to unsubscribe " + _this.guid, err);
            callback(err);
            return;
          }
          console.log("unsubscribed " + _this.name + " " + _this.guid);
          _this.destroy();
          return callback();
        };
      })(this));
    };

    Source.prototype.destroy = function() {
      this.emit("destroy");
      return this.isDestroyed = true;
    };

    Source.prototype.rename = function(name, callback) {
      if (callback == null) {
        callback = function() {
          return true;
        };
      }
      this.preset("name", name);
      return App.messageCenter.invoke("renameSource", {
        guid: this.guid,
        name: name
      }, (function(_this) {
        return function(err) {
          if (err) {
            _this.undo();
          } else {
            _this.confirm();
          }
          return callback(err);
        };
      })(this));
    };

    Source.prototype.forceUpdate = function(callback) {
      return App.messageCenter.invoke("forceUpdateSource", this.guid, (function(_this) {
        return function(err) {
          if (err) {
            callback(err);
            return;
          }
          return App.messageCenter.invoke("getSource", _this.guid, function(err, source) {
            console.debug("update source to hehe ", source);
            _this.sets(source);
            return callback(null);
          });
        };
      })(this));
    };

    Source.prototype.describe = function(description, callback) {
      if (callback == null) {
        callback = function() {
          return true;
        };
      }
      this.preset("description", description);
      return App.messageCenter.invoke("setSourceDescription", {
        guid: this.guid,
        description: description
      }, (function(_this) {
        return function(err) {
          if (err) {
            _this.undo();
          } else {
            _this.confirm();
          }
          return callback(err);
        };
      })(this));
    };

    return Source;

  })(Model);

  SourceFolder = (function(_super) {
    __extends(SourceFolder, _super);

    SourceFolder.loadFolderStore = function(callback) {
      return App.persistentDataStoreManager.load("sourceFolderConfig", function(err, store) {
        return callback(err, store);
      });
    };

    function SourceFolder(data) {
      SourceFolder.__super__.constructor.call(this);
      this.declare(["name", "collapse", "type", "children"]);
      this.sets(data);
      this.data.type = "folder";
      this.data.id = this.data.id || Date.now().toString() + Math.random().toString().substring(2, 13);
    }

    SourceFolder.prototype.toJSON = function() {
      var children, item;
      children = (function() {
        var _i, _len, _ref, _results;
        _ref = this.children;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          item = _ref[_i];
          _results.push(item.toJSON({
            filter: ["name", "guid", "uri", "type"]
          }));
        }
        return _results;
      }).call(this);
      return {
        name: this.name,
        collapse: this.collapse,
        type: "folder",
        children: children
      };
    };

    return SourceFolder;

  })(Model);

  Archive = (function(_super) {
    __extends(Archive, _super);

    Archive.getByCustom = function(option, callback) {
      return App.messageCenter.invoke("getCustomArchives", option, function(err, archives) {
        var archive, result;
        if (err) {
          callback(err);
          return;
        }
        result = (function() {
          var _i, _len, _results;
          _results = [];
          for (_i = 0, _len = archives.length; _i < _len; _i++) {
            archive = archives[_i];
            _results.push(new Archive(archive));
          }
          return _results;
        })();
        return callback(null, result);
      });
    };

    function Archive(data) {
      Archive.__super__.constructor.call(this);
      this.declare(["name", "originalLink", "content", "displayContent", "title", "hasRead", "star", "guid", "createDate", "sourceGuid", "sourceName", "like", "share", "listName", "meta", "author", "lockRead"]);
      this.sets(data);
      this.data.meta = this.data.meta || {};
    }

    Archive.prototype.changeList = function(name, callback) {
      console.debug("call change list");
      return App.messageCenter.invoke("moveArchiveToList", {
        guid: this.guid,
        listName: name
      }, (function(_this) {
        return function(err) {
          _this.listName = name;
          return callback(err);
        };
      })(this));
    };

    Archive.prototype.markAsShare = function(callback) {
      return App.messageCenter.invoke("share", this.guid, (function(_this) {
        return function(err) {
          if (!err) {
            _this.share = true;
          }
          return callback(err);
        };
      })(this));
    };

    Archive.prototype.markAsUnshare = function(callback) {
      return App.messageCenter.invoke("unshare", this.guid, (function(_this) {
        return function(err) {
          if (!err) {
            _this.share = false;
          }
          return callback(err);
        };
      })(this));
    };

    Archive.prototype.markAsRead = function(callback) {
      if (this.lockRead) {
        callback(new Error("already locked read"));
        return;
      }
      return App.messageCenter.invoke("markArchiveAsRead", this.guid, (function(_this) {
        return function(err) {
          if (!err) {
            if (!_this.hasRead) {
              _this.hasRead = true;
              App.modelSyncManager.emit("archive/read", _this);
            }
          }
          return callback(err);
        };
      })(this));
    };

    Archive.prototype.markAsUnread = function(callback) {
      return App.messageCenter.invoke("markArchiveAsUnread", this.guid, (function(_this) {
        return function(err) {
          if (!err) {
            if (_this.hasRead) {
              _this.hasRead = false;
              App.modelSyncManager.emit("archive/unread", _this);
            }
          }
          return callback(err);
        };
      })(this));
    };

    Archive.prototype.likeArchive = function(callback) {
      return App.messageCenter.invoke("likeArchive", this.guid, (function(_this) {
        return function(err) {
          if (!err) {
            _this.like = true;
          }
          return callback(err);
        };
      })(this));
    };

    Archive.prototype.unlikeArchive = function(callback) {
      return App.messageCenter.invoke("unlikeArchive", this.guid, (function(_this) {
        return function(err) {
          if (!err) {
            _this.like = false;
          }
          return callback(err);
        };
      })(this));
    };

    Archive.prototype.readLaterArchive = function(callback) {
      return this.changeList("read later", (function(_this) {
        return function(err) {
          if (err) {
            callback(err);
            return;
          }
          _this.listName = "read later";
          return callback();
        };
      })(this));
    };

    Archive.prototype.unreadLaterArchive = function(callback) {
      if (this.listName !== "read later") {
        callback("not in read later list");
        return;
      }
      return this.changeList(null, (function(_this) {
        return function(err) {
          if (err) {
            callback(err);
            return;
          }
          _this.listName = null;
          return callback();
        };
      })(this));
    };

    Archive.prototype.getFirstValidProfile = function() {
      var item, _i, _len, _ref;
      if (!this.meta || !this.meta.shareRecords) {
        return null;
      }
      _ref = this.meta.shareRecords;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        console.log(item.profile);
        if (item.profile && item.profile.email && item.profile.nickname) {
          return {
            hash: md5(item.profile.email.trim()),
            nickname: item.profile.nickname
          };
        }
      }
      return null;
    };

    return Archive;

  })(Model);

  AllArchiveListCollection = (function(_super) {
    __extends(AllArchiveListCollection, _super);

    function AllArchiveListCollection() {
      AllArchiveListCollection.__super__.constructor.call(this);
      this.setId("name");
      this.on("add", (function(_this) {
        return function(list) {
          return App.modelSyncManager.emit("archiveList/add", list);
        };
      })(this));
      this.on("remove", (function(_this) {
        return function(list) {
          return App.modelSyncManager.emit("archiveList/remove", list);
        };
      })(this));
    }

    return AllArchiveListCollection;

  })(Leaf.Collection);

  ArchiveList = (function(_super) {
    __extends(ArchiveList, _super);

    ArchiveList.lists = new AllArchiveListCollection();

    ArchiveList.sync = function(callback) {
      if (callback == null) {
        callback = function() {};
      }
      return App.messageCenter.invoke("getLists", {}, (function(_this) {
        return function(err, lists) {
          if (err) {
            callback(err);
            return;
          }
          lists = lists.map(function(list) {
            return new ArchiveList(list);
          });
          return callback(null, lists);
        };
      })(this));
    };

    ArchiveList.create = function(name, callback) {
      if (callback == null) {
        callback = function() {
          return true;
        };
      }
      if (!name || !name.trim()) {
        callback("invalid name");
        return;
      }
      return App.messageCenter.invoke("createList", name.trim(), function(err) {
        if (err) {
          callback(err);
          return;
        }
        return callback(null, new ArchiveList({
          name: name
        }));
      });
    };

    function ArchiveList(data) {
      ArchiveList.__super__.constructor.call(this);
      this.declare(["name", "count"]);
      this.data = data;
      this.defaults({
        count: 0
      });
      if (!this.name) {
        throw new Error("invalid list data");
      }
      App.modelSyncManager.on("listChange", (function(_this) {
        return function(info) {
          if (info.from === _this.name) {
            _this.remove(new Archive(info.archive));
          }
          if (info.to === _this.name) {
            info.archive.listName = _this.name;
            return _this.add(new Archive(info.archive));
          }
        };
      })(this));
      return ArchiveList.lists.add(this);
    }

    ArchiveList.prototype.getArchives = function(option, callback) {
      var count, offset, sort, splitter;
      if (option == null) {
        option = {};
      }
      count = option.count || 20;
      offset = option.offset || 0;
      splitter = option.splitter || null;
      sort = option.sort || "latest";
      return App.messageCenter.invoke("getList", {
        name: this.name,
        count: count,
        offset: offset,
        splitter: splitter,
        sort: sort
      }, (function(_this) {
        return function(err, listInfo) {
          if (listInfo == null) {
            listInfo = {};
          }
          if (!listInfo || !listInfo.archives) {
            callback(err, null);
            return;
          }
          return callback(err, listInfo.archives.map(function(info) {
            return new Archive(info);
          }));
        };
      })(this));
    };

    ArchiveList.prototype["delete"] = function(callback) {
      return App.messageCenter.invoke("removeList", this.name, (function(_this) {
        return function(err) {
          if (err) {
            callback(err);
            return;
          }
          ArchiveList.lists.remove(_this);
          return callback(null);
        };
      })(this));
    };

    ArchiveList.prototype.add = function(archive) {
      this.count++;
      console.debug(this.name, "emit add archive");
      return this.emit("add", archive);
    };

    ArchiveList.prototype.remove = function(archive) {
      this.count--;
      return this.emit("remove", archive);
    };

    return ArchiveList;

  })(Model);

  Model.Source = Source;

  Model.SourceFolder = SourceFolder;

  Model.Archive = Archive;

  Model.ArchiveList = ArchiveList;

  module.exports = Model;

}).call(this);
