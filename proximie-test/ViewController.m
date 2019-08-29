//
//  ViewController.m
//  proximie-test
//
//  Created by Elie El Khoury on 8/30/19.
//  Copyright © 2019 Elie El Khoury. All rights reserved.
//

#import "ViewController.h"
#import "ProcessorClass.h"

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"

@interface ViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>

@property BOOL enableFiltering;

@property AVCaptureDevice *videoDevice;
@property AVCaptureSession *captureSession;
@property dispatch_queue_t captureSessionQueue;

@property CIContext *ciContext;
@property EAGLContext *eaglContext;
@property (nonatomic, assign) CMVideoDimensions currentVideoDimensions;

// OUTPUT
@property GLKView *originalVideoGLKView;
@property CGRect originalVideoBounds;

@property GLKView *filteredVideoGLKView;
@property CGRect filteredVideoBounds;

@end

@implementation ViewController

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self initialize];
}

- (void)initialize {
    
    _enableFiltering = NO;
    
    // get the input device and also validate the settings
    AVCaptureDeviceDiscoverySession *captureDeviceDiscoverySession = [AVCaptureDeviceDiscoverySession
                                                                      discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera]
                                                                      mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
    
    if (captureDeviceDiscoverySession.devices.count > 0) {
        
        // create the dispatch queue for handling capture session delegate method calls
        _captureSessionQueue = dispatch_queue_create("capture_session_queue", NULL);
        
        [self setupContexts];
        
        [self initializeSession];
        
        // setup the GLKView for video/image preview
        [self intializeOriginalGLKView];
        [self intializeFilteredGLKView];
        
    } else {
        
        NSLog(@"No device with AVMediaTypeVideo");
    }
}

- (void)setupContexts {
    
    // setup the GLKView for video/image preview
    _eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    // create the CIContext instance, note that this must be done after _videoPreviewView is properly set up
    _ciContext = [CIContext contextWithEAGLContext:_eaglContext options:@{kCIContextWorkingColorSpace : [NSNull null]} ];
}

- (void)initializeSession {
    
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
        [videoDataOutput setSampleBufferDelegate:self queue:self.captureSessionQueue];
        
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

- (void)intializeOriginalGLKView {
    
    UIView *window = self.originalView;
    
    _originalVideoGLKView = [[GLKView alloc] initWithFrame:window.bounds context:_eaglContext];
    _originalVideoGLKView.enableSetNeedsDisplay = NO;
    
    // because the native video image from the back camera is in UIDeviceOrientationLandscapeLeft (i.e. the home button is on the right), we need to apply a clockwise 90 degree transform so that we can draw the video preview as if we were in a landscape-oriented view; if you're using the front camera and you want to have a mirrored preview (so that the user is seeing themselves in the mirror), you need to apply an additional horizontal flip (by concatenating CGAffineTransformMakeScale(-1.0, 1.0) to the rotation transform)
    _originalVideoGLKView.transform = CGAffineTransformMakeRotation(M_PI_2);
    _originalVideoGLKView.frame = window.bounds;
    
    // we make our video preview view a subview of the window, and send it to the back; this makes FHViewController's view (and its UI elements) on top of the video preview, and also makes video preview unaffected by device rotation
    [window addSubview:_originalVideoGLKView];
    [window sendSubviewToBack:_originalVideoGLKView];
    
    // bind the frame buffer to get the frame buffer width and height;
    // the bounds used by CIContext when drawing to a GLKView are in pixels (not points),
    // hence the need to read from the frame buffer's width and height;
    // in addition, since we will be accessing the bounds in another queue (_captureSessionQueue),
    // we want to obtain this piece of information so that we won't be
    // accessing _videoPreviewView's properties from another thread/queue
    [_originalVideoGLKView bindDrawable];
    
    _originalVideoBounds = CGRectZero;
    _originalVideoBounds.size.width = _originalVideoGLKView.drawableWidth;
    _originalVideoBounds.size.height = _originalVideoGLKView.drawableHeight;
}

- (void)intializeFilteredGLKView {
    
    UIView *window = self.filteredView;
    
    _filteredVideoGLKView = [[GLKView alloc] initWithFrame:window.bounds context:_eaglContext];
    _filteredVideoGLKView.enableSetNeedsDisplay = NO;
    
    _filteredVideoGLKView.transform = CGAffineTransformMakeRotation(M_PI_2);
    _filteredVideoGLKView.frame = window.bounds;
    
    [window addSubview:_filteredVideoGLKView];
    [window sendSubviewToBack:_filteredVideoGLKView];
    
    [_filteredVideoGLKView bindDrawable];
    _filteredVideoBounds = CGRectZero;
    _filteredVideoBounds.size.width = _filteredVideoGLKView.drawableWidth;
    _filteredVideoBounds.size.height = _filteredVideoGLKView.drawableHeight;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    // update the video dimensions information
    CMFormatDescriptionRef formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer);
    _currentVideoDimensions = CMVideoFormatDescriptionGetDimensions(formatDesc);
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CIImage *sourceImage = [CIImage imageWithCVPixelBuffer:(CVPixelBufferRef)imageBuffer options:nil];
    
    [self bindimage:sourceImage toDisplay:_originalVideoGLKView withBounds:_originalVideoBounds];
    
    CGImageRef img = [_ciContext createCGImage:sourceImage fromRect:[sourceImage extent]];
    
    [self bindimage:sourceImage toDisplay:_filteredVideoGLKView withBounds:_filteredVideoBounds];
    
    if (_enableFiltering == YES) {
        
        CIImage *processedSource = [ProcessorClass process:img rect:_filteredVideoBounds processingMode:to_BGR];
        [self bindimage:processedSource toDisplay:_filteredVideoGLKView withBounds:_filteredVideoBounds];
        
    } else {
        
        CIImage *processedSource = [ProcessorClass process:img rect:_filteredVideoBounds processingMode:no_processing];
        [self bindimage:processedSource toDisplay:_filteredVideoGLKView withBounds:_filteredVideoBounds];
    }
    
}

- (void)bindimage:(CIImage *)sourceImage toDisplay:(GLKView *)videoGLKView withBounds:(CGRect)videoBounds {
    
    CGRect drawRect = [self computeAspectRatio:sourceImage withPreviewBounds:videoBounds];
    
    [videoGLKView bindDrawable];
    
    if (_eaglContext != [EAGLContext currentContext])
        [EAGLContext setCurrentContext:_eaglContext];
    
    [_ciContext drawImage:sourceImage inRect:videoBounds fromRect:drawRect];
    
    [videoGLKView display];
}

- (CGRect)computeAspectRatio:(CIImage *)sourceImage withPreviewBounds:(CGRect)PreviewVideoBounds {
    
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


#pragma mark - Actions

- (IBAction)didTapStart:(UIButton *)sender {
    
    dispatch_async(_captureSessionQueue, ^(void) {
        [self.captureSession startRunning];
    });
}

- (IBAction)didTapStop:(UIButton *)sender {
    
    [self.captureSession stopRunning];
    
}

- (IBAction)didChangeSegment:(UISegmentedControl *)sender {
    
    if (sender.selectedSegmentIndex == 0) {
        _enableFiltering = NO;
    } else if (sender.selectedSegmentIndex == 1) {
        _enableFiltering = YES;
    }
}

#pragma GCC diagnostic pop

@end
