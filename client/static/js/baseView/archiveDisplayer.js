// Generated by CoffeeScript 1.8.0
(function() {
  var App, ArchiveDisplayer, ArchiveDisplayerListSelector, ArchiveDisplayerListSelectorItem, ContentImage, Model, Popup, SmartImage, i18n, moment, tm,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  i18n = require("/i18n");

  moment = require("/lib/moment");

  App = require("/app");

  Model = require("/model");

  SmartImage = require("/widget/smartImage");

  ContentImage = require("/widget/contentImage");

  tm = require("/templateManager");

  ArchiveDisplayer = (function(_super) {
    __extends(ArchiveDisplayer, _super);

    function ArchiveDisplayer(template) {
      this.include(ContentImage);
      this.include(SmartImage);
      ArchiveDisplayer.__super__.constructor.call(this, template);
      this.useDisplayContent = true;
    }

    ArchiveDisplayer.prototype.setArchive = function(archive) {
      if (this.archive) {
        this.archive.stopListenBy(this);
        this.stopBubble(this.archive);
      }
      this.archive = archive;
      this.bubble(this.archive, "change");
      this.archive.listenBy(this, "change", this.render);
      return this.render();
    };

    ArchiveDisplayer.prototype.unsetArchive = function() {
      if (this.archive) {
        this.archive.stopListenBy(this);
      }
      return this.archive = null;
    };

    ArchiveDisplayer.prototype.focus = function() {
      return this.node$.addClass("focus");
    };

    ArchiveDisplayer.prototype.blur = function() {
      return this.node$.removeClass("focus");
    };

    ArchiveDisplayer.prototype._renderShareInfo = function(profile, howmany) {
      var html, words;
      if (howmany === 0) {
        this.UI.shareInfo$.text("");
        return true;
      }
      if (!profile) {
        this.UI.shareInfo$.text(i18n.thisManyPeopleHasShareIt_i(howmany));
        return true;
      }
      if (profile) {
        html = "<img src='http://www.gravatar.com/avatar/" + profile.hash + "?s=12&d=identicon'></img>";
        if (howmany > 1) {
          words = i18n.andThisMorePeopleHasShareIt_i(howmany - 1);
        } else {
          words = profile.nickname + " " + i18n.sharesIt();
        }
        return this.UI.shareInfo$.html(html + words);
      }
    };

    ArchiveDisplayer.prototype.render = function() {
      var content, forceProxy, maybeList, originalLink, profile, shareRecords, toDisplay;
      this.UI.title$.text(this.archive.title);
      if (this.UI.avatar && this.archive.author && this.archive.author.avatar) {
        this.UI.avatar$.addClass("show");
        this.UI.avatar.src = this.archive.author.avatar;
        this.UI.avatar.errorSrc = "/image/author-avatar-default.png";
        this.UI.avatar.loadingSrc = "/image/author-avatar-default.png";
      } else {
        this.UI.avatar$.removeClass("show");
      }
      if (this.archive.originalLink) {
        this.UI.title$.attr("href", this.archive.originalLink);
      }
      if (this.archive.like) {
        this.UI.like$.addClass("active");
      } else {
        this.UI.like$.removeClass("active");
      }
      maybeList = this.archive.listName || this.maybeList || App.userConfig.get("" + this.archive.sourceGuid + "/maybeList") || "read later";
      this.VM.listName = maybeList;
      if (this.archive.listName === maybeList) {
        this.UI.readLater$.addClass("active");
      } else {
        this.UI.readLater$.removeClass("active");
      }
      if (this.archive.listName) {
        this.VM.listText = "list (" + this.archive.listName + ")";
      } else {
        this.VM.listText = "list";
      }
      if (this.archive.createDate) {
        this.UI.date$.text(moment(this.archive.createDate).format(i18n.fullDateFormatString()));
      }
      if (this.archive.share) {
        this.UI.share$.addClass("active");
      } else {
        this.UI.share$.removeClass("active");
      }
      shareRecords = this.archive.meta.shareRecords;
      if (shareRecords) {
        profile = this.archive.getFirstValidProfile();
        this._renderShareInfo(profile, shareRecords.length);
      }
      this.UI.sourceName$.text(this.archive.sourceName);
      originalLink = this.archive.originalLink || "";
      if (this.useDisplayContent) {
        toDisplay = this.archive.displayContent || this.archive.content;
      } else {
        toDisplay = this.archive.content;
      }
      if (this.currentContent !== toDisplay) {
        this.currentContent = toDisplay;
        if (!this.currentContent) {
          this.UI.content$.text("");
          return;
        }
        forceProxy = App.userConfig.get("enableResourceProxy/" + this.archive.sourceGuid);
        if ((App.userConfig.get("enableResourceProxy") || forceProxy) && App.userConfig.get("useResourceProxyByDefault")) {
          content = document.createElement("div");
          content.innerHTML = sanitizer.sanitize(toDisplay);
          $(content).find("img").each(function() {
            var contentImage, img;
            img = this;
            contentImage = this.namespace.createWidgetByElement(elem, "ContentImage");
            if (contentImage) {
              contentImage.replace(img);
              img.removeAttribute("src");
              return img = contentImage.node;
            } else {
              console.log(this.namespace.scope);
              return console.error("no content image");
            }
          });
          this.UI.content$.html(content.innerHTML);
        } else {
          this.UI.content$.html(sanitizer.sanitize(toDisplay));
        }
        return this.UI.content$.find("a").each(function() {
          return this.setAttribute("target", "_blank");
        });
      }
    };

    ArchiveDisplayer.prototype.onClickShare = function() {
      if (!this.archive.share) {
        console.log(this.archive);
        return this.archive.markAsShare((function(_this) {
          return function(err) {
            return _this.render();
          };
        })(this));
      } else {
        return this.archive.markAsUnshare((function(_this) {
          return function(err) {
            return _this.render();
          };
        })(this));
      }
    };

    ArchiveDisplayer.prototype.onClickReadLater = function() {
      var maybeList;
      maybeList = App.userConfig.get("" + this.archive.sourceGuid + "/maybeList") || "read later";
      if (!this.archive.listName) {
        return this.archive.changeList(maybeList, (function(_this) {
          return function(err) {
            if (err) {
              console.error(err);
            }
            return _this.render();
          };
        })(this));
      } else {
        return this.archive.changeList(null, (function(_this) {
          return function(err) {
            if (err) {
              console.error(err);
            }
            return _this.render();
          };
        })(this));
      }
    };

    ArchiveDisplayer.prototype.onClickLike = function() {
      if (!this.archive.like) {
        return this.archive.likeArchive((function(_this) {
          return function(err) {
            if (err) {
              console.error(err);
            }
            return _this.render();
          };
        })(this));
      } else {
        return this.archive.unlikeArchive((function(_this) {
          return function(err) {
            if (err) {
              console.error(err);
            }
            return _this.render();
          };
        })(this));
      }
    };

    ArchiveDisplayer.prototype.onClickList = function(e) {
      if (!this.listSelector) {
        this.listSelector = new ArchiveDisplayerListSelector();
        this.listSelector.listenBy(this, "select", (function(_this) {
          return function(listModel) {
            return _this.archive.changeList(listModel.name, function(err) {
              App.userConfig.set("" + _this.archive.sourceGuid + "/maybeList", listModel.name);
              _this.listSelector.active(listModel.name);
              _this.listSelector.hide();
              return _this.render();
            });
          };
        })(this));
      }
      this.listSelector.updateState();
      this.listSelector.show(e);
      if (this.archive.listName) {
        return this.listSelector.active(this.archive.listName);
      }
    };

    ArchiveDisplayer.prototype.markAsLike = function() {
      if (!this.archive.like) {
        return this.archive.likeArchive(function() {
          return this.render();
        });
      }
    };

    ArchiveDisplayer.prototype.markAsUnlike = function() {
      if (!this.archive.like) {
        return this.archive.unlikeArchive((function(_this) {
          return function() {
            return _this.render();
          };
        })(this));
      }
    };

    return ArchiveDisplayer;

  })(Leaf.Widget);

  Popup = require("/widget/popup");

  tm.use("baseView/archiveDisplayerListSelector");

  ArchiveDisplayerListSelector = (function(_super) {
    __extends(ArchiveDisplayerListSelector, _super);

    function ArchiveDisplayerListSelector() {
      ArchiveDisplayerListSelector.__super__.constructor.call(this, App.templates.baseView.archiveDisplayerListSelector);
      this.lists = Leaf.Widget.makeList(this.UI.lists);
      this.lists.on("child/add", (function(_this) {
        return function(item) {
          return item.listenBy(_this, "select", _this.select);
        };
      })(this));
      this.lists.on("child/remove", (function(_this) {
        return function(item) {
          return item.stopListenBy(_this);
        };
      })(this));
    }

    ArchiveDisplayerListSelector.prototype.updateState = function() {
      var list, _i, _len, _ref, _results;
      this.lists.length = 0;
      _ref = Model.ArchiveList.lists.models;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        list = _ref[_i];
        _results.push(this.lists.push(new ArchiveDisplayerListSelectorItem(list)));
      }
      return _results;
    };

    ArchiveDisplayerListSelector.prototype.show = function(e) {
      var height, left, top;
      ArchiveDisplayerListSelector.__super__.show.call(this);
      if (!e) {
        return;
      }
      if (Leaf.Util.isMobile()) {
        return;
      }
      this.node$.width(300);
      height = this.node$.height();
      top = e.clientY + 15 - height;
      left = e.clientX - 10;
      top = top > 0 && top || 0;
      left = left > 0 && left || 0;
      return this.node$.css({
        position: "absolute",
        top: top,
        left: left
      });
    };

    ArchiveDisplayerListSelector.prototype.select = function(item) {
      return this.emit("select", item.list);
    };

    ArchiveDisplayerListSelector.prototype.active = function(name) {
      var item, _i, _len, _ref, _results;
      if (!name) {
        return;
      }
      _ref = this.lists;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        item.deactive();
        if (item.list.name === name) {
          _results.push(item.active());
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    };

    ArchiveDisplayerListSelector.prototype.onClickCloseButton = function() {
      return this.hide();
    };

    return ArchiveDisplayerListSelector;

  })(Popup);

  ArchiveDisplayerListSelectorItem = (function(_super) {
    __extends(ArchiveDisplayerListSelectorItem, _super);

    function ArchiveDisplayerListSelectorItem(list) {
      this.list = list;
      ArchiveDisplayerListSelectorItem.__super__.constructor.call(this, "<li data-text='name'></li>");
      this.VM.name = this.list.name;
    }

    ArchiveDisplayerListSelectorItem.prototype.onClickNode = function() {
      return this.emit("select", this);
    };

    ArchiveDisplayerListSelectorItem.prototype.active = function() {
      return this.VM.name = "(current) " + this.list.name;
    };

    ArchiveDisplayerListSelectorItem.prototype.deactive = function() {
      return this.VM.name = this.list.name;
    };

    return ArchiveDisplayerListSelectorItem;

  })(Leaf.Widget);

  module.exports = ArchiveDisplayer;

}).call(this);
