
var exec = require('cordova/exec');


function PDFTron() {
  var me = this;
}

PDFTron.prototype.showDocumentViewer = function (success, error) {
  exec(success, error, 'PDFTron', 'showDocumentViewer', []);
};

function NativeViewer(dictionary, element, success, error) {
  if (element) {
    exec(success, error, 'PDFTron', 'NativeViewer', [dictionary, element.id]);
  } else {
    exec(success, error, 'PDFTron', 'NativeViewer', [dictionary]);
  }

  exec(onMessageFromNative, null, 'PDFTron', 'messageChannel', []);
};

function onMessageFromNative(msg) {
  var cordova = require('cordova');
  var action = msg.action;

  switch (action) {
    // PDFTron events
    case 'topLeftButtonPressed':
    case 'documentLoaded':
      cordova.fireDocumentEvent(action);
      break;
    default:
      throw new Error('Unknown event action ' + action);
  }
};

PDFTron.prototype.NativeViewer = NativeViewer;

NativeViewer.prototype.disableElements = function (arguments, success, error) {
  exec(success, error, 'PDFTron', 'disableElements', arguments);
};

NativeViewer.prototype.enableTools = function (arguments, success, error) {
  exec(success, error, 'PDFTron', 'enableTools', arguments);
};

NativeViewer.prototype.disableTools = function (arguments, success, error) {
  exec(success, error, 'PDFTron', 'disableTools', arguments);
};

NativeViewer.prototype.setToolMode = function (arguments, success, error) {
  exec(success, error, 'PDFTron', 'setToolMode', [arguments]);
};

NativeViewer.prototype.loadDocument = function (arguments, success, error) {
  exec(success, error, 'PDFTron', 'loadDocument', [arguments]);
};

NativeViewer.prototype.showDocumentViewer = function (success, error) {
  exec(success, error, 'PDFTron', 'showDocumentViewer', []);
};

module.exports = new PDFTron();
