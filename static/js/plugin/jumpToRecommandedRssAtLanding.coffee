class JumpToRecommandedRssAtLanding
    load:()->
        sybil.rssList.on "firstSync",()->
            for rss in sybil.rssList.items
                if rss.data.unreadCount > 0
                    rss.onClickNode()
                    break
Plugins.push JumpToRecommandedRssAtLanding