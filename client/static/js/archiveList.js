// Generated by CoffeeScript 1.7.1
(function() {
  var ArchiveConditionKeyword, ArchiveConditionLike, ArchiveConditionReadLater, ArchiveFilter, ArchiveList, ArchiveListItem,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  ArchiveList = (function(_super) {
    __extends(ArchiveList, _super);

    function ArchiveList(template) {
      this.applyPreviewMode = __bind(this.applyPreviewMode, this);
      this.archiveFilter = new ArchiveFilter();
      this.archiveFilter.on("change", (function(_this) {
        return function() {
          _this.clear();
          return _this.load(_this.archiveInfo);
        };
      })(this));
      ArchiveList.__super__.constructor.call(this, template || App.templates["archive-list"]);
      this._appendQueue = async.queue(((function(_this) {
        return function(item, done) {
          if (item._queueId !== _this._queueTaskId) {
            done();
            return;
          }
          return setTimeout((function() {
            if (item._queueId === _this._queueTaskId) {
              _this.appendArchiveListItem(item);
            }
            return done();
          }), 10);
        };
      })(this)), 1);
      this._queueTaskId = 0;
      this.archiveListItems = [];
      this.sort = "latest";
      this.viewRead = false;
      this.offset = null;
      this.count = 20;
      this.scrollCheckTimer = setInterval(((function(_this) {
        return function() {
          if (!_this.UI.containerWrapper) {
            return;
          }
          if (typeof _this.lastScrollTop === "number" && _this.lastScrollTop !== _this.UI.containerWrapper.scrollTop) {
            _this.onScroll();
          }
          return _this.lastScrollTop = _this.UI.containerWrapper.scrollTop;
        };
      })(this)), 300);
      App.userConfig.on("change/previewMode", this.applyPreviewMode.bind(this));
      App.userConfig.init("useResourceProxyByDefault", false);
      App.userConfig.init("enableResourceProxy", true);
    }

    ArchiveList.prototype.applyPreviewMode = function() {
      var globalPreviewMode, infoPreviewMode;
      if (!this.archiveInfo) {
        return;
      }
      globalPreviewMode = App.userConfig.get("previewMode", false);
      infoPreviewMode = App.userConfig.get("previewModeFor" + this.archiveInfo.name, globalPreviewMode);
      if (infoPreviewMode) {
        return this.node$.addClass("preview-mode");
      } else {
        return this.node$.removeClass("preview-mode");
      }
    };

    ArchiveList.prototype.load = function(info) {
      this.clear();
      this.UI.emptyHint$.hide();
      this.archiveInfo = info;
      this.render();
      return this.moreArchive();
    };

    ArchiveList.prototype.render = function() {
      this.UI.title$.show();
      this.UI.sourceName$.text(this.archiveInfo.name);
      this.applyPreviewMode();
      if (this.viewRead) {
        return this.UI.toggleViewAll$.text("view unread");
      } else {
        return this.UI.toggleViewAll$.text("view all");
      }
    };

    ArchiveList.prototype.clear = function() {
      var item, _i, _len, _ref;
      this._queueTaskId++;
      this.isLoadingMore = false;
      this.noMore = false;
      this.offset = null;
      _ref = this.archiveListItems;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        item.remove();
      }
      this.archiveListItems.length = 0;
      this.UI.containerWrapper.scrollTop = 0;
      this.UI.emptyHint$.show();
      return this.UI.title$.hide();
    };

    ArchiveList.prototype.moreArchive = function() {
      var last, query, sourceGuids, _taskId;
      if (this.noMore) {
        return;
      }
      if (this.isLoadingMore) {
        return;
      }
      if (!this.archiveInfo) {
        return;
      }
      this.isLoadingMore = true;
      last = this.archiveListItems[this.archiveListItems.length - 1];
      if (last && last.archive) {
        this.offset = last.archive.guid;
      } else {
        this.offset = void 0;
      }
      sourceGuids = this.archiveInfo.sourceGuids;
      _taskId = this._queueTaskId;
      query = this.archiveFilter.buildQuery() || {};
      query.sourceGuids = sourceGuids;
      console.log(query);
      this.UI.loadingHint$.show();
      return Model.Archive.getByCustom({
        query: query,
        viewRead: this.viewRead,
        sort: this.sort,
        offset: this.offset,
        count: this.count
      }, (function(_this) {
        return function(err, archives) {
          var archive, archiveListItem, _i, _len, _results;
          _this.UI.loadingHint$.hide();
          _this.isLoadingMore = false;
          if (_taskId !== _this._queueTaskId) {
            return;
          }
          if (err || !(archives instanceof Array)) {
            console.error(err || "no archive!");
            console.trace();
            return;
          }
          if (archives.length === 0) {
            _this.onNoMore();
            return;
          }
          _results = [];
          for (_i = 0, _len = archives.length; _i < _len; _i++) {
            archive = archives[_i];
            archiveListItem = new ArchiveListItem(archive);
            _results.push(_this.appendListItemQueue(archiveListItem));
          }
          return _results;
        };
      })(this));
    };

    ArchiveList.prototype.appendListItemQueue = function(item) {
      item._queueId = this._queueTaskId;
      return this._appendQueue.push(item);
    };

    ArchiveList.prototype.onNoMore = function() {
      console.log("noMore!", this.offset, this.count);
      this.noMore = true;
      return this.UI.emptyHint$.show();
    };

    ArchiveList.prototype.appendArchiveListItem = function(item) {
      console.trace();
      this.UI.emptyHint$.hide();
      item.appendTo(this.UI.container);
      item.on("read", (function(_this) {
        return function(data) {
          return App.emit("read", data);
        };
      })(this));
      item.on("unread", (function(_this) {
        return function(data) {
          return App.emit("unread", data);
        };
      })(this));
      return this.archiveListItems.push(item);
    };

    ArchiveList.prototype.onClickMarkAllAsRead = function() {
      return async.eachLimit(this.archiveInfo.sourceGuids, 3, ((function(_this) {
        return function(guid, done) {
          var source;
          source = Model.Source.getByGuid(guid);
          if (!source) {
            console.error(source, guid);
            done();
            return;
          }
          return source.markAllAsRead(function(err) {
            if (err) {
              console.error(err);
              done();
              return;
            }
            source.unreadCount = 0;
            source.emit("change");
            return done();
          });
        };
      })(this)), (function(_this) {
        return function(err) {
          console.log("complete mark all as read");
          return _this.load(_this.archiveInfo);
        };
      })(this));
    };

    ArchiveList.prototype.onClickToggleViewAll = function() {
      if (this.viewRead) {
        this.viewRead = false;
        this.load(this.archiveInfo);
      } else {
        this.viewRead = true;
        this.load(this.archiveInfo);
      }
      return this.render();
    };

    ArchiveList.prototype.onClickViewUnread = function() {
      if (!this.viewRead) {

      }
    };

    ArchiveList.prototype.onClickPreviewMode = function() {
      var previewMode;
      console.debug("inside pm");
      if (this.archiveInfo) {
        console.log("pm in!");
        previewMode = App.userConfig.get("previewModeFor" + this.archiveInfo.name, false);
        console.log("pm ", "previewModeFor" + this.archiveInfo.name, previewMode);
        App.userConfig.set("previewModeFor" + this.archiveInfo.name, !previewMode);
        return this.applyPreviewMode();
      }
    };

    ArchiveList.prototype.onScroll = function() {
      var bottom, divider, item, top, _i, _len, _ref, _results;
      if (this.UI.containerWrapper.scrollHeight - this.UI.containerWrapper.scrollTop - this.UI.containerWrapper.clientHeight < this.UI.containerWrapper.clientHeight / 2) {
        this.moreArchive();
      }
      divider = this.UI.containerWrapper.scrollTop;
      divider += $(window).height() / 3;
      _ref = this.archiveListItems;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        top = item.node.offsetTop;
        bottom = item.node.offsetTop + item.node.clientHeight;
        if (divider > top && !item.archive.hasRead) {
          item.markAsRead();
          _results.push(console.log("mark as read", item.archive.guid));
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    };

    return ArchiveList;

  })(Leaf.Widget);

  ArchiveListItem = (function(_super) {
    __extends(ArchiveListItem, _super);

    function ArchiveListItem(archive) {
      this.archive = archive;
      ArchiveListItem.__super__.constructor.call(this, App.templates["archive-list-item"]);
      this.setArchive(this.archive);
    }

    ArchiveListItem.prototype.onClickContent = function() {
      if (this.lockRead) {
        return;
      }
      this.archive.markAsRead((function(_this) {
        return function(err) {
          if (err) {
            console.error(err);
            return;
          }
          return _this.render();
        };
      })(this));
      return true;
    };

    ArchiveListItem.prototype.onClickTitle = function(e) {
      window.open(this.archive.originalLink);
      e.stopPropagation();
      e.preventDefault();
      e.stopImmediatePropagation();
      return false;
    };

    ArchiveListItem.prototype.onClickHeader = function(e) {
      this.node$.toggleClass("collapse");
      return this.markAsRead();
    };

    ArchiveListItem.prototype.markAsRead = function() {
      if (this.lockRead) {
        return;
      }
      if (this.isMarking) {
        return;
      }
      if (this.archive.hasRead) {
        return;
      }
      this.isMarking = true;
      return this.archive.markAsRead((function(_this) {
        return function(err) {
          if (err) {
            console.error(err);
            return;
          }
          _this.render();
          return _this.isMarking = false;
        };
      })(this));
    };

    ArchiveListItem.prototype.onClickKeepUnread = function(e) {
      e.preventDefault();
      e.stopPropagation();
      return this.onClickMarkAsUnread();
    };

    ArchiveListItem.prototype.render = function() {
      ArchiveListItem.__super__.render.call(this);
      if (this.lockRead) {
        this.node$.addClass("lock-read");
      } else {
        this.node$.removeClass("lock-read");
      }
      if (this.archive.hasRead) {
        return this.node$.addClass("read");
      } else {
        return this.node$.removeClass("read");
      }
    };

    ArchiveListItem.prototype.onClickMarkAsUnread = function() {
      this.lockRead = true;
      if (this.archive.hasRead === false) {
        this.render();
        return;
      }
      console.debug("mark as unread");
      return this.archive.markAsUnread((function(_this) {
        return function(err) {
          if (err) {
            console.error(err);
            return;
          }
          console.debug("mark as unread done->render");
          console.debug(_this.lockRead, _this.archive.hasRead, "is the state");
          return _this.render();
        };
      })(this));
    };

    return ArchiveListItem;

  })(ArchiveDisplayer);

  ArchiveFilter = (function(_super) {
    __extends(ArchiveFilter, _super);

    function ArchiveFilter() {
      ArchiveFilter.__super__.constructor.call(this, App.templates["archive-filter"]);
      this.conditions = Leaf.Widget.makeList(this.UI.conditions);
    }

    ArchiveFilter.prototype.buildQuery = function() {
      var condition, query, _i, _len, _ref;
      if (this.conditions.length === 0) {
        return null;
      }
      query = {};
      _ref = this.conditions;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        condition = _ref[_i];
        if (condition.type === "keyword") {
          query.keywords = query.keywords || [];
          query.keywords.push(condition.value);
        }
        if (condition.type === "like") {
          query.properties.like = true;
        }
        if (condition.type === "readLater") {
          query.properties.readLater = true;
        }
      }
      return query;
    };

    ArchiveFilter.prototype.clear = function() {
      return this.conditions.length = 0;
    };

    ArchiveFilter.prototype.addCondition = function(condition) {
      this.emit("change");
      console.error(condition, "~~~");
      return this.conditions.push(condition);
    };

    return ArchiveFilter;

  })(Leaf.Widget);

  ArchiveConditionKeyword = (function(_super) {
    __extends(ArchiveConditionKeyword, _super);

    function ArchiveConditionKeyword(value) {
      this.value = value;
      ArchiveConditionKeyword.__super__.constructor.call(this, App.templates["archive-filter-condition"]);
      this.type = "keyword";
    }

    return ArchiveConditionKeyword;

  })(Leaf.Widget);

  ArchiveConditionLike = (function(_super) {
    __extends(ArchiveConditionLike, _super);

    function ArchiveConditionLike(value) {
      this.value = value;
      this.type = "like";
    }

    return ArchiveConditionLike;

  })(Leaf.Widget);

  ArchiveConditionReadLater = (function(_super) {
    __extends(ArchiveConditionReadLater, _super);

    function ArchiveConditionReadLater() {
      this.type = "readLater";
    }

    return ArchiveConditionReadLater;

  })(Leaf.Widget);

  window.ArchiveListItem = ArchiveListItem;

  window.ArchiveList = ArchiveList;

}).call(this);
