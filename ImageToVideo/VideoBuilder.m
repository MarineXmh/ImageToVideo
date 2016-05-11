//
//  VideoBuilder.m
//  ImageToVideo
//
//  Created by Xu Menghua on 16/5/11.
//  Copyright © 2016年 Xu Menghua. All rights reserved.
//

#import "VideoBuilder.h"

@interface VideoBuilder ()

@property (nonatomic, strong) AVAssetWriter *videoWriter;
@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *adaptor;
@property (nonatomic, strong) AVAssetWriterInput *writerInput;

@property (nonatomic, assign) NSInteger frameNumber;

@property (nonatomic, assign) CGSize    videoSize;
@property (nonatomic, strong) NSString *videoPath;
@property (nonatomic, assign) int32_t timeScale;

@end

@implementation VideoBuilder

- (VideoBuilder *)initWithOutputSize:(CGSize)size Timescale:(int32_t)scale OutputPath:(NSString *)path {
    self = [super init];
    
    if (self) {
        
        _videoSize = size;
        _videoPath = path;
        _timeScale = scale;
        
        NSError *error = nil;
        
        self.videoWriter = [[AVAssetWriter alloc]initWithURL:[NSURL fileURLWithPath:path]
                                                    fileType:AVFileTypeQuickTimeMovie
                                                       error:&error];
        
        NSParameterAssert(self.videoWriter);
        
        NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                       AVVideoCodecH264,AVVideoCodecKey,
                                       [NSNumber numberWithInt:_videoSize.width],AVVideoWidthKey,
                                       [NSNumber numberWithInt:_videoSize.height],AVVideoHeightKey,
                                       nil];
        
        self.writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                              outputSettings:videoSettings];
        
        self.adaptor = [AVAssetWriterInputPixelBufferAdaptor
                        assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self.writerInput
                        sourcePixelBufferAttributes:nil];
        
        NSParameterAssert(self.writerInput);
        NSParameterAssert([self.videoWriter canAddInput:self.writerInput]);
        
        [self.videoWriter addInput:self.writerInput];
        
        [self.videoWriter startWriting];
        
        [self.videoWriter startSessionAtSourceTime:kCMTimeZero];
    }
    
    return self;
}

- (BOOL)addVideoFrameWithImage:(UIImage *)image{
    
    CVPixelBufferRef buffer = NULL;
    
    if (self.writerInput.readyForMoreMediaData) {
        CMTime frameTime = CMTimeMake(1, self.timeScale);
        
        CMTime lastTime = CMTimeMake(self.frameNumber, self.timeScale);
        
        CMTime presentTime = CMTimeAdd(lastTime, frameTime);
        
        if (self.frameNumber == 0) {
            presentTime = CMTimeMake(0, self.timeScale);
        }
        
        buffer = [self pixelBufferFromCGImage:[image CGImage]];
        if (buffer) {
            
            if ([self.adaptor appendPixelBuffer:buffer withPresentationTime:presentTime]) {
                CVPixelBufferRelease(buffer);
                self.frameNumber++;
                return YES;
            }
            
        }
        
    }
    
    return NO;
    
}

- (void)maskFinishWithSuccess:(successBlock)success Fail:(failBlock)fail {
    
    [self.writerInput markAsFinished];
    
    [self.videoWriter finishWritingWithCompletionHandler:^{
        if (self.videoWriter.status != AVAssetReaderStatusFailed && self.videoWriter.status == AVAssetWriterStatusCompleted) {
            
            if (success) {
                success();
            }
            
        } else {
            if (fail) {
                fail(_videoWriter.error);
            }
            
            NSLog(@"create video failed, %@",self.videoWriter.error);
        }
    }];
    
    CVPixelBufferPoolRelease(self.adaptor.pixelBufferPool);
}

- (void)convertVideoWithImageArray:(NSArray *)images Success:(successBlock)success Fail:(failBlock)fail {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        int i;
        CVPixelBufferRef buffer = NULL;
        
        for ( i = 0; i < [images count];) {
            if (self.writerInput.readyForMoreMediaData) {
                CMTime frameTime = CMTimeMake(1,self.timeScale);
                
                CMTime lastTime = CMTimeMake(i,self.timeScale);
                
                CMTime presentTime = CMTimeAdd(lastTime, frameTime);
                
                if (i == 0) {
                    presentTime = CMTimeMake(0,self.timeScale);
                }
                
                buffer = [self pixelBufferFromCGImage:[images[i] CGImage]];
                
                if (buffer) {
                    
                    if ([self.adaptor appendPixelBuffer:buffer withPresentationTime:presentTime]) {
                        i++;
                    }
                    
                    CVPixelBufferRelease(buffer);
                }
            }
        }
        
        if (i == images.count) {
            [self maskFinishWithSuccess:success Fail:fail];
        }
    });
}

