//
//  ViewController.m
//  ImageToVideo
//
//  Created by Xu Menghua on 16/5/10.
//  Copyright © 2016年 Xu Menghua. All rights reserved.
//

#import "ViewController.h"
#import "VideoBuilder.h"

@interface ViewController ()

@property (nonatomic, strong) VideoBuilder *videoBuilder;
@property (nonatomic, strong) NSString *videoPath;
@property (nonatomic, strong) NSString *audioPath;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSString *fileName = @"output.mov";
    self.videoPath = [NSString stringWithFormat:@"%@/%@", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0], fileName];
    [[NSFileManager defaultManager] removeItemAtPath:self.videoPath error:nil];
    self.videoBuilder = [[VideoBuilder alloc] initWithOutputSize:CGSizeMake(1920, 1080) Timescale:1 OutputPath:self.videoPath];
    self.audioPath = [[NSBundle mainBundle] pathForResource:@"audio" ofType:@"mp3"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (IBAction)start:(UIButton *)sender {
    UIImage *image = [UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"img" ofType:@"png"]];
    NSArray *images = @[image];
    __weak ViewController *weakSelf = self;
    [self.videoBuilder convertVideoWithImageArray:images Success:^{
        NSLog(@"success");
        [self.videoBuilder addAudioToVideoAudioPath:self.audioPath Completion:^{
            NSLog(@"add audio completed");
            [weakSelf.videoBuilder convertToMP4Completed:^{
                NSLog(@"convert to mp4 completed");
            }];
        }];
    } Fail:^(NSError *error) {
        NSLog(@"%@", error.localizedDescription);
    }];
}

@end
