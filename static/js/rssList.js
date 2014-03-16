// Generated by CoffeeScript 1.6.3
(function() {
  var RssList,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  RssList = (function(_super) {
    var RssListItem;

    __extends(RssList, _super);

    function RssList() {
      var _this = this;
      RssList.__super__.constructor.call(this, sybil.templates["rss-list"]);
      this.items = [];
      sybil.preferenceManager.watch("hideEmptyRss", function(value) {
        if (value) {
          return _this.node$.addClass("hide-empty-rss");
        } else {
          return _this.node$.removeClass("hide-empty-rss");
        }
      });
    }

    RssList.prototype.toggleEmptyRss = function() {
      return sybil.preferenceManager.toggle("hideEmptyRss");
    };

    RssList.prototype.focus = function(id) {
      var item, _i, _len, _ref;
      _ref = this.items;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        if (item.data.id === id) {
          item.focus();
          return;
        }
      }
    };

    RssList.prototype.ListItem = RssListItem = (function(_super1) {
      __extends(RssListItem, _super1);

      function RssListItem(data, parent) {
        RssListItem.__super__.constructor.call(this, sybil.templates["rss-list-item"]);
        this.parent = parent;
        this.init(data);
        this.appendTo(this.parent.UI.listContainer);
      }

      RssListItem.prototype.init = function(data) {
        this.data = data;
        this.UI.name$.text(data.title || "anonymous");
        this.UI.count$.text(data.unreadCount || 0);
        if (data.unreadCount === 0) {
          return this.node$.addClass("empty");
        }
      };

      RssListItem.prototype.remove = function() {
        var _this = this;
        RssListItem.__super__.remove.call(this);
        return this.parent.items = this.parent.item.filter(function(item) {
          return item !== _this;
        });
      };

      RssListItem.prototype.onClickNode = function() {
        return sybil.router.goto("/rss/" + (this.data.id.escapeBase64()));
      };

      RssListItem.prototype.focus = function() {
        var item, _i, _len, _ref;
        _ref = this.parent.items;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          item = _ref[_i];
          item.unfocus();
        }
        this.node$.addClass("focus");
        return this.parent.currentFocusedItem = this;
      };

      RssListItem.prototype.unfocus = function() {
        return this.node$.removeClass("focus");
      };

      return RssListItem;

    })(Leaf.Widget);

    RssList.prototype.landing = function() {
      var _this = this;
      return this.sync(function() {
        return _this.emit("firstSync");
      });
    };

    RssList.prototype.addRss = function(data) {
      return this.items.push(new RssListItem(data, this));
    };

    RssList.prototype.getListItemById = function(id) {
      var item, _i, _len, _ref;
      _ref = this.items;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        if (item.data.id === id) {
          return item;
        }
      }
      return null;
    };

    RssList.prototype.getRssById = function(id, callback) {
      var item, _i, _len, _ref,
        _this = this;
      _ref = this.items;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        if (item.data.id === id) {
          return callback(null, item.data);
        }
      }
      this.sync(function(err) {
        var _j, _len1, _ref1;
        if (err) {
          callback(new Error("not found"));
        }
        _ref1 = _this.items;
        for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
          item = _ref1[_j];
          if (item.data.id === id) {
            return callback(null, item.data);
          }
        }
        return callback(new Error("not found"));
      });
    };

    RssList.prototype.onClickSubscribeButton = function() {
      var rssUrl,
        _this = this;
      rssUrl = this.UI.rssInput.value;
      return API.subscribe(rssUrl).success(function(data) {
        sybil.hint("done");
        return _this.sync();
      });
    };

    RssList.prototype.gotoNextUnreadRss = function() {
      var index, item, start, _i, _len, _ref, _results;
      if (!this.currentFocusedItem) {
        start = -1;
      } else {
        start = this.items.indexOf(this.currentFocusedItem);
      }
      _ref = this.items;
      _results = [];
      for (index = _i = 0, _len = _ref.length; _i < _len; index = ++_i) {
        item = _ref[index];
        if (index > start && item.data.unreadCount > 0) {
          item.onClickNode();
          break;
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    };

    RssList.prototype.sync = function(callback) {
      var _this = this;
      this.syncCallbacks = this.syncCallbacks || [];
      if (callback) {
        this.syncCallbacks.push(callback);
      }
      return API.rss().success(function(rsses) {
        var item, _callback, _i, _j, _len, _len1, _ref, _results;
        for (_i = 0, _len = rsses.length; _i < _len; _i++) {
          item = rsses[_i];
          _this.addRss(item);
        }
        if (!sybil.feedList.currentRss && _this.items[0]) {
          sybil.router.goto("/rss/" + (_this.items[0].data.id.escapeBase64()));
          _ref = _this.syncCallbacks;
          _results = [];
          for (_j = 0, _len1 = _ref.length; _j < _len1; _j++) {
            _callback = _ref[_j];
            _results.push(_callback(null, rsses));
          }
          return _results;
        }
      }).fail(function(err) {
        console.error(err);
        console.error("fail to get rss list");
        return callback(err);
      });
    };

    return RssList;

  })(Leaf.Widget);

  window.RssList = RssList;

}).call(this);
