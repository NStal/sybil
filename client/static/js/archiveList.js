// Generated by CoffeeScript 1.8.0
(function() {
  var App, ArchiveList, ArchiveListController, ArchiveListItem, CubeLoadingHint, EndlessArchiveLoader, Model, ScrollChecker, SwipeChecker, async,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  Model = require("model");

  App = require("app");

  ScrollChecker = require("util/scrollChecker");

  SwipeChecker = require("util/swipeChecker");

  async = require("lib/async");

  EndlessArchiveLoader = require("procedure/endlessArchiveLoader");

  CubeLoadingHint = require("/widget/cubeLoadingHint");

  ArchiveList = (function(_super) {
    __extends(ArchiveList, _super);

    function ArchiveList(template) {
      this.appendArchive = __bind(this.appendArchive, this);
      this._createArchiveLoader = __bind(this._createArchiveLoader, this);
      this.applyPreviewMode = __bind(this.applyPreviewMode, this);
      this.include(CubeLoadingHint);
      ArchiveList.__super__.constructor.call(this, template || App.templates["archive-list"]);
      this._appendQueue = async.queue(((function(_this) {
        return function(item, done) {
          _this.archiveListItems.push(item);
          return setTimeout((function() {
            return done();
          }), 4);
        };
      })(this)), 1);
      this.sort = "latest";
      this.viewRead = false;
      this.loadCount = 10;
      this.scrollChecker = new ScrollChecker(this.UI.containerWrapper);
      this.scrollChecker.listenBy(this, "scroll", this.onScroll);
      this.archiveListItems = Leaf.Widget.makeList(this.UI.container);
      this.archiveListController = new ArchiveListController(null, this);
      this.initSubWidgets();
      App.modelSyncManager.on("archive", (function(_this) {
        return function(archive) {
          var _ref;
          if (_this.archiveInfo && (_ref = archive.sourceGuid, __indexOf.call(_this.archiveInfo.sourceGuids, _ref) >= 0)) {
            return _this.showUpdateHint();
          }
        };
      })(this));
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
      this.disableMarkAsRead = true;
      this.archiveListController.saveLocation();
      if (infoPreviewMode) {
        this.node$.addClass("preview-mode");
      } else {
        this.node$.removeClass("preview-mode");
      }
      this.archiveListController.restoreLocation();
      return this.disableMarkAsRead = false;
    };

    ArchiveList.prototype.load = function(info) {
      var query;
      this.clear();
      this.archiveInfo = info;
      query = {};
      query.sourceGuids = info.sourceGuids;
      this._createArchiveLoader(query);
      this.UI.emptyHint$.hide();
      this.UI.loadingHint.hide();
      this.archiveListItems.length = 0;
      this.render();
      this.emit("load");
      this.hideUpdateHint();
      return this.more();
    };

    ArchiveList.prototype.showUpdateHint = function() {
      if (this.refreshHintShowInterval == null) {
        this.refreshHintShowInterval = 1000 * 7;
      }
      this.UI.refreshHint$.addClass("show");
      if (this._updateHintTimer) {
        this._updateHintTimer = null;
        clearTimeout(this._updateHintTimer);
      }
      return this._updateHintTimer = setTimeout(this.hideUpdateHint.bind(this), this.refreshHintShowInterval);
    };

    ArchiveList.prototype.hideUpdateHint = function() {
      clearTimeout(this._updateHintTimer);
      this._updateHintTimer = null;
      return this.UI.refreshHint$.removeClass("show");
    };

    ArchiveList.prototype.onClickRefreshHint = function() {
      this.load(this.archiveInfo);
      return this.hideUpdateHint();
    };

    ArchiveList.prototype.onClickHideRefreshHint = function(e) {
      if (e) {
        e.capture();
      }
      return this.hideUpdateHint();
    };

    ArchiveList.prototype._createArchiveLoader = function(query) {
      if (this.archiveLoader) {
        this.archiveLoader.stopListenBy(this);
      }
      this.archiveLoader = new EndlessArchiveLoader();
      this.archiveLoader.reset({
        query: query,
        viewRead: this.viewRead,
        sort: this.sort,
        count: this.loadCount
      });
      this.archiveLoader.listenBy(this, "archive", this.appendArchive);
      this.archiveLoader.listenBy(this, "noMore", this.onNoMore);
      this.archiveLoader.listenBy(this, "startLoading", (function(_this) {
        return function() {
          return _this.UI.loadingHint.show();
        };
      })(this));
      this.archiveLoader.listenBy(this, "endLoading", (function(_this) {
        return function() {
          return _this.UI.loadingHint.hide();
        };
      })(this));
      return this.archiveLoader;
    };

    ArchiveList.prototype.appendArchive = function(archive) {
      var item;
      this.UI.emptyHint$.hide();
      item = new ArchiveListItem(archive);
      return this._appendQueue.push(item);
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
      this.archiveLoader = null;
      this.UI.containerWrapper.scrollTop = 0;
      this.UI.emptyHint$.show();
      return this.UI.title$.hide();
    };

    ArchiveList.prototype.more = function(callback) {
      if (callback == null) {
        callback = function() {};
      }
      if (!this.archiveLoader) {
        callback("not ready");
        return;
      }
      if (this.archiveLoader.noMore) {
        callback("no more");
        return;
      }
      return this.archiveLoader.more((function(_this) {
        return function(err) {
          if (err) {
            if (err === "isLoading") {
              callback("loading");
              return;
            }
            App.showError(err);
            callback("fail");
            return;
          }
          return callback();
        };
      })(this));
    };

    ArchiveList.prototype.onNoMore = function() {
      return this.UI.emptyHint$.show();
    };

    ArchiveList.prototype.onClickMarkAllAsRead = function() {
      return async.eachLimit(this.archiveInfo.sourceGuids, 3, ((function(_this) {
        return function(guid, done) {
          var source;
          source = Model.Source.sources.get(guid);
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
      divider = this.UI.containerWrapper.scrollTop;
      divider += $(window).height() / 3;
      if (this.disableMarkAsRead) {
        return;
      }
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
      ArchiveListItem.__super__.constructor.call(this, App.templates["archive-list-item"]);
      this.setArchive(archive);
    }

    ArchiveListItem.prototype.onClickContent = function() {
      if (this.lockRead) {
        return;
      }
      this.markAsRead();
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

  })(require("archiveDisplayer"));

  ArchiveListController = (function(_super) {
    __extends(ArchiveListController, _super);

    function ArchiveListController(template, archiveList) {
      ArchiveListController.__super__.constructor.call(this, template || App.templates["archive-list-controller"]);
      this.archiveList = archiveList;
      this.swipeChecker = new SwipeChecker(this.node);
      this.swipeChecker.on("swipeleft", (function(_this) {
        return function(e) {
          return _this.node$.addClass("left-mode");
        };
      })(this));
      this.swipeChecker.on("swiperight", (function(_this) {
        return function(e) {
          e.preventDefault();
          e.stopImmediatePropagation();
          return _this.node$.removeClass("left-mode");
        };
      })(this));
      this.archiveList.scrollChecker.listenBy(this, "scroll", (function(_this) {
        return function() {
          return _this.updatePosition();
        };
      })(this));
      this.locationStacks = [];
      this.archiveList.on("load", (function(_this) {
        return function() {
          return _this.locationStacks = [];
        };
      })(this));
    }

    ArchiveListController.prototype.updatePosition = function() {
      var last;
      if (this.archiveList.archiveListItems.length - 5 >= 0) {
        last = this.archiveList.archiveListItems[this.archiveList.archiveListItems.length - 5];
      } else {
        last = this.archiveList.archiveListItems[0];
      }
      if (!last) {
        return;
      }
      if (last.node.offsetTop < this.archiveList.UI.containerWrapper.scrollTop) {
        return this.archiveList.more(function(err) {
          return console.debug("load more", err);
        });
      }
    };

    ArchiveListController.prototype.onClickPrevious = function() {
      var adjust, current;
      current = this.getCurrentItem();
      adjust = 5;
      if (this.isItemTopVisible(current, adjust)) {
        return this.scrollToItem(this.getPreviousItem());
      } else {
        return this.scrollToItem(current);
      }
    };

    ArchiveListController.prototype.onClickNext = function() {
      if (this.isLast(this.getCurrentItem())) {
        this.archiveList.UI.containerWrapper.scrollTop = this.getCurrentItem().node.offsetTop + this.getCurrentItem().node.offsetHeight;
        return;
      }
      return this.scrollToItem(this.getNextItem());
    };

    ArchiveListController.prototype.scrollToItem = function(item) {
      var top;
      if (!item) {
        return;
      }
      top = item.node.offsetTop;
      return this.archiveList.UI.containerWrapper.scrollTop = top;
    };

    ArchiveListController.prototype.isItemTopVisible = function(item, adjust) {
      var top;
      if (adjust == null) {
        adjust = 0;
      }
      top = this.archiveList.UI.containerWrapper.scrollTop;
      console.log(item.node.offsetTop + adjust > top);
      return item.node.offsetTop + adjust > top;
    };

    ArchiveListController.prototype.getCurrentItem = function() {
      var currentItem, item, top, _i, _len, _ref;
      top = this.archiveList.UI.containerWrapper.scrollTop;
      currentItem = this.archiveList.archiveListItems[0];
      _ref = this.archiveList.archiveListItems;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        if (item.node.offsetTop > top) {
          break;
        }
        currentItem = item;
      }
      return currentItem;
    };

    ArchiveListController.prototype.getPreviousItem = function() {
      var current, index, item, _i, _len, _ref;
      current = this.getCurrentItem();
      _ref = this.archiveList.archiveListItems;
      for (index = _i = 0, _len = _ref.length; _i < _len; index = ++_i) {
        item = _ref[index];
        if (item === current) {
          return this.archiveList.archiveListItems[index - 1] || null;
        }
      }
    };

    ArchiveListController.prototype.getNextItem = function() {
      var current, index, item, _i, _len, _ref;
      current = this.getCurrentItem();
      _ref = this.archiveList.archiveListItems;
      for (index = _i = 0, _len = _ref.length; _i < _len; index = ++_i) {
        item = _ref[index];
        if (item === current) {
          return this.archiveList.archiveListItems[index + 1] || null;
        }
      }
    };

    ArchiveListController.prototype.isLast = function(item) {
      return this.archiveList.archiveListItems[this.archiveList.archiveListItems.length - 1] === item;
    };

    ArchiveListController.prototype.saveLocation = function() {
      var current;
      current = this.getCurrentItem();
      if (current) {
        return this.locationStacks.push(current);
      }
    };

    ArchiveListController.prototype.restoreLocation = function() {
      var item;
      item = this.locationStacks.pop();
      if (item) {
        return this.scrollToItem(item);
      }
    };

    return ArchiveListController;

  })(Leaf.Widget);

  module.exports = ArchiveList;

}).call(this);
