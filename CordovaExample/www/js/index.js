/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */
var app = {
  // Application Constructor
  initialize: function () {
    document.addEventListener('deviceready', this.onDeviceReady.bind(this), false);
  },

  // deviceready Event Handler
  //
  // Bind any cordova events here. Common events are:
  // 'pause', 'resume', etc.
  onDeviceReady: function () {
    this.receivedEvent('deviceready');
  },

  onTopLeftButtonPressed: function () {
    console.log('onTopLeftButtonPressed');
  },

  onShowDocument: function () {
    this.viewer.loadDocument('https://pdftron.s3.amazonaws.com/downloads/pdfref.pdf');
  },

  // Update DOM on a Received Event
  receivedEvent: function (id) {
    var parentElement = document.getElementById(id);
    var listeningElement = parentElement.querySelector('.listening');
    var receivedElement = parentElement.querySelector('.received');

    listeningElement.setAttribute('style', 'display:none;');
    receivedElement.setAttribute('style', 'display:block;');

    console.log('PDFTron', PDFTron);

    var openButton = document.getElementById("showDocument");
    if (openButton) {
      openButton.addEventListener("click", this.onShowDocument.bind(this), false);
    }

    console.log('Received Event: ' + id);

    var viewerElement = document.getElementById('viewer');

    if (viewerElement) {
      var rect = viewerElement.getBoundingClientRect();
      this.viewer = new PDFTron.NativeViewer({
        l: '<your-key-here>',
        initialDoc: 'https://pdftron.s3.amazonaws.com/downloads/pl/PDFTRON_mobile_about.pdf',
        boundingRect: { left: rect.left, top: rect.top, width: rect.width, height: rect.height },
        topLeftButtonTitle: 'Menu',
        showTopLeftButton: true,
        disabledElements: [
          'searchButton',
          'lineToolButton'
        ]
      }, viewerElement);

      // this.viewer.disableElements(['toolsButton']);
      // this.viewer.disableTools(['AnnotationCreateSticky', 'AnnotationCreateFreeHand']);
      // this.viewer.enableTools(['AnnotationCreateSticky', 'AnnotationCreateFreeHand']);
      // this.viewer.setToolMode('AnnotationCreateFreeHand');
      // this.viewer.loadDocument('https://pdftron.s3.amazonaws.com/downloads/pdfref.pdf');

      // present full screen if no `viewerElement` parameter passed to NativeViewer
      // this.viewer.showDocumentViewer();
      
      // top left button click event
      document.addEventListener("topLeftButtonPressed", this.onTopLeftButtonPressed.bind(this), false);
    }
  }
};

app.initialize();
