#import "MyWebSocket.h"
#import "HTTPLogging.h"
#import "HTTPServer.h"

#import "ComCrowdgameTrivnetModule.h"

// Log levels: off, error, warn, info, verbose
// Other flags : trace
static const int httpLogLevel = HTTP_LOG_LEVEL_WARN | HTTP_LOG_FLAG_TRACE;

static int socketCounter = 0;

@implementation MyWebSocket

@synthesize socketID;

- (void)didOpen
{
  socketCounter++;
  socketID = socketCounter;

  HTTPLogTrace();
	
  [super didOpen];
}

@end
