//
//  VideoBuilder.h
//  ImageToVideo
//
//  Created by Xu Menghua on 16/5/11.
//  Copyright © 2016年 Xu Menghua. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <UIKit/UIKit.h>

typedef void(^successBlock)(void);
typedef void(^failBlock)(NSError *error);
typedef void(^exportAsynchronouslyWithCompletionHandler)(void);
typedef void(^convertToMp4Completed)(void);

@interface VideoBuilder : NSObject

- (VideoBuilder *)initWithOutputSize:(CGSize)size Timescale:(int32_t)scale OutputPath:(NSString *)path;
- (BOOL)addVideoFrameWithImage:(UIImage *)image;
- (void)maskFinishWithSuccess:(successBlock)success Fail:(failBlock)fail;
- (void)convertVideoWithImageArray:(NSArray *)images Success:(successBlock)success Fail:(failBlock)fail;
- (void)addAudioToVideoAudioPath:(NSString *)audioPath Completion:(exportAsynchronouslyWithCompletionHandler)completion;
- (void)convertToMP4Completed:(convertToMp4Completed)Completed;

@end
