// Generated by CoffeeScript 1.8.0
(function() {
  var ContextMenu, CoreData, DragContext, Model, SmartImage, SourceAuthorizeTerminal, SourceList, SourceListDragController, SourceListFolder, SourceListItem, SourceListItemBase, SourceListManager, tm,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    __slice = [].slice,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  tm = require("/templateManager");

  CoreData = require("/coreData");

  DragContext = require("/util/dragContext");

  ContextMenu = require("/widget/contextMenu");

  SourceAuthorizeTerminal = require("/sourceUtil/sourceAuthorizeTerminal");

  Model = require("/model");

  SmartImage = require("/widget/smartImage");

  tm.use("sourceView/sourceList");

  SourceListManager = (function(_super) {
    __extends(SourceListManager, _super);

    function SourceListManager(context) {
      this.context = context;
      SourceListManager.__super__.constructor.call(this);
      this.debug();
      this.folderCoreData = new CoreData("sourceFolderConfig");
      this.reset();
    }

    SourceListManager.prototype.reset = function() {
      this.data.structures = [];
      return this.data.flatStructures = [];
    };

    SourceListManager.prototype.init = function() {
      if (this.state === !"void") {
        return;
      }
      return this.setState("prepareCoreData");
    };

    SourceListManager.prototype.save = function() {
      clearTimeout(this.timer);
      return this.timer = setTimeout(this._save.bind(this), 500);
    };

    SourceListManager.prototype._save = function() {
      var folders, item, p, _i, _j, _len, _len1, _ref;
      folders = [];
      _ref = this.data.flatStructures;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        if (item.type === "folder") {
          folders.push({
            name: item.model.name,
            type: "folder",
            children: [],
            collapse: item.model.collapse
          });
        } else if (item.type === "source") {
          if (item.parent) {
            for (_j = 0, _len1 = folders.length; _j < _len1; _j++) {
              p = folders[_j];
              if (p.name === item.parent.model.name) {
                p.children.push({
                  name: item.model.name,
                  guid: item.model.guid,
                  type: "source"
                });
                break;
              }
            }
          } else {
            folders.push({
              name: item.model.name,
              guid: item.model.guid,
              type: "source"
            });
          }
        }
      }
      return this.folderCoreData.set("folders", folders);
    };

    SourceListManager.prototype.packAt = function(index) {
      return this.data.flatStructures[index];
    };

    SourceListManager.prototype.logicPackAfter = function(index) {
      var item, next;
      item = this.packAt(index);
      if (!item) {
        return null;
      }
      if (item.type === "source" && !item.parent) {
        return this.packAt(index + 1);
      } else if (item.type === "source" && item.parent) {
        while (true) {
          index++;
          next = this.packAt(index);
          if (!next) {
            return null;
          }
          if (next.parent === item.parent) {
            continue;
          }
          return next;
        }
      } else if (item.type === "folder") {
        while (true) {
          index++;
          next = this.packAt(index);
          if (!next) {
            return null;
          }
          if (next.parent === item) {
            continue;
          }
          return next;
        }
      }
      return null;
    };

    SourceListManager.prototype.updatePackDimension = function() {
      var hidden, index, item, posIndex, _i, _len, _ref;
      posIndex = 0;
      _ref = this.data.flatStructures;
      for (index = _i = 0, _len = _ref.length; _i < _len; index = ++_i) {
        item = _ref[index];
        item.flatIndex = index;
        hidden = false;
        if (item.parent) {
          if (!item.parent.model.collapse) {
            hidden = true;
            item.hide = true;
          } else {
            hidden = false;
            item.hide = false;
          }
          item.indent = 1;
        } else {
          item.indent = 0;
        }
        item.position = posIndex;
        if (item.type === "folder" && item.model.collapse) {
          item.expand = item.model.children.length + 1;
        } else {
          item.expand = null;
        }
        if (!hidden) {
          posIndex += 1;
        }
      }
      return this.save();
    };

    SourceListManager.prototype.addFolder = function(name) {
      var folder, info, item, _i, _len, _ref;
      if (name instanceof Model.SourceFolder) {
        folder = name;
      } else {
        folder = new Model.SourceFolder({
          name: name.toString(),
          collapse: true,
          type: "folder",
          children: []
        });
      }
      _ref = this.data.flatStructures;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        if (item.type === "folder" && item.name === folder.name) {
          console.error("can't create duplicate folder");
          return;
        }
      }
      info = {
        type: "folder",
        model: folder,
        name: name,
        parent: null
      };
      this.data.flatStructures.unshift(info);
      this.updatePackDimension();
      this.context.children.push(new SourceListFolder(info, this.context));
    };

    SourceListManager.prototype.addSource = function(source) {
      var info;
      info = {
        type: "source",
        model: source,
        name: name,
        parent: null
      };
      this.data.flatStructures.unshift(info);
      this.updatePackDimension();
      this.context.children.push(new SourceListItem(info, this.context));
    };

    SourceListManager.prototype.removeSource = function(pack) {
      var child, cindex, index, item, _i, _j, _len, _len1, _ref, _ref1;
      if (pack.type !== "source") {
        return;
      }
      _ref = this.data.flatStructures;
      for (index = _i = 0, _len = _ref.length; _i < _len; index = ++_i) {
        item = _ref[index];
        if (item === pack) {
          if (pack.parent) {
            _ref1 = pack.parent.model.children;
            for (cindex = _j = 0, _len1 = _ref1.length; _j < _len1; cindex = ++_j) {
              child = _ref1[cindex];
              if (child === pack.model) {
                pack.parent.model.children.splice(cindex, 1);
                break;
              }
            }
          }
          this.data.flatStructures.splice(index, 1);
          break;
        }
      }
      return this.updatePackDimension();
    };

    SourceListManager.prototype.removeFolder = function(pack) {
      var index, item, target, _i, _len, _ref;
      if (pack.type !== "folder") {
        return;
      }
      _ref = this.data.flatStructures;
      for (index = _i = 0, _len = _ref.length; _i < _len; index = ++_i) {
        item = _ref[index];
        if (item === pack) {
          target = index;
        } else if (item.parent === pack) {
          item.parent = null;
        }
      }
      if (typeof target === "number") {
        this.data.flatStructures.splice(target, 1);
      }
      console.debug("remove folder", pack, this.data.flatStructures);
      return this.updatePackDimension();
    };

    SourceListManager.prototype._move = function(pack, position) {
      var count, insertion, target, _ref, _ref1;
      if (position == null) {
        position = this.data.flatStructures.length;
      }
      target = this.data.flatStructures[position];
      if (target && target.parent && pack.type === "folder") {
        return;
      }
      if (target && pack === target.parent) {
        return;
      }
      if (pack.type === "folder") {
        count = pack.model.children.length + 1;
      } else {
        count = 1;
      }
      insertion = this.data.flatStructures.splice(pack.flatIndex, count) || [];
      if (pack.flatIndex < position) {
        position -= count;
      }
      if (position < 0) {
        position = 0;
      }
      if (position < this.data.flatStructures.length) {
        (_ref = this.data.flatStructures).splice.apply(_ref, [position, 0].concat(__slice.call(insertion)));
      } else {
        (_ref1 = this.data.flatStructures).push.apply(_ref1, insertion);
      }
      return this.updatePackDimension();
    };

    SourceListManager.prototype._setParent = function(pack, parentPack) {
      var folder;
      if (pack.parent === parentPack) {
        return;
      }
      if (pack.parent) {
        folder = pack.parent.model;
        folder.children = folder.children.filter(function(item) {
          return item !== pack.model;
        });
        pack.parent = null;
      }
      if (parentPack) {
        pack.parent = parentPack;
        return parentPack.model.children.push(pack.model);
      }
    };

    SourceListManager.prototype.atPrepareCoreData = function(sole) {
      return this.folderCoreData.load((function(_this) {
        return function(err) {
          if (_this.stale(sole)) {
            return;
          }
          if (err) {
            _this.error(err);
            return;
          }
          return _this.setState("syncSources");
        };
      })(this));
    };

    SourceListManager.prototype.atSyncSources = function(sole) {
      return Model.Source.sources.sync((function(_this) {
        return function() {
          return _this.setState("buildStructure");
        };
      })(this));
    };

    SourceListManager.prototype.atBuildStructure = function() {
      var child, contains, folder, item, items, source, _i, _j, _k, _len, _len1, _len2, _ref, _ref1, _ref2, _ref3, _ref4;
      this.data.structures = [];
      contains = [];
      items = (this.folderCoreData.get("folders")) || [];
      for (_i = 0, _len = items.length; _i < _len; _i++) {
        item = items[_i];
        if (item.type === "folder") {
          folder = new Model.SourceFolder({
            name: item.name,
            type: "folder",
            collapse: item.collapse
          });
          if (folder.children == null) {
            folder.children = [];
          }
          _ref = item.children || [];
          for (_j = 0, _len1 = _ref.length; _j < _len1; _j++) {
            child = _ref[_j];
            if (_ref1 = child.guid, __indexOf.call(contains, _ref1) >= 0) {
              continue;
            }
            source = Model.Source.sources.findOne({
              guid: child.guid
            });
            contains.push(child.guid);
            if (source) {
              folder.children.push(source);
            }
          }
          this.data.structures.push(folder);
        } else if (item.type === "source") {
          if (_ref2 = item.guid, __indexOf.call(contains, _ref2) >= 0) {
            continue;
          }
          source = Model.Source.sources.findOne({
            guid: item.guid
          });
          contains.push(source.guid);
          if (source) {
            this.data.structures.push(source);
          }
        }
      }
      _ref3 = Model.Source.sources.models;
      for (_k = 0, _len2 = _ref3.length; _k < _len2; _k++) {
        source = _ref3[_k];
        if (_ref4 = source.guid, __indexOf.call(contains, _ref4) < 0) {
          this.data.structures.push(source);
        }
      }
      return this.setState("buildFlatStructures");
    };

    SourceListManager.prototype.atBuildFlatStructures = function() {
      var childIndex, cindex, folder, index, item, pindex, source, _i, _j, _len, _len1, _ref, _ref1;
      _ref = this.data.structures;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        if (item instanceof Model.SourceFolder) {
          pindex = this.data.flatStructures.length;
          folder = {
            name: item.name,
            type: "folder",
            parent: null,
            flatIndex: pindex,
            model: item
          };
          this.data.flatStructures.push(folder);
          _ref1 = item.children;
          for (childIndex = _j = 0, _len1 = _ref1.length; _j < _len1; childIndex = ++_j) {
            source = _ref1[childIndex];
            cindex = this.data.flatStructures.length;
            this.data.flatStructures.push({
              name: source.name,
              type: "source",
              parent: folder,
              flatIndex: cindex,
              model: source
            });
          }
        } else {
          index = this.data.flatStructures.length;
          this.data.flatStructures.push({
            name: item.name,
            type: "source",
            parent: null,
            flatIndex: index,
            model: item
          });
        }
      }
      this.updatePackDimension();
      return this.setState("fillSourceList");
    };

    SourceListManager.prototype.atFillSourceList = function() {
      var child, item, _i, _len, _ref;
      this.context.children.length = 0;
      _ref = this.data.flatStructures;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        if (item.type === "folder") {
          child = new SourceListFolder(item, this.context);
        } else if (item.type === "source") {
          child = new SourceListItem(item, this.context);
        } else {
          continue;
        }
        this.context.children.push(child);
      }
      this.context.reflow();
      return this.setState("wait");
    };

    SourceListManager.prototype.atWait = function() {
      App.modelSyncManager.listenBy(this, "source", (function(_this) {
        return function(source) {
          _this.addSource(source);
        };
      })(this));
    };

    return SourceListManager;

  })(Leaf.States);

  SourceList = (function(_super) {
    __extends(SourceList, _super);

    function SourceList() {
      SourceList.__super__.constructor.call(this, App.templates.sourceView.sourceList);
      this.children = Leaf.Widget.makeList(this.UI.container);
      this.relations = [];
      this.manager = new SourceListManager(this);
      this.dragController = new SourceListDragController(this);
      App.afterInitialLoad((function(_this) {
        return function() {
          return _this.manager.init();
        };
      })(this));
    }

    SourceList.prototype.updateItemHeight = function() {
      var item, _i, _len, _ref;
      _ref = this.children;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        if (item.pack.type === "source" && !item.isHide) {
          this.itemHeight = item.node$.height();
          return;
        }
      }
      return this.itemHeight = 36;
    };

    SourceList.prototype.reflow = function() {
      var item, _i, _len, _ref, _results;
      this.updateItemHeight();
      _ref = this.children;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        if (item.pack.hide) {
          item.hide();
        } else {
          item.show();
        }
        item.indent(item.pack.indent || 0);
        item.node$.css({
          transform: "translateY(" + (item.pack.position * this.itemHeight) + "px)",
          zIndex: item.pack.position + 1
        });
        if (item.pack.expand) {
          _results.push(item.node$.css({
            height: item.pack.expand * this.itemHeight
          }));
        } else {
          _results.push(item.node$.css({
            height: "auto"
          }));
        }
      }
      return _results;
    };

    SourceList.prototype.onClickAddSourceButton = function() {
      return App.addSourcePopup.show();
    };

    SourceList.prototype.onClickAddFolderButton = function() {
      var name;
      name = (prompt("name", "untitled") || "").trim();
      if (!name) {
        return;
      }
      this.manager.addFolder(name);
      return this.reflow();
    };

    return SourceList;

  })(Leaf.Widget);

  SourceListItemBase = (function(_super) {
    __extends(SourceListItemBase, _super);

    function SourceListItemBase(template, pack) {
      SourceListItemBase.__super__.constructor.call(this, template);
    }

    SourceListItemBase.prototype.active = function() {
      var item, _i, _len, _ref;
      if (this.context) {
        _ref = this.context.children;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          item = _ref[_i];
          item.deactive();
        }
      }
      this.node.classList.add("active");
      return this.isActive = true;
    };

    SourceListItemBase.prototype.deactive = function() {
      this.node.classList.remove("active");
      return this.isActive = false;
    };

    SourceListItemBase.prototype.indent = function(level) {
      if (this.indentLevel === level) {
        return;
      }
      if (level === 0) {
        this.node$.removeClass("indent");
      } else {
        this.node$.addClass("indent");
      }
      return this.indentLevel = level;
    };

    SourceListItemBase.prototype.hide = function() {
      if (this.isHide) {
        return;
      }
      this.isHide = true;
      return this.node$.addClass("hide");
    };

    SourceListItemBase.prototype.show = function() {
      if (!this.isHide) {
        return;
      }
      this.isHide = false;
      return this.node$.removeClass("hide");
    };

    return SourceListItemBase;

  })(Leaf.Widget);

  tm.use("sourceView/sourceListItem");

  SourceListItem = (function(_super) {
    var SourceListItemContextMenu;

    __extends(SourceListItem, _super);

    SourceListItemContextMenu = (function(_super1) {
      __extends(SourceListItemContextMenu, _super1);

      function SourceListItemContextMenu(item) {
        this.item = item;
        this.selections = [
          {
            name: "source detail",
            callback: this.showSourceDetail.bind(this)
          }, {
            name: "unsubscribe",
            callback: this.unsubscribe.bind(this)
          }
        ];
        SourceListItemContextMenu.__super__.constructor.call(this, this.selections);
      }

      SourceListItemContextMenu.prototype.showSourceDetail = function() {
        return this.item.showSourceDetail();
      };

      SourceListItemContextMenu.prototype.unsubscribe = function() {
        if (!confirm("unsubscribe item " + this.item.source.name + "?")) {
          return;
        }
        return this.item.unsubscribe();
      };

      return SourceListItemContextMenu;

    })(ContextMenu);

    function SourceListItem(pack, context) {
      this.pack = pack;
      this.context = context;
      this.include(SmartImage);
      SourceListItem.__super__.constructor.call(this, App.templates.sourceView.sourceListItem);
      this.source = this.pack.model;
      this.source.on("change", this.render.bind(this));
      this.node.oncontextmenu = (function(_this) {
        return function(e) {
          e.preventDefault();
          e.stopImmediatePropagation();
          if (!_this.contextMenu) {
            _this.contextMenu = new SourceListItemContextMenu(_this);
          }
          return _this.contextMenu.show(e);
        };
      })(this);
      this.render();
    }

    SourceListItem.prototype.render = function() {
      var bigErrorTime, lastErrorDate, smallErrorTime, style;
      this.VM.name = this.source.name;
      this.VM.guid = this.source.guid;
      this.VM.unreadCount = (parseInt(this.source.unreadCount) >= 0) && parseInt(this.source.unreadCount).toString() || "?";
      style = "no-update";
      if (parseInt(this.source.unreadCount) > 0) {
        style = "has-update";
      }
      if (parseInt(this.source.unreadCount) >= 20) {
        style = "many-update";
      }
      this.VM.statusStyle = style;
      this.VM.state = "ok";
      smallErrorTime = 1000 * 60 * 60;
      bigErrorTime = 1000 * 60 * 60 * 24 * 2;
      if (this.source.lastError) {
        if (this.source.lastErrorDate) {
          lastErrorDate = (Date.now() - new Date(this.source.lastErrorDate).getTime()) || 0;
        } else {
          lastErrorDate = -1;
        }
        if (lastErrorDate < 0) {
          this.VM.state = "warn";
        } else if (lastErrorDate < smallErrorTime) {
          this.VM.state = "unhealthy";
        } else if (lastErrorDate < bigErrorTime) {
          this.VM.state = "warn";
        } else {
          this.VM.state = "error";
        }
      }
      if (this.source.requireLocalAuth) {
        this.VM.state = "error";
      }
      this.UI.sourceIcon.loadingSrc = "/image/favicon-default.png";
      this.UI.sourceIcon.errorSrc = "/image/favicon-default.png";
      return this.UI.sourceIcon.src = "plugins/iconProxy?url=" + (encodeURIComponent(this.source.uri));
    };

    SourceListItem.prototype.unsubscribe = function(callback) {
      this.context.children.removeItem(this);
      this.context.manager.removeSource(this.pack);
      return this.context.reflow();
    };

    SourceListItem.prototype.showSourceDetail = function() {
      App.sourceView.sourceDetail.setSource(this.source);
      return App.sourceView.sourceDetail.show();
    };

    SourceListItem.prototype.onClickNode = function(e) {
      console.debug("hehe");
      e.capture();
      this.active();
      if (this.source.requireLocalAuth) {
        if (this.source.authorizeTerminal) {
          this.source.authorizeTerminal.hide();
        }
        this.source.authorizeTerminal = new SourceAuthorizeTerminal(this.source);
      }
      return this.context.emit("select", {
        type: "source",
        sourceGuids: [this.source.guid],
        name: this.source.name
      });
    };

    return SourceListItem;

  })(SourceListItemBase);

  tm.use("sourceView/sourceListFolder");

  SourceListFolder = (function(_super) {
    var SourceListFolderContextMenu;

    __extends(SourceListFolder, _super);

    SourceListFolderContextMenu = (function(_super1) {
      __extends(SourceListFolderContextMenu, _super1);

      function SourceListFolderContextMenu(folder) {
        this.folder = folder;
        this.selections = [
          {
            name: "remove folder",
            callback: this["delete"].bind(this)
          }, {
            name: "rename folder",
            callback: this.rename.bind(this)
          }
        ];
        SourceListFolderContextMenu.__super__.constructor.call(this, this.selections);
      }

      SourceListFolderContextMenu.prototype.rename = function() {
        var name;
        name = prompt("folder name", this.folder.model.name);
        if (name && name.trim()) {
          this.folder.model.name = name;
          this.folder.pack.name = name;
          return this.folder.context.manager.save();
        }
      };

      SourceListFolderContextMenu.prototype["delete"] = function() {
        if (!confirm("remove this folder " + this.folder.model.name + "(source will be kept)?")) {
          return;
        }
        return this.folder.removeFolder();
      };

      return SourceListFolderContextMenu;

    })(ContextMenu);

    function SourceListFolder(pack, context) {
      this.pack = pack;
      this.context = context;
      SourceListFolder.__super__.constructor.call(this, App.templates.sourceView.sourceListFolder);
      this.model = this.pack.model;
      this.model.listenBy(this, "change", this.render.bind(this));
      this.node.oncontextmenu = (function(_this) {
        return function(e) {
          e.preventDefault();
          e.stopImmediatePropagation();
          if (!_this.contextMenu) {
            _this.contextMenu = new SourceListFolderContextMenu(_this);
          }
          return _this.contextMenu.show(e);
        };
      })(this);
      this.render();
    }

    SourceListFolder.prototype.onClickFolderIcon = function(e) {
      e.capture();
      this.model.collapse = !this.model.collapse;
      return this.render();
    };

    SourceListFolder.prototype.onClickNode = function() {
      var child;
      this.active();
      return this.context.emit("select", {
        type: "folder",
        sourceGuids: (function() {
          var _i, _len, _ref, _results;
          _ref = this.model.children;
          _results = [];
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            child = _ref[_i];
            _results.push(child.guid);
          }
          return _results;
        }).call(this),
        name: this.model.name
      });
    };

    SourceListFolder.prototype.removeFolder = function() {
      this.context.children.removeItem(this);
      this.context.manager.removeFolder(this.pack);
      return this.context.reflow();
    };

    SourceListFolder.prototype.render = function() {
      var item, style, unreadCount, _i, _len, _ref;
      unreadCount = 0;
      _ref = this.model.children;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        if (typeof item.unreadCount === "number") {
          unreadCount += item.unreadCount;
        }
      }
      this.VM.name = this.model.name;
      this.VM.unreadCount = unreadCount;
      if (this.VM.collapse !== this.model.collapse) {
        this.VM.collapse = this.model.collapse;
        this.context.manager.updatePackDimension();
        this.context.reflow();
      }
      style = "no-update";
      if (parseInt(unreadCount) > 0) {
        style = "has-update";
      }
      if (parseInt(unreadCount) >= 20) {
        style = "many-update";
      }
      this.VM.statusStyle = style;
      if (!this.model.collapse) {
        return this.VM.iconClass = "fa-folder";
      } else {
        return this.VM.iconClass = "fa-folder-open";
      }
    };

    SourceListFolder.prototype.toggleCollapse = function(e) {
      return this.model.collapse = !this.model.collapse;
    };

    return SourceListFolder;

  })(SourceListItemBase);

  SourceListDragController = (function(_super) {
    __extends(SourceListDragController, _super);

    function SourceListDragController(context) {
      this.context = context;
      this.dragContext = new DragContext();
      this.dragContext.on("start", (function(_this) {
        return function(e) {
          var shadow;
          shadow = document.createElement("span");
          shadow.style.color = "white";
          shadow.classList.add("no-interaction");
          shadow.innerHTML = e.draggable.innerText.trim().substring(0, 30);
          return _this.dragContext.addDraggingShadow(shadow);
        };
      })(this));
      this.dragContext.on("drop", (function(_this) {
        return function(e) {
          return _this.drop(e.draggable.widget, e.droppable.widget, e);
        };
      })(this));
      this.dragContext.on("hover", (function(_this) {
        return function(e) {
          return _this.drop(e.draggable.widget, e.droppable.widget, e);
        };
      })(this));
      this.context.children.on("child/add", this.addToContext.bind(this));
      this.context.children.on("child/remove", this.removeFromContext.bind(this));
    }

    SourceListDragController.prototype.addToContext = function(item) {
      if (item instanceof SourceListItem) {
        return this.dragContext.addContext(item.node);
      } else if (item instanceof SourceListFolder) {
        return this.dragContext.addContext(item.UI.title);
      } else {
        throw new Error("add invalid drag item");
      }
    };

    SourceListDragController.prototype.removeFromContext = function(item) {
      if (item instanceof SourceListItem) {
        return this.dragContext.addContext(item.node);
      } else if (item instanceof SourceListFolder) {
        return this.dragContext.addContext(item.UI.title);
      }
    };

    SourceListDragController.prototype.getDropType = function(from, to, e) {
      var height;
      e = e.offsetY;
      if (to.pack.type === "folder") {
        height = to.UI.title$.height();
      } else {
        height = to.node$.height();
      }
      if (e > height / 2) {
        return "after";
      } else {
        return "before";
      }
    };

    SourceListDragController.prototype.drop = function(from, to, e) {
      var dropType, fromPack, next, toPack;
      if (from === to) {
        return;
      }
      dropType = this.getDropType(from, to, e);
      fromPack = from.pack;
      toPack = to.pack;
      if (fromPack.type === "folder" && toPack.parent) {
        next = this.context.manager.packAt(toPack.flatIndex + 1);
        if (next && next.parent !== toPack.parent) {
          this.context.manager._move(fromPack, next.flatIndex);
        }
      } else if (fromPack.type === "folder" && toPack.type === "folder") {
        if (dropType === "before") {
          this.context.manager._move(fromPack, toPack.flatIndex);
        } else {
          next = this.context.manager.logicPackAfter(toPack.flatIndex);
          if (!next) {
            this.context.manager._move(fromPack, null);
          } else {
            this.context.manager._move(fromPack, next.flatIndex);
          }
        }
      } else if (fromPack.type === "folder" && toPack.type === "source" && !toPack.parent) {
        if (dropType === "before") {
          this.context.manager._move(fromPack, toPack.flatIndex);
        } else {
          this.context.manager._move(fromPack, toPack.flatIndex + 1);
        }
      } else if (fromPack.type === "source" && toPack.type === "source") {
        if (toPack.parent) {
          this.context.manager._setParent(fromPack, toPack.parent);
        } else {
          this.context.manager._setParent(fromPack, null);
        }
        if (dropType === "before") {
          this.context.manager._move(fromPack, toPack.flatIndex);
        } else if (dropType === "after") {
          this.context.manager._move(fromPack, toPack.flatIndex + 1);
        }
      } else if (fromPack.type === "source" && toPack.type === "folder") {
        if (dropType === "before") {
          this.context.manager._setParent(fromPack, null);
          this.context.manager._move(fromPack, toPack.flatIndex);
        } else {
          this.context.manager._setParent(fromPack, toPack);
          this.context.manager._move(fromPack, toPack.flatIndex + 1);
        }
      }
      if (!fromPack.parent || fromPack.parent && fromPack.parent.model.collapse) {
        fromPack.hide = false;
      }
      return this.context.reflow();
    };

    return SourceListDragController;

  })(Leaf.EventEmitter);

  module.exports = SourceList;

}).call(this);