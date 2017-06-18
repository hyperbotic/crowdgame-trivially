Ti.API.info("+");
Ti.API.info("+");
Ti.API.info("TRIVIALLY CONSOLE ++++++++++++++++++++++++++++++++++++++");
Ti.API.info("PLAYER NETWORK STUB ++++++++++++++++++++++++++++++++++++++");
Ti.API.info("++++++++++++++++++++++++++++++++++++++++++++++++++++++++");

var Hyperbotic = {};
var Hy = Hyperbotic;

require('underscore-1.5.2.js');
require('uuid.js');

require('generated_js/config.js');

require('generated_js/trace.js');
require('generated_js/extensions.js');
require('generated_js/utils.js');

require('generated_js/http_server_proxy.js');
require('generated_js/player_network.js');

var gPlayerNetwork = new Hy.Network.PlayerNetwork();

Ti.API.info("++++++++++++++++++++++++++++++++++++++++++++++++++++++++");
Ti.API.info("+");
Ti.API.info("+");

