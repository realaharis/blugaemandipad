#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CFNetwork/CFNetwork.h>
#import <Security/Security.h>
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

__attribute__((visibility("default"), used, weak))
__attribute__((visibility("default"), used, weak))
Class DBExportedNSAutoreleasePool __asm__("_OBJC_CLASS_$_NSAutoreleasePool") = Nil;
__attribute__((visibility("default"), used, weak))
Class DBExportedNSObject __asm__("_OBJC_CLASS_$_NSObject") = Nil;
__attribute__((visibility("default"), used, weak))
Class DBExportedNSException __asm__("_OBJC_CLASS_$_NSException") = Nil;
__attribute__((visibility("default"), used, weak))
Class DBExportedNSRunLoop __asm__("_OBJC_CLASS_$_NSRunLoop") = Nil;
__attribute__((visibility("default"), used, weak))
Class DBExportedNSThread __asm__("_OBJC_CLASS_$_NSThread") = Nil;
__attribute__((visibility("default"), used, weak))
Class DBExportedNSTimer __asm__("_OBJC_CLASS_$_NSTimer") = Nil;
__attribute__((visibility("default"), used, weak))
Class DBExportedNSDate __asm__("_OBJC_CLASS_$_NSDate") = Nil;
__attribute__((visibility("default"), used, weak))
Class DBExportedNSValue __asm__("_OBJC_CLASS_$_NSValue") = Nil;
__attribute__((visibility("default"), used, weak))
Class DBExportedNSNumber __asm__("_OBJC_CLASS_$_NSNumber") = Nil;
__attribute__((visibility("default"), used, weak))
Class DBExportedNSMutableArray __asm__("_OBJC_CLASS_$_NSMutableArray") = Nil;
__attribute__((visibility("default"), used, weak))
Class DBExportedNSMutableDictionary __asm__("_OBJC_CLASS_$_NSMutableDictionary") = Nil;
__attribute__((visibility("default"), used, weak))
Class DBExportedNSMutableData __asm__("_OBJC_CLASS_$_NSMutableData") = Nil;
__attribute__((visibility("default"), used, weak))
Class DBExportedNSMutableString __asm__("_OBJC_CLASS_$_NSMutableString") = Nil;
Class DBExportedNSUserDefaults __asm__("_OBJC_CLASS_$_NSUserDefaults") = Nil;
__attribute__((visibility("default"), used, weak))
Class DBExportedNSNotificationCenter __asm__("_OBJC_CLASS_$_NSNotificationCenter") = Nil;
__attribute__((visibility("default"), used, weak))
Class DBExportedNSProcessInfo __asm__("_OBJC_CLASS_$_NSProcessInfo") = Nil;
__attribute__((visibility("default"), used, weak))
Class DBExportedNSFileManager __asm__("_OBJC_CLASS_$_NSFileManager") = Nil;
__attribute__((visibility("default"), used, weak))
Class DBExportedNSBundle __asm__("_OBJC_CLASS_$_NSBundle") = Nil;
__attribute__((visibility("default"), used, weak))
Class DBExportedNSURL __asm__("_OBJC_CLASS_$_NSURL") = Nil;
__attribute__((visibility("default"), used, weak))
Class DBExportedNSData __asm__("_OBJC_CLASS_$_NSData") = Nil;
__attribute__((visibility("default"), used, weak))
Class DBExportedNSString __asm__("_OBJC_CLASS_$_NSString") = Nil;
__attribute__((visibility("default"), used, weak))
Class DBExportedNSArray __asm__("_OBJC_CLASS_$_NSArray") = Nil;
__attribute__((visibility("default"), used, weak))
Class DBExportedNSDictionary __asm__("_OBJC_CLASS_$_NSDictionary") = Nil;
__attribute__((visibility("default"), used, weak))
Class DBExportedNSError __asm__("_OBJC_CLASS_$_NSError") = Nil;

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


