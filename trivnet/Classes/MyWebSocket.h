#import <Foundation/Foundation.h>
#import "WebSocket.h"

@class ComCrowdgameTrivnetModule;

@interface MyWebSocket : WebSocket
{
  int socketID;
}

@property(assign) int socketID;

@end
