#import "ExceptionCatcher.h"

@implementation PIKExceptionCatcher

+ (NSException *)catchException:(void (NS_NOESCAPE ^)(void))tryBlock {
    @try {
        tryBlock();
        return nil;
    }
    @catch (NSException *exception) {
        return exception;
    }
}

@end
