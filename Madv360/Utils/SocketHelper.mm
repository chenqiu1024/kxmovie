//
//  SocketHelper.m
//  Madv360_v1
//
//  Created by FutureBoy on 11/23/15.
//  Copyright © 2015 Cyllenge. All rights reserved.
//

#import "SocketHelper.h"
#import "MVDeviceResponse.h"
#import "NSString+Extensions.h"
#include <fstream>
#include <netdb.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <pthread.h>
#include <arpa/inet.h>

using namespace std;

int g_commandServerSocket = -1;
int g_fileServerSocket = -1;
int g_liveServerSocket = -1;

void connectServer(const char* addressIP, int addressPort, CallbackBlock callback) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int sockfd;
        struct sockaddr_in server_addr;
        //    struct hostent* host;
        
        sockfd = socket(AF_INET, SOCK_STREAM, 0);
        if (sockfd == -1)
        {
            fprintf(stderr,"Socket error:%s\n",strerror(errno));
            if (callback)
            {
                dispatch_async(dispatch_get_main_queue(), ^() {
                    NSError* error = [NSError errorWithDomain:@"com.madv360.exception.socketerror" code:-1 userInfo:nil];
                    callback(nil, error, [NSString stringWithUTF8String:strerror(errno)]);
                });
            }
        }
        
        bzero(&server_addr, sizeof(server_addr));
        server_addr.sin_family = AF_INET;
        server_addr.sin_port = htons(addressPort);
        server_addr.sin_addr.s_addr = inet_addr(addressIP);
        
        int con_flag;//, res2;
        //    pthread_t thread_write;
        
        int on = 1;
        setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on)); //其实这个就是阻止服务端一关掉，再启动，运行不了的情况发生
        
        con_flag = connect(sockfd, (struct sockaddr *)(&server_addr), sizeof(struct sockaddr));   //连接服务端
        if (con_flag == -1)
        {
            fprintf(stderr,"Connect Error:%s\a\n",strerror(errno));
            if (callback)
            {
                dispatch_async(dispatch_get_main_queue(), ^() {
                    NSError* error = [NSError errorWithDomain:@"com.madv360.exception.socketerror" code:-1 userInfo:nil];
                    callback(nil, error, [NSString stringWithUTF8String:strerror(errno)]);
                });
            }
        }
        else
        {
            if (callback)
            {
                dispatch_async(dispatch_get_main_queue(), ^() {
                    callback(@(sockfd), nil, nil);
                });
            }
        }
    });
}

void connectServerSocket(int* pSockFD, const char* addressIP, int addressPort, CallbackBlock callback) {
    connectServer(addressIP, addressPort, ^id(id responseObject, NSError *error, NSString *errMsg) {
        if (!error)
        {
            *pSockFD = [responseObject intValue];
        }
        
        if (callback)
        {
            callback(responseObject, error, errMsg);
        }
        return nil;
    });
}

void connectCommandServer(const char* addressIP, int addressPort, CallbackBlock callback) {
    connectServerSocket(&g_commandServerSocket, addressIP, addressPort, callback);
}

void connectFileServer(const char* addressIP, int addressPort, CallbackBlock callback) {
    connectServerSocket(&g_fileServerSocket, addressIP, addressPort, callback);
}

void dispatchBlockOnQueueAsync(dispatch_queue_t srcQueue, dispatch_queue_t dstQueue, void(^block)(void)) {
    if (!block) return;
    
    //    static const char* QueueKey = "QueueKey";
    //    static const char* QueueValue = "Value";
    //    static dispatch_once_t once;
    //    dispatch_once(&once, ^{
    //        dispatch_queue_set_specific(dispatch_get_main_queue(), QueueKey, (void*)QueueValue, nil);
    //    });
    
    if (srcQueue == dstQueue)
    {
        block();
    }
    else
    {
        dispatch_async(dstQueue, block);
    }
}