// Security.framework compatibility globals.  Keep the historical wire values
// used by SecItem dictionaries so macOS-linked clients can bind through the
// DBSecurity ordinal without depending on where modern iOS exports them.
#define DB_SECSTR(sym, value) \
    __attribute__((visibility("default"), used, weak)) \
    const CFStringRef sym = CFSTR(value)

DB_SECSTR(kSecClass, "class");
DB_SECSTR(kSecClassCertificate, "cert");
DB_SECSTR(kSecClassGenericPassword, "genp");
DB_SECSTR(kSecClassIdentity, "idnt");
DB_SECSTR(kSecClassInternetPassword, "inet");
DB_SECSTR(kSecClassKey, "keys");

DB_SECSTR(kSecAttrAccount, "acct");
DB_SECSTR(kSecAttrService, "svce");
DB_SECSTR(kSecAttrAccessGroup, "agrp");
DB_SECSTR(kSecAttrLabel, "labl");
DB_SECSTR(kSecAttrDescription, "desc");
DB_SECSTR(kSecAttrComment, "icmt");
DB_SECSTR(kSecAttrCreator, "crtr");
DB_SECSTR(kSecAttrType, "type");
DB_SECSTR(kSecAttrCreationDate, "cdat");
DB_SECSTR(kSecAttrModificationDate, "mdat");
DB_SECSTR(kSecAttrGeneric, "gena");
DB_SECSTR(kSecAttrSynchronizable, "sync");
DB_SECSTR(kSecAttrSynchronizableAny, "syna");

DB_SECSTR(kSecMatchLimit, "m_Limit");
DB_SECSTR(kSecMatchLimitAll, "m_LimitAll");
DB_SECSTR(kSecMatchLimitOne, "m_LimitOne");

DB_SECSTR(kSecReturnData, "r_Data");
DB_SECSTR(kSecReturnAttributes, "r_Attributes");
DB_SECSTR(kSecReturnPersistentRef, "r_PersistentRef");
DB_SECSTR(kSecReturnRef, "r_Ref");

DB_SECSTR(kSecValueData, "v_Data");
DB_SECSTR(kSecValueRef, "v_Ref");
DB_SECSTR(kSecValuePersistentRef, "v_PersistentRef");

