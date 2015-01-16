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
	//alert(api_key);
	customSuccess = success;
	customFail = fail;
	exec(pushNotification.successFn, pushNotification.failureFn, 'PushNotification', 'pushRegister', [api_key]);
};

	/**
	 Unregisters the device with the APNS (iOS) or GCM (Android) and the Unified Push server.
	 @status Stable
	 @param {Function} success - callback to be executed if the request results in success
	 @param {Function} [error] - callback to be executed if the request results in error
	 @returns {void}
	 @example
	 push.unregister(successHandler, errorHandler);
	 */
	PushNotification.prototype.unregister = function(successCallback, errorCallback) {
		// alert("unregister");
		if (errorCallback == null) {
			errorCallback = function() {
			}
		}

		if ( typeof successCallback != "function") {
			console.log("Push.unregister failure: success callback parameter must be a function");
			return;
		}

		exec(successCallback, errorCallback, "PushNotification", "unregister", []);
	};


	/**
    Call this to set the application icon badge -- ios specific
    @status Stable
    @param {Function} success - callback to be executed if the request results in success
    @param {String|Number} [badge] - the badge number to set on the application icon
    @returns {void}
    @example
    push.setApplicationIconBadgeNumber(successHandler, errorHandler);
*/
PushNotification.prototype.setApplicationIconBadgeNumber = function (successCallback, badge) {
    if (typeof successCallback != "function") {
        console.log("Push.setApplicationIconBadgeNumber failure: success callback parameter must be a function");
        return;
    }

    exec(successCallback, successCallback, "PushPlugin", "setApplicationIconBadgeNumber", [
        {badge: badge}
    ]);
};

/**
 * Call this function to tell the OS if there was data or not so it can schedule the next fetch operation
 * @param {int} dataType - one of the BackgroundFetchResults or 0 new data 1 no data or 2 failed
 * @returns {void}
 */
PushNotification.prototype.setContentAvailable = function(dataType) {
    //return exec(null, null, "PushPlugin", "setContentAvailable", [{type: dataType}]);
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