//
//  ProcessorClass.m
//  proximie-test
//
//  Created by Elie El Khoury on 8/30/19.
//  Copyright © 2019 Elie El Khoury. All rights reserved.
//

#import "ProcessorClass.h"
#import <opencv2/videoio/cap_ios.h>
#import <opencv2/imgproc/imgproc.hpp>

using namespace cv;

@implementation ProcessorClass

#ifdef __cplusplus

/// process method using CIImage as input. Convert it from RGB  to BGR
+ (CIImage *)process:(CGImageRef)sourceImageRef rect:(CGRect)drawRect processingMode:(ProcessingMode)mode {
    
    //    [ProcessorClass imageDump:sourceImageRef];
    
    Mat cvInput = [ProcessorClass cvMatFromCGImage:sourceImageRef andRect:drawRect];
    
    switch (mode) {
            
        case 0: { // convert RGB to BGR
            Mat cvOutput; // output
            cvtColor(cvInput, cvOutput, COLOR_RGB2BGRA);
            return [ProcessorClass CIImageFromCvMat:cvOutput];
        }
            break;
            
        default: return [ProcessorClass CIImageFromCvMat:cvInput]; // no filtering
            break;
    }
    
}

/// Create CV Mat from CIImage
+ (Mat)cvMatFromCGImage:(CGImageRef)sourceImageRef andRect:(CGRect)drawRect {
    
    CGFloat cols = drawRect.size.width;
    CGFloat rows = drawRect.size.height;
    
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(sourceImageRef);
    
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                   // Pointer to backing data
                                                    cols,                         // Width of bitmap
                                                    rows,                         // Height of bitmap
                                                    8,                           // Bits per component
                                                    cvMat.step[0],                // Bytes per row
                                                    colorSpace,                   // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), sourceImageRef);
    
    CGContextRelease(contextRef);
    CGImageRelease(sourceImageRef);
    
    return cvMat;
}

+ (CIImage *)CIImageFromCvMat:(Mat)cvMat {
    
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    CGColorSpaceRef colorSpace;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
                                        cvMat.rows,                                 //height
                                        8,                                          //bpc - bits per component
                                        32,//8 * cvMat.elemSize(),                  //bpp - bits per pixel - cvMat.elemSize() = 3
                                        cvMat.step[0],                              //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        kCGImageAlphaNoneSkipLast,                  // bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );
    
    CIImage *ciImage = [CIImage imageWithCGImage:imageRef];
    
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return ciImage;
}

/// Helper method to output image info
+ (void)imageDump:(CGImageRef)cgimage {
    
    //    UIImage* image = [UIImage imageNamed:file];
    //    CGImageRef cgimage = image.CGImage;
    
    size_t width  = CGImageGetWidth(cgimage);
    size_t height = CGImageGetHeight(cgimage);
    
    size_t bpr = CGImageGetBytesPerRow(cgimage);
    size_t bpp = CGImageGetBitsPerPixel(cgimage);
    size_t bpc = CGImageGetBitsPerComponent(cgimage);
    size_t bytes_per_pixel = bpp / bpc;
    
    CGBitmapInfo info = CGImageGetBitmapInfo(cgimage);
    
    NSLog(
          @"\n"
          "==========\n"
          "CGImageGetHeight: %d\n"
          "CGImageGetWidth:  %d\n"
          "CGImageGetColorSpace: %@\n"
          "CGImageGetBitsPerPixel:     %d\n"
          "CGImageGetBitsPerComponent: %d\n"
          "CGImageGetBytesPerRow:      %d\n"
          "CGImageGetBitmapInfo: 0x%.8X\n"
          "  kCGBitmapAlphaInfoMask     = %s\n"
          "  kCGBitmapFloatComponents   = %s\n"
          "  kCGBitmapByteOrderMask     = 0x%.8X\n"
          "  kCGBitmapByteOrderDefault  = %s\n"
          "  kCGBitmapByteOrder16Little = %s\n"
          "  kCGBitmapByteOrder32Little = %s\n"
          "  kCGBitmapByteOrder16Big    = %s\n"
          "  kCGBitmapByteOrder32Big    = %s\n",
          (int)width,
          (int)height,
          CGImageGetColorSpace(cgimage),
          (int)bpp,
          (int)bpc,
          (int)bpr,
          (unsigned)info,
          (info & kCGBitmapAlphaInfoMask)     ? "YES" : "NO",
          (info & kCGBitmapFloatComponents)   ? "YES" : "NO",
          (info & kCGBitmapByteOrderMask),
          ((info & kCGBitmapByteOrderMask) == kCGBitmapByteOrderDefault)  ? "YES" : "NO",
          ((info & kCGBitmapByteOrderMask) == kCGBitmapByteOrder16Little) ? "YES" : "NO",
          ((info & kCGBitmapByteOrderMask) == kCGBitmapByteOrder32Little) ? "YES" : "NO",
          ((info & kCGBitmapByteOrderMask) == kCGBitmapByteOrder16Big)    ? "YES" : "NO",
          ((info & kCGBitmapByteOrderMask) == kCGBitmapByteOrder32Big)    ? "YES" : "NO"
          );
    
    //    CGDataProviderRef provider = CGImageGetDataProvider(cgimage);
    //    NSData *data = (id)CFBridgingRelease(CGDataProviderCopyData(provider));
    //    uint8_t *bytes = [data bytes];
    //
    //    printf("Pixel Data:\n");
    //
    //    for (size_t row = 0; row < height; row++) {
    //
    //        for (size_t col = 0; col < width; col++) {
    //
    //            const uint8_t * pixel = &bytes[row * bpr + col * bytes_per_pixel];
    //
    //            printf("(");
    //
    //            for (size_t x = 0; x < bytes_per_pixel; x++) {
    //                printf("%.2X", pixel[x]);
    //                if( x < bytes_per_pixel - 1 )
    //                    printf(",");
    //            }
    //
    //            printf(")");
    //            if( col < width - 1 )
    //                printf(", ");
    //        }
    //
    //        printf("\n");
    //    }
}

#endif

@end
