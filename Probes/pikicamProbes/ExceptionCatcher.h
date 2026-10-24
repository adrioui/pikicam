#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// ObjC shim: Swift cannot catch NSException directly. Probe code uses this
/// to trap API that throws NSInvalidArgumentException (e.g. setting
/// photoQualityPrioritization = .quality on a RAW settings object).
@interface PIKExceptionCatcher : NSObject
+ (nullable NSException *)catchException:(void (NS_NOESCAPE ^)(void))tryBlock;
@end

NS_ASSUME_NONNULL_END
