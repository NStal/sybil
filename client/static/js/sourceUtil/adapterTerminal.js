// Generated by CoffeeScript 1.8.0
(function() {
  var App, CubeLoadingHint, HintStack, SubscribeAdapterTerminal, tm,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  App = require("/app");

  HintStack = require("/hintStack");

  CubeLoadingHint = require("/widget/cubeLoadingHint");

  tm = require("/templateManager");

  tm.use("sourceUtil/subscribeAdapterTerminal");

  SubscribeAdapterTerminal = (function(_super) {
    __extends(SubscribeAdapterTerminal, _super);

    function SubscribeAdapterTerminal(candidate) {
      this.include(CubeLoadingHint);
      SubscribeAdapterTerminal.__super__.constructor.call(this, App.templates.sourceUtil.subscribeAdapterTerminal);
      console.debug(candidate, "from termional");
      this.candidate = candidate;
      this.Data.mode = "accepter";
      this.register();
      this.Data.subscribeHint = this.candidate.subscribeHint || ("Would you like to subscribe " + this.candidate.uri);
      console.debug(this.candidate.data, this.candidate.requireLocalAuth, "~~", this.candidate);
      if (this.candidate.requireLocalAuth) {
        this.requireAuth();
      }
      this.Data.hintTitle = this.candidate.uri;
      this.Data.waitTitle = this.candidate.uri;
      if (this.candidate.panic) {
        this.fail();
      }
      this.show();
    }

    SubscribeAdapterTerminal.prototype.register = function() {
      console.debug("register " + this.candidate.cid);
      App.messageCenter.listenBy(this, "event/candidate/requireAuth", this.handlePossibleCandidateAuth);
      App.messageCenter.listenBy(this, "event/candidate/subscribe", this.handlePossibleCandidateSubscribe);
      return App.messageCenter.listenBy(this, "event/candidate/fail", this.handlePossibleCandidateFail);
    };

    SubscribeAdapterTerminal.prototype.requireAuth = function() {
      this.Data.mode = "authenticator";
      return this.Data.authHint = this.candidate.authHint || ("Please enter you authorization info for " + this.candidate.uri);
    };

    SubscribeAdapterTerminal.prototype.fail = function(panic) {
      this.candidate.panic = panic || this.candidate.panic;
      this.Data.mode = "failure";
      return this.Data.failureHint = "Subscribe failed due to " + (JSON.stringify(this.candidate.panic));
    };

    SubscribeAdapterTerminal.prototype.handlePossibleCandidateAuth = function(candidate) {
      if (candidate.cid === this.candidate.cid) {
        this.candidate = candidate;
        this.requireAuth();
      }
    };

    SubscribeAdapterTerminal.prototype.handlePossibleCandidateCaptcha = function(candidate) {
      console.debug("possible captcha", candidate);
      if (candidate.cid === this.candidate.cid) {
        this.Data.mode = "pin-recognizer";
      }
    };

    SubscribeAdapterTerminal.prototype.handlePossibleCandidateSubscribe = function(info) {
      if (info.cid === this.candidate.cid) {
        this.release();
        return this.hide();
      }
    };

    SubscribeAdapterTerminal.prototype.handlePossibleCandidateFail = function(info) {
      console.debug("candidate fail", info, "!!!!");
      if (info.cid === this.candidate.cid && info.panic) {
        return this.fail(info.panic);
      }
    };

    SubscribeAdapterTerminal.prototype.onClickRetry = function() {
      this.wait("initializing...");
      return this.retry((function(_this) {
        return function(err) {
          return true;
        };
      })(this));
    };

    SubscribeAdapterTerminal.prototype.onClickCancel = function() {
      return this.cancel((function(_this) {
        return function(err) {
          _this.release();
          return _this.hide();
        };
      })(this));
    };

    SubscribeAdapterTerminal.prototype.onKeydownUsername = function(e) {
      if (e.which === Leaf.Key.enter) {
        return this.UI.secret$.focus();
      }
    };

    SubscribeAdapterTerminal.prototype.onKeydownSecret = function(e) {
      if (e.which === Leaf.Key.enter) {
        return this.onClickAuthorize();
      }
    };

    SubscribeAdapterTerminal.prototype.onClickAccept = function() {
      return this.accept((function(_this) {
        return function() {
          return _this.wait("accepting...");
        };
      })(this));
    };

    SubscribeAdapterTerminal.prototype.onClickDecline = function() {
      return this.decline((function(_this) {
        return function() {
          return _this.hide();
        };
      })(this));
    };

    SubscribeAdapterTerminal.prototype.onClickAuthorize = function() {
      var secret, username;
      username = this.UI.username.value;
      secret = this.UI.secret.value;
      return this.auth(username, secret, (function(_this) {
        return function() {
          return _this.wait("authorizing...");
        };
      })(this));
    };

    SubscribeAdapterTerminal.prototype.onClickRefuse = function() {
      return this.decline((function(_this) {
        return function() {
          return _this.hide();
        };
      })(this));
    };

    SubscribeAdapterTerminal.prototype.hint = function(word) {
      this.Data.mode = "hinter";
      return this.Data.hint = word;
    };

    SubscribeAdapterTerminal.prototype.wait = function(word) {
      this.Data.mode = "waiter";
      return this.UI.loadingHint.hint = word;
    };

    SubscribeAdapterTerminal.prototype.release = function() {
      return App.messageCenter.stopListenBy(this);
    };

    SubscribeAdapterTerminal.prototype.auth = function(username, secret, callback) {
      if (callback == null) {
        callback = function() {};
      }
      console.log("authCandidate", {
        cid: this.candidate.cid,
        username: username,
        secret: secret
      });
      return this.accept((function(_this) {
        return function() {
          return App.messageCenter.invoke("authCandidate", {
            cid: _this.candidate.cid,
            username: username,
            secret: secret
          }, function(err) {
            return callback(err);
          });
        };
      })(this));
    };

    SubscribeAdapterTerminal.prototype.retry = function(callback) {
      if (callback == null) {
        callback = function() {};
      }
      return App.messageCenter.invoke("retryCandidate", {
        cid: this.candidate.cid,
        retry: true
      }, (function(_this) {
        return function(err) {
          return callback();
        };
      })(this));
    };

    SubscribeAdapterTerminal.prototype.cancel = function(callback) {
      if (callback == null) {
        callback = function() {};
      }
      return App.messageCenter.invoke("retryCandidate", {
        cid: this.candidate.cid,
        retry: false
      }, (function(_this) {
        return function(err) {
          return callback();
        };
      })(this));
    };

    SubscribeAdapterTerminal.prototype.accept = function(callback) {
      if (callback == null) {
        callback = function() {};
      }
      return App.messageCenter.invoke("acceptCandidate", this.candidate.cid, (function(_this) {
        return function(err) {
          _this.accepted = true;
          return callback(err);
        };
      })(this));
    };

    SubscribeAdapterTerminal.prototype.decline = function(callback) {
      if (callback == null) {
        callback = function() {};
      }
      return App.messageCenter.invoke("declineCandidate", this.candidate.cid, (function(_this) {
        return function(err) {
          return callback(err);
        };
      })(this));
    };

    SubscribeAdapterTerminal.prototype.error = function(error) {};

    return SubscribeAdapterTerminal;

  })(HintStack.HintStackItem);

  module.exports = SubscribeAdapterTerminal;

}).call(this);
