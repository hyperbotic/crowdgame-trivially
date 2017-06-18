#import "MyHTTPConnection.h"
#import "MyHTTPServer.h"
#import "HTTPMessage.h"
#import "HTTPResponse.h"
#import "HTTPDynamicFileResponse.h"
#import "GCDAsyncSocket.h"
#import "MyWebSocket.h"
#import "HTTPLogging.h"

#import "ComCrowdgameTrivnetModule.h"

// Log levels: off, error, warn, info, verbose
// Other flags: trace
static const int httpLogLevel = HTTP_LOG_LEVEL_VERBOSE | HTTP_LOG_FLAG_TRACE;


@implementation MyHTTPConnection

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
	HTTPLogTrace();

	HTTPLogVerbose(@"MyHTTPConnection: path=%@", path);

	if ([path isEqualToString:@"/"] ||
            [path isEqualToString:@"/main.js-txt"]) //cellini // Trivially 2.5 change
	{
		// The socket.js file contains a URL template that needs to be completed:
		// 
		// ws = new WebSocket("%%WEBSOCKET_URL%%");
		// 
		// We need to replace "%%WEBSOCKET_URL%%" with whatever URL the server is running on.
		// We can accomplish this easily with the HTTPDynamicFileResponse class,
		// which takes a dictionary of replacement key-value pairs,
		// and performs replacements on the fly as it uploads the file.
		
		NSString *wsLocation;
		
		NSString *wsHost = [request headerField:@"Host"];
		if (wsHost == nil)
		{
			NSString *port = [NSString stringWithFormat:@"%hu", [asyncSocket localPort]];
			wsLocation = [NSString stringWithFormat:@"ws://localhost:%@%/service", port];
		}
		else
		{
			wsLocation = [NSString stringWithFormat:@"ws://%@/service", wsHost];
		}
		
		NSDictionary *replacementDict = [NSMutableDictionary dictionaryWithObject:wsLocation forKey:@"WEBSOCKET_URL"];
		
		return [[[HTTPDynamicFileResponse alloc] initWithFilePath:[self filePathForURI:path]
		                                            forConnection:self
		                                                separator:@"%%"
		                                    replacementDictionary:replacementDict] autorelease];
	}
	
	return [super httpResponseForMethod:method URI:path];
}

- (WebSocket *)webSocketForURI:(NSString *)path
{
	HTTPLogTrace2(@"%@[%p]: webSocketForURI: %@", THIS_FILE, self, path);
	
	if([path isEqualToString:@"/service"])
	{
		HTTPLogInfo(@"MyHTTPConnection: Creating MyWebSocket...");

		MyWebSocket* w = [[[MyWebSocket alloc] initWithRequest:request socket:asyncSocket] autorelease]; //cellini
                ComCrowdgameTrivnetModule *m = ((MyHTTPServer *)config.server).module;
 	        HTTPLogTrace2(@"%@[%p]: webSocketForURI: module=%p", THIS_FILE, self, m);
 	        HTTPLogTrace2(@"%@[%p]: webSocketForURI: pattern=%d", THIS_FILE, self, m.pattern);
		[w setDelegate: m]; //cellini
	        return w;
	}
	
	return [super webSocketForURI:path];
}

@end
