#import "MlkitOcr.h"

#import <React/RCTBridge.h>
#import <React/RCTLog.h>

#import <Photos/Photos.h>

#import <CoreGraphics/CoreGraphics.h>
#import <GoogleMLKit/MLKit.h>

@implementation MlkitOcr

RCT_EXPORT_MODULE()

static NSString *const detectionNoResultsMessage = @"Something went wrong";



NSMutableArray * getCornerPoints(NSArray *cornerPoints) {
    NSMutableArray *result = [NSMutableArray array];

    if (cornerPoints == nil) {
        return result;
    }

    for (NSValue *point in cornerPoints) {
        NSMutableDictionary *resultPoint = [NSMutableDictionary dictionary];
        [resultPoint setObject:[NSNumber numberWithFloat:point.CGPointValue.x] forKey:@"x"];
        [resultPoint setObject:[NSNumber numberWithFloat:point.CGPointValue.y] forKey:@"y"];
        [result addObject:resultPoint];
    }

    return result;
}

NSDictionary * getBounding(CGRect frame) {
    return @{
        @"top": @(frame.origin.y),
        @"left": @(frame.origin.x),
        @"width": @(frame.size.width),
        @"height": @(frame.size.height)
    };
}

NSMutableDictionary * prepareOutput(MLKText *result, UIImage *image) {
    NSMutableArray *output = [NSMutableArray array];

    for (MLKTextBlock *block in result.blocks) {
        NSMutableArray *blockElements = [NSMutableArray array];

        for (MLKTextLine *line in block.lines) {
            NSMutableArray *lineElements = [NSMutableArray array];

            for (MLKTextElement *element in line.elements) {
                NSMutableDictionary *e = [NSMutableDictionary dictionary];
                e[@"text"] = element.text;
                e[@"cornerPoints"] = getCornerPoints(element.cornerPoints);
                e[@"bounding"] = getBounding(element.frame);
                [lineElements addObject:e];
            }

            NSMutableDictionary *l = [NSMutableDictionary dictionary];
            l[@"text"] = line.text;
            l[@"cornerPoints"] = getCornerPoints(line.cornerPoints);
            l[@"elements"] = lineElements;
            l[@"bounding"] = getBounding(line.frame);
            [blockElements addObject:l];
        }

        NSMutableDictionary *b = [NSMutableDictionary dictionary];
        b[@"text"] = block.text;
        b[@"cornerPoints"] = getCornerPoints(block.cornerPoints);
        b[@"bounding"] = getBounding(block.frame);
        b[@"lines"] = blockElements;
        [output addObject:b];
    }

    NSMutableDictionary *res = [NSMutableDictionary dictionary];
    res[@"textRecognition"] = output;

    NSString *base64Image = @"";

    if (image) {
        NSData *imageData = UIImagePNGRepresentation(image);

        if (imageData) {
            base64Image = [imageData base64EncodedStringWithOptions:0];
        }
    }

    res[@"base64Image"] = base64Image;
    return res;
}

- (void)handleRecognizer:(UIImage *)image imagePath:(NSString *)imagePath resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject {
    if (!image) {
        dispatch_async(dispatch_get_main_queue(), ^{
            RCTLog(@"No image found %@", imagePath);
            reject(@"no_image", @"No image path provided", nil);
        });
        return;
    }

    MLKChineseTextRecognizerOptions *chineseOptions = [[MLKChineseTextRecognizerOptions alloc] init];
    MLKTextRecognizer *textRecognizer = [MLKTextRecognizer textRecognizerWithOptions:chineseOptions];

    MLKVisionImage *handler = [[MLKVisionImage alloc] initWithImage:image];

    [textRecognizer processImage:handler
                      completion:^(MLKText *_Nullable result, NSError *_Nullable error) {
        @try {
            if (error != nil || result == nil) {
                NSString *errorString = error ? error.localizedDescription : detectionNoResultsMessage;
                @throw [NSException exceptionWithName:@"failure"
                                               reason:errorString
                                             userInfo:nil];
                return;
            }

            NSMutableDictionary *output = prepareOutput(result, image);
            dispatch_async(dispatch_get_main_queue(), ^{
                               resolve(output);
                           });
        } @catch (NSException *e) {
            NSString *errorString = e ? e.reason : detectionNoResultsMessage;
            NSDictionary *pData = @{
                    @"error": [NSMutableString stringWithFormat:@"On-Device text detection failed with error: %@", errorString],
            };
            dispatch_async(dispatch_get_main_queue(), ^{
                               resolve(pData);
                           });
        }
    }];
}

