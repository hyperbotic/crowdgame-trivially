# crowdgame-trivially
CrowdGame Trivially - iOS App

CrowdGame Trivially is a new take on the quiz game genre. Trivially can be enjoyed by up to 11 players, who use the web browsers on their own mobile devices or PCs to respond instantly to questions displayed on an iPad running the CrowdGame Trivially app.

Trivially is a real-time, multi-player, multi-display game, turning your iPad into a mini-game console for you and your crowd, showing who’s playing, quiz questions, countdown clock, and real-time results for all to see.

You can learn more here: http://crowdgame.com/trivially-details/

We're sharing it here in the hopes that someone will find it helpful or interesting to browse the source code. 

However, your use of this code does not in any way impart any rights or privileges regarding the CrowdGame, Trivially, or Hyperbotic Labs brands or copyrights.

This repository doesn't contain all of the assets needed to recreate the app. For instance, none of the graphical assets are included, nor are the various config files required by Appcelerator (http://www.appcelerator.com/), the environment used to build the app.

The majority of the app is written in CoffeeScript (http://coffeescript.org/). However, the app also contains an embedded HTTP server (in Objective-C, a modified version of Cocoa HTTP Server), packaged as an Appcelerator module, which serves up a simple web experience to up to 11 devices on the same network. As trivia questions are shown on the iPad's screen, users can answer on their devices. The app tallies scores as players ring in their answers. The users' web page apps communicate with the HTTP server via Web Sockets.

As offered in the App Store, the app included a small number of free trivia content packs. Users could also buy (and download) additional content packs.

Also, users could create their own trivia contests: the questions and answers would be entered into a Google Spreadsheet, which the app would then download for play.

The app was last successfully built and deployed as version 2.6 to the iOS App Store in March, 2015. Since then, there have been a number of changes to both the Appcelerator environment and iOS; as a result, the source code as it currently stands undoubtedly would need some modifications to bring it up to date and in compliance with the latest App Store requirements.

A note about the code: undoubtedly the code (style, algorithms, approach to abstraction, and so on) could be viewed as lacking in many, many ways. The app was built as a learning experience, and while we had a lot of fun in the process, there are lots of things we'd differently a second time around. 

Please also see the repository for a related app, CrowdGame Trivially Pro.

Enjoy!
