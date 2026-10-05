#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString * const DBPluginLogPrefix = @"[DarwinBridgeLC]";

static void DBLog(NSString *message) {
    NSLog(@"%@ %@", DBPluginLogPrefix, message);
}

@interface DBCompatObject : NSObject
@end

@implementation DBCompatObject
+ (BOOL)resolveInstanceMethod:(SEL)sel {
    DBLog([NSString stringWithFormat:@"unhandled instance selector %@ on %@", NSStringFromSelector(sel), NSStringFromClass(self)]);
    return [super resolveInstanceMethod:sel];
}
+ (BOOL)resolveClassMethod:(SEL)sel {
    DBLog([NSString stringWithFormat:@"unhandled class selector %@ on %@", NSStringFromSelector(sel), NSStringFromClass(self)]);
    return [super resolveClassMethod:sel];
}
@end

#define DB_EMPTY_CLASS(name) @interface name : DBCompatObject @end @implementation name @end

DB_EMPTY_CLASS(NSAlert)
DB_EMPTY_CLASS(NSBitmapImageRep)
DB_EMPTY_CLASS(NSColorSpace)
DB_EMPTY_CLASS(NSCursor)
DB_EMPTY_CLASS(NSEvent)
DB_EMPTY_CLASS(NSFontManager)
DB_EMPTY_CLASS(NSGraphicsContext)
DB_EMPTY_CLASS(NSImage)
DB_EMPTY_CLASS(NSMenu)
DB_EMPTY_CLASS(NSMenuItem)
DB_EMPTY_CLASS(NSOpenPanel)
DB_EMPTY_CLASS(NSScreen)
DB_EMPTY_CLASS(NSView)
DB_EMPTY_CLASS(NSWindow)
DB_EMPTY_CLASS(SBApplication)
DB_EMPTY_CLASS(NSAppleEventManager)

@interface NSHTTPURLResponse : NSURLResponse
- (instancetype)initWithURL:(NSURL *)URL
                 statusCode:(NSInteger)statusCode
                HTTPVersion:(NSString *)HTTPVersion
               headerFields:(NSDictionary<NSString *, NSString *> *)headerFields;
+ (NSString *)localizedStringForStatusCode:(NSInteger)statusCode;
- (NSInteger)statusCode;
- (NSDictionary *)allHeaderFields;
@end

@implementation NSHTTPURLResponse {
    NSInteger _dbStatusCode;
    NSDictionary *_dbHeaderFields;
}
- (instancetype)initWithURL:(NSURL *)URL
                 statusCode:(NSInteger)statusCode
                HTTPVersion:(NSString *)HTTPVersion
               headerFields:(NSDictionary<NSString *,NSString *> *)headerFields {
    self = [super initWithURL:URL MIMEType:nil expectedContentLength:-1 textEncodingName:nil];
    if (self) {
        _dbStatusCode = statusCode;
        _dbHeaderFields = [headerFields copy] ?: @{};
        DBLog([NSString stringWithFormat:@"NSHTTPURLResponse status=%ld", (long)statusCode]);
    }
    return self;
}
+ (NSString *)localizedStringForStatusCode:(NSInteger)statusCode {
    return [NSHTTPURLResponse localizedStringForStatusCode:statusCode];
}
- (NSInteger)statusCode { return _dbStatusCode; }
- (NSDictionary *)allHeaderFields { return _dbHeaderFields ?: @{}; }
@end

@interface NSApplication : DBCompatObject
+ (instancetype)sharedApplication;
- (void)run;
- (void)terminate:(id)sender;
@end

@implementation NSApplication
+ (instancetype)sharedApplication {
    static NSApplication *app;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ app = [NSApplication new]; });
    DBLog(@"NSApplication sharedApplication");
    return app;
}
- (void)run {
    DBLog(@"NSApplication run requested; UIKit host keeps the process event loop alive");
}
- (void)terminate:(id)sender {
    DBLog(@"NSApplication terminate requested");
}
@end

id NSApp = nil;
NSString *NSCalibratedRGBColorSpace = @"NSCalibratedRGBColorSpace";
NSString *NSDeviceRGBColorSpace = @"NSDeviceRGBColorSpace";
NSString *NSEventTrackingRunLoopMode = @"NSEventTrackingRunLoopMode";
NSString *NSModalPanelRunLoopMode = @"NSModalPanelRunLoopMode";

int32_t Gestalt(uint32_t selector, int32_t *response) {
    if (response) *response = 0;
    DBLog([NSString stringWithFormat:@"Gestalt selector=0x%08x", selector]);
    return 0;
}

void DBDarwinBridgeRuntimeCheckpoint(const char *phase, const char *detail) {
    NSString *p = phase ? [NSString stringWithUTF8String:phase] : @"unknown";
    NSString *d = detail ? [NSString stringWithUTF8String:detail] : @"";
    DBLog([NSString stringWithFormat:@"checkpoint %@ %@", p, d]);
}

const char *DBDarwinBridgePluginVersion(void) {
    return "0.1.0-stage20";
}

__attribute__((constructor))
static void DBDarwinBridgePluginInit(void) {
    NSApp = [NSApplication sharedApplication];
    DBLog(@"compatibility plugin loaded");
    DBLog([NSString stringWithFormat:@"UIKit=%@ MetalClassProbe=%@",
           NSStringFromClass(UIApplication.class),
           NSClassFromString(@"MTLDevice") ? @"yes" : @"no"]);
}
