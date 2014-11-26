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

PushNotification.prototype.startWork = function(api_key, success, fail) {
	alert(api_key);
	customSuccess = success;
	customFail = fail;
	exec(pushNotification.successFn, pushNotification.failureFn, 'PushNotification', 'pushRegister', [api_key]);
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
	argscheck.checkArgs('fF', 'PushNotification.getInfo', arguments);
	exec(successCallback, errorCallback, "PushNotification", "getInfo", []);
};
var pushNotification = new PushNotification();

module.exports = pushNotification;