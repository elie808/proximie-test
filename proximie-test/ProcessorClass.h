//
//  ProcessorClass.h
//  proximie-test
//
//  Created by Elie El Khoury on 8/30/19.
//  Copyright © 2019 Elie El Khoury. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ProcessorClass : NSObject

typedef enum {
    to_BGR,
    no_processing
} ProcessingMode;

+ (CIImage *)process:(CGImageRef)sourceImageRef rect:(CGRect)drawRect processingMode:(ProcessingMode)mode;

@end

NS_ASSUME_NONNULL_END
