// Generated by CoffeeScript 1.8.0
(function() {
  var AddSourcePopup, App, SubscribeAssistant, async, tm,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  async = require("/component/async");

  App = require("/app");

  SubscribeAssistant = require("/view/sourceUtil/subscribeAssistant");

  tm = require("/common/templateManager");

  tm.use("view/sourceUtil/addSourcePopup");

  AddSourcePopup = (function(_super) {
    __extends(AddSourcePopup, _super);

    function AddSourcePopup() {
      AddSourcePopup.__super__.constructor.call(this, App.templates.view.sourceUtil.addSourcePopup);
      this.node$.hide();
    }

    AddSourcePopup.prototype.onClickSubmit = function() {
      var uris;
      uris = this.UI.input.value.trim().split(/\s+/).map(function(item) {
        return item.trim();
      });
      uris = uris.filter(function(item) {
        return item;
      });
      uris.forEach(function(uri) {
        return new SubscribeAssistant(uri);
      });
      this.UI.input.value = "";
      return this.hide();
    };

    AddSourcePopup.prototype.onClickCancel = function() {
      this.UI.input.value = "";
      return this.hide();
    };

    AddSourcePopup.prototype.show = function() {
      this.node$.show();
      return this.UI.input$.focus();
    };

    AddSourcePopup.prototype.hide = function() {
      return this.node$.hide();
    };

    return AddSourcePopup;

  })(Leaf.Widget);

  module.exports = AddSourcePopup;

}).call(this);
