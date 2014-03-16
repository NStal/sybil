// Generated by CoffeeScript 1.7.1
(function() {
  var SourceList, SourceListFolder, SourceListItem,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    __slice = [].slice,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  SourceListFolder = (function(_super) {
    __extends(SourceListFolder, _super);

    function SourceListFolder(name) {
      this.name = name;
      SourceListFolder.__super__.constructor.call(this, App.templates["source-list-folder"]);
      this.children = Leaf.Widget.makeList(this.UI.container);
      this.isCollapse = true;
      this.render();
      this.children.on("child/add", (function(_this) {
        return function(child) {
          _this.render();
          child.parent = _this;
          _this.emit("childAdd", child);
          _this.emit("change");
          child.on("change", function() {
            return _this.render();
          });
          child.on("select", function() {
            return _this.emit("select", child);
          });
          return child.on("delete", function() {
            _this.children.removeItem(child);
            return _this.render();
          });
        };
      })(this));
      this.children.on("child/remove", (function(_this) {
        return function(child) {
          if (child.parent === _this) {
            child.parent = null;
          }
          child.removeAllListeners();
          _this.render();
          _this.emit("childRemove", child);
          return _this.emit("change");
        };
      })(this));
      this.UI.title.oncontextmenu = (function(_this) {
        return function(e) {
          var selections;
          e.preventDefault();
          selections = [
            {
              name: "delete folder",
              callback: function() {
                if (!confirm("remove this folder " + _this.name + "?")) {
                  return;
                }
                return _this["delete"]();
              }
            }, {
              name: "unsubscribe all",
              callback: function() {
                if (!confirm("unsubscribe all in this folder " + _this.name + "?")) {
                  return;
                }
                return _this.unsubscribeAll();
              }
            }, {
              name: "rename folder",
              callback: function() {
                name = prompt("folder name", _this.name);
                if (name) {
                  _this.name = name.trim();
                } else {
                  return;
                }
                _this.render();
                return _this.emit("change");
              }
            }
          ];
          return ContextMenu.showByEvent(e, selections);
        };
      })(this);
    }

    SourceListFolder.prototype.initChildren = function(children) {
      var child, source, _i, _len, _ref;
      this.children.length = 0;
      _ref = children || [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        child = _ref[_i];
        source = Model.Source.getOrCreate(child);
        child = new SourceListItem(source);
        this.children.push(child);
        child.parent = this;
      }
      return this.render();
    };

    SourceListFolder.prototype.unsubscribeAll = function() {
      var item, _i, _len, _ref, _results;
      _ref = this.children;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        _results.push(item.unsubscribe());
      }
      return _results;
    };

    SourceListFolder.prototype.onClickTitle = function() {
      return this.emit("select", this);
    };

    SourceListFolder.prototype.active = function() {
      this.node$.addClass("active");
      return this.isActive = true;
    };

    SourceListFolder.prototype.deactive = function() {
      this.node$.removeClass("active");
      return this.isActive = false;
    };

    SourceListFolder.prototype.toJSON = function() {
      var child;
      return {
        children: (function() {
          var _i, _len, _ref, _results;
          _ref = this.children;
          _results = [];
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            child = _ref[_i];
            _results.push(child.toJSON());
          }
          return _results;
        }).call(this),
        name: this.name,
        type: "folder",
        collapse: this.isCollapse
      };
    };

    SourceListFolder.prototype.render = function() {
      var child, unreadCount, _i, _len, _ref;
      this.UI.name$.text(this.name);
      unreadCount = 0;
      _ref = this.children;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        child = _ref[_i];
        unreadCount += child.source.unreadCount || 0;
      }
      this.UI.unreadCounter$.text(unreadCount);
      if (!this.isCollapse) {
        this.node$.removeClass("collapse");
        this.UI.folderIcon$.removeClass("fa-folder-open");
        return this.UI.folderIcon$.addClass("fa-folder");
      } else {
        this.UI.folderIcon$.removeClass("fa-folder");
        this.UI.folderIcon$.addClass("fa-folder-open");
        return this.node$.addClass("collapse");
      }
    };

    SourceListFolder.prototype.onClickFolderIcon = function(e) {
      this.isCollapse = !this.isCollapse;
      this.render();
      e.stopPropagation();
      return this.emit("change");
    };

    SourceListFolder.prototype["delete"] = function() {
      console.log("delete this " + this.name);
      return this.emit("delete", this);
    };

    return SourceListFolder;

  })(Leaf.Widget);

  SourceListItem = (function(_super) {
    __extends(SourceListItem, _super);

    function SourceListItem(source) {
      SourceListItem.__super__.constructor.call(this, App.templates["source-list-item"]);
      this.set(source);
      this.render();
      this.node.oncontextmenu = (function(_this) {
        return function(e) {
          var selections;
          e.preventDefault();
          selections = [
            {
              name: "unsubscribe",
              callback: function() {
                if (!confirm("unsubscribe item " + _this.source.name + "?")) {
                  return;
                }
                return _this.unsubscribe();
              }
            }
          ];
          return ContextMenu.showByEvent(e, selections);
        };
      })(this);
    }

    SourceListItem.prototype.unsubscribe = function(callback) {
      if (callback == null) {
        callback = (function(_this) {
          return function() {
            return true;
          };
        })(this);
      }
      return this.source.unsubscribe(callback);
    };

    SourceListItem.prototype.set = function(source) {
      this.source = source;
      this.source.on("remove", (function(_this) {
        return function() {
          return _this["delete"]();
        };
      })(this));
      return this.source.on("change", (function(_this) {
        return function() {
          _this.render();
          return _this.emit("change");
        };
      })(this));
    };

    SourceListItem.prototype["delete"] = function() {
      return this.emit("delete");
    };

    SourceListItem.prototype.render = function() {
      var self, url;
      this.UI.name$.text(this.source.name);
      this.UI.name.title = this.source.guid;
      this.UI.name.setAttribute("alt", this.source.guid);
      this.UI.unreadCounter$.text((parseInt(this.source.unreadCount) >= 0) && parseInt(this.source.unreadCount).toString() || "?");
      if (this.iconLoaded) {
        return;
      }
      url = "http://www.google.com/s2/favicons?domain=" + this.source.uri + "&alt=feed";
      console.log(this.source);
      this.UI.sourceIcon$.attr("src", url);
      this.UI.sourceIcon.onerror = function() {
        this.src = "/image/favicon-default.png";
        return console.debug("load default");
      };
      self = this;
      return this.UI.sourceIcon.onload = function() {
        this.style.display = "inline";
        return self.iconLoaded = true;
      };
    };

    SourceListItem.prototype.onClickName = function() {
      this.emit("select", this);
      return false;
    };

    SourceListItem.prototype.active = function() {
      this.node$.addClass("active");
      return this.isActive = true;
    };

    SourceListItem.prototype.deactive = function() {
      this.node$.removeClass("active");
      return this.isActive = false;
    };

    SourceListItem.prototype.toJSON = function() {
      var json;
      json = this.source.toJSON();
      json.type = "source";
      return json;
    };

    return SourceListItem;

  })(Leaf.Widget);

  SourceList = (function(_super) {
    __extends(SourceList, _super);

    function SourceList() {
      this.folderConfig = Model.Config.getConfig("sourceFolderConfig");
      Model.on("config/ready", (function(_this) {
        return function() {
          clearTimeout(_this.buildTimer);
          return _this.buildFolderData();
        };
      })(this));
      Model.on("source/add", (function(_this) {
        return function(source) {
          return _this.tryAddSource(source, true);
        };
      })(this));
      SourceList.__super__.constructor.call(this, App.templates["source-list"]);
      this.children = Leaf.Widget.makeList(this.UI.container);
      this.dragContext = new DragContext();
      this.dragContext.on("start", (function(_this) {
        return function(e) {
          var shadow;
          shadow = document.createElement("span");
          shadow.innerHTML = e.draggable.innerText;
          return _this.dragContext.addDraggingShadow(shadow);
        };
      })(this));
      this.dragContext.on("drop", (function(_this) {
        return function(e) {
          _this.moveListItem(e.draggable.widget, e.droppable.widget, e);
          _this.save();
          return _this.UI.cursor$.hide();
        };
      })(this));
      this.dragContext.on("hover", (function(_this) {
        return function(e) {
          return _this.hintMovePosition(e.draggable.widget, e.droppable.widget, e);
        };
      })(this));
      this.dragContext.on("release", (function(_this) {
        return function(e) {
          return _this.UI.cursor$.hide();
        };
      })(this));
      this.dragContext.on("move", (function(_this) {
        return function(e) {
          if (!e.dragHover) {
            return _this.UI.cursor$.hide();
          }
        };
      })(this));
      this.children.on("child/add", this._attach.bind(this));
      this.children.on("child/remove", this._detach.bind(this));
    }

    SourceList.prototype.buildFolderData = function() {
      var child, folder, folders, _i, _len, _results;
      folders = this.folderConfig.get("folders", []);
      console.log(folders);
      _results = [];
      for (_i = 0, _len = folders.length; _i < _len; _i++) {
        child = folders[_i];
        if (child.type === "folder") {
          folder = new SourceListFolder(child.name);
          this.children.push(folder);
          folder.isCollapse = child.collapse;
          console.log("init " + folder.name + " with", child.children);
          _results.push(folder.initChildren(child.children));
        } else if (child.type === "source") {
          _results.push(this.addSource(Model.Source.getOrCreate(child)));
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    };

    SourceList.prototype._attach = function(item) {
      var folder;
      if (item.hasAttach) {
        throw new Error("Programmer Error");
      }
      item.hasAttach = true;
      item.on("select", (function(_this) {
        return function(who) {
          return _this.select(who);
        };
      })(this));
      item.on("delete", (function(_this) {
        return function() {
          var children, index, _ref;
          if (item instanceof SourceListFolder) {
            children = item.children.toArray();
            item.children.length = 0;
            index = _this.children.indexOf(item);
            (_ref = _this.children).splice.apply(_ref, [index, 1].concat(__slice.call(children)));
          } else {
            _this.children.removeItem(item);
          }
          return _this.save();
        };
      })(this));
      this._attachDrag(item);
      if (item instanceof SourceListFolder) {
        folder = item;
        folder.on("change", (function(_this) {
          return function(who) {
            return _this.save();
          };
        })(this));
        return folder.on("childAdd", (function(_this) {
          return function(who) {
            var child, _i, _len, _ref, _results;
            _this._attachDrag(who);
            _ref = _this.children;
            _results = [];
            for (_i = 0, _len = _ref.length; _i < _len; _i++) {
              child = _ref[_i];
              if (child.source && child.source.guid === who.source.guid) {
                _this.children.removeItem(child);
                break;
              } else {
                _results.push(void 0);
              }
            }
            return _results;
          };
        })(this));
      }
    };

    SourceList.prototype._attachDrag = function(item) {
      var subChild, _i, _len, _ref;
      if (item._hasDragContext) {
        return;
      }
      if (item instanceof SourceListFolder) {
        this.dragContext.addDraggable(item.UI.title);
        this.dragContext.addDroppable(item.UI.title);
        _ref = item.children;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          subChild = _ref[_i];
          this.dragContext.addDraggable(subChild.node);
          this.dragContext.addDroppable(subChild.node);
        }
      } else {
        this.dragContext.addDraggable(item.node);
        this.dragContext.addDroppable(item.node);
      }
      return item._hasDragContext = true;
    };

    SourceList.prototype._detach = function(child) {
      console.log("detach...");
      child.hasAttach = false;
      child.removeAllListeners();
      return this._detachDrag(child);
    };

    SourceList.prototype._detachDrag = function(item) {
      if (!item._hasDragContext) {
        return;
      }
      if (item instanceof SourceListFolder) {
        this.dragContext.removeDraggable(item.UI.title);
        this.dragContext.removeDroppable(item.UI.title);
      } else {
        this.dragContext.addDraggable(item.node);
        this.dragContext.addDroppable(item.node);
      }
      return item._hasDragContext = false;
    };

    SourceList.prototype.moveListItem = function(from, to, event) {
      var index, offset, towards;
      towards = this.getMovePosition(from, to, event);
      if (!towards) {
        return;
      }
      if (towards === "inside") {
        if (this.hintActiveFolder) {
          this.hintActiveFolder.deactive();
          this.hintActiveFolder = null;
        }
        from.parentList.removeItem(from);
        to.children.splice(0, 0, from);
        return;
      }
      if (towards === "after") {
        offset = 1;
      } else {
        offset = 0;
      }
      from.parentList.removeItem(from);
      index = to.parentList.indexOf(to);
      to.parentList.splice(index + offset, 0, from);
      return this.save();
    };

    SourceList.prototype.hintMovePosition = function(from, to, event) {
      var towards;
      towards = this.getMovePosition(from, to, event);
      this.UI.cursor$.show();
      if (this.hintActiveFolder) {
        this.hintActiveFolder.deactive();
        this.hintActiveFolder = null;
      }
      if (towards === "inside") {
        this.hintActiveFolder = to;
        to.active();
      } else {
        if (this.hintActiveFolder) {
          this.hintActiveFolder.deactive();
        }
        this.hintActiveFolder = null;
      }
      if (towards === "after") {
        return this.UI.cursor$.insertAfter(to.node);
      } else if (towards === "before") {
        return this.UI.cursor$.insertBefore(to.node);
      } else {
        return this.UI.cursor$.hide();
      }
    };

    SourceList.prototype.getMovePosition = function(from, to, e) {
      if (!from || !to || !event) {
        throw "invalid move ment";
      }
      if (from instanceof SourceListFolder && to instanceof SourceListItem) {
        if (to.parent instanceof SourceListFolder) {
          return null;
        }
      }
      if (to instanceof SourceListFolder && from instanceof SourceListItem) {
        if ((to.node$.height() * 3 / 4) > e.offsetY && e.offsetY > (to.node$.height() / 3)) {
          return "inside";
        }
      }
      if (e.offsetY > to.node$.height() / 2) {
        return "after";
      } else {
        return "before";
      }
    };

    SourceList.prototype.addSource = function(source, reverse) {
      var child, subChild, _i, _j, _len, _len1, _ref, _ref1;
      if (reverse == null) {
        reverse = false;
      }
      _ref = this.children;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        child = _ref[_i];
        if (child instanceof SourceListFolder) {
          _ref1 = child.children;
          for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
            subChild = _ref1[_j];
            if (subChild.source.guid === source.guid) {
              subChild["delete"]();
              break;
            }
          }
        } else if (child instanceof SourceListItem) {
          if (child.source.guid === source.guid) {
            child["delete"]();
            break;
          }
        } else {
          throw new Error("unknown list item");
        }
      }
      child = new SourceListItem(source);
      if (reverse) {
        return this.children.unshift(child);
      } else {
        return this.children.push(child);
      }
    };

    SourceList.prototype.tryAddSource = function(source, reverse) {
      var child, subChild, _i, _j, _len, _len1, _ref, _ref1;
      if (reverse == null) {
        reverse = true;
      }
      _ref = this.children;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        child = _ref[_i];
        if (child instanceof SourceListFolder) {
          _ref1 = child.children;
          for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
            subChild = _ref1[_j];
            if (subChild.source.guid === source.guid) {
              return;
            }
          }
        } else if (child instanceof SourceListItem) {
          if (child.source.guid === source.guid) {
            return;
          }
        } else {
          throw new Error("unknown list item");
        }
      }
      child = new SourceListItem(source);
      if (reverse) {
        return this.children.unshift(child);
      } else {
        return this.children.push(child);
      }
    };

    SourceList.prototype.select = function(who) {
      var child, info;
      console.log("select", who);
      if (this.currentItem) {
        this.currentItem.deactive();
      }
      this.currentItem = who;
      who.active();
      info = {};
      if (who instanceof SourceListFolder) {
        if (who.children.length === 0) {
          return;
        }
        info.type = "folder";
        info.sourceGuids = (function() {
          var _i, _len, _ref, _results;
          _ref = who.children;
          _results = [];
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            child = _ref[_i];
            _results.push(child.source.guid);
          }
          return _results;
        })();
        info.name = who.name;
        info.hash = info.type;
      } else {
        info.type = "source";
        info.sourceGuids = [who.source.guid];
        info.name = who.source.name;
      }
      return this.emit("select", info);
    };

    SourceList.prototype.save = function() {
      var _save;
      if (this._saveTimer) {
        clearTimeout(this._saveTimer);
      }
      _save = function() {
        var child, folders, item, names, q, x;
        console.debug(this.children.length, "total folder length");
        folders = (function() {
          var _i, _len, _ref, _results;
          _ref = this.children;
          _results = [];
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            child = _ref[_i];
            _results.push(child.toJSON());
          }
          return _results;
        }).call(this);
        names = (function() {
          var _i, _len, _results;
          _results = [];
          for (_i = 0, _len = folders.length; _i < _len; _i++) {
            item = folders[_i];
            _results.push(item.name || item.source.name);
          }
          return _results;
        })();
        q = [];
        while (x = names.pop()) {
          if (__indexOf.call(q, x) >= 0) {
            throw "conflict names!";
          }
          q.push(x);
        }
        return this.folderConfig.set("folders", folders);
      };
      return this._saveTimer = setTimeout(_save.bind(this), this._saveDelay || 100);
    };

    SourceList.prototype.onClickAddSourceButton = function() {
      return App.addSourcePopup.show();
    };

    SourceList.prototype.onClickAddFolderButton = function() {
      var child, name;
      name = prompt("name", "untitled").trim();
      if (!name) {
        return;
      }
      child = new SourceListFolder(name);
      this.children.unshift(child);
      return this.save();
    };

    return SourceList;

  })(Leaf.Widget);

  window.SourceList = SourceList;

}).call(this);
