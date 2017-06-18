#import <Foundation/Foundation.h>
#import "HTTPServer.h"

@class MyWebSocket;
@class ComCrowdgameTrivnetModule;

@interface MyHTTPServer: HTTPServer
{
  ComCrowdgameTrivnetModule *module;
}

@property(assign) ComCrowdgameTrivnetModule *module;

- (MyWebSocket *)findWebSocket:(int)socketID;

@end