- (void)handlePHAssets:(NSString *)imagePath resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject {
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if (status == PHAuthorizationStatusAuthorized) {
            NSString *localIdentifier = [imagePath substringFromIndex:5];
            PHFetchResult<PHAsset *> *fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[localIdentifier]
                                                                                     options:nil];

            if (fetchResult.count == 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                                   RCTLog(@"No image found %@", imagePath);
                                   reject(@"no_image", @"No image path provided", nil);
                               });
                return;
            }

            PHAsset *asset = fetchResult.firstObject;

            if (asset) {
                PHImageManager *imageManager = [PHImageManager defaultManager];
                PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
                options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
                options.resizeMode = PHImageRequestOptionsResizeModeExact;

                [imageManager requestImageForAsset:asset
                                        targetSize:PHImageManagerMaximumSize
                                       contentMode:PHImageContentModeDefault
                                           options:options
                                     resultHandler:^(UIImage *_Nullable result, NSDictionary *_Nullable info) {
                    if (result) {
                        [self handleRecognizer:result
                                     imagePath:imagePath
                                      resolver:resolve
                                      rejecter:reject];
                    } else {
                        dispatch_async(dispatch_get_main_queue(), ^{
                                           RCTLog(@"No image found %@", imagePath);
                                           reject(@"no_image", @"No image path provided", nil);
                                       });
                        return;
                    }
                }];
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                                   RCTLog(@"No image found %@", imagePath);
                                   reject(@"no_image", @"No image path provided", nil);
                               });
                return;
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                               RCTLog(@"No Photo Library Permissions%@", imagePath);
                               reject(@"no_permissions", @"No photo library permissions", nil);
                           });
            return;
        }
    }];
}

- (void)handleAuthStatus:(PHAuthorizationStatus)status resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject {
    switch (status) {
        case PHAuthorizationStatusAuthorized: {
            // 已授权，可以访问相册
            NSDictionary *ret = @{
                    @"auth": @(YES),
                    @"code": @(1),
                    @"message": @"Authorized"
            };
            resolve(ret);
            break;
        }

        case PHAuthorizationStatusDenied: {
            // 拒绝
            NSDictionary *ret = @{
                    @"auth": @(NO),
                    @"code": @(-1),
                    @"message": @"Denied"
            };
            resolve(ret);
            break;
        }

        case PHAuthorizationStatusRestricted: {
            // 被拒绝或受限，不能访问相册
            NSDictionary *ret = @{
                    @"auth": @(NO),
                    @"code": @(-2),
                    @"message": @"Restricted"
            };
            resolve(ret);
            break;
        }

        case PHAuthorizationStatusNotDetermined: {
            // 尚未确定，请求访问相册权限
            NSDictionary *ret = @{
                    @"auth": @(NO),
                    @"code": @(-3),
                    @"message": @"NotDetermined"
            };
            resolve(ret);
            break;
        }

        default:
            break;
    }
}

RCT_REMAP_METHOD(detectFromUri, detectFromUri:(NSString *)imagePath resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    if (!imagePath) {
        RCTLog(@"No image uri provided");
        reject(@"wrong_arguments", @"No image uri provided", nil);
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if ([imagePath hasPrefix:@"ph://"]) {
            [self handlePHAssets:imagePath resolver:resolve rejecter:reject];
        } else {
            NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:imagePath]];
            UIImage *image = [UIImage imageWithData:imageData];

            if (!image) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    RCTLog(@"No image found %@", imagePath);
                    reject(@"no_image", @"No image path provided", nil);
                });
                return;
            }

            [self handleRecognizer:image imagePath:imagePath resolver:resolve rejecter:reject];
        }
    });
}

RCT_REMAP_METHOD(detectFromFile, detectFromFile:(NSString *)imagePath resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    if (!imagePath) {
        reject(@"wrong_arguments", @"No image path provided", nil);
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if ([imagePath hasPrefix:@"ph://"]) {
            [self handlePHAssets:imagePath resolver:resolve rejecter:reject];
        } else {
            NSData *imageData = [NSData dataWithContentsOfFile:imagePath];
            UIImage *image = [UIImage imageWithData:imageData];

            if (!image) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    RCTLog(@"No image found %@", imagePath);
                    reject(@"no_image", @"No image path provided", nil);
                });
                return;
            }

            [self handleRecognizer:image imagePath:imagePath resolver:resolve rejecter:reject];
        }
    });
}

RCT_REMAP_METHOD(checkAuth, checkAuth:(NSDictionary *)param resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    // 检查相册权限状态
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];

    [self handleAuthStatus:status resolver:resolve rejecter:reject];
}


RCT_REMAP_METHOD(requestAuth, requestAuth:(NSDictionary *)param resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        [self handleAuthStatus:status
                      resolver:resolve
                      rejecter:reject];
    }];
}

@end
