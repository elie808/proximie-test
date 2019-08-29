//
//  ViewController.h
//  proximie-test
//
//  Created by Elie El Khoury on 8/30/19.
//  Copyright © 2019 Elie El Khoury. All rights reserved.
//

#import <UIKit/UIKit.h>
@import GLKit;
@import AVFoundation;

NS_ASSUME_NONNULL_BEGIN

@interface ViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIView *originalView;
@property (weak, nonatomic) IBOutlet UIView *filteredView;

@end

NS_ASSUME_NONNULL_END