void sendMessageAsync(dispatch_queue_t msgQueue, int sockfd, NSString* message, dispatch_queue_t callbackQueue, CallbackBlock callback) {
    dispatch_async(msgQueue, ^{
        const char* msg = [message UTF8String];
        long writeSize = strlen(msg) + 1;
        NSLog(@"Request string : (%ld) \"%s\"", writeSize,msg);
        long status;
        if ((status = write(sockfd, msg, writeSize)) < 0)
        {
            if (callback)
            {
                dispatchBlockOnQueueAsync(msgQueue, callbackQueue,^{
                    NSError* error = [NSError errorWithDomain:@"com.madv360.exception.socketerror" code:-1 userInfo:nil];
                    callback(nil, error, [NSString stringWithFormat:@"Socket writing failed : %s", strerror(errno)]);
                });
            }
            return;
        }
        else if (status > 0 && status < writeSize)
        {
            if (callback)
            {
                dispatchBlockOnQueueAsync(msgQueue, callbackQueue,^{
                    NSError* error = [NSError errorWithDomain:@"com.madv360.exception.socketerror" code:-1 userInfo:nil];
                    callback(nil, error, [NSString stringWithFormat:@"Socket writing incomplete : %s", strerror(errno)]);
                });
            }
            return;
        }
        NSLog(@"Socket write status : %ld", status);
        
        char readBuf[8192];
        long readSize;
        if ((readSize = read(sockfd, readBuf, 8192)) >= 1)
        {
            readBuf[readSize] = '\0';
            NSLog(@"Response string : (%ld) \"%s\"", readSize, readBuf);
            NSError* error = nil;
            NSData* responseData = [NSData dataWithBytes:readBuf length:readSize];
            NSString* responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
            
            if (callback)
            {
                dispatchBlockOnQueueAsync(msgQueue, callbackQueue,^{
                    callback(responseString, error, responseString);
                });
            }
        }
        else if (readSize == -1)
        {
            /* Error, check errno, take action... */
            if (callback)
            {
                dispatchBlockOnQueueAsync(msgQueue, callbackQueue,^{
                    NSError* error = [NSError errorWithDomain:@"com.madv360.exception.socketerror" code:-2 userInfo:nil];
                    callback(nil, error, [NSString stringWithFormat:@"Socket reading error : %s", strerror(errno)]);
                });
            }
        }
        else if (readSize == 0)
        {
            /* Peer closed the socket, finish the close */
            close(sockfd);
            /* Further processing... */
            if (callback)
            {
                dispatchBlockOnQueueAsync(msgQueue, callbackQueue,^{
                    NSError* error = [NSError errorWithDomain:@"com.madv360.exception.socketerror" code:-2 userInfo:nil];
                    callback(nil, error, [NSString stringWithFormat:@"Socket reading meet closed peer : %s", strerror(errno)]);
                });
            }
        }
    });
}

