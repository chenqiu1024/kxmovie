//
//  SocketHelper.h
//  Madv360_v1
//
//  Created by FutureBoy on 11/23/15.
//  Copyright © 2015 Cyllenge. All rights reserved.
//

#ifndef SocketHelper_h
#define SocketHelper_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "MVDeviceRequest.h"

#ifdef __cplusplus
extern "C" {
#endif

extern int g_commandServerSocket;
extern int g_fileServerSocket;
extern int g_liveServerSocket;

typedef id (^CallbackBlock) (id responseObject, NSError* error, NSString* errMsg);

dispatch_queue_t sharedSocketQueue();

void dispatchBlockOnQueueAsync(dispatch_queue_t srcQueue, dispatch_queue_t dstQueue, void(^block)(void));

void connectServer(const char* addressIP, int addressPort, CallbackBlock callback);

void connectFileServer(const char* addressIP, int addressPort, CallbackBlock callback);
void connectCommandServer(const char* addressIP, int addressPort, CallbackBlock callback);

void sendMessageAsync(dispatch_queue_t msgQueue, int sockfd, NSString* message, dispatch_queue_t callbackQueue, CallbackBlock callback);

void sendJSONMessage(int sockfd, int sessionID, MVDeviceRequest* request, CallbackBlock callback);

void sendJSONMessageAsync(dispatch_queue_t msgQueue, int sockfd, int sessionID, MVDeviceRequest* request, dispatch_queue_t callbackQueue, CallbackBlock callback);

void saveFileChunk(const char* filepath, int fileOffset, const char* data, int dataOffset, int size);

void downloadFile(NSString* localFilePath, NSString* remoteFilePath, int fileSize, int chunkSize, int fileSocket, int commandSocket, int sessionID, dispatch_queue_t callbackQueue, CallbackBlock callback);

UIAlertController* alertWithResponse(UIViewController* parentViewController, id responseObject, NSError* error, NSString* errMsg);

#ifdef __cplusplus
}
#endif

#endif /* SocketHelper_h */
