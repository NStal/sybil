// Generated by CoffeeScript 1.8.0
(function() {
  var App, ArchiveDisplayer, ArchiveList, ArchiveListItem, CubeLoadingHint, List, ListArchiveDisplayer, ListItem, ListView, Model, ScrollChecker, SwipeChecker, View, moment, tm,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  App = require("/app");

  SwipeChecker = require("/util/swipeChecker");

  Model = require("/model");

  View = require("/view");

  ArchiveDisplayer = require("/baseView/archiveDisplayer");

  ScrollChecker = require("/util/scrollChecker");

  CubeLoadingHint = require("/widget/cubeLoadingHint");

  moment = require("/lib/moment");

  tm = require("/templateManager");

  ListView = (function(_super) {
    __extends(ListView, _super);

    function ListView() {
      var checker;
      this.list = new List();
      this.archives = new ArchiveList();
      this.archiveDisplayer = new ListArchiveDisplayer();
      this.list.on("init", (function(_this) {
        return function() {
          if (_this.isShow) {
            return _this.show();
          }
        };
      })(this));
      this.list.on("select", (function(_this) {
        return function(list) {
          _this.archives.load(list.archiveList);
          return _this.slideTo(1);
        };
      })(this));
      this.archives.on("archive", (function(_this) {
        return function() {
          console.debug("slide to 1");
          return _this.slideTo(1);
        };
      })(this));
      this.archives.on("select", (function(_this) {
        return function(archiveListItem) {
          _this.archiveDisplayer.display(archiveListItem.archive);
          if (_this.currentArchiveListItem) {
            _this.currentArchiveListItem.deselect();
          }
          _this.currentArchiveListItem = archiveListItem;
          _this.slideTo(2);
          return _this.enableArchiveAutoSlide = true;
        };
      })(this));
      ListView.__super__.constructor.call(this, $(".list-view")[0], "list view");
      checker = new SwipeChecker(this.node);
      checker.on("swiperight", (function(_this) {
        return function(ev) {
          return _this.previousSlide();
        };
      })(this));
      checker.on("swipeleft", (function(_this) {
        return function(ev) {
          return _this.nextSlide();
        };
      })(this));
      this.currentSlide = 0;
    }

    ListView.prototype.slideTo = function(count) {
      if (count < 0) {
        count = 0;
      }
      if (count > 2) {
        count = 2;
      }
      this.currentSlide = count;
      return this.applySlide();
    };

    ListView.prototype.nextSlide = function() {
      return this.slideTo(this.currentSlide + 1 || 2);
    };

    ListView.prototype.previousSlide = function() {
      if (this.currentSlide <= 0) {
        return;
      }
      return this.slideTo(this.currentSlide - 1 || 0);
    };

    ListView.prototype.applySlide = function() {
      if (this.currentSlide === 0) {
        return this.node$.removeClass("slide-col2").removeClass("slide-col3");
      } else if (this.currentSlide === 1) {
        return this.node$.addClass("slide-col2").removeClass("slide-col3");
      } else if (this.currentSlide === 2) {
        if (!this.archiveDisplayer.archive) {
          return;
        }
        return this.node$.addClass("slide-col2").addClass("slide-col3");
      }
    };

    ListView.prototype.show = function() {
      if (!this.list.current && this.list.lists.length > 0) {
        this.list.lists[0].select();
      }
      return ListView.__super__.show.call(this);
    };

    return ListView;

  })(View);

  tm.use("listView/listViewList");

  List = (function(_super) {
    __extends(List, _super);

    function List() {
      List.__super__.constructor.call(this, App.templates.listView.listViewList);
      this.lists = Leaf.Widget.makeList(this.UI.container);
      App.afterInitialLoad((function(_this) {
        return function() {
          return Model.ArchiveList.sync(function() {
            return _this.emit("init");
          });
        };
      })(this));
      App.modelSyncManager.on("archiveList/add", (function(_this) {
        return function(list) {
          return _this.lists.push(new ListItem(list));
        };
      })(this));
      this.lists.on("child/add", (function(_this) {
        return function(list) {
          return _this.bubble(list, "select", function() {
            if (this.current) {
              this.current.node$.removeClass("select");
            }
            this.current = list;
            return ["select", list];
          });
        };
      })(this));
    }

    List.prototype.onClickAddListButton = function() {
      var name;
      name = prompt("enter you list name");
      if (!name || !name.trim()) {
        return;
      }
      name = name.trim();
      return Model.ArchiveList.create(name, (function(_this) {
        return function(err, list) {
          console.debug("create list", err, list);
          if (err) {
            return App.showError(err);
          }
        };
      })(this));
    };

    return List;

  })(Leaf.Widget);

  tm.use("listView/listViewListItem");

  ListItem = (function(_super) {
    __extends(ListItem, _super);

    function ListItem(archiveList) {
      this.archiveList = archiveList;
      this.onClickNode = __bind(this.onClickNode, this);
      ListItem.__super__.constructor.call(this, App.templates.listView.listViewListItem);
      this.archiveList.on("add", (function(_this) {
        return function(archive) {
          return _this.render();
        };
      })(this));
      this.archiveList.on("remove", (function(_this) {
        return function(archive) {
          return _this.render();
        };
      })(this));
      this.archiveList.on("change", (function(_this) {
        return function() {
          return _this.render();
        };
      })(this));
      this.render();
    }

    ListItem.prototype.render = function() {
      this.UI.name$.text(this.archiveList.name);
      this.UI.unreadCounter$.text(this.archiveList.count);
      return this.name = this.archiveList.name;
    };

    ListItem.prototype.select = function() {
      this.emit("select", this);
      return this.node$.addClass("select");
    };

    ListItem.prototype.onClickNode = function() {
      return this.select();
    };

    return ListItem;

  })(Leaf.Widget);

  tm.use("listView/listViewArchiveList");

  ArchiveList = (function(_super) {
    __extends(ArchiveList, _super);

    function ArchiveList() {
      this.include(CubeLoadingHint);
      ArchiveList.__super__.constructor.call(this, App.templates.listView.listViewArchiveList);
      this.archives = Leaf.Widget.makeList(this.UI.archives);
      this.archives.on("child/add", (function(_this) {
        return function(archiveListItem) {
          archiveListItem.listName = _this.currentList.name;
          return archiveListItem.listenBy(_this, "select", function() {
            return _this.emit("select", archiveListItem);
          });
        };
      })(this));
      this.archives.on("child/remove", (function(_this) {
        return function(item) {};
      })(this));
      this.scrollChecker = new ScrollChecker(this.node);
      this.scrollChecker.on("scrollBottom", (function(_this) {
        return function() {
          return _this.more();
        };
      })(this));
    }

    ArchiveList.prototype.load = function(list) {
      if (this.currentList) {
        this.currentList.stopListenBy(this);
      }
      this.currentList = list;
      this.currentList.listenBy(this, "add", this.prependArchive);
      this.currentList.listenBy(this, "remove", this.removeArchive);
      this.archives.length = 0;
      this.noMore = false;
      this.UI.loadingHint.hide();
      return this.more();
    };

    ArchiveList.prototype.more = function() {
      var list, loadCount;
      if (this.noMore) {
        return;
      }
      loadCount = 20;
      list = this.currentList;
      this.UI.loadingHint.show();
      return this.currentList.getArchives({
        offset: this.archives.length,
        count: loadCount
      }, (function(_this) {
        return function(err, archives) {
          var archive, _i, _len;
          if (_this.currentList !== list) {
            return;
          }
          _this.UI.loadingHint.hide();
          for (_i = 0, _len = archives.length; _i < _len; _i++) {
            archive = archives[_i];
            _this.archives.push(new ArchiveListItem(archive));
          }
          if (archives.length !== loadCount) {
            return _this.noMore = true;
          }
        };
      })(this));
    };

    ArchiveList.prototype.prependArchive = function(archive) {
      var item, _i, _len, _ref;
      _ref = this.archives;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        if (item.archive.guid === archive.guid) {
          if (item.isDone) {
            item.isDone = false;
            item.render();
          }
          return;
        }
      }
      this.emit("archive");
      return this.archives.unshift(new ArchiveListItem(archive));
    };

    ArchiveList.prototype.removeArchive = function(archive) {
      var index, item, _i, _len, _ref;
      _ref = this.archives;
      for (index = _i = 0, _len = _ref.length; _i < _len; index = ++_i) {
        item = _ref[index];
        if (item.archive.guid === archive.guid) {
          if (!item.isDone) {
            item.isDone = true;
            item.render();
            return;
          }
        }
      }
    };

    ArchiveList.prototype.onClickMoreButton = function() {
      return this.more();
    };

    return ArchiveList;

  })(Leaf.Widget);

  tm.use("listView/listViewArchiveListItem");

  ArchiveListItem = (function(_super) {
    __extends(ArchiveListItem, _super);

    function ArchiveListItem(archive) {
      this.archive = archive;
      ArchiveListItem.__super__.constructor.call(this, App.templates.listView.listViewArchiveListItem);
      this.render();
      this.isDone = false;
    }

    ArchiveListItem.prototype.onClickNode = function() {
      return this.select();
    };

    ArchiveListItem.prototype.select = function() {
      this.emit("select", this);
      return this.node$.addClass("select");
    };

    ArchiveListItem.prototype.deselect = function() {
      return this.node$.removeClass("select");
    };

    ArchiveListItem.prototype.render = function() {
      this.UI.title$.text(this.archive.title);
      this.UI.content$.text(this.genPreview(this.archive.content));
      if (!this.isDone) {
        return this.node$.removeClass("clear");
      } else {
        return this.node$.addClass("clear");
      }
    };

    ArchiveListItem.prototype.markAsDone = function() {
      if (this.isDone) {
        return;
      }
      return this.archive.changeList(null, (function(_this) {
        return function(err) {
          _this.isDone = true;
          return _this.render();
        };
      })(this));
    };

    ArchiveListItem.prototype.markAsUndone = function() {
      if (!this.isDone) {
        return;
      }
      return this.archive.changeList(this.listName, (function(_this) {
        return function(err) {
          _this.isDone = false;
          return _this.render();
        };
      })(this));
    };

    ArchiveListItem.prototype.onClickDone = function(e) {
      if (e) {
        e.preventDefault();
        e.stopImmediatePropagation();
      }
      if (this.isDone) {
        return this.markAsUndone();
      } else {
        return this.markAsDone();
      }
    };

    ArchiveListItem.prototype.genPreview = function(content) {
      var container, maxLength, result;
      container = document.createElement("div");
      container.innerHTML = content;
      maxLength = 50;
      result = $(container).text().trim().substring(0, maxLength);
      if (result.length === maxLength) {
        result += "...";
      } else if (result.length === 0) {
        result = "( empty )";
      }
      return result;
    };

    return ArchiveListItem;

  })(Leaf.Widget);

  tm.use("baseView/archiveDisplayer");

  ListArchiveDisplayer = (function(_super) {
    __extends(ListArchiveDisplayer, _super);

    function ListArchiveDisplayer() {
      ListArchiveDisplayer.__super__.constructor.call(this, App.templates.baseView.archiveDisplayer);
      this.node$.addClass("no-article");
    }

    ListArchiveDisplayer.prototype.display = function(archive) {
      this.node$.removeClass("no-article");
      this.setArchive(archive);
      this.node.scrollTop = 0;
      return this.render();
    };

    return ListArchiveDisplayer;

  })(ArchiveDisplayer);

  module.exports = ListView;

}).call(this);