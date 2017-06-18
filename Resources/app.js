/* Ensure that we stay in landscape mode during initialization */
var tempWindow = Ti.UI.createWindow({color: "#000", orientationModes:[Ti.UI.LANDSCAPE_LEFT, Ti.UI.LANDSCAPE_RIGHT], zindex:1});
var tempImage = Ti.UI.createImageView({image: "assets/bkgnds/animations/splash.png"});
tempWindow.add(tempImage);
tempWindow.open();
tempWindow.show();

var Hyperbotic = {};
var Hy = Hyperbotic;

Ti.API.info("+");
Ti.API.info("+");
Ti.API.info("TRIVIALLY CONSOLE ++++++++++++++++++++++++++++++++++++++");
Ti.API.info("++++++++++++++++++++++++++++++++++++++++++++++++++++++++");
Ti.API.info("+");
Ti.API.info("+");
Ti.API.info("Version=" + Ti.App.version);
Ti.API.info("Publisher=" + Ti.App.publisher);
Ti.API.info("URL=" + Ti.App.url);
Ti.API.info("+");
Ti.API.info("+");
Ti.API.info("AvailableMemory=" + Ti.Platform.availableMemory);
Ti.API.info("Platform Name=" + Ti.Platform.name);
Ti.API.info("Device=" + Ti.Platform.model);
Ti.API.info("OS=" + Ti.Platform.osname + " " + Ti.Platform.version);
Ti.API.info("UUID=" + Ti.Platform.id);
Ti.API.info("+");
Ti.API.info("+");
Ti.API.info("Online=" + Ti.Network.online);
Ti.API.info("NetworkType=" + Ti.Network.networkType);

/*alert(Ti.Network.networkTypeName + " " + Ti.Platform.address + " online=" + Ti.Network.online);*/
Ti.API.info("NetworkTypeName=" + Ti.Network.networkTypeName);
Ti.API.info("IP address => " + Ti.Platform.address);
Ti.API.info("+");
Ti.API.info("+");
Ti.API.info("+");
Ti.API.info("+");

_ = require('underscore-1.5.2.js');

require('uuid.js');

require('generated_js/config.js');

require('generated_js/trace.js');

if(Hy.Trace.name != "Trace") {
    alert("CrowdGame Trivially error: minification active");
}

require('generated_js/extensions.js');
require('generated_js/utils.js');

require('generated_js/network_utils.js');
require('generated_js/download_utils.js');
require('generated_js/update_utils.js');
require('generated_js/iap.js');

require('generated_js/analytics.js');
require('generated_js/commerce.js');
require('generated_js/options.js');
require('generated_js/contest.js');
require('generated_js/content.js');
require('generated_js/player.js');
require('generated_js/address_coder.js');
require('generated_js/player_network_proxy.js');
require('generated_js/ui.js');
require('generated_js/views.js');
require('generated_js/media.js');
require('generated_js/avatar.js');
require('generated_js/message_marquee.js');
require('generated_js/panels.js');
require('generated_js/pages.js');
require('generated_js/console_app.js');

(new Hy.ConsoleApp(tempWindow, tempImage)).init().start();

