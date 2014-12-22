(function(win, doc){
    var ENTRY = 'mweibo';
    var PRELOGIN = '//login.sina.com.cn/sso/prelogin.php?checkpin=1&entry=' + ENTRY;
    var LOGIN = '//passport.sina.cn/sso/login';
    var VERIFY_IMAGE = '//passport.sina.cn/captcha/image';
    var ERROR_COUNT = 0;
    var ERROR_COUNT_Mobile = 0;
    
    function parseJSON(str){
	if(typeof(str) === 'object') {
	    return str;
	} else {
	    if(window.JSON){
		return JSON.parse(str);
	    } else {
		return eval('(' + str + ')');
	    }
	}
    }
    
    function encodeFormData(data){
	var pairs = [], regexp = /%20/g;

	var value;
	for(var key in data){
	    value = data[key].toString();

	    // encodeURIComponent encodes spaces as %20 instead of "+"
	    pairs.push(win.encodeURIComponent(key).replace(regexp, '+') +
		       '=' + win.encodeURIComponent(value).replace(regexp, '+'));
	}

	return pairs.join('&');
    }
    
    function $(id){
	return doc.getElementById(id);
    }
    var LOGIN_SUCCESS_ADDRESS = $('loginSuccessAddress').value;
    
    
    function hasClass(elem, cls){
	var reg = new RegExp('(^|\\s)' + cls + '($|\\s)');
	return reg.test(elem.className);
    }

    function removeClass(elem, cls){
	var reg = new RegExp('(^|\\s)' + cls + '($|\\s)', 'g');
	elem.className = elem.className.replace(reg, ' ');
    }

    function addClass(elem, cls){
	if(!hasClass(elem, cls)){
	    elem.className += ' ' + cls;
	}
    }

    var addEvent = doc.addEventListener ?
	function(elem, type, fn){
	    elem.addEventListener(type, fn, false);
	} : function(elem, type, fn){
	    elem.attachEvent('on' + type, fn);
	};
    function bind(fn, context){
	return function(){
	    fn.call(context);
	};
    }
    function utf8_to_b64(str){
	return win.btoa(win.encodeURIComponent(trim(str)));
    }
    function trim(str){
	return (!str) ? '' : str.toString().replace(/^\s+|\s+$/g, '');
    }
    function objLength(obj) {
	var cnt = 0;
	if (typeof obj != "object") return 0;
	for (var k in obj) {
	    if (obj.hasOwnProperty(k)) cnt++;
	}
	return cnt;
    }
    
    function Login(){
	this.init();
    };
    
    Login.prototype = {
	mode: 0,
	countDown : 60,
	intervalCount : 0,
	lastLogin: $('lastLogin'),
	loginName: $('loginName'),
	loginPassword: $('loginPassword'),
	loginNamePassword: $('loginNamePassword'),
	dVerifyCode: $('dVerifyCodeWrapper'),
	weidunCode: $('loginDVCode'),
	needWeidun: false,
	verifyCodeWrapper: $('verifyCodeWrapper'),
	verifyImage: $('verifyCodeImage'),
	verifyCode: $('loginVCode'),
	changeVerifyCode :$('changeVerifyCode'),
	needVerifyCode: false,
	errorMsg: $('errorMsg'),
	errorDialogMsg : $('errorDialogMsg'),
	errorDialog : $('errorDialog'),
	loginNamePanel : $('loginNamePanel'),
	jumpName: $('loginName'),
	errorDialogBtnF: $('errorDialogBtnF'),
	errorDialogBtnT: $('errorDialogBtnT'),
	errorBtn : $('errorBtn'),
	//	countDownButton :  $('mVerifyBtn'), 
	mobileLogin:$('mobileLogin'),
	passwordLogin:$('passwordLogin'),
	forgetPassword : $('forgetPassword'),
	register :  $('register'),
	loginAction : $('loginAction'),
	weiboLogin : $('weiboLogin'),
	loginWrapper : $('loginWrapper'),
	accountWrapper : $('accountWrapper'),
	uctext : $('uctext'),
	weibotext : $('weibotext'),
	ucORweiboLogin : $('ucORweiboLogin'),
	changeLogin : $('changeLogin'),
	errorDialogPanel : $('errorDialogPanel'),
	oldUserName : $('oldUserName'),
	avatarWrapper : $('avatarWrapper'),
	loginnameclear : $('loginnameclear'),
	ucname : $('ucname'),
	ucavatar : $('ucavatar'),
	loginRF : $('loginRF'),
	postform : $('postform'),
	loginfrom : $('loginfrom'),

	loginRF : $('loginRF'),
	postform : $('postform'),
	loginfrom : $('loginfrom'),
	clientId : $('client_id'),
	redirectUri : $('redirect_uri'),
	display : $('display'),
	offcialMobile : $('offcialMobile'),
	action : $('action'),
	quickAuth : $('quick_auth'),
	countDownKey : true,
	disabled : false,
	appsetInterval : null,
        featurecode : $('featurecode'),
	
	init: function(){
	    var that = this;
	    that.bindEvent();
	    that.ucYORN();	
	},
	ucYORN:function(){
	    var that = this; 
	    var loginRFValue = that.loginRF.value;
	    if(window.ucweb&&window.ucweb.startRequest&&loginRFValue!=1){
		var ucCode = window.ucweb.startRequest('shell.comments.getToken', ['weibo','noauth']);
		var url = 'http://passport.sina.cn/sso/uclogin';//php请求接口
		if(ucCode&&trim(ucCode.length>8)){
		    ajax({
			url:'https://passport.sina.cn/signin/ajuclogin',
			data:{
			    token : ucCode
			},
			type : 'get',
			onsuccess : function(ret){
			    var result = parseJSON(ret);
			    if(result.retcode == 20000000){
				that.ucname.innerHTML = result.data.nick;
				that.ucavatar.src = result.data.avatar;
				that.loginWrapper.style.display = 'none';
				that.accountWrapper.style.display = 'block';
				that.uctext.style.display = 'block';
				that.weibotext.style.display = 'none';
				that.ucORweiboLogin.onclick = function(){
				    ajax({
					url: 'https://passport.sina.cn/sso/uclogin',
					type: 'post',
					data: {
					    token : ucCode,
					    entry : 'mweibo',
					    r:LOGIN_SUCCESS_ADDRESS
					},
					onsuccess: function(ret){
					    var result = parseJSON(ret);
					    if(result.retcode == 20000000){
						that.addCookie(result.data,true);
					    } 
					}
				    });					
				};
			    }else{
				that.weiboAppYORN();
			    };
			}
		    });
		}else{
		    that.weiboAppYORN();
		    return;
		}
	    }else{
		that.weiboAppYORN();
	    }
	},
	bindEvent: function(){
	    var that = this;
	    addEvent($('loginAction'), 'click', bind(this.doLogin, this));
	    addEvent(this.loginName, 'blur', bind(this.checkVerify, this));
	    addEvent(this.loginName, 'focus', bind(this.onInput, this));
	    addEvent(this.loginPassword, 'focus', bind(this.onInput, this));
	    addEvent(this.verifyImage, 'click', bind(this.getVerifyImage, this));
	    addEvent(this.changeVerifyCode, 'click', bind(this.getVerifyImage, this));
	    addEvent(this.changeLogin, 'click', function() {
		that.accountWrapper.style.display = 'none';
		that.loginWrapper.style.display = 'block';
	    });
	    addEvent(this.weidunCode, 'focus', function() {
		that.weidunCode.type = "tel";
	    });
	    addEvent(this.weidunCode, 'blur', function() {
		that.weidunCode.type = "text";
	    });
	    addEvent(this.errorDialogBtnF, 'click', function() {
		that.errorDialog.style.display = "none";
	    });
	    addEvent(win, 'resize', function(){
		that.setErrorDialogPanelPosition();
	    });
	    addEvent(that.errorDialogBtnT,'click',function(){
		var opt = {},formdata={},formstr='';
		opt.type = 'get';
		opt.url = 'https://passport.sina.cn/signin/ajsu';
		opt.data = {};
		opt.data.entry = 'mweibo';
		var inputs = that.postform.getElementsByTagName('input');
		for(var i = 0 ;i<inputs.length;i++){
		    formdata[inputs[i].id] = inputs[i].value;
		}
		debugger;
		formstr = encodeFormData(formdata);
		
		
		var loginRFValue = that.loginRF.value;
		
		formdata.client_id = that.clientId.value;
		formdata.redirect_uri = that.redirectUri.value;
		formdata.display = that.display.value;
		formdata.offcialMobile = that.offcialMobile.value;
		formdata.action = that.action.value;
		formdata.quick_auth = that.quickAuth.value;
		
		formstr = encodeFormData(formdata);
		debugger;
		
		var loginRFValue = that.loginRF.value;
		if(that.mode == 0 ){
		    opt.data.su = utf8_to_b64(trim(that.loginName.value));
		}
		opt.onsuccess = function(ret){
		    var result = parseJSON(ret);
		    if(result.retcode == 20000000){
			var href =  'https://passport.sina.cn/signin/loginsms?code='+result.data.code+'&r='+LOGIN_SUCCESS_ADDRESS+'&rf='+loginRFValue+'&'+formstr;
                        if (that.featurecode.value || that.featurecode.value.trim().length !== 0) {
                            href = href + "&featurecode=" + that.featurecode.value;
                        }
			win.location.href = href;
		    }
		}
		ajax(opt);
	    });
	    addEvent(that.loginnameclear,'click',function(){
		that.mode = 0;
		that.loginName.value = '';
		that.loginPassword.value = '';
		that.verifyCode.value = '';
		that.weidunCode.value = '';
		that.avatarWrapper.innerHTML='';
		that.verifyCodeWrapper.style.display = 'none';
		that.dVerifyCode.style.display = 'none';
		that.onInput();
		that.loginnameclear.className = "input-clear hid";
	    });
	},
	weiboAppYORN : function(){
	    var that = this;
	    var loginRFValue = that.loginRF.value;
	    var timeout = window.setTimeout(function(){
                that.loginWrapper.style.display = 'block';
		that.accountWrapper.style.display = 'none';
            }, 1000);
	    if(loginRFValue != 1){
		jsonp({
		    url: 'http://127.0.0.1:9527/query?appid=com.sina.weibo',
		    onsuccess: function(ret){
			var result = parseJSON(ret);
			if(result.result == 200&&result.hasLoginUser == 1){
			    window.clearTimeout(timeout);
			    that.loginWrapper.style.display = 'none';
			    that.accountWrapper.style.display = 'block';
			    that.uctext.style.display = 'none';
			    that.weibotext.style.display = 'block';
			    ucORweiboLogin.onclick = function(){
				ajax({
				    url: "https://passport.sina.cn/sso/ajgetappt?entry=abc",
				    type: 'get',
				    onsuccess: function(ret){
					var result = parseJSON(ret);
					if(result.retcode == 20000000){
					    win.location.href = "sinaweibo://browser?url=https%3A%2F%2Fpassport.sina.cn%2Fwapclient%2Fconfirm%3Ff%3Dw%26token%3D"+result.data.token;
					    that.appsetInterval = window.setInterval(function(){that.appLogin(result.data.token)}, 3000);
					}else{
					    win.location.href = "https://passport.sina.cn/wapclient/error?info=1";
					}
				    }
				});
			    };
			}
		    }
		});
	    }
	},
	doNeedVerifyCode: function(){
	    this.needVerifyCode = true;
	    this.verifyCodeWrapper.style.display = 'block';
	    this.getVerifyImage();
	},
	doNeedWeidun: function(){
	    this.needWeidun = true;
	    this.dVerifyCode.style.display = 'block';
	},
	doNeedMobile : function(url){
	    this.needWeidun = false;
	    this.needVerifyCode = false;
	    this.needMobile = true;
	    this.verifyCodeWrapper.style.display = 'none';
	    this.dVerifyCode.style.display = 'none';
	    this.errorDialogBtnT.innerHTML = '验证码登录';
	    this.errorDialogMsg.innerHTML = '您的账号是通过快速注册方式获得的，需通过验证码登陆方式登陆微博';
	    this.errorDialog.style.display = 'block';
	    this.setErrorDialogPanelPosition();
	},
	doLogin: function(){
	    if(this.disabled){
		return;
	    }
	    var that = this;
	    var fromValue = that.loginfrom.value;
	    var loginRFValue = trim(that.loginRF.value);
	    if(that.validate()){
		var data;
		that.changeDisabled(true);
		if(that.mode == 0){
		    data = {
			username: trim(that.loginName.value),
			password: trim(that.loginPassword.value),
			savestate: 1
		    };
		} else {
		    data = {
			password: trim(that.loginPassword.value),
			savestate: 1
		    };
		}
		if(that.needWeidun){
		    data.vsn = trim(that.weidunCode.value);
		    //	that.weidunCode.value = '';
		}
		if(that.needVerifyCode){
		    data.pincode = trim(that.verifyCode.value);
		    data.pcid = that.verifyImage.getAttribute('data-pcid');
		}
		
		
		
		if(that.oldUserName.vaule != that.loginName.value){
		    ERROR_COUNT = 0;
		    ERROR_COUNT_Mobile = 0;
		}
		
		that.oldUserName.vaule = that.loginName.value;
		
		
		data.ec = ERROR_COUNT;

		
		data.pagerefer = document.referrer;
		
		data.entry = 'mweibo';
		
		loginRFValue ? data.rf = trim(loginRFValue) : null;
		
		data.loginfrom = fromValue;
		data.client_id = fClientid;
		
		if (that.featurecode.value || that.featurecode.value.trim().length !== 0) {
                    data.featurecode = that.featurecode.value;
                }

		ajax({
		    url: LOGIN,
		    type: 'post',
		    data: data,
		    onsuccess: function(ret){
			var result = parseJSON(ret);
			if(result.retcode == 20000000){
			    that.addCookie(result.data);
			} else {
			    that.dealLoginFail(result);
			}
		    }
		});

	    }
	},
	changeDisabled : function(control){
	    this.disabled = control;
	},
	errorDialogBtnHidden : function(){
	    this.errorDialogBtnMsg.innerHTML = '';
	    this.errorDialogBtn.style.display = 'none';
	},
	newRegister:function(){
	    var href = this.register.href;
	    this.errorDialogBtnHidden();
	    win.location.href = href;		
	},
	dealLoginFail: function(result){
	    //分成两种显示方式，一种是在顶导显示一种是用弹层显示
	    var that = this;
	    var loginRFValue = that.loginRF.value;
	    if(result.retcode == 50011009 || result.retcode == 50011011 || result.retcode == 50011002 || result.retcode == 50011008 || result.retcode == 50011010 || result.retcode == 50011012){
		//当rf为1的时候只提示错误
		if(result.retcode == 50011002&&loginRFValue!=1) {
		    if(ERROR_COUNT >= 2) {
			var errorData = parseJSON(result.data);
			if(errorData.er == 1) {
			    that.errorDialogBtnT.innerHTML = '确定';
			    addEvent(that.errorDialogBtnT,'click',function(){
				win.location.href = 'http://m.weibo.cn/forgotpwd/index';
			    });
			    that.errorDialogMsg.innerHTML = '登录失败，是否找回密码？';
			    that.errorDialog.style.display = 'block';
			    that.setErrorDialogPanelPosition();
			}
		    }else if (result.data.im === 1){//只有绑定手机的用户才在两次错误的时候出现使用手机验证码登录的流程
			
			if(ERROR_COUNT_Mobile ===1){
			    
			    that.errorDialogBtnT.innerHTML = '验证码登录';
			    that.errorDialogMsg.innerHTML = '帐号或密码错误，你也可以选择短信验证码方式登录微博。';
			    that.errorDialog.style.display = 'block';
			    that.setErrorDialogPanelPosition();
			    
			}else{
			    that.errorMsg.innerHTML = result.msg;
			    that.errorMsg.style.display = 'block';
			}
			ERROR_COUNT++;
			ERROR_COUNT_Mobile++;
		    } else{
			ERROR_COUNT++;
			ERROR_COUNT_Mobile = 0;
			that.errorMsg.innerHTML = result.msg;
			that.errorMsg.style.display = 'block';
		    }
		    if(that.needVerifyCode){
			that.getVerifyImage();
		    }
		}else{
		    that.errorMsg.innerHTML = result.msg;
		    that.errorMsg.style.display = 'block';
		}
		
	    }else{
		that.errorMsg.innerHTML = result.msg;
		
		that.errorMsg.style.display = 'block';
		
		if(result.retcode == 50011003 || result.retcode == 50011004){
		    that.needWeidun = true;
		    that.dVerifyCode.style.display = 'block';
		} else if(result.retcode == 50011005 || result.retcode == 50011006){
		    that.needVerifyCode = true;
		    that.verifyCodeWrapper.style.display = 'block';		
		    that.getVerifyImage();
		}			
	    }
	    that.weidunCode.value = '';
	    that.changeDisabled(false);
	},
	addCookie: function(obj,uc){
	    var that = this;
	    
	    setTimeout(function(){
		uc ? that.goToNextPageUC(obj) : that.goToNextPage(obj);
	    },5000);
	    var crossdomainlist = obj.crossdomainlist;
	    var counter = objLength(crossdomainlist);
	    if (counter == 0) {
		that.goToNextPage(obj);
	    }
	    for(var d in crossdomainlist) {
		if (!crossdomainlist.hasOwnProperty(d)) continue;
		jsonp({
		    url: crossdomainlist[d] + '&savestate=1',
		    onsuccess: function(){
			counter--;
			if (counter <= 0) {
			    uc ? that.goToNextPageUC(obj) : that.goToNextPage(obj);
			}
		    }
		});
	    }
	},
	goToNextPage: function(obj){
	    var that = this; 
	    if(obj['toauth']!=1){
		var href =  obj['loginresulturl'] ? obj['loginresulturl'] + '&savestate=1&url=' + LOGIN_SUCCESS_ADDRESS : win.decodeURIComponent(LOGIN_SUCCESS_ADDRESS);
		win.location.href = href;
	    }else{
		if(obj['ticket']){
		    var ipt = document.createElement('input');
		    that.postform.appendChild(ipt);
		    ipt.id = 'ticket';
		    ipt.name = 'ticket';
		    ipt.type = 'hidden';
		    ipt.value = obj['ticket'];
		}
		that.postform.submit();
	    }
	},
	goToNextPageUC: function(obj){
	    var that = this; 
	    if(obj['toauth']!=1){
		var href = obj['loginresulturl'] ? obj['loginresulturl'] : win.decodeURIComponent(LOGIN_SUCCESS_ADDRESS);
		win.location.href = href;
	    }else{
		if(obj['ticket']){
		    var ipt = document.createElement('input');
		    that.postform.appendChild(ipt);
		    ipt.id = 'ticket';
		    ipt.name = 'ticket';
		    ipt.type = 'hidden';
		    ipt.value = obj['ticket'];
		}
		that.postform.submit();
	    }
	},
	validate: function(){
	    var username = trim(this.loginName.value);
	    var password = trim(this.loginPassword.value);
	    var that = this;
	    if(this.mode == 0){
		if(username.length == 0){
		    this.errorMsg.innerHTML = '用户名不能为空';			
		    this.errorMsg.style.display = 'block';
		    return false;
		} else if(password.length == 0&&!this.needMobile){
		    this.errorMsg.innerHTML = '密码不能为空';				
		    this.errorMsg.style.display = 'block';
		    return false;
		}
	    } else {
		if(password.length == 0&&!this.needMobile){				
		    this.errorMsg.innerHTML = '密码不能为空';
		    this.errorMsg.style.display = 'block';
		    return false;
		}
	    }
	    if(this.needWeidun && trim(this.weidunCode.value).length == 0){
		this.errorMsg.innerHTML = '请输入微盾动态码';		
		this.errorMsg.style.display = 'block';
		return false;
	    } else if(this.needVerifyCode && trim(this.verifyCode.value).length == 0){
		this.errorMsg.innerHTML = '请输入验证码';		
		this.errorMsg.style.display = 'block';
		return false;
	    }

	    return true;
	},
	checkVerify: function(){
	    var that = this;
	    var oldUserName =that.oldUserName.value,username = trim(that.loginName.value);
	    if(that.mode != 0&&oldUserName === username){
		return true;
	    }else{
		//增加对于手机验证码登陆情况的判断，，增加一个超链，增加一个点击事件
		if(that.mode != 0){
		    that.mode = 0;
		    that.avatarWrapper.innerHTML='';
		}
		jsonp({
		    url: PRELOGIN + '&su=' + utf8_to_b64(username),
		    onsuccess: function(ret){
			if(ret.retcode === 0){
			    if(ret.nopwd === 1&&ret.lm==1){
				that.verifyCodeWrapper.style.display = 'none';
				that.dVerifyCode.style.display = 'none';
				that.errorDialogBtnT.innerHTML = '验证码登录';
				that.errorDialogMsg.innerHTML = '您的账号是通过快速注册方式获得的，需通过验证码登陆方式登陆微博';
				that.errorDialog.style.display = 'block';
				that.setErrorDialogPanelPosition();
			    }else{
				switch(ret.showpin){//此处不要忘记隐藏需要手机验证码登陆时要隐藏的东西
				case 1:
				    that.dVerifyCode.style.display = 'none';
				    that.verifyCodeWrapper.style.display = 'block';
				    that.errorMsg.style.display = 'none';
				    that.getVerifyImage();
				    that.needVerifyCode = true;
				    that.needMobile = false;
				    that.needWeidun = false;
				    break;
				case 2:
				    that.dVerifyCode.style.display = 'block';
				    that.verifyCodeWrapper.style.display = 'none';
				    that.errorMsg.style.display = 'none';
				    that.needWeidun = true;
				    that.needMobile = false;
				    that.needVerifyCode = false;
				    break;
				default:
				    that.verifyCodeWrapper.style.display = 'none';
				    that.dVerifyCode.style.display = 'none';
				    that.errorMsg.style.display = 'none';
				    that.needVerifyCode = false;
				    that.needWeidun = false;
				    that.needMobile = false;
				    break;
				}
			    }
			}
		    }
		});
	    }
	},
	onInput: function(){
	    this.errorMsg.innerHTML = '';
	    this.errorMsg.style.display = 'none';
	},
	getVerifyImage: function(){
	    var that = this;
	    ajax({
		url: VERIFY_IMAGE,
		type: 'get',
		onsuccess: function(ret){
		    var result = parseJSON(ret);
		    if(result.retcode == 20000000){
			that.verifyImage.src = result.data.image;
			that.verifyImage.setAttribute('data-pcid', result.data.pcid);
		    }
		}
	    });
	},
	appLogin : function(token){
	    var that = this;
	    if(that.intervalCount >= 200){
		win.clearInterval(that.appsetInterval);
		that.intervalCount = 0;
		return;
	    };
	    that.intervalCount++;
	    ajax({
		url: 'https://passport.sina.cn/wapclient/check?token='+token+'&r='+LOGIN_SUCCESS_ADDRESS,
		type: 'get',
		onsuccess: function(ret){
		    var json = parseJSON(ret);
		    if(json.retcode == 20000000){
			window.location.href = json.data;
		    }
		}
	    })
	},
	setErrorDialogPanelPosition : function(){
	    var that = this;
	    that.setPosition(that.errorDialogPanel,'center');
	},
	setPosition : function(dom,position){
	    var top,left,width = dom.offsetWidth,height = dom.offsetHeight,
		winWidth = doc.body.clientWidth,winHeight = doc.body.clientHeight,
		dd = doc.documentElement,db = doc.body,
		limitTop = top = Math.max(window.pageYOffset || 0, dd.scrollTop, db.scrollTop),
		limitLeft = left = Math.max(window.pageXOffset || 0, dd.scrollLeft, db.scrollLeft);
	    if(position === 'center'){
		top +=(winHeight - height) / 2;
		left += (winWidth - width) / 2;
		if(top < limitTop) top = limitTop;
		if(left < limitLeft) left = limitLeft;
	    }
	    dom.style.top = top + 'px';
	    dom.style.left = left + 'px';
	}
    };
    
    win.loginApp = new Login();
    
    addEvent(document, 'keydown', function(e){
	e = e || window.event;
	if(e.keyCode == 13){
	    loginApp.doLogin();
	}
    });
})(window, document);
