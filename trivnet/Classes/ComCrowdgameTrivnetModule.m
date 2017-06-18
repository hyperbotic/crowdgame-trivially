/**
 * Appcelerator Titanium is Copyright (c) 2009-2010 by Appcelerator, Inc.
 * and licensed under the Apache Public License (version 2)
 */
#import <Foundation/Foundation.h>  //+++++

#import "ComCrowdgameTrivnetModule.h"
#import "TiBase.h"
#import "TiHost.h"
#import "TiUtils.h"

#import "MyHTTPServer.h" //++++++++++
#import "MyHTTPConnection.h" //++++++++++
#import "MyWebSocket.h" //++++++++++
#import "DDLog.h" //++++++++++
#import "DDTTYLogger.h" //++++++++++
#import "DDASLLogger.h" //++++++++++
#import "DDFileLogger.h" //++++++++++

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_VERBOSE; //++++++++++

@implementation ComCrowdgameTrivnetModule

@synthesize pattern; //++++++++++

#pragma mark Internal

// this is generated for your module, please do not change it
-(id)moduleGUID
{
	return @"e2d5a578-4684-4991-b697-cd799ac1d093";
}

// this is generated for your module, please do not change it
-(NSString*)moduleId
{
	return @"com.crowdgame.trivnet";
}

#pragma mark Lifecycle

-(void)startup
{
	// this method is called when the module is first loaded
	// you *must* call the superclass
	[super startup];
	
	NSLog(@"[INFO] %@ loaded",self);

        pattern = 123456; //++++++++++
	NSLog(@"[INFO] %@ set pattern",self); //++++++++++
}

-(void)shutdown:(id)sender
{
	// this method is called when the module is being unloaded
	// typically this is during shutdown. make sure you don't do too
	// much processing here or the app will be quit forceably
	
	// you *must* call the superclass
	[super shutdown:sender];
}

#pragma mark Cleanup 

-(void)dealloc
{
	// release any resources that have been retained by the module
	[super dealloc];
}

#pragma mark Internal Memory Management

-(void)didReceiveMemoryWarning:(NSNotification*)notification
{
	// optionally release any resources that can be dynamically
	// reloaded once memory is available - such as caches
	[super didReceiveMemoryWarning:notification];
}

#pragma mark Listener Notifications

-(void)_listenerAdded:(NSString *)type count:(int)count
{
  DDLogInfo(@"TRIVNET::_listenerAdded %d %@", count, type); //++++++++++
}

-(void)_listenerRemoved:(NSString *)type count:(int)count
{
  DDLogInfo(@"TRIVNET::_listenerRemoved %d %@", count, type); //++++++++++
}

#pragma Public APIs

-(id)example:(id)args
{
	// example method
	return @"hello world";
}

-(id)exampleProp
{
	// example property getter
	return @"hello world";
}

-(void)setExampleProp:(id)value
{
	// example property setter
}

//++++++++++++++++++++
// Methods that can be called by consuming apps
//
// startServer
// stop
// restart
// sendMessage
// republishBonjour
//
// Events that are fired by this module:
//
// httpServerReady
// httpServerSocketOpened
// httpServerSocketClosed
// httpServerMessageReceived
//

- (void)startServer:(id)args
{
	// Configure our logging framework.
	// To keep things simple and fast, we're just going to log to the Xcode console.
	[DDLog addLogger:[DDTTYLogger sharedInstance]];
	[DDLog addLogger:[DDASLLogger sharedInstance]];

	[DDLog addLogger: [[DDFileLogger alloc] init]];

	// Create server using our custom MyHTTPServer class
	httpServer = [[MyHTTPServer alloc] init];
	httpServer.module = self;
	DDLogInfo(@"Setting module=%p", self);


	// Tell server to use our custom MyHTTPConnection class.
	[httpServer setConnectionClass:[MyHTTPConnection class]];

	// Tell the server to broadcast its presence via Bonjour.
	// This allows browsers such as Safari to automatically discover our service.
	[httpServer setType:@"_http._tcp."];

	// Normally there's no need to run our server on any specific port.
	// Technologies like Bonjour allow clients to dynamically discover the server's port at runtime.
	// However, for easy testing you may want force a certain port so you can just hit the refresh button.
	[httpServer setPort:20116];

	// Serve files from our embedded Web folder
	NSString *webPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Web"];
	DDLogInfo(@"Setting document root: %@", webPath);
	
	[httpServer setDocumentRoot:webPath];

	// Start the server (and check for problems)
	
	NSError *error;
	if([httpServer start:&error])
        {
        	[self serverReady];
        }
        else
	{
		DDLogError(@"Error starting HTTP Server: %@", error);
	}

        return; // @"OK1"; //TEST
}

