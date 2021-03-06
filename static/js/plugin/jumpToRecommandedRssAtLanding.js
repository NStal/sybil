// Generated by CoffeeScript 1.6.3
(function() {
  var JumpToRecommandedRssAtLanding;

  JumpToRecommandedRssAtLanding = (function() {
    function JumpToRecommandedRssAtLanding() {}

    JumpToRecommandedRssAtLanding.prototype.load = function() {
      return sybil.rssList.on("firstSync", function() {
        var rss, _i, _len, _ref, _results;
        _ref = sybil.rssList.items;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          rss = _ref[_i];
          if (rss.data.unreadCount > 0) {
            rss.onClickNode();
            break;
          } else {
            _results.push(void 0);
          }
        }
        return _results;
      });
    };

    return JumpToRecommandedRssAtLanding;

  })();

  Plugins.push(JumpToRecommandedRssAtLanding);

}).call(this);
