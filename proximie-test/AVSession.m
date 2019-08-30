//
//  AVSession.m
//  proximie-test
//
//  Created by Elie El Khoury on 8/30/19.
//  Copyright © 2019 Elie El Khoury. All rights reserved.
//

#import "AVSession.h"

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"

@implementation AVSession

- (void)initializeSessionWithDelegate:(id<AVCaptureVideoDataOutputSampleBufferDelegate>)sessionDelegate {
    
    // create the dispatch queue for handling capture session delegate method calls
    _captureSessionQueue = dispatch_queue_create("capture_session_queue", NULL);
    
    dispatch_async(_captureSessionQueue, ^(void) {
        
        // get the input device and also validate the settings
        AVCaptureDeviceDiscoverySession *captureDeviceDiscoverySession = [AVCaptureDeviceDiscoverySession
                                                                          discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera]
                                                                          mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
        NSArray *videoDevices = [captureDeviceDiscoverySession devices];
        
        // AVCaptureDeviceDiscoverySession
        AVCaptureDevicePosition position = AVCaptureDevicePositionBack;
        
        for (AVCaptureDevice *device in videoDevices) {
            if (device.position == position) {
                self.videoDevice = device;
                break;
            }
        }
        
        // obtain device input
        NSError *error = nil;
        AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:self.videoDevice error:&error];
        if (!videoDeviceInput) {
            NSLog(@"%@", [NSString stringWithFormat:@"Unable to obtain video device input, error: %@", error]);
            return;
        }
        
        // obtain the preset and validate the preset
        NSString *preset = AVCaptureSessionPresetHigh;
        if (![self.videoDevice supportsAVCaptureSessionPreset:preset]) {
            NSLog(@"%@", [NSString stringWithFormat:@"Capture session preset not supported by video device: %@", preset]);
            return;
        }
        
        // create the capture session
        self.captureSession = [[AVCaptureSession alloc] init];
        self.captureSession.sessionPreset = preset;
        
        // CoreImage wants BGRA pixel format
        NSDictionary *outputSettings = @{ (id)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithInteger:kCVPixelFormatType_32BGRA]};
        
        // create and configure video data output
        AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
        videoDataOutput.videoSettings = outputSettings;
        
        // create the dispatch queue for handling capture session delegate method calls
        self.captureSessionQueue = dispatch_queue_create("capture_session_queue", NULL);
        [videoDataOutput setSampleBufferDelegate:sessionDelegate queue:self.captureSessionQueue];
        
        videoDataOutput.alwaysDiscardsLateVideoFrames = YES;
        
        // begin configure capture session
        [self.captureSession beginConfiguration];
        
        if (![self.captureSession canAddOutput:videoDataOutput]) {
            NSLog(@"Cannot add video data output");
            self.captureSession = nil;
            return;
        }
        
        // connect the video device input and video data and still image outputs
        [self.captureSession addInput:videoDeviceInput];
        [self.captureSession addOutput:videoDataOutput];
        
        [self.captureSession commitConfiguration];
    });
}

- (void)initializeContexts {
    
    // setup the GLKView for video/image preview
    _eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    // create the CIContext instance, note that this must be done after _videoPreviewView is properly set up
    _ciContext = [CIContext contextWithEAGLContext:_eaglContext options:@{kCIContextWorkingColorSpace : [NSNull null]} ];
}

- (void)bindimage:(CIImage *)sourceImage toDisplay:(GLKView *)videoGLKView withBounds:(CGRect)videoBounds {
    
    CGRect drawRect = [AVSession computeAspectRatio:sourceImage withPreviewBounds:videoBounds];
    
    [videoGLKView bindDrawable];
    
    if (_eaglContext != [EAGLContext currentContext])
        [EAGLContext setCurrentContext:_eaglContext];
    
    [_ciContext drawImage:sourceImage inRect:videoBounds fromRect:drawRect];
    
    [videoGLKView display];
}

+ (CGRect)computeAspectRatio:(CIImage *)sourceImage withPreviewBounds:(CGRect)PreviewVideoBounds {
    
    // we want to maintain the aspect radio of the screen size, so we clip the video image
    CGRect sourceImageExtent = sourceImage.extent;
    
    //    CGFloat sourceAspect = sourceImageExtent.size.width / sourceImageExtent.size.height;
    //    CGFloat previewAspect = PreviewVideoBounds.size.width  / PreviewVideoBounds.size.height;
    
    //    if (sourceAspect > previewAspect) {
    //
    //        // use full height of the video image, and center crop the width
    //        sourceImageExtent.origin.x += (sourceImageExtent.size.width - sourceImageExtent.size.height * previewAspect) / 2.0;
    //        sourceImageExtent.size.width = sourceImageExtent.size.height * previewAspect;
    //
    //    } else {
    //
    //        // use full width of the video image, and center crop the height
    //        sourceImageExtent.origin.y += (sourceImageExtent.size.height - sourceImageExtent.size.width / previewAspect) / 2.0;
    //        sourceImageExtent.size.height = sourceImageExtent.size.width / previewAspect;
    //    }
    
    return sourceImageExtent;
}

@end

#pragma GCC diagnostic pop