DB_SECSTR(kSecAttrAccessControl, "accc");
DB_SECSTR(kSecAttrAccessGroupToken, "com.apple.token");
DB_SECSTR(kSecAttrAuthenticationType, "atyp");
DB_SECSTR(kSecAttrAuthenticationTypeDPA, "dpaa");
DB_SECSTR(kSecAttrAuthenticationTypeDefault, "dflt");
DB_SECSTR(kSecAttrAuthenticationTypeHTMLForm, "form");
DB_SECSTR(kSecAttrAuthenticationTypeHTTPBasic, "http");
DB_SECSTR(kSecAttrAuthenticationTypeHTTPDigest, "httd");
DB_SECSTR(kSecAttrAuthenticationTypeMSN, "msna");
DB_SECSTR(kSecAttrAuthenticationTypeNTLM, "ntlm");
DB_SECSTR(kSecAttrAuthenticationTypeRPA, "rpaa");
DB_SECSTR(kSecAttrCertificateEncoding, "cenc");
DB_SECSTR(kSecAttrCertificateType, "ctyp");
DB_SECSTR(kSecAttrIsExtractable, "extr");
DB_SECSTR(kSecAttrIsInvisible, "invi");
DB_SECSTR(kSecAttrIsNegative, "nega");
DB_SECSTR(kSecAttrIsSensitive, "sens");
DB_SECSTR(kSecAttrIssuer, "issr");
DB_SECSTR(kSecAttrKeyTypeEC, "73");
DB_SECSTR(kSecAttrKeyTypeECSECPrimeRandom, "73");
DB_SECSTR(kSecAttrPath, "path");
DB_SECSTR(kSecAttrPort, "port");
DB_SECSTR(kSecAttrProtocol, "ptcl");
DB_SECSTR(kSecAttrProtocolAFP, "afp ");
DB_SECSTR(kSecAttrProtocolAppleTalk, "atlk");
DB_SECSTR(kSecAttrProtocolDAAP, "daap");
DB_SECSTR(kSecAttrProtocolEPPC, "eppc");
DB_SECSTR(kSecAttrProtocolFTP, "ftp ");
DB_SECSTR(kSecAttrProtocolFTPAccount, "ftpa");
DB_SECSTR(kSecAttrProtocolFTPProxy, "ftpx");
DB_SECSTR(kSecAttrProtocolFTPS, "ftps");
DB_SECSTR(kSecAttrProtocolHTTP, "http");
DB_SECSTR(kSecAttrProtocolHTTPProxy, "htpx");
DB_SECSTR(kSecAttrProtocolHTTPS, "htps");
DB_SECSTR(kSecAttrProtocolHTTPSProxy, "htsx");
DB_SECSTR(kSecAttrProtocolIMAP, "imap");
DB_SECSTR(kSecAttrProtocolIMAPS, "imps");
DB_SECSTR(kSecAttrProtocolIPP, "ipp ");
DB_SECSTR(kSecAttrProtocolIRC, "irc ");
DB_SECSTR(kSecAttrProtocolIRCS, "ircs");
DB_SECSTR(kSecAttrProtocolLDAP, "ldap");
DB_SECSTR(kSecAttrProtocolLDAPS, "ldps");
DB_SECSTR(kSecAttrProtocolNNTP, "nntp");
DB_SECSTR(kSecAttrProtocolNNTPS, "ntps");
DB_SECSTR(kSecAttrProtocolPOP3, "pop3");
DB_SECSTR(kSecAttrProtocolPOP3S, "pops");
DB_SECSTR(kSecAttrProtocolRTSP, "rtsp");
DB_SECSTR(kSecAttrProtocolRTSPProxy, "rtsx");
DB_SECSTR(kSecAttrProtocolSMB, "smb ");
DB_SECSTR(kSecAttrProtocolSMTP, "smtp");
DB_SECSTR(kSecAttrProtocolSOCKS, "sox ");
DB_SECSTR(kSecAttrProtocolSSH, "ssh ");
DB_SECSTR(kSecAttrProtocolTelnet, "teln");
DB_SECSTR(kSecAttrProtocolTelnetS, "tels");
DB_SECSTR(kSecAttrPublicKeyHash, "pkhh");
DB_SECSTR(kSecAttrSecurityDomain, "sdmn");
DB_SECSTR(kSecAttrSerialNumber, "slnr");
DB_SECSTR(kSecAttrServer, "srvr");
DB_SECSTR(kSecAttrSubject, "subj");
DB_SECSTR(kSecAttrSubjectKeyID, "skid");
DB_SECSTR(kSecAttrSyncViewHint, "vwht");
DB_SECSTR(kSecAttrTokenID, "tkid");
DB_SECSTR(kSecAttrTokenIDSecureEnclave, "com.apple.setoken");

DB_SECSTR(kSecImportExportPassphrase, "passphrase");
DB_SECSTR(kSecImportItemCertChain, "chain");
DB_SECSTR(kSecImportItemIdentity, "identity");
DB_SECSTR(kSecImportItemKeyID, "keyid");
DB_SECSTR(kSecImportItemLabel, "label");
DB_SECSTR(kSecImportItemTrust, "trust");

DB_SECSTR(kSecMatchCaseInsensitive, "m_CaseInsensitive");
DB_SECSTR(kSecMatchEmailAddressIfPresent, "m_EmailAddressIfPresent");
DB_SECSTR(kSecMatchIssuers, "m_Issuers");
DB_SECSTR(kSecMatchItemList, "m_ItemList");
DB_SECSTR(kSecMatchPolicy, "m_Policy");
DB_SECSTR(kSecMatchSearchList, "m_SearchList");
DB_SECSTR(kSecMatchSubjectContains, "m_SubjectContains");
DB_SECSTR(kSecMatchTrustedOnly, "m_TrustedOnly");
DB_SECSTR(kSecMatchValidOnDate, "m_ValidOnDate");

