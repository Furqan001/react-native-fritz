//
//  RNFritzVisionImageLabeling.m
//  RNFritz
//
//  Created by Zain Sajjad on 22/01/2019.
//

#import "RNFritzVisionImageLabeling.h"

#if __has_include(<FritzVisionLabelModel/FritzVisionLabelModel.h>)

#import "RNFritz.h"
#import "RNFritzUtils.h"

@import FritzVisionLabelModel;

@implementation RNFritzVisionImageLabeling 

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}
RCT_EXPORT_MODULE()

- (FritzVisionLabelModelOptions *) getLabelModelOptions: (NSDictionary *)params {
    return [[FritzVisionLabelModelOptions alloc]
            initWithThreshold:[[params valueForKey:@"threshold"] floatValue]
            numResults:[[params valueForKey:@"resultLimit"] doubleValue]];
}

RCT_REMAP_METHOD(detect,
                 detect:(NSDictionary *)params
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject
                 ) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        RNFritz *fritz = [[RNFritz alloc] init];
        @try {
            [fritz initializeDetection:resolve rejector:reject];
            NSString *imagePath = [params valueForKey:@"imagePath"];
            FritzVisionImage *visionImage = [RNFritzUtils getFritzVisionImage:imagePath];
            FritzVisionLabelModelOptions *options = [self getLabelModelOptions:params];
            FritzVisionLabelModel *visionModel = [FritzVisionLabelModel new];
            [visionModel
             predict:visionImage
             options:options
             completion:^(NSArray *objects, NSError *error) {
                 @try {
                     if (error != nil) {
                         [fritz onError:error];
                         return;
                     }
                     [fritz onSuccess:objects];
                 }
                 @catch (NSException *e) {
                     [fritz catchException:e];
                 }
             }];
        }
        @catch (NSException *e) {
            [fritz catchException:e];
        }
    });
    
}

@end

#else

@implementation RNFritzVisionImageLabeling

@end
#endif