- (void)stop:(id)args
{
  DDLogInfo(@"TRIVNET::stop");
  //  [httpServer stop:NO]; //crashes
  [httpServer dealloc];
  httpServer = nil;
}

- (void)restart:(id)args
{
  DDLogInfo(@"TRIVNET::restart");
  //  [httpServer republishBonjour]; //Crashes
  //  [httpServer dealloc];
  [DDLog removeAllLoggers];

  [httpServer release];
  [self startServer:nil];

  return;
}

- (void)republishBonjour:(id)args
{
  DDLogInfo(@"TRIVNET::republishBonjour - ENTER");
  [httpServer republishBonjour]; // Crashes
  DDLogInfo(@"TRIVNET::republishBonjour - EXIT");

  return;
}

- (void)sendMessage:(id)args
{
  int socketID= [TiUtils intValue:[args objectAtIndex:0]];
  NSString* m = [TiUtils stringValue:[args objectAtIndex:1]];

  DDLogInfo(@"TRIVNET::sendMessage: socket=%d %@ (ENTER)", socketID, m);		

  MyWebSocket* sock = [httpServer findWebSocket:socketID];

  if (sock == nil) {
    DDLogInfo(@"TRIVNET::sendMessage: %d %@ (COULD NOT FIND SOCKET)", socketID, m);
  }
  else {
    DDLogInfo(@"TRIVNET::sendMessage: %d %@ (SENDING)", socketID, m);		
    [sock sendMessage:m];
  }

  return;
}

- (id)getPublishedHostname:(id)args
{

  NSString* hostname = [httpServer publishedName];

  DDLogInfo(@"TRIVNET::getPublishedHostname %@", hostname);		

  return hostname; // Should we return a copy instead??
}


// Other methods
//
- (void)serverReady
{
  DDLogInfo(@"TRIVNET::serverReady");

  if ([self _hasListeners:@"httpServerReady"])
    {
      NSString* hostname = [httpServer publishedName];
      NSString* port = [NSString stringWithFormat:@"%d", [httpServer listeningPort]];
      DDLogInfo(@"TRIVNET::serverReady %@:%@(FIRING)", hostname, port);

      NSMutableDictionary *event = [NSMutableDictionary dictionaryWithObject:hostname forKey:@"hostname"];
      [event setObject:port forKey:@"port"];
      [self fireEvent:@"httpServerReady" withObject:event];
    }

  return;
}

- (void)webSocketDidOpen:(MyWebSocket*)sock
{
  DDLogInfo(@"TRIVNET::webSocketDidOpen %d", sock.socketID);

  if ([self _hasListeners:@"httpServerSocketOpened"])
    {
      DDLogInfo(@"TRIVNET::didOpen %d (FIRING)", sock.socketID);
      NSMutableDictionary *event = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInt:sock.socketID] forKey:@"socketID"];
      [self fireEvent:@"httpServerSocketOpened" withObject:event];
    }

  return;
}

- (void)webSocketDidClose:(MyWebSocket*)sock
{
  DDLogInfo(@"TRIVNET::webSocketDidClose %d", sock.socketID);

  if ([self _hasListeners:@"httpServerSocketClosed"])
    {
      DDLogInfo(@"TRIVNET::webSocketDidClose %d (FIRING)", sock.socketID);
      NSMutableDictionary *event = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInt:sock.socketID] forKey:@"socketID"];
      [self fireEvent:@"httpServerSocketClosed" withObject:event];
    }

  return;
}

- (void)didReceiveMessage:(NSString*)msg webSocket:(MyWebSocket*)sock
{
  DDLogInfo(@"TRIVNET::didReceiveMessage %d %@", sock.socketID, msg);

  if ([self _hasListeners:@"httpServerMessageReceived"])
    {
      DDLogInfo(@"TRIVNET::didReceiveMessage %d %@ (FIRING)", sock.socketID, msg);
      NSMutableDictionary *event = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInt:sock.socketID] forKey:@"socketID"];
      [event setObject:msg forKey:@"message"];
      [self fireEvent:@"httpServerMessageReceived" withObject:event];
    }

  return;
}


- (void)statusChange:(NSString*)status domain:(NSString*)domain type:(NSString*)type name:(NSString*)name 
{
  DDLogInfo(@"TRIVNET::statusChange %@: %@ %@ %@", status, domain, type, name);

  if ([self _hasListeners:@"httpServerServiceStatusChange"])
    {
      NSMutableDictionary *event = [NSMutableDictionary dictionaryWithObject:status forKey:@"status"];
      [event setObject:domain forKey:@"domain"];
      [event setObject:type forKey:@"type_"];
      [event setObject:name forKey:@"name"];
      [self fireEvent:@"httpServerServiceStatusChange" withObject:event];
    }

  return;
}



@end
