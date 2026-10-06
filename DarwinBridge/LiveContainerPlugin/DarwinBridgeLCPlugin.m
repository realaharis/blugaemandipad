#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CFNetwork/CFNetwork.h>
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

@interface DBNSHTTPURLResponseShim : NSURLResponse
- (instancetype)initWithURL:(NSURL *)URL
                 statusCode:(NSInteger)statusCode
                HTTPVersion:(NSString *)HTTPVersion
               headerFields:(NSDictionary<NSString *, NSString *> *)headerFields;
+ (NSString *)localizedStringForStatusCode:(NSInteger)statusCode;
- (NSInteger)statusCode;
- (NSDictionary *)allHeaderFields;
@end

@implementation DBNSHTTPURLResponseShim {
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
        DBLog([NSString stringWithFormat:@"NSHTTPURLResponse shim status=%ld", (long)statusCode]);
    }
    return self;
}
+ (NSString *)localizedStringForStatusCode:(NSInteger)statusCode {
    return [NSString stringWithFormat:@"HTTP %ld", (long)statusCode];
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


// Mach-O clients bind Objective-C classes by the exported symbol
// _OBJC_CLASS_$_ClassName. Runtime registration alone is too late for dyld's
// non-flat ordinal bind, so export an actual data symbol from the compatibility
// dylib. The value is populated by the plugin constructor.
__attribute__((visibility("default"), used))
Class DBExportedNSHTTPURLResponse __asm__("_OBJC_CLASS_$_NSHTTPURLResponse") = Nil;

__attribute__((visibility("default"), used))
Class DBExportedNSMutableURLRequest __asm__("_OBJC_CLASS_$_NSMutableURLRequest") = Nil;
__attribute__((visibility("default"), used))
Class DBExportedNSURLRequest __asm__("_OBJC_CLASS_$_NSURLRequest") = Nil;
__attribute__((visibility("default"), used))
Class DBExportedNSURLResponse __asm__("_OBJC_CLASS_$_NSURLResponse") = Nil;
__attribute__((visibility("default"), used))
Class DBExportedNSCachedURLResponse __asm__("_OBJC_CLASS_$_NSCachedURLResponse") = Nil;

__attribute__((visibility("default"), used))
Class DBExportedNSURLProtectionSpace __asm__("_OBJC_CLASS_$_NSURLProtectionSpace") = Nil;
__attribute__((visibility("default"), used))
Class DBExportedNSURLCredential __asm__("_OBJC_CLASS_$_NSURLCredential") = Nil;
__attribute__((visibility("default"), used))
Class DBExportedNSURLAuthenticationChallenge __asm__("_OBJC_CLASS_$_NSURLAuthenticationChallenge") = Nil;
__attribute__((visibility("default"), used))
Class DBExportedNSURLCache __asm__("_OBJC_CLASS_$_NSURLCache") = Nil;
__attribute__((visibility("default"), used))
Class DBExportedNSHTTPCookie __asm__("_OBJC_CLASS_$_NSHTTPCookie") = Nil;
__attribute__((visibility("default"), used))
Class DBExportedNSHTTPCookieStorage __asm__("_OBJC_CLASS_$_NSHTTPCookieStorage") = Nil;
__attribute__((visibility("default"), used))
Class DBExportedNSURLProtocol __asm__("_OBJC_CLASS_$_NSURLProtocol") = Nil;
__attribute__((visibility("default"), used))
Class DBExportedNSURLSession __asm__("_OBJC_CLASS_$_NSURLSession") = Nil;
__attribute__((visibility("default"), used))
Class DBExportedNSURLSessionConfiguration __asm__("_OBJC_CLASS_$_NSURLSessionConfiguration") = Nil;

__attribute__((visibility("default"), used))
Class DBExportedNSURLConnection __asm__("_OBJC_CLASS_$_NSURLConnection") = Nil;
__attribute__((visibility("default"), used))
Class DBExportedNSURLCredentialStorage __asm__("_OBJC_CLASS_$_NSURLCredentialStorage") = Nil;
__attribute__((visibility("default"), used))
Class DBExportedNSURLSessionTask __asm__("_OBJC_CLASS_$_NSURLSessionTask") = Nil;
__attribute__((visibility("default"), used))
Class DBExportedNSURLSessionDataTask __asm__("_OBJC_CLASS_$_NSURLSessionDataTask") = Nil;
__attribute__((visibility("default"), used))
Class DBExportedNSURLSessionDownloadTask __asm__("_OBJC_CLASS_$_NSURLSessionDownloadTask") = Nil;
__attribute__((visibility("default"), used))
Class DBExportedNSURLSessionUploadTask __asm__("_OBJC_CLASS_$_NSURLSessionUploadTask") = Nil;
__attribute__((visibility("default"), used))
Class DBExportedNSURLSessionStreamTask __asm__("_OBJC_CLASS_$_NSURLSessionStreamTask") = Nil;
__attribute__((visibility("default"), used))
Class DBExportedNSURLSessionWebSocketTask __asm__("_OBJC_CLASS_$_NSURLSessionWebSocketTask") = Nil;
__attribute__((visibility("default"), used))
Class DBExportedNSURLSessionTaskMetrics __asm__("_OBJC_CLASS_$_NSURLSessionTaskMetrics") = Nil;
__attribute__((visibility("default"), used))
Class DBExportedNSURLSessionTaskTransactionMetrics __asm__("_OBJC_CLASS_$_NSURLSessionTaskTransactionMetrics") = Nil;
__attribute__((visibility("default"), used))
Class DBExportedNSHost __asm__("_OBJC_CLASS_$_NSHost") = Nil;
__attribute__((visibility("default"), used))
Class DBExportedNSNetService __asm__("_OBJC_CLASS_$_NSNetService") = Nil;
__attribute__((visibility("default"), used))
Class DBExportedNSNetServiceBrowser __asm__("_OBJC_CLASS_$_NSNetServiceBrowser") = Nil;
__attribute__((visibility("default"), used))
Class DBExportedNSInputStream __asm__("_OBJC_CLASS_$_NSInputStream") = Nil;
__attribute__((visibility("default"), used))
Class DBExportedNSOutputStream __asm__("_OBJC_CLASS_$_NSOutputStream") = Nil;


// CFNetwork on macOS exposes a number of real data globals that older/native
// clients bind by dylib ordinal.  iOS may provide them from a different image
// or omit the legacy export entirely, so keep compatible exports in the
// DarwinBridge CFNetwork alias. Values match Apple's historical CFNetwork ABI.
__attribute__((visibility("default"), used))
const SInt32 DB_kCFStreamErrorDomainFTP __asm__("_kCFStreamErrorDomainFTP") = 6;
__attribute__((visibility("default"), used))
const SInt32 DB_kCFStreamErrorDomainHTTP __asm__("_kCFStreamErrorDomainHTTP") = 4;
__attribute__((visibility("default"), used))
const SInt32 DB_kCFStreamErrorDomainNetDB __asm__("_kCFStreamErrorDomainNetDB") = 12;
__attribute__((visibility("default"), used))
const SInt32 DB_kCFStreamErrorDomainSystemConfiguration __asm__("_kCFStreamErrorDomainSystemConfiguration") = 13;
__attribute__((visibility("default"), used))
const SInt32 DB_kCFStreamErrorDomainMach __asm__("_kCFStreamErrorDomainMach") = 11;
__attribute__((visibility("default"), used))
const SInt32 DB_kCFStreamErrorDomainNetServices __asm__("_kCFStreamErrorDomainNetServices") = 10;
__attribute__((visibility("default"), used))
const CFIndex DB_kCFStreamErrorDomainWinSock __asm__("_kCFStreamErrorDomainWinSock") = 7;
__attribute__((visibility("default"), used))
const int DB_kCFStreamErrorDomainSOCKS __asm__("_kCFStreamErrorDomainSOCKS") = 5;
__attribute__((visibility("default"), used))
const int DB_kCFStreamErrorDomainSSL __asm__("_kCFStreamErrorDomainSSL") = 3;

__attribute__((visibility("default"), used))
const CFStringRef DB_kCFErrorDomainCFNetwork __asm__("_kCFErrorDomainCFNetwork") = CFSTR("kCFErrorDomainCFNetwork");
__attribute__((visibility("default"), used))
const CFStringRef DB_kCFHTTPVersion1_0 __asm__("_kCFHTTPVersion1_0") = CFSTR("HTTP/1.0");
__attribute__((visibility("default"), used))
const CFStringRef DB_kCFHTTPVersion1_1 __asm__("_kCFHTTPVersion1_1") = CFSTR("HTTP/1.1");
__attribute__((visibility("default"), used))
const CFStringRef DB_kCFProxyHostNameKey __asm__("_kCFProxyHostNameKey") = CFSTR("kCFProxyHostNameKey");
__attribute__((visibility("default"), used))
const CFStringRef DB_kCFProxyPortNumberKey __asm__("_kCFProxyPortNumberKey") = CFSTR("kCFProxyPortNumberKey");
__attribute__((visibility("default"), used))
const CFStringRef DB_kCFStreamNetworkServiceType __asm__("_kCFStreamNetworkServiceType") = CFSTR("kCFStreamNetworkServiceType");
__attribute__((visibility("default"), used))
const CFStringRef DB_kCFStreamNetworkServiceTypeVoIP __asm__("_kCFStreamNetworkServiceTypeVoIP") = CFSTR("kCFStreamNetworkServiceTypeVoIP");
__attribute__((visibility("default"), used))
const CFStringRef DB_kCFStreamPropertyHTTPProxy __asm__("_kCFStreamPropertyHTTPProxy") = CFSTR("kCFStreamPropertyHTTPProxy");
__attribute__((visibility("default"), used))
const CFStringRef DB_kCFStreamPropertyHTTPResponseHeader __asm__("_kCFStreamPropertyHTTPResponseHeader") = CFSTR("kCFStreamPropertyHTTPResponseHeader");
__attribute__((visibility("default"), used))
const CFStringRef DB_kCFStreamPropertyHTTPShouldAutoredirect __asm__("_kCFStreamPropertyHTTPShouldAutoredirect") = CFSTR("kCFStreamPropertyHTTPShouldAutoredirect");
__attribute__((visibility("default"), used))
const CFStringRef DB_kCFStreamPropertySSLSettings __asm__("_kCFStreamPropertySSLSettings") = CFSTR("kCFStreamPropertySSLSettings");
__attribute__((visibility("default"), used))
const CFStringRef DB_kCFStreamSSLAllowsAnyRoot __asm__("_kCFStreamSSLAllowsAnyRoot") = CFSTR("kCFStreamSSLAllowsAnyRoot");
__attribute__((visibility("default"), used))
const CFStringRef DB_kCFStreamSSLAllowsExpiredCertificates __asm__("_kCFStreamSSLAllowsExpiredCertificates") = CFSTR("kCFStreamSSLAllowsExpiredCertificates");
__attribute__((visibility("default"), used))
const CFStringRef DB_kCFStreamSSLAllowsExpiredRoots __asm__("_kCFStreamSSLAllowsExpiredRoots") = CFSTR("kCFStreamSSLAllowsExpiredRoots");
__attribute__((visibility("default"), used))
const CFStringRef DB_kCFStreamSSLCertificates __asm__("_kCFStreamSSLCertificates") = CFSTR("kCFStreamSSLCertificates");
__attribute__((visibility("default"), used))
const CFStringRef DB_kCFStreamSSLIsServer __asm__("_kCFStreamSSLIsServer") = CFSTR("kCFStreamSSLIsServer");
__attribute__((visibility("default"), used))
const CFStringRef DB_kCFStreamSSLLevel __asm__("_kCFStreamSSLLevel") = CFSTR("kCFStreamSSLLevel");
__attribute__((visibility("default"), used))
const CFStringRef DB_kCFStreamSSLPeerName __asm__("_kCFStreamSSLPeerName") = CFSTR("kCFStreamSSLPeerName");
__attribute__((visibility("default"), used))
const CFStringRef DB_kCFStreamSSLValidatesCertificateChain __asm__("_kCFStreamSSLValidatesCertificateChain") = CFSTR("kCFStreamSSLValidatesCertificateChain");

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
    // Some macOS-linked clients bind NSHTTPURLResponse from CFNetwork while
    // iOS exposes the class through Foundation. Register a compatibility class
    // under the expected Objective-C runtime name only when it is absent.
    if (objc_getClass("NSHTTPURLResponse") == Nil) {
        Class source = DBNSHTTPURLResponseShim.class;
        Class dynamic = objc_allocateClassPair(class_getSuperclass(source), "NSHTTPURLResponse", 0);
        if (dynamic) {
            unsigned int methodCount = 0;
            Method *methods = class_copyMethodList(source, &methodCount);
            for (unsigned int i = 0; i < methodCount; i++) {
                class_addMethod(dynamic,
                                method_getName(methods[i]),
                                method_getImplementation(methods[i]),
                                method_getTypeEncoding(methods[i]));
            }
            free(methods);
            objc_registerClassPair(dynamic);
            DBLog(@"registered NSHTTPURLResponse compatibility class");
        }
    }
    Class httpResponseClass = objc_getClass("NSHTTPURLResponse");
    if (httpResponseClass == Nil) {
        httpResponseClass = DBNSHTTPURLResponseShim.class;
    }
    DBExportedNSHTTPURLResponse = httpResponseClass;
    DBExportedNSMutableURLRequest = objc_getClass("NSMutableURLRequest");
    DBExportedNSURLRequest = objc_getClass("NSURLRequest");
    DBExportedNSURLResponse = objc_getClass("NSURLResponse");
    DBExportedNSCachedURLResponse = objc_getClass("NSCachedURLResponse");
    DBExportedNSURLProtectionSpace = objc_getClass("NSURLProtectionSpace");
    DBExportedNSURLCredential = objc_getClass("NSURLCredential");
    DBExportedNSURLAuthenticationChallenge = objc_getClass("NSURLAuthenticationChallenge");
    DBExportedNSURLCache = objc_getClass("NSURLCache");
    DBExportedNSHTTPCookie = objc_getClass("NSHTTPCookie");
    DBExportedNSHTTPCookieStorage = objc_getClass("NSHTTPCookieStorage");
    DBExportedNSURLProtocol = objc_getClass("NSURLProtocol");
    DBExportedNSURLSession = objc_getClass("NSURLSession");
    DBExportedNSURLSessionConfiguration = objc_getClass("NSURLSessionConfiguration");
    DBExportedNSURLConnection = objc_getClass("NSURLConnection");
    DBExportedNSURLCredentialStorage = objc_getClass("NSURLCredentialStorage");
    DBExportedNSURLSessionTask = objc_getClass("NSURLSessionTask");
    DBExportedNSURLSessionDataTask = objc_getClass("NSURLSessionDataTask");
    DBExportedNSURLSessionDownloadTask = objc_getClass("NSURLSessionDownloadTask");
    DBExportedNSURLSessionUploadTask = objc_getClass("NSURLSessionUploadTask");
    DBExportedNSURLSessionStreamTask = objc_getClass("NSURLSessionStreamTask");
    DBExportedNSURLSessionWebSocketTask = objc_getClass("NSURLSessionWebSocketTask");
    DBExportedNSURLSessionTaskMetrics = objc_getClass("NSURLSessionTaskMetrics");
    DBExportedNSURLSessionTaskTransactionMetrics = objc_getClass("NSURLSessionTaskTransactionMetrics");
    DBExportedNSHost = objc_getClass("NSHost");
    DBExportedNSNetService = objc_getClass("NSNetService");
    DBExportedNSNetServiceBrowser = objc_getClass("NSNetServiceBrowser");
    DBExportedNSInputStream = objc_getClass("NSInputStream");
    DBExportedNSOutputStream = objc_getClass("NSOutputStream");
    DBLog([NSString stringWithFormat:@"exported NSHTTPURLResponse class symbol -> %@", NSStringFromClass(httpResponseClass)]);
    DBLog(@"exported CFNetwork/Foundation URL compatibility class symbols");

    NSApp = [NSApplication sharedApplication];
    DBLog(@"compatibility plugin loaded");
    DBLog([NSString stringWithFormat:@"UIKit=%@ MetalClassProbe=%@",
           NSStringFromClass(UIApplication.class),
           NSClassFromString(@"MTLDevice") ? @"yes" : @"no"]);
}
