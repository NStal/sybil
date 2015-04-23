// Generated by CoffeeScript 1.8.0
(function() {
  var App, Model, SourceAuthorizeTerminal, tm,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  App = require("/app");

  Model = App.Model;

  tm = require("/common/templateManager");

  tm.use("view/sourceUtil/sourceAuthorizeTerminal");

  SourceAuthorizeTerminal = (function(_super) {
    __extends(SourceAuthorizeTerminal, _super);

    function SourceAuthorizeTerminal(source) {
      this.source = source;
      SourceAuthorizeTerminal.__super__.constructor.call(this, App.templates.view.sourceUtil.sourceAuthorizeTerminal);
      if (!this.source.requireLocalAuth) {
        setTimeout(((function(_this) {
          return function() {
            _this.emit("authorized");
            return _this.hide();
          };
        })(this)), 100);
        return;
      }
      document.body.appendChild(this.node);
      App.hintStack.push(this);
      App.modelSyncManager.listenBy(this, "source/authorized", (function(_this) {
        return function(source) {
          if (source === _this.source) {
            _this.emit("authorized");
            return _this.clear();
          }
        };
      })(this));
      this.Data.mode = "authenticator";
      App.modelSyncManager.listenBy(this, "source/requireLocalAuth", (function(_this) {
        return function(source) {
          if (source === _this.source) {
            _this.hint("authorization failed, please try again");
            _this.emit("requireLocalAuth");
            return _this.Data.mode = "authenticator";
          }
        };
      })(this));
    }

    SourceAuthorizeTerminal.prototype.auth = function(username, secret, callback) {
      if (callback == null) {
        callback = function() {};
      }
      this.hint("authorizing");
      console.log;
      return App.messageCenter.invoke("authSource", {
        guid: this.source.guid,
        username: this.UI.username$.val().trim(),
        secret: this.UI.secret$.val()
      }, function(err, result) {
        return callback(err, result);
      });
    };

    SourceAuthorizeTerminal.prototype.hint = function(message) {
      this.Data.mode = "hinter";
      return this.Data.hint = message;
    };

    SourceAuthorizeTerminal.prototype.hide = function() {
      return this.emit("hide", this);
    };

    SourceAuthorizeTerminal.prototype.clear = function() {
      App.modelSyncManager.stopListenBy(this);
      return this.hide();
    };

    SourceAuthorizeTerminal.prototype.onKeydownUsername = function(e) {
      if (e.which === Leaf.Key.enter) {
        return this.UI.secret$.focus();
      }
    };

    SourceAuthorizeTerminal.prototype.onKeydownSecret = function(e) {
      if (e.which === Leaf.Key.enter) {
        return this.onClickAuthorize();
      }
    };

    SourceAuthorizeTerminal.prototype.onClickAuthorize = function() {
      var secret, username;
      username = this.UI.username.value;
      secret = this.UI.secret.value;
      return this.auth(username, secret, (function(_this) {
        return function() {
          return _this.hint("authorizing");
        };
      })(this));
    };

    SourceAuthorizeTerminal.prototype.onClickRefuse = function() {
      return this.hide();
    };

    return SourceAuthorizeTerminal;

  })(Leaf.Widget);

  module.exports = SourceAuthorizeTerminal;

}).call(this);