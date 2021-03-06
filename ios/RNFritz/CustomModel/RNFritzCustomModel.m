//
//  RNFritzCustomModel.m
//  RNFritz
//
//  Created by Zain Sajjad on 23/01/2019.
//

#import <React/RCTLog.h>
#import "RNFritz.h"
#import "RNFritzUtils.h"
#import "FritzCustomModel.h"
#import "RNFritzCustomModel.h"

@import CoreML;
@import Vision;
@import FritzVision;

@implementation RNFritzCustomModel {
    NSMutableDictionary *models;
};

BOOL initialized = false;

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}
RCT_EXPORT_MODULE()

//+ (NSArray *) models = [[NSArray alloc] init];

- (instancetype) init {
    self = [super init];
    models = [[NSMutableDictionary alloc] init];
    return self;
}

- (NSMutableArray *) prepareOutput: (NSArray *)labels predicate:(NSPredicate *)predicate limit:(long *)limit {
    NSMutableArray *output = [NSMutableArray array];
    NSArray *temp = [labels filteredArrayUsingPredicate:predicate];
    NSArray *objects = [temp subarrayWithRange:NSMakeRange(0, MIN(limit, temp.count))];
    for (VNClassificationObservation *label in labels) {
        [output addObject:@{
                            @"label": [label valueForKey:@"description"],
                            @"description": [label valueForKey:@"description"],
                            @"confidence": [label valueForKey:@"confidence"],
                            }];
    }
    return output;
}

- (VNCoreMLModel *) loadModel: (NSString *)modelName {
    NSURL *modelUrl = [[NSBundle mainBundle] URLForResource:modelName withExtension:@"mlmodelc"];
    NSError *error;
    MLModel *model = [MLModel modelWithContentsOfURL:modelUrl error:&error].fritz;
    if (error) {
        @throw error;
    }
    VNCoreMLModel *visionModel = [VNCoreMLModel modelForMLModel:model error:&error];
    if (error) {
        @throw error;
    }
    return visionModel;
}

- (VNCoreMLModel *) getModel: (NSString *)modelName {
    if (![models valueForKey:modelName]) {
        VNCoreMLModel *newModel = [self loadModel:modelName];
        [models setValue:newModel forKey:modelName];
    }
    return [models valueForKey:modelName];
}

RCT_REMAP_METHOD(initializeModel,
                 initializeModel:
                (NSString *)modelName
                resolver:(RCTPromiseResolveBlock)resolve
                rejecter:(RCTPromiseRejectBlock)reject) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            [self getModel:modelName];
            dispatch_async(dispatch_get_main_queue(), ^{
                resolve(@YES);
            });
        }
        @catch (NSException *exception) {
            NSError *error = [RNFritzUtils errorFromException:exception];
            dispatch_async(dispatch_get_main_queue(), ^{
                reject([NSString stringWithFormat: @"%ld", [error code]],
                       [error description],
                       error);
            });
        }
    });
}


RCT_REMAP_METHOD(detectFromImage,
                 detectFromImage:
                 (NSString *)modelName
                 params:(NSDictionary *)params
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject
                 ) {
    if (@available(iOS 11.0, *)) {

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        RNFritz *fritz = [[RNFritz alloc] init];
        @try {
            [fritz initializeDetection:resolve rejector:reject];
            NSDictionary *options = [[NSDictionary alloc] init];
            NSData *imageData = [RNFritzUtils getImageData:[params valueForKey:@"imagePath"]];

            VNCoreMLModel *model = [self getModel:modelName];
            VNCoreMLRequest *modelRequest =
                [[VNCoreMLRequest alloc]
                 initWithModel:model
                 completionHandler:(VNRequestCompletionHandler) ^(VNRequest *request, NSError *error){
                    dispatch_async(dispatch_get_main_queue(), ^{
                        @try {
                            if (error != nil) {
                                [fritz onError:error];
                                return;
                            }
                            NSPredicate *predicate = [NSPredicate
                                                      predicateWithFormat:@"self.confidence >= %f",
                                                      [[params valueForKey:@"threshold"] floatValue]];
                            long limit = [[params valueForKey:@"resultLimit"] integerValue];
                            NSArray *output = [self prepareOutput:request.results predicate:predicate limit:limit];
                            [fritz onSuccess:output];
                        }
                        @catch (NSException *e) {
                            [fritz catchException:e];
                        }
                    });
                 }];
            VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithData:imageData options:options];
            NSError *error;
            [handler performRequests:@[modelRequest] error:&error];
        }
        @catch (NSException *e) {
            [fritz catchException:e];
        }
    });
    } else {
        resolve(@NO);
    }
    
}

@end
