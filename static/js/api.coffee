builder = new Leaf.ApiFactory()
builder.defaultMethod = "GET"
declare = builder.declare.bind(builder);
declare "subscribe",["source:string"]
declare "unsubscribe",["source:string"]
declare "rss",[]
declare "feed",["source:string","count:number","offset:number?","type:string?"]
declare "read",["id:string"]
declare "unread",["id:string"]
declare "markAllAsRead",["source:string"] 
window.API = builder.build()