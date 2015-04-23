
module.exports = (function() {
    return function(option) {
        // we push h1,h2  hijack state
        // should always at h2 when every thing is finished
        // I found that browser history.back is not sync method
        //        var history = null;
        
        //var console = {debug:function(){}}
        // fake history for browser don't support history
        var option = option || {}
        var hasHistory = !! window.history.pushState;
        var virtualLocation = document.location.toString();
        var fakeHistory = {
            pushState: function(data,title,url) {
                if (window.history.pushState) {
                    window.history.pushState.apply(this, arguments);
                }else{
                    setLocation(url);
                }
            },
            replaceState: function() {
                if (window.history.replaceState) {
                    window.history.replaceState.apply(this, arguments);
                }else{
                    setLocation(url);
                }
            },
            back: function() {
                if (window.history.back) {
                    window.history.back.apply(this, arguments);
                }
            },
            forward: function() {
                if (window.history.forward) {
                    window.history.forward.apply(this, arguments);
                }
            }
        }
        var setLocation = function(url){
            document.location;
            virtualLocation = url;
        }
        var getLocation = function(){
            if(hasHistory){
                return document.location.toString();
            }else{
                return virtualLocation || document.location.toString();
            }
        }
        if (hasHistory) {
            history = window.history;
        } else {
            history = fakeHistory;
        }
        // end history polly fill
        var obj = {
            stack:[]
            ,push:function(id,callback){
                this.stack.push({id:id,callback:callback});
            }
            ,pop:function(){
                return this.stack.pop();
            }
            ,remove:function(id){
                this.stack = this.stack.filter(function(item){return item.id != id});
            }
            ,active:function(){
                this._tick = this.tick.bind(this);
                window.addEventListener("popstate",this._tick);
                this.debug("before recover",history.length);
                this.recoverHistoryHooks("h1");
                this.debug("after recover",history.length,history.state);
                this.isActive = true
            }
            ,deactive:function(){
                window.removeEventListener("popstate",this._tick);
                this.isActive = false
            }
            ,clearStack:function(){
                // clear stacked back button hijack
                while(stack.length > 0){
                    var item = this.pop();
                    if (item) {
                        try {
                            item.callback();
                        } catch (e) {
                            console.error(e);
                            console.error(e.stack);
                        }
                    }
                }
            }

            // I have to use a state machine since history.back
            // is an  async method not even has a call back to indicate me it's done
            // I have to use a state machine to track what to do
            ,stateMachineMap:{
                // hstate-hasBackButtonHook-unloadState-pushingUrl
                "h1-true-none-\\w+":"_callHookAndRecoverH2"
                ,"h1-false-none-\\w+":"_backBeforeH1AndRouting"
                ,"\\w+-\\w+-route-\\w+":"_previousRoute"
                ,"route-true-none-\\w+":"_recoverH1AndClearHooksAndRouteToCurrentUrl"
                ,"route-false-none-\\w+":"_recoverH1AndRouteToCurrentUrl"
                ,"\\w+-\\w+-h2-\\w+":"_unloadToH1"
                ,"\\w+-\\w+-h1-true":"_pushUrl"
                ,"none-\\w+-none-\\w+":"_recoverH1"
            }
            ,unloadState:"none"
            ,hstate:"none"
            ,debug:function(){
                return
                var args = [].slice.call(arguments,0)
                console.debug.apply(console,args)
            }
            ,tick:function(e){
                var tickInfo = e.state || {}
                var hstate = tickInfo.hstate || "none";
                var hasBackButtonHook = this.stack.length > 0;
                var states = [hstate,hasBackButtonHook,this.unloadState,this.pushingUrl].join("-"); 
                //debugger;
                this.hstate = hstate;
                var mapHandler = null;
                
                this.debug("states",states,history.length);
                for(checker in this.stateMachineMap){
                    var reg = new RegExp(checker,"i");

                    if(reg.test(states)){
                        mapHandler = this.stateMachineMap[checker]
                    }
                }
                if(this[mapHandler]){
                    this.debug("e.state",e.state,"maps:",mapHandler);
                    return this[mapHandler]();
                }else{
                    
                    // default action just go silent
                    console.error("unkown state",states);
                    if(option.debug){
                        this.debug("likely to be empty history")
                        this.debug("just go back...")
                        return true;
                        this.debug("prevent it to easier debug.");
                        return false;
                    }else{
                        this.debug("let it go.");
                        return true;
                    }
                }
                return false;
            }
            // Note: no callback or pop callback
            // can be excuted when not full recover to h2
            ,_callHookAndRecoverH2:function(){
                this.recoverHistoryHooks("h2");
                var handler = this.pop();
                handler.callback();
                return false;
            }
            ,_backBeforeH1AndRouting:function(){
                this.unloadState = "route"
                history.back();
                return false;
            }
            ,_recoverH1AndRouteToCurrentUrl:function(){
                this.recoverHistoryHooks("h1")
                this.emit("routeTo", getLocation());
                return false;
            }
            ,_recoverH1AndClearHooksAndRouteToCurrentUrl:function(){
                this.recoverHistoryHooks("h1");
                this.clearStack();
                this.emit("routeTo", getLocation());
                return false;
            }
            ,_unloadToH1:function(){
                this.debug("unload to h1",history.length);
                this.unloadState = "h1";
                history.back();
                return false;
            }
            ,_unloadToRoute:function(){
                
                this.debug("unload to route",history.length);
                this.unloadState = "route";
                history.back();
                return false;
            }
            ,_previousRoute:function(){
                this.debug("to previous route",history.length);
                this.unloadState = "none";
                history.back();
            }
            ,_pushUrl:function(){
                // this is an expectation for the above Note "no callback before recover to h2"
                // because we need to modify something before h1 and h2
                
                this.debug("push url",this._pushHistoryUrl,history.length);
                this.unloadState = "none";
                this.pushingUrl = false
                if(this._pushHistoryUrl){
                    history.pushState({hstate:"route"},"",this._pushHistoryUrl);
                }
                this.recoverHistoryHooks("h1");
                if(this._doneUnloadBackButton){
                    var callback = this._doneUnloadBackButton;
                    this._doneUnloadBackButton = null;
                    callback();
                }
                return false;
            }
            ,_previousRoute:function(){
                this.unloadState = "none";
                this.pushingUrl = false;
                history.back();
                return false;
            }
            ,_back:function(){
                history.back();
                return false;
            }
            ,_recoverH1:function(){
                this.recoverHistoryHooks("h1");
                return false;
            }
            ,ensure:function(url,silent){
                var urlModule = require("/lib/url").url
                var target = urlModule.parse(url)
                var current = urlModule.parse(getLocation())
                if(target.pathname === current.pathname){
                    return true;
                }
                this.goto(url,silent);
            }
            ,goto:function(url,silent){
                if(!this.isActive){
                    return;
                }
                if(this.gotoModifier){
                    url = this.gotoModifier(url)
                }
                if(this.unloadState != "none"){
                    this.debug("can't goto any where before fully unload h2");
                    return;
                }
                this._pushHistoryUrl = url;
                this._doneUnloadBackButton = function(){
                    if (silent) {
                        return;
                    }
                    this.emit("routeTo",getLocation());
                }.bind(this);
                this.unloadState = "h2";
                this.pushingUrl = true;
                history.back();
            }
            ,recoverHistoryHooks:function(from){
                if(from == "h2"){
                    history.pushState({hstate:"h2"},"",this._bhUrl || getLocation());
                }else{
                    history.pushState({hstate:"h1"},"",getLocation());
                    history.pushState({hstate:"h2"},"",this._bhUrl || getLocation());
                }
                this.hstate = "h2";
            }
            ,getLocation:function(){
                return getLocation();
            }
            ,setBackButtonHistory:function(url){
                this.debug("setBackButtonHistory",url);
                if(!this._oldUrl){
                    this._oldUrl = window.location.toString();
                    this.debug("save old",this._oldUrl,"from",url);
                }
                if(!url){
                    this.debug("recover old url",this._oldUrl);
                    history.replaceState({hstate:"h2"},"",this._oldUrl);
                    this._oldUrl = null
                    this._bhUrl = null;
                }else{
                    this._bhUrl = url;
                    history.replaceState({hstate:"h2"},"",url);
                }
            }
        }
        Leaf.EventEmitter.mixin(obj)
        return obj;
    }
})()
