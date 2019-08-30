//
//  ViewController.m
//  proximie-test
//
//  Created by Elie El Khoury on 8/30/19.
//  Copyright © 2019 Elie El Khoury. All rights reserved.
//

#import "ViewController.h"
#import "AVSession.h"
#import "ProcessorClass.h"

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"

@interface ViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>

@property AVSession *session;

@property BOOL enableFiltering;

@property GLKView *originalVideoGLKView;
@property CGRect originalVideoBounds;

@property GLKView *filteredVideoGLKView;
@property CGRect filteredVideoBounds;

//@property CMVideoDimensions currentVideoDimensions;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

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
        
        _session = [[AVSession alloc] init];
        
        [_session initializeContexts];
        
        [_session initializeSessionWithDelegate:self];
        
        // setup the GLKView for video/image preview
        [self intializeOriginalGLKView];
        [self intializeFilteredGLKView];
        
    } else {
        
        NSLog(@"No device with AVMediaTypeVideo");
    }
}

- (void)intializeOriginalGLKView {
    
    UIView *window = self.originalView;
    
    _originalVideoGLKView = [[GLKView alloc] initWithFrame:window.bounds context:_session.eaglContext];
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
    
    _filteredVideoGLKView = [[GLKView alloc] initWithFrame:window.bounds context:_session.eaglContext];
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

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    // update the video dimensions information
    // CMFormatDescriptionRef formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer);
    // _currentVideoDimensions = CMVideoFormatDescriptionGetDimensions(formatDesc);
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CIImage *sourceImage = [CIImage imageWithCVPixelBuffer:(CVPixelBufferRef)imageBuffer options:nil];
    
    [_session bindimage:sourceImage toDisplay:_originalVideoGLKView withBounds:_originalVideoBounds];
    
    CGImageRef img = [_session.ciContext createCGImage:sourceImage fromRect:[sourceImage extent]];
    
    if (_enableFiltering == YES) {
        
        CIImage *processedSource = [ProcessorClass process:img rect:_filteredVideoBounds processingMode:to_BGR];
        [_session bindimage:processedSource toDisplay:_filteredVideoGLKView withBounds:_filteredVideoBounds];
        
    } else {
        
        CIImage *processedSource = [ProcessorClass process:img rect:_filteredVideoBounds processingMode:no_processing];
        [_session bindimage:processedSource toDisplay:_filteredVideoGLKView withBounds:_filteredVideoBounds];
    }
}

#pragma mark - Actions

- (IBAction)didTapStart:(UIButton *)sender {
    
    dispatch_async(self.session.captureSessionQueue, ^(void) {
        [self.session.captureSession startRunning];
    });
}

- (IBAction)didTapStop:(UIButton *)sender {
    
    [self.session.captureSession stopRunning];
    
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