DB_SECSTR(kSecUseAuthenticationContext, "u_AuthCtx");
DB_SECSTR(kSecUseAuthenticationUI, "u_AuthUI");
DB_SECSTR(kSecUseAuthenticationUIAllow, "u_AuthUIA");
DB_SECSTR(kSecUseAuthenticationUIFail, "u_AuthUIF");
DB_SECSTR(kSecUseAuthenticationUISkip, "u_AuthUIS");
DB_SECSTR(kSecUseItemList, "u_ItemList");

DB_SECSTR(kSecPolicyAppleCodeSigning, "1.2.840.113635.100.1.16");
DB_SECSTR(kSecPolicyAppleEAP, "1.2.840.113635.100.1.9");
DB_SECSTR(kSecPolicyAppleIDValidation, "1.2.840.113635.100.1.18");
DB_SECSTR(kSecPolicyAppleIPsec, "1.2.840.113635.100.1.11");
DB_SECSTR(kSecPolicyApplePKINITClient, "1.2.840.113635.100.1.14");
DB_SECSTR(kSecPolicyApplePKINITServer, "1.2.840.113635.100.1.15");
DB_SECSTR(kSecPolicyApplePassbookSigning, "1.2.840.113635.100.1.22");
DB_SECSTR(kSecPolicyApplePayIssuerEncryption, "1.2.840.113635.100.1.39");
DB_SECSTR(kSecPolicyAppleRevocation, "1.2.840.113635.100.1.21");
DB_SECSTR(kSecPolicyAppleSMIME, "1.2.840.113635.100.1.8");
DB_SECSTR(kSecPolicyAppleSSL, "1.2.840.113635.100.1.3");
DB_SECSTR(kSecPolicyAppleTimeStamping, "1.2.840.113635.100.1.20");
DB_SECSTR(kSecPolicyAppleX509Basic, "1.2.840.113635.100.1.2");
DB_SECSTR(kSecPolicyClient, "SecPolicyClient");
DB_SECSTR(kSecPolicyMacAppStoreReceipt, "1.2.840.113635.100.1.19");
DB_SECSTR(kSecPolicyName, "SecPolicyName");
DB_SECSTR(kSecPolicyOid, "SecPolicyOid");
DB_SECSTR(kSecPolicyRevocationFlags, "SecPolicyRevocationFlags");
DB_SECSTR(kSecPolicyTeamIdentifier, "SecPolicyTeamIdentifier");

DB_SECSTR(kSecPrivateKeyAttrs, "private");
DB_SECSTR(kSecPublicKeyAttrs, "public");
DB_SECSTR(kSecPropertyTypeError, "error");
DB_SECSTR(kSecPropertyTypeTitle, "title");
DB_SECSTR(kSecSharedPassword, "spwd");

DB_SECSTR(kSecTrustCertificateTransparency, "TrustCertificateTransparency");
DB_SECSTR(kSecTrustCertificateTransparencyWhiteList, "TrustCertificateTransparencyWhiteList");
DB_SECSTR(kSecTrustEvaluationDate, "TrustEvaluationDate");
DB_SECSTR(kSecTrustInfoExtendedValidationKey, "ExtendedValidation");
DB_SECSTR(kSecTrustExtendedValidation, "TrustExtendedValidation");
DB_SECSTR(kSecTrustOrganizationName, "Organization");
DB_SECSTR(kSecTrustResultValue, "TrustResultValue");
DB_SECSTR(kSecTrustRevocationChecked, "TrustRevocationChecked");
DB_SECSTR(kSecTrustRevocationValidUntilDate, "TrustExpirationDate");

#undef DB_SECSTR