- (void)addAudioToVideoAudioPath:(NSString *)audioPath Completion:(exportAsynchronouslyWithCompletionHandler)completion {
    AVURLAsset* audioAsset = [[AVURLAsset alloc]initWithURL:[NSURL fileURLWithPath:audioPath] options:nil];
    AVURLAsset* videoAsset = [[AVURLAsset alloc]initWithURL:[NSURL fileURLWithPath:self.videoPath] options:nil];
    
    AVMutableComposition* mixComposition = [AVMutableComposition composition];
    
    AVMutableCompositionTrack *compositionCommentaryTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    [compositionCommentaryTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, audioAsset.duration) ofTrack:[[audioAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0] atTime:kCMTimeZero error:nil];
    
    AVMutableCompositionTrack *compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.duration)ofTrack:[[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:kCMTimeZero error:nil];
    
    AVAssetExportSession* assetExport = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetPassthrough];
    
    NSString *exportPath = self.videoPath;
    NSURL *exportUrl = [NSURL fileURLWithPath:exportPath];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:exportPath])
    {
        [[NSFileManager defaultManager] removeItemAtPath:exportPath error:nil];
    }
    
    assetExport.outputFileType = AVFileTypeQuickTimeMovie;
    assetExport.outputURL = exportUrl;
    assetExport.shouldOptimizeForNetworkUse = YES;
    
    [assetExport exportAsynchronouslyWithCompletionHandler:completion];
}

- (void)convertToMP4Completed:(convertToMp4Completed)Completed
{
    NSString *filePath = self.videoPath;
    NSString *mp4FilePath = [filePath stringByReplacingOccurrencesOfString:@"mov" withString:@"mp4"];
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_async(queue, ^{
        
        AVURLAsset *avAsset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:filePath] options:nil];
        NSArray *compatiblePresets = [AVAssetExportSession exportPresetsCompatibleWithAsset:avAsset];
        if ([compatiblePresets containsObject:AVAssetExportPresetHighestQuality]) {
            AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:avAsset presetName:AVAssetExportPresetHighestQuality];
            exportSession.outputURL = [NSURL fileURLWithPath:mp4FilePath];
            exportSession.outputFileType = AVFileTypeMPEG4;
            if ([[NSFileManager defaultManager] fileExistsAtPath:mp4FilePath])
            {
                [[NSFileManager defaultManager] removeItemAtPath:mp4FilePath error:nil];
            }
            [exportSession exportAsynchronouslyWithCompletionHandler:^(void)
             {
                 switch (exportSession.status) {
                     case AVAssetExportSessionStatusUnknown: {
                         NSLog(@"AVAssetExportSessionStatusUnknown");
                         break;
                     }
                     case AVAssetExportSessionStatusWaiting: {
                         NSLog(@"AVAssetExportSessionStatusWaiting");
                         break;
                     }
                     case AVAssetExportSessionStatusExporting: {
                         NSLog(@"AVAssetExportSessionStatusExporting");
                         break;
                     }
                     case AVAssetExportSessionStatusFailed: {
                         NSLog(@"AVAssetExportSessionStatusFailed error:%@", exportSession.error);
                         break;
                     }
                     case AVAssetExportSessionStatusCompleted: {
                         NSLog(@"AVAssetExportSessionStatusCompleted");
                         dispatch_async(dispatch_get_main_queue(),^{
                             Completed();
                         });
                         break;
                     }
                     default: {
                         NSLog(@"AVAssetExportSessionStatusCancelled");
                         break;
                     }
                 }
             }];
        }
    });
}


- (CVPixelBufferRef)pixelBufferFromCGImage:(CGImageRef)image {
    
    if (image) {
        NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSNumber numberWithBool:YES],kCVPixelBufferCGImageCompatibilityKey,
                                 [NSNumber numberWithBool:YES],kCVPixelBufferCGBitmapContextCompatibilityKey, nil];
        
        CVPixelBufferRef pxbuffer = NULL;
        
        CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, CGImageGetWidth(image), CGImageGetHeight(image), kCVPixelFormatType_32ARGB,(__bridge CFDictionaryRef)options, &pxbuffer);
        
        NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);

        CVPixelBufferLockBaseAddress(pxbuffer, 0);
        void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
        NSParameterAssert(pxdata != NULL);
        
        CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
        
        CGContextRef context = CGBitmapContextCreate(pxdata, CGImageGetWidth(image), CGImageGetHeight(image), 8, 4*CGImageGetWidth(image), rgbColorSpace, kCGImageAlphaNoneSkipFirst);

        NSParameterAssert(context);

        CGContextConcatCTM(context, CGAffineTransformMakeRotation(0));
        CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image)), image);
        
        CGColorSpaceRelease(rgbColorSpace);
        CGContextRelease(context);
        
        CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
        
        return pxbuffer;
    } else {
        return NULL;
    }
}

@end
