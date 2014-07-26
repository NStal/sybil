SourceAuthorizer

Source
    from: SourceModel
    has: SourceUpdator
    has: SourceAuthorizer
    has: SourceInitialzer
    
Collector
    from: HardCode
    hasMany: Source

Source can be directly interacted with other modules when needed, Though create/delete and stop/restart should always go through collector.