void sendJSONMessageAsync(dispatch_queue_t msgQueue, int sockfd, int sessionID, MVDeviceRequest* request, dispatch_queue_t callbackQueue, CallbackBlock callback) {
    NSMutableDictionary* jsonDict = [request mj_keyValues];
    [jsonDict addEntriesFromDictionary:@{@"token":@(sessionID)}];
    NSString* jsonStr = [NSString stringWithJSONDictionary:jsonDict];
    
    dispatch_async(msgQueue, ^{
        const char* msg = [jsonStr UTF8String];
        long writeSize = strlen(msg) + 1;
        NSLog(@"Request string : (%ld) \"%s\"", writeSize,msg);
        long status;
        if ((status = write(sockfd, msg, writeSize)) < 0)
        {
            if (callback)
            {
                dispatchBlockOnQueueAsync(msgQueue, callbackQueue,^{
                    NSError* error = [NSError errorWithDomain:@"com.madv360.exception.socketerror" code:-1 userInfo:nil];
                    callback(nil, error, [NSString stringWithFormat:@"Socket writing failed : %s", strerror(errno)]);
                });
            }
        }
        else if (status > 0 && status < writeSize)
        {
            if (callback)
            {
                dispatchBlockOnQueueAsync(msgQueue, callbackQueue,^{
                    NSError* error = [NSError errorWithDomain:@"com.madv360.exception.socketerror" code:-1 userInfo:nil];
                    callback(nil, error, [NSString stringWithFormat:@"Socket writing incomplete : %s", strerror(errno)]);
                });
            }
        }
        NSLog(@"Socket write status : %ld", status);
        
        NSDictionary* responseDict = nil;
        char readBuf[1024];
        long readSize;
        if ((readSize = read(sockfd, readBuf, 1024)) >= 1)
        {
            readBuf[readSize] = '\0';
            NSLog(@"Response string : (%ld) \"%s\"", readSize, readBuf);
            NSError* error = nil;
            NSData* responseData = [NSData dataWithBytes:readBuf length:readSize];
            NSString* responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
            responseDict = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableLeaves error:&error];
            MVDeviceResponse* responseObject = [MVDeviceResponse mj_objectWithKeyValues:responseDict];
            
            if (callback)
            {
                dispatchBlockOnQueueAsync(msgQueue, callbackQueue,^{
                    callback(responseObject, error, responseString);
                });
            }
        }
        else if (readSize == -1)
        {
            /* Error, check errno, take action... */
            if (callback)
            {
                dispatchBlockOnQueueAsync(msgQueue, callbackQueue,^{
                    NSError* error = [NSError errorWithDomain:@"com.madv360.exception.socketerror" code:-2 userInfo:nil];
                    callback(nil, error, [NSString stringWithFormat:@"Socket reading error : %s", strerror(errno)]);
                });
            }
        }
        else if (readSize == 0)
        {
            /* Peer closed the socket, finish the close */
            close(sockfd);
            /* Further processing... */
            if (callback)
            {
                dispatchBlockOnQueueAsync(msgQueue, callbackQueue,^{
                    NSError* error = [NSError errorWithDomain:@"com.madv360.exception.socketerror" code:-2 userInfo:nil];
                    callback(nil, error, [NSString stringWithFormat:@"Socket reading meet closed peer : %s", strerror(errno)]);
                });
            }
        }
    });
}

dispatch_queue_t sharedSocketQueue() {
    static dispatch_once_t once;
    static dispatch_queue_t msgQueue;
    dispatch_once(&once, ^{
        msgQueue = dispatch_queue_create("com.madv360.commandsqueue", DISPATCH_QUEUE_SERIAL);//dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0);
    });
    return msgQueue;
}

void sendJSONMessage(int sockfd, int sessionID, MVDeviceRequest* request, CallbackBlock callback) {
    sendJSONMessageAsync(sharedSocketQueue(), sockfd, sessionID, request, dispatch_get_main_queue(), callback);
}

void saveFileChunk(const char* filepath, int fileOffset, const char* data, int dataOffset, int size) {
    ofstream ofs(filepath, ios::out | ios::in | ios::binary);
    ofs.seekp(fileOffset, ios::beg);
    ofs.write(data + dataOffset, size);
    ofs.flush();
    ofs.close();
}

bool downloadFileChunk(NSString* localFilePath, int fileOffset, int socket, int dataOffset, int size, dispatch_queue_t callbackQueue,  CallbackBlock callback) {
    char* buffer = new char[size];
    long readSize;
    if ((readSize = read(socket, buffer, size)) > 0)
    {
        saveFileChunk(localFilePath.UTF8String, fileOffset, (const char*) buffer, dataOffset, size);
        
        delete[] buffer;
        return true;
    }
    else if (0 == readSize)
    {
        if (callback)
        {
            dispatchBlockOnQueueAsync(dispatch_get_current_queue(), callbackQueue, ^{
                callback(nil, nil, [NSString stringWithFormat:@"downloadFileChunk $ Failed#1 during : read %d bytes and write start from %d of file %@", size, fileOffset, localFilePath]);
            });
        }
    }
    else if (-1 == readSize)
    {
        close(socket);
        if (callback)
        {
            dispatchBlockOnQueueAsync(dispatch_get_current_queue(), callbackQueue, ^{
                callback(nil, nil, [NSString stringWithFormat:@"downloadFileChunk $ Failed#2 during : read %d bytes and write start from %d of file %@; Socket is closed", size, fileOffset, localFilePath]);
            });
        }
    }
    delete[] buffer;
    return false;
}

