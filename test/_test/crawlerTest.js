(function() {
  var fetcher, rssFetcher;

  rssFetcher = require("../crawler/rssFetcher.coffee");

  fetcher = new rssFetcher.RssFetcher("http://bitinn.net/category/asides/feed/");

  fetcher.fetch(function(err, info) {
    if (err) {
      throw err;
    }
    return console.log("meta", info.meta);
  });

}).call(this);
