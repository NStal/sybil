// Generated by CoffeeScript 1.8.0
(function() {
  var App, View, ViewSelectItem, ViewSwitcher,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  App = require("app");

  View = (function(_super) {
    __extends(View, _super);

    View.views = [];

    function View(template, name) {
      View.__super__.constructor.call(this, template);
      this.name = name;
      View.views.push(this);
      this.isShow = true;
    }

    View.prototype.show = function() {
      if (this.isShow) {
        return;
      }
      this.isShow = true;
      this.node$.show();
      return this.emit("show");
    };

    View.prototype.hide = function() {
      if (!this.isShow) {
        return;
      }
      this.isShow = false;
      this.node$.hide();
      return this.emit("hide");
    };

    return View;

  })(Leaf.Widget);

  ViewSwitcher = (function(_super) {
    __extends(ViewSwitcher, _super);

    function ViewSwitcher() {
      ViewSwitcher.__super__.constructor.call(this, $(".view-switcher")[0]);
      this.currentView = null;
      this.viewItems = [];
      this.hideListener = this.hideListener.bind(this);
      this.hide();
    }

    ViewSwitcher.prototype.switchTo = function(name) {
      var has, oldView, view, _i, _len, _ref;
      has = false;
      _ref = View.views;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        view = _ref[_i];
        if (!(view.name === name)) {
          continue;
        }
        if (this.currentView && this.currentView.name === name) {
          return;
        }
        if (this.currentView) {
          this.currentView.hide();
        }
        oldView = this.currentView;
        this.emit("viewChange", view);
        this.currentView = view;
        if (oldView && oldView.onSwitchOff) {
          oldView.onSwitchOff();
        }
        view.show();
        this.VM.title = name;
        if (view.onSwitchTo) {
          view.onSwitchTo();
        }
        return;
      }
      if (!has) {
        throw new Error("view " + name + " not found");
      }
    };

    ViewSwitcher.prototype.onClickTitle = function(e) {
      e.stopImmediatePropagation();
      e.preventDefault();
      this.syncViews();
      if (this.isShow) {
        return this.hide();
      } else {
        return this.show();
      }
    };

    ViewSwitcher.prototype.hideListener = function(e) {
      e.stopImmediatePropagation();
      e.preventDefault();
      this.hide();
      return false;
    };

    ViewSwitcher.prototype.show = function() {
      window.addEventListener("click", this.hideListener);
      this.isShow = true;
      this.VM.showSelector = true;
      return this.VM.caretClass = "fa-caret-down";
    };

    ViewSwitcher.prototype.hide = function() {
      window.removeEventListener("click", this.hideListener);
      this.isShow = false;
      this.VM.showSelector = false;
      return this.VM.caretClass = "fa-caret-right";
    };

    ViewSwitcher.prototype.syncViews = function() {
      var has, myView, view, _i, _j, _k, _len, _len1, _len2, _ref, _ref1, _ref2;
      _ref = this.viewItems;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        myView = _ref[_i];
        myView.__match = "not match";
      }
      _ref1 = View.views;
      for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
        view = _ref1[_j];
        has = false;
        _ref2 = this.viewItems;
        for (_k = 0, _len2 = _ref2.length; _k < _len2; _k++) {
          myView = _ref2[_k];
          if (view.name === myView.name) {
            has = true;
            myView.__match = "match";
            break;
          }
        }
        if (!has) {
          this.addView(view.name);
        }
      }
      return this.viewItems = this.viewItems.filter(function(item) {
        return item.__match !== "not match";
      });
    };

    ViewSwitcher.prototype.addView = function(name) {
      var viewItem;
      viewItem = new ViewSelectItem(name);
      this.viewItems.push(viewItem);
      viewItem.appendTo(this.UI.viewSelector);
      return viewItem.on("select", (function(_this) {
        return function() {
          _this.switchTo(viewItem.name);
          return _this.hide();
        };
      })(this));
    };

    return ViewSwitcher;

  })(Leaf.Widget);

  ViewSelectItem = (function(_super) {
    __extends(ViewSelectItem, _super);

    function ViewSelectItem(name) {
      this.name = name;
      ViewSelectItem.__super__.constructor.call(this, document.createElement("li"));
      this.node$.text(this.name);
    }

    ViewSelectItem.prototype.onClickNode = function(e) {
      e.stopImmediatePropagation();
      e.preventDefault();
      return this.emit("select");
    };

    return ViewSelectItem;

  })(Leaf.Widget);

  module.exports = View;

  module.exports.ViewSwitcher = ViewSwitcher;

}).call(this);