void downloadFile(NSString* localFilePath, NSString* remoteFilePath, int fileSize, int chunkSize, int fileSocket, int commandSocket, int sessionID, dispatch_queue_t callbackQueue, CallbackBlock callback) {
    static dispatch_once_t once;
    static dispatch_queue_t downloadQueue;
    dispatch_once(&once, ^{
        downloadQueue = dispatch_queue_create("com.madv360.downloadqueue", DISPATCH_QUEUE_SERIAL);
    });
    
//    char* chunkBuffer = new char[chunkSize];
    int chunks = fileSize / chunkSize;
    int residualSize = fileSize % chunkSize;
    int fileOffset = 0;
//    __block int tasks = (residualSize > 0 ? chunks + 1 : chunks);
    
    FILE* fp = fopen(localFilePath.UTF8String, "w+");
    fclose(fp);
    ///!!!
    for (int i=0; i<chunks; ++i)
    {
        NSString* message = [NSString stringWithFormat:@"{\"token\":%d,\"msg_id\":1285,\"param\":\"%@\",\"offset\":%d,\"fetch_size\":%d}", sessionID, remoteFilePath, fileOffset, chunkSize];
        dispatch_async(downloadQueue, ^{
            downloadFileChunk(localFilePath, fileOffset, fileSocket, 0, chunkSize, callbackQueue, callback);
        });
        sendMessageAsync(sharedSocketQueue(), g_commandServerSocket, message, downloadQueue, ^id(id responseObject, NSError *error, NSString *errMsg) {
            if (!error)
            {
                ///
            }
            else
            {
                dispatchBlockOnQueueAsync(downloadQueue, callbackQueue, ^{
                    callback(responseObject, error, errMsg);
                });
            }
            
//            if (0 >= --tasks)
//            {
//                delete[] chunkBuffer;
//            }
            return nil;
        });
        fileOffset += chunkSize;
    }
    if (residualSize > 0)
    {
        NSString* message = [NSString stringWithFormat:@"{\"token\":%d,\"msg_id\":1285,\"param\":\"%@\",\"offset\":%d,\"fetch_size\":%d}", sessionID, remoteFilePath, fileOffset, residualSize];
        dispatch_async(downloadQueue, ^{
            downloadFileChunk(localFilePath, fileOffset, fileSocket, 0, residualSize, callbackQueue, callback);
        });
        sendMessageAsync(sharedSocketQueue(), g_commandServerSocket, message, downloadQueue, ^id(id responseObject, NSError *error, NSString *errMsg) {
            if (!error)
            {
                ///
            }
            else
            {
                dispatchBlockOnQueueAsync(downloadQueue, callbackQueue, ^{
                    callback(responseObject, error, errMsg);
                });
            }
            
//            if (0 >= --tasks)
//            {
//                delete[] chunkBuffer;
//            }
            return nil;
        });
    }
}

UIAlertController* alertWithResponse(UIViewController* parentViewController, id responseObject, NSError* error, NSString* errMsg) {
    NSString* str = [NSString stringWithFormat:@"Response:%@\nError:%@\nErrMsg:%@", responseObject, error, errMsg];
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:nil message:str preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:action];
    [parentViewController presentViewController:alert animated:NO completion:nil];
    return alert;
}
