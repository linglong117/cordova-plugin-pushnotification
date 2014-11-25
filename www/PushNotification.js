var argscheck = require('cordova/argscheck'), channel = require('cordova/channel'), utils = require('cordova/utils'), exec = require('cordova/exec'), cordova = require('cordova');

var PushNotification = function() {
	this.registered = false;
	//
	this.appId = null;
	this.channelId = null;
	this.clientId = null;

	var me = this;

	me.getInfo(function(info) {
		me.appId = info.appId;
		me.channelId = info.channelId;
		me.clientId = info.clientId;
	});

	//alert("me >>>> " + JSON.stringify(me));
};

PushNotification.prototype.customSuccess = {};
PushNotification.prototype.customFail = {};

PushNotification.prototype.init = function(api_key, success, fail) {
	//alert(api_key);
	customSuccess = success;
	customFail = fail;
	exec(success, fail, 'PushNotification', 'init', [api_key]);
};

PushNotification.prototype.register = function(options, successCallback, errorCallback) {

	//alert("options" + JSON.stringify(options));

	// customSuccess = success;
	// customFail = fail;
	// exec(fastgoPushNotification.successFn, fastgoPushNotification.failureFn, 'PushNotification', 'init', [api_key]);

	//alert("PushNotification.prototype.register");
	alert("opt  >>>> " + JSON.stringify(options));

	if (errorCallback == null) {
		errorCallback = function() {
		}
	}

	if ( typeof errorCallback != "function") {
		console.log("PushNotification.register failure: failure parameter not a function");
		return
	}

	if ( typeof successCallback != "function") {
		console.log("PushNotification.register failure: success callback parameter must be a function");
		return
	}

	cordova.exec(successCallback, errorCallback, "PushPlugin", "register", [options]);

};

PushNotification.prototype.successFn = function(info) {
	//alert(JSON.stringify(info));
	if (info) {
		customSuccess(info);
		pushNotification.registered = true;
		cordova.fireDocumentEvent("cloudPushRegistered", info);
	}
};

PushNotification.prototype.failureFn = function(info) {
	customFail(info);
	pushNotification.registered = false;
};

PushNotification.prototype.getInfo = function(successCallback, errorCallback) {
               //alert("getInfo");
	argscheck.checkArgs('fF', 'PushNotification.getInfo', arguments);
	exec(successCallback, errorCallback, "PushNotification", "getInfo", []);
};
               
               
var pushNotification = new PushNotification();

module.exports = pushNotification;
