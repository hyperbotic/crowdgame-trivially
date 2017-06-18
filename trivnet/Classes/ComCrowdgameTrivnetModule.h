/**
 * Appcelerator Titanium is Copyright (c) 2009-2010 by Appcelerator, Inc.
 * and licensed under the Apache Public License (version 2)
 */
#import "TiModule.h"

#import "MyWebSocket.h"

@class MyHTTPServer;

//
// https://wiki.appcelerator.org/display/guides/iOS+Module+Development+Guide#iOSModuleDevelopmentGuide-ReturningObjectValues
// 
@interface ComCrowdgameTrivnetModule : TiModule<WebSocketDelegate>
{
  int pattern;
  MyHTTPServer *httpServer; 
}

- (void)statusChange:(NSString*)status domain:(NSString*)domain type:(NSString*)type name:(NSString*)name;

@property int pattern;

@end