// Foundation data constants frequently bind to the Foundation dylib ordinal.
// Export the common URL/error/defaults/stream globals through DBFoundation.
#define DB_FNDSTR(sym, value) \
    __attribute__((visibility("default"), used, weak)) \
    NSString * const sym = @value

DB_FNDSTR(NSURLErrorDomain, "NSURLErrorDomain");
DB_FNDSTR(NSURLErrorKey, "NSURL");
DB_FNDSTR(NSPOSIXErrorDomain, "NSPOSIXErrorDomain");
DB_FNDSTR(NSOSStatusErrorDomain, "NSOSStatusErrorDomain");
DB_FNDSTR(NSMachErrorDomain, "NSMachErrorDomain");
DB_FNDSTR(NSCocoaErrorDomain, "NSCocoaErrorDomain");
DB_FNDSTR(NSUnderlyingErrorKey, "NSUnderlyingError");
DB_FNDSTR(NSLocalizedDescriptionKey, "NSLocalizedDescription");
DB_FNDSTR(NSLocalizedFailureReasonErrorKey, "NSLocalizedFailureReason");
DB_FNDSTR(NSLocalizedRecoverySuggestionErrorKey, "NSLocalizedRecoverySuggestion");
DB_FNDSTR(NSLocalizedRecoveryOptionsErrorKey, "NSLocalizedRecoveryOptions");
DB_FNDSTR(NSRecoveryAttempterErrorKey, "NSRecoveryAttempter");
DB_FNDSTR(NSHelpAnchorErrorKey, "NSHelpAnchor");
DB_FNDSTR(NSStringEncodingErrorKey, "NSStringEncodingErrorKey");
DB_FNDSTR(NSFilePathErrorKey, "NSFilePathErrorKey");
DB_FNDSTR(NSErrorFailingURLStringKey, "NSErrorFailingURLStringKey");
DB_FNDSTR(NSURLErrorFailingURLPeerTrustErrorKey, "NSURLErrorFailingURLPeerTrustErrorKey");
DB_FNDSTR(NSURLErrorBackgroundTaskCancelledReasonKey, "NSURLErrorBackgroundTaskCancelledReasonKey");

DB_FNDSTR(NSGlobalDomain, "NSGlobalDomain");
DB_FNDSTR(NSArgumentDomain, "NSArgumentDomain");
DB_FNDSTR(NSRegistrationDomain, "NSRegistrationDomain");
DB_FNDSTR(NSUserDefaultsDidChangeNotification, "NSUserDefaultsDidChangeNotification");
DB_FNDSTR(NSUserDefaultsSizeLimitExceededNotification, "NSUserDefaultsSizeLimitExceededNotification");

DB_FNDSTR(NSFileType, "NSFileType");
DB_FNDSTR(NSFileSize, "NSFileSize");
DB_FNDSTR(NSFileModificationDate, "NSFileModificationDate");
DB_FNDSTR(NSURLFileScheme, "file");

