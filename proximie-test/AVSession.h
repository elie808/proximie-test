//
//  AVSession.h
//  proximie-test
//
//  Created by Elie El Khoury on 8/30/19.
//  Copyright © 2019 Elie El Khoury. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@import GLKit;
@import AVFoundation;

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"

@interface AVSession : NSObject

@property AVCaptureDevice *videoDevice;
@property AVCaptureSession *captureSession;
@property dispatch_queue_t captureSessionQueue;

@property CIContext *ciContext;
@property EAGLContext *eaglContext;

- (void)initializeContexts;
- (void)initializeSessionWithDelegate:(id<AVCaptureVideoDataOutputSampleBufferDelegate>)SessionDelegate;
- (void)bindimage:(CIImage *)sourceImage toDisplay:(GLKView *)videoGLKView withBounds:(CGRect)videoBounds;

+ (CGRect)computeAspectRatio:(CIImage *)sourceImage withPreviewBounds:(CGRect)PreviewVideoBounds;

@end

#pragma GCC diagnostic pop
