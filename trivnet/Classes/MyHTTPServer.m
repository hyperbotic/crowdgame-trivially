#import "MyHTTPServer.h"
#import "MyWebSocket.h"
#import "HTTPLogging.h"
#import "ComCrowdgameTrivnetModule.h"

static const int httpLogLevel = HTTP_LOG_LEVEL_INFO; // | HTTP_LOG_FLAG_TRACE;

@implementation MyHTTPServer

@synthesize module;

- (MyWebSocket *)findWebSocket:(int)socketID
{
  MyWebSocket* sock = nil;

  [webSocketsLock lock];
  for (MyWebSocket *webSocket in webSockets)
  {
    if(webSocket.socketID == socketID) {
      sock = webSocket;
    }
  }
  [webSocketsLock unlock];

  return sock;
}

- (void)netServiceDidPublish:(NSNetService *)ns
{
	HTTPLogInfo(@"Bonjour Service Published (SUBCLASS): domain(%@) type(%@) name(%@)", [ns domain], [ns type], [ns name]);
        [module statusChange:@"bonjourPublishSuccess" domain:[ns domain] type:[ns type] name:[ns name]];
}

- (void)netService:(NSNetService *)ns didNotPublish:(NSDictionary *)errorDict
{
	HTTPLogWarn(@"Failed to Publish Bonjour Service (SUBCLASS): domain(%@) type(%@) name(%@) - %@",
	                                         [ns domain], [ns type], [ns name], errorDict);
        [module statusChange:@"bonjourPublishFailure" domain:[ns domain] type:[ns type] name:[ns name]];
}

@end