DB_FNDSTR(NSStreamSocketSecurityLevelKey, "NSStreamSocketSecurityLevelKey");
DB_FNDSTR(NSStreamSocketSecurityLevelNone, "NSStreamSocketSecurityLevelNone");
DB_FNDSTR(NSStreamSocketSecurityLevelSSLv2, "NSStreamSocketSecurityLevelSSLv2");
DB_FNDSTR(NSStreamSocketSecurityLevelSSLv3, "NSStreamSocketSecurityLevelSSLv3");
DB_FNDSTR(NSStreamSocketSecurityLevelTLSv1, "NSStreamSocketSecurityLevelTLSv1");
DB_FNDSTR(NSStreamSocketSecurityLevelNegotiatedSSL, "NSStreamSocketSecurityLevelNegotiatedSSL");
DB_FNDSTR(NSStreamSOCKSProxyConfigurationKey, "NSStreamSOCKSProxyConfigurationKey");
DB_FNDSTR(NSStreamSOCKSProxyHostKey, "NSStreamSOCKSProxyHostKey");
DB_FNDSTR(NSStreamSOCKSProxyPortKey, "NSStreamSOCKSProxyPortKey");
DB_FNDSTR(NSStreamSOCKSProxyVersionKey, "NSStreamSOCKSProxyVersionKey");
DB_FNDSTR(NSStreamSOCKSProxyUserKey, "NSStreamSOCKSProxyUserKey");
DB_FNDSTR(NSStreamSOCKSProxyPasswordKey, "NSStreamSOCKSProxyPasswordKey");
DB_FNDSTR(NSStreamSOCKSProxyVersion4, "NSStreamSOCKSProxyVersion4");
DB_FNDSTR(NSStreamSOCKSProxyVersion5, "NSStreamSOCKSProxyVersion5");
DB_FNDSTR(NSStreamSocketSSLErrorDomain, "NSStreamSocketSSLErrorDomain");
DB_FNDSTR(NSStreamSOCKSErrorDomain, "NSStreamSOCKSErrorDomain");
DB_FNDSTR(NSStreamNetworkServiceType, "NSStreamNetworkServiceType");
DB_FNDSTR(NSStreamNetworkServiceTypeVoIP, "NSStreamNetworkServiceTypeVoIP");
DB_FNDSTR(NSStreamNetworkServiceTypeVideo, "NSStreamNetworkServiceTypeVideo");
DB_FNDSTR(NSStreamNetworkServiceTypeBackground, "NSStreamNetworkServiceTypeBackground");
DB_FNDSTR(NSStreamNetworkServiceTypeVoice, "NSStreamNetworkServiceTypeVoice");
DB_FNDSTR(NSStreamNetworkServiceTypeCallSignaling, "NSStreamNetworkServiceTypeCallSignaling");

#undef DB_FNDSTR


// macOS Foundation exports the NSGeometry zero constants as data symbols.
// iOS uses the CoreGraphics geometry ABI, which is layout-compatible on arm64.
__attribute__((visibility("default"), used, weak))
const CGPoint NSZeroPoint = {0.0, 0.0};
__attribute__((visibility("default"), used, weak))
const CGSize NSZeroSize = {0.0, 0.0};
__attribute__((visibility("default"), used, weak))
const CGRect NSZeroRect = {{0.0, 0.0}, {0.0, 0.0}};

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
    DBExportedNSAutoreleasePool = objc_getClass("NSAutoreleasePool");
    DBExportedNSObject = objc_getClass("NSObject");
    DBExportedNSException = objc_getClass("NSException");
    DBExportedNSRunLoop = objc_getClass("NSRunLoop");
    DBExportedNSThread = objc_getClass("NSThread");
    DBExportedNSTimer = objc_getClass("NSTimer");
    DBExportedNSDate = objc_getClass("NSDate");
    DBExportedNSValue = objc_getClass("NSValue");
    DBExportedNSNumber = objc_getClass("NSNumber");
    DBExportedNSMutableArray = objc_getClass("NSMutableArray");
    DBExportedNSMutableDictionary = objc_getClass("NSMutableDictionary");
    DBExportedNSMutableData = objc_getClass("NSMutableData");
    DBExportedNSMutableString = objc_getClass("NSMutableString");
    DBExportedNSUserDefaults = objc_getClass("NSUserDefaults");
    DBExportedNSNotificationCenter = objc_getClass("NSNotificationCenter");
    DBExportedNSProcessInfo = objc_getClass("NSProcessInfo");
    DBExportedNSFileManager = objc_getClass("NSFileManager");
    DBExportedNSBundle = objc_getClass("NSBundle");
    DBExportedNSURL = objc_getClass("NSURL");
    DBExportedNSData = objc_getClass("NSData");
    DBExportedNSString = objc_getClass("NSString");
    DBExportedNSArray = objc_getClass("NSArray");
    DBExportedNSDictionary = objc_getClass("NSDictionary");
    DBExportedNSError = objc_getClass("NSError");
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
