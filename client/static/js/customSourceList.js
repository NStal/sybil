// Generated by CoffeeScript 1.8.0
(function() {
  var CustomGroupItem, CustomListItem, CustomSourceItem, CustomSourceList, CustomTagItem, WorkspaceSelector, WorkspaceSelectorItem,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  CustomSourceList = (function(_super) {
    __extends(CustomSourceList, _super);

    function CustomSourceList() {
      CustomSourceList.__super__.constructor.call(this, App.templates["custom-source-list"]);
      this.selector = new WorkspaceSelector(this.UI.selector);
      this.selector.on("select", (function(_this) {
        return function(workspace) {
          return _this.switchTo(workspace);
        };
      })(this));
      this.selector.on("sync", (function(_this) {
        return function() {
          if (Workspace.workspaces.length !== 0 && !_this.currentWorkspace) {
            return _this.switchTo(Workspace.workspaces[0]);
          }
        };
      })(this));
      this.listItems = [];
    }

    CustomSourceList.prototype.switchTo = function(workspace) {
      this.currentWorkspace = workspace;
      return this.syncWorkspace();
    };

    CustomSourceList.prototype.select = function(item) {
      this.currentItem = item;
      return this.customArchiveList.setSelector(item.member);
    };

    CustomSourceList.prototype.syncWorkspace = function() {
      var has, index, item, member, workspace, _i, _j, _k, _l, _len, _len1, _len2, _len3, _ref, _ref1, _ref2, _ref3;
      workspace = this.currentWorkspace;
      if (!workspace) {
        return;
      }
      _ref = this.listItems;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        item.__match = "not match";
      }
      _ref1 = workspace.members;
      for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
        member = _ref1[_j];
        has = false;
        _ref2 = this.listItems;
        for (_k = 0, _len2 = _ref2.length; _k < _len2; _k++) {
          item = _ref2[_k];
          if (item.member === member) {
            item.__match = "match";
            has = true;
            break;
          }
        }
        if (!has) {
          this.add(CustomListItem.create(member));
        }
      }
      _ref3 = this.listItems;
      for (index = _l = 0, _len3 = _ref3.length; _l < _len3; index = ++_l) {
        item = _ref3[index];
        if (item.__match === "not match") {
          this.listItems[item] = null;
          item.remove();
        }
      }
      return this.listItems = this.listItems.filter(function(item) {
        return item;
      });
    };

    CustomSourceList.prototype.save = function() {
      var item;
      this.currentWorkspace.members = (function() {
        var _i, _len, _ref, _results;
        _ref = this.listItems;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          item = _ref[_i];
          _results.push(item.member);
        }
        return _results;
      }).call(this);
      return this.currentWorkspace.save();
    };

    CustomSourceList.prototype.add = function(item) {
      item.appendTo(this.UI.container);
      item.on("change", (function(_this) {
        return function() {
          return _this.save();
        };
      })(this));
      item.on("select", (function(_this) {
        return function(who) {
          return _this.select(who);
        };
      })(this));
      this.listItems.push(item);
      return this.save();
    };

    CustomSourceList.prototype.onClickAddGroup = function() {
      var group, item;
      group = WorkspaceMember.fromJSON({
        type: "group",
        items: [],
        name: "new group"
      });
      this.currentWorkspace.add(group);
      item = new CustomGroupItem(group);
      this.add(item);
      return item.startEdit();
    };

    CustomSourceList.prototype.onClickAddSource = function() {
      return App.sourceSelector.select((function(_this) {
        return function(err, sources) {
          var item, source, sourceMember, _i, _len, _results;
          if (err || !sources) {
            return;
          }
          _results = [];
          for (_i = 0, _len = sources.length; _i < _len; _i++) {
            source = sources[_i];
            sourceMember = WorkspaceMember.fromJSON({
              type: "source",
              name: source.name,
              guid: source.guid
            });
            _this.currentWorkspace.add(sourceMember);
            item = new CustomSourceItem(sourceMember);
            _results.push(_this.add(item));
          }
          return _results;
        };
      })(this));
    };

    CustomSourceList.prototype.onClickAddTag = function() {
      return App.tagSelector.select((function(_this) {
        return function(err, tags) {
          var item, tag, tagMember, _i, _len, _results;
          if (err || !tags) {
            return;
          }
          _results = [];
          for (_i = 0, _len = tags.length; _i < _len; _i++) {
            tag = tags[_i];
            tagMember = WorkspaceMember.fromJSON({
              type: "tag",
              tagName: tag.name
            });
            _this.currentWorkspace.add(tagMember);
            item = new CustomTagItem(tagMember);
            _results.push(_this.add(item));
          }
          return _results;
        };
      })(this));
    };

    CustomSourceList.prototype.onClickClearAll = function() {
      return console.log("not implemented yet");
    };

    return CustomSourceList;

  })(Leaf.Widget);

  CustomListItem = (function(_super) {
    __extends(CustomListItem, _super);

    CustomListItem.create = function(item) {
      if (item.type === "group") {
        return new CustomGroupItem(item);
      }
      if (item.type === "source") {
        return new CustomSourceItem(item);
      }
      if (item.type === "tag") {
        return new CustomTagItem(item);
      }
      throw "unknown custom item type " + item.type;
    };

    function CustomListItem(template) {
      CustomListItem.__super__.constructor.call(this, template);
    }

    CustomListItem.prototype.onClickNode = function(e) {
      this.emit("select", this);
      e.stopPropagation();
      return false;
    };

    return CustomListItem;

  })(Leaf.Widget);

  CustomGroupItem = (function(_super) {
    __extends(CustomGroupItem, _super);

    function CustomGroupItem(member) {
      var item, _i, _len, _ref;
      this.member = member;
      CustomGroupItem.__super__.constructor.call(this, App.templates["custom-group-item"]);
      this.slideSpeed = 100;
      this.listItems = [];
      this.render();
      _ref = this.member.items;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        item = CustomListItem.create(item);
        this.add(item);
      }
      console.log(this.onClickNode);
      this.UI.name.oncontextmenu = (function(_this) {
        return function(e) {
          e.preventDefault();
          return _this.startEdit();
        };
      })(this);
    }

    CustomGroupItem.prototype.add = function(item) {
      if (item instanceof CustomGroupItem) {
        throw "invalid group data that contains other group";
      }
      this.listItems.push(item);
      item.appendTo(this.UI.container);
      item.on("change", (function(_this) {
        return function() {
          return _this.emit("change");
        };
      })(this));
      item.on("select", (function(_this) {
        return function(who) {
          return _this.emit("select", who);
        };
      })(this));
      return this.emit("change");
    };

    CustomGroupItem.prototype.onClickEditToggler = function() {
      if (this.isEdit) {
        return this.endEdit();
      } else {
        return this.startEdit();
      }
    };

    CustomGroupItem.prototype.onKeydownNameInput = function(e) {
      if (e.which === Leaf.Key.enter) {
        return this.endEdit();
      }
    };

    CustomGroupItem.prototype.onClickFolderIcon = function(e) {
      if (this.isExpand) {
        this.hideContents();
      } else {
        this.showContents();
      }
      e.stopPropagation();
      return false;
    };

    CustomGroupItem.prototype.showContents = function() {
      this.UI.actions$.slideDown(this.slideSpeed);
      this.UI.container$.slideDown(this.slideSpeed);
      this.UI.folderIcon$.removeClass("fa-folder-o");
      this.UI.folderIcon$.addClass("fa-folder-open-o");
      return this.isExpand = true;
    };

    CustomGroupItem.prototype.hideContents = function() {
      this.UI.actions$.slideUp(this.slideSpeed);
      this.UI.container$.slideUp(this.slideSpeed);
      this.UI.folderIcon$.removeClass("fa-folder-open-o");
      this.UI.folderIcon$.addClass("fa-folder-o");
      return this.isExpand = false;
    };

    CustomGroupItem.prototype.render = function() {
      return this.UI.name$.text(this.member.name);
    };

    CustomGroupItem.prototype.save = function() {
      var item;
      return this.member.items = (function() {
        var _i, _len, _ref, _results;
        _ref = this.items;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          item = _ref[_i];
          _results.push(item.member);
        }
        return _results;
      }).call(this);
    };

    CustomGroupItem.prototype.startEdit = function() {
      this.isEdit = true;
      this.UI.nameInput$.show();
      this.UI.name$.hide();
      this.UI.nameInput$.focus();
      return this.UI.nameInput.value = this.member.name || "no name";
    };

    CustomGroupItem.prototype.endEdit = function() {
      var value;
      this.isEdit = false;
      value = this.UI.nameInput.value.trim();
      if (this.member.name !== value) {
        this.member.name = value;
        this.emit("change");
        this.render();
      }
      this.UI.nameInput$.hide();
      return this.UI.name$.show();
    };

    CustomGroupItem.prototype.onClickAddSource = function() {
      return App.sourceSelector.select((function(_this) {
        return function(err, sources) {
          var item, source, sourceMember, _i, _len, _results;
          if (err || !sources) {
            return;
          }
          _results = [];
          for (_i = 0, _len = sources.length; _i < _len; _i++) {
            source = sources[_i];
            sourceMember = WorkspaceMember.fromJSON({
              type: "source",
              name: source.name,
              guid: source.guid
            });
            _this.member.add(sourceMember);
            item = new CustomSourceItem(sourceMember);
            _results.push(_this.add(item));
          }
          return _results;
        };
      })(this));
    };

    CustomGroupItem.prototype.onClickAddTag = function() {
      return App.tagSelector.select((function(_this) {
        return function(err, tags) {
          var item, tag, tagMember, _i, _len, _results;
          if (err || !tags) {
            return;
          }
          _results = [];
          for (_i = 0, _len = tags.length; _i < _len; _i++) {
            tag = tags[_i];
            tagMember = WorkspaceMember.fromJSON({
              type: "tag",
              tagName: tag.name
            });
            _this.member.add(tagMember);
            item = new CustomTagItem(tagMember);
            _results.push(_this.add(item));
          }
          return _results;
        };
      })(this));
    };

    return CustomGroupItem;

  })(CustomListItem);

  CustomSourceItem = (function(_super) {
    __extends(CustomSourceItem, _super);

    function CustomSourceItem(member) {
      this.member = member;
      CustomSourceItem.__super__.constructor.call(this, App.templates["custom-source-item"]);
      this.UI.name$.text(this.member.name);
    }

    return CustomSourceItem;

  })(CustomListItem);

  CustomTagItem = (function(_super) {
    __extends(CustomTagItem, _super);

    function CustomTagItem(member) {
      this.member = member;
      CustomTagItem.__super__.constructor.call(this, App.templates["custom-tag-item"]);
      this.UI.name$.text(this.member.tagName);
    }

    return CustomTagItem;

  })(CustomListItem);

  WorkspaceSelectorItem = (function(_super) {
    __extends(WorkspaceSelectorItem, _super);

    function WorkspaceSelectorItem(workspace) {
      this.workspace = workspace;
      WorkspaceSelectorItem.__super__.constructor.call(this, "<span></span>");
      this.node$.text(this.workspace.name);
    }

    return WorkspaceSelectorItem;

  })(Leaf.Widget);

  WorkspaceSelector = (function(_super) {
    __extends(WorkspaceSelector, _super);

    function WorkspaceSelector(template) {
      WorkspaceSelector.__super__.constructor.call(this, template);
      this.items = [];
      Model.on("workspace/sync", (function(_this) {
        return function() {
          _this.sync();
          return console.log("synced", Workspace.workspaces);
        };
      })(this));
    }

    WorkspaceSelector.prototype.sync = function() {
      var has, index, item, workspace, _i, _j, _k, _l, _len, _len1, _len2, _len3, _ref, _ref1, _ref2, _ref3;
      _ref = this.items;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        item.__match = "not match";
      }
      _ref1 = Workspace.workspaces;
      for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
        workspace = _ref1[_j];
        has = false;
        _ref2 = this.items;
        for (_k = 0, _len2 = _ref2.length; _k < _len2; _k++) {
          item = _ref2[_k];
          if (item.name === workspace.name) {
            item.__match = "match";
            has = true;
            break;
          }
        }
        if (!has) {
          this.addWorkspace(workspace);
        }
      }
      _ref3 = this.items;
      for (index = _l = 0, _len3 = _ref3.length; _l < _len3; index = ++_l) {
        item = _ref3[index];
        if (item.__match === "not match") {
          item.remove();
          this.items[index] = null;
        }
      }
      this.items = this.items.filter(function(item) {
        return item;
      });
      return this.emit("sync");
    };

    WorkspaceSelector.prototype.addWorkspace = function(workspace) {
      var selector;
      selector = new WorkspaceSelectorItem(workspace);
      this.items.push(selector);
      selector.onClickNode = (function(_this) {
        return function() {
          return _this.emit("select", selector.workspace);
        };
      })(this);
      return selector.appendTo(this.node);
    };

    return WorkspaceSelector;

  })(Leaf.Widget);

  window.CustomSourceList = CustomSourceList;

}).call(this);
