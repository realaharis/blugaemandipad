# Stage 21G loader audit

The pre-initializer blocker is invalid **native runtime identity**, not a missing
shim symbol. The plugin downloaded from CI artifact **11436883293**, run
**37516140814**, commit `4b192bfe604e05203b40dc04d51798954f7cd660`, contains 78
invalid class/metaclass/constant-string identity exports.

`baseline-evidence.json` records independently parsed final bytes:

- `DBCompatObject.superclass` rebases to `0x11e20`, the zero-filled
  `_OBJC_CLASS_$_NSObject` variable, not an Objective-C class object.
- The first `__cfstring` object's isa rebases to `0x11fe8`, the zero-filled
  `___CFConstantStringClassReference` array.
- The plugin **does** have an initializer: `__TEXT,__init_offsets` -> `0x62f4`.
  Checking only `__mod_init_func` would incorrectly miss it.
- That downloaded plugin has valid ad-hoc code-page hashes. Simulating the old
  packager's install-name rename invalidates code page zero. This is a simulation
  of the alias mutation, not inspection of the user's installed guest IPA.
- The old linker emitted ordinary dependencies, **no LC_REEXPORT_DYLIB**. Comments
  in the packager claiming that native frameworks were re-exported were false.

An exported `Class` variable supplies the address of a pointer-sized cell. Dyld's
ObjC class bind expects the class object itself at that address. Assigning the
cell in a later constructor cannot fix this extra indirection or a superclass
that libobjc reads before that constructor. Similarly, zero-filled arrays cannot
replace the native constant-string class.

The macOS runtime regression compiles and actually dlopens a minimal reproduction
of that bad superclass. CI run 37519931058 observed **SIGSEGV (-11), no constructor
marker**. The version using a native Foundation re-export loaded successfully and
printed `CONSTRUCTOR_REACHED`. This demonstrates the failure mechanism on Apple's
runtime; it does not identify a device PC without a trace.

## Correction

- Remove fabricated native class/metaclass cells and constant-string anchors.
- Use linker `LC_REEXPORT_DYLIB` for native frameworks. Remove shadowed native CF
  singleton variables, preserving native object identity.
- Build small, separately identified **forwarding dylibs** for each original
  library ordinal. They re-export one implementation, without duplicating classes.
- Build `DBBootstrap.dylib` as C + libSystem only. Log to stderr and the guest's
  HOME/Documents using POSIX calls, without Foundation string objects.
- Copy all pre-signed dylibs byte for byte. Remove the stale Riot signature
  command from the changed executable; retain all section/file offsets. Destination
  signing must happen after LiveContainer's own modifications.
- Keep bootstrap injection bounded by section, segment, symbol and linkedit
  regions. Refuse insufficient/occupied padding rather than shifting payload.
- Declare ABI 1 for redirected DarwinBridge library commands and dylib IDs.
- Fix debugger signal continuation: `vCont;Cxx:thread;c`, not single-step `Sxx`.
  Only recognized protocol BRKs advance PC; unknown/fatal traps are preserved.

The host `MachOLoader`, `SymbolBroker`, dry-run, readiness and event-log stages
are analysis/planning for this IPA route. They do not execute inside the guest
loaded by LiveContainer. Resolving a host address does not validate an exported
plugin ABI or prove a guest instruction. Readiness text now says this explicitly,
and the planned entry offset is labeled `expected-lc-main` rather than a runtime event.

## Real execution chain (pinned upstream; installed version unknown)

Audited LiveContainer commit `4dbe0f9a626de801184a42c0be8d2cb105058e3d`:

1. `CFBundleExecutable` selects the guest file. `LCAppInfo.m` patches it during
   install/update, converts MH_EXECUTE to MH_DYLIB, modifies PAGEZERO/flags, adds an
   ID and TweakLoader, and retains LC_MAIN. It may disable duplicated dylib commands;
   distinct forwarding paths avoid that ordinal hazard.
2. With a certificate and signing enabled it invokes ZSign after mutation. The
   `dontSign`, no-certificate and 32-bit branches skip signing. On iOS 26+ the
   bootstrap explicitly requires JIT-less certificate setup. JIT is not proof of
   a valid guest signature. CI validates ad-hoc integrity, not device trust.
3. `LCBootstrap.m` changes bundle/executable path and guest HOME, invokes
   `dlopen_nolock(... RTLD_LAZY|RTLD_GLOBAL|RTLD_FIRST)`, then looks up LC_MAIN and
   calls it. Constructors complete as part of dlopen; LC_MAIN has not run if image
   loading/ObjC registration fails.
4. That path expects the guest to start UIApplicationMain. A desktop NSRunLoop
   does not establish an iOS UIApplication lifecycle, and a queued overlay cannot
   prove startup when no UIWindowScene exists. The existing NSApplication shim is
   still incomplete; Stage 21G makes no playable-game/UI claim.

CI compiles the exact pinned upstream `LCPatchExecSlice` plus its helpers and runs
it on the final fixture binary, then checks ordinals, sections, LC_MAIN and re-signs.
This establishes behavior for the pinned source only, not the installed build.

## iOS runtime execution test

`run_ios_probe.py` builds the full compatibility source for the available iOS
simulator, installs a native UIKit probe and loads the forwarding dylibs. The test
requires native NSObject/NSString pointer identity through three distinct aliases,
one shared implementation address, both bootstrap and plugin constructor log
markers, and successful UIApplicationMain startup. Its logs and simulator/runtime
identity are uploaded with the audit. Run 37521172666 reached both constructors,
the file logger, heartbeat and UIKit main on arm64 iOS 26.2. Its log also exposed
three pre-existing runtime-name collisions (NSColor, NSFont, NSTask). These existing
shims now use distinct DBShim runtime names, with Mach-O aliases pointing directly
to their real class/metaclass objects. The integration test checks those identities
and rejects duplicate-class warnings. Dynamic NSClassFromString lookup of the
original names still resolves to iOS classes; full AppKit behavior is not claimed.
This is simulator execution, not iPad proof.

## Final artifact validation and limits

The same Swift packager used by the app is invoked on a real compiled ARM64 macOS
fixture with AppKit/Foundation/CFNetwork dependencies. Its resulting IPA is
extracted and inspected, all included Mach-Os are checked with file/otool/nm/vtool,
then signed and checked with `codesign --verify --strict` and independent code-page
hash verification. Section metadata/content and bind/fixup blobs are compared to
the original. The bootstrap path must resolve, its initializer must point into
executable text, forwarders cannot define ObjC classes, and the native class
identities must remain undefined imports. The fixture is **not the Riot client**.

The pinned official Riot game binary is separately downloaded and inspected. The
minimal executable-only package omits RiotGamesApi/RPatch/mvg and full resources;
LDAP/OpenGL/ApplicationServices also require a real port. That full game is not an
approved candidate. The minimal packager now refuses unresolved relative payload
dependencies or unconverted desktop framework paths instead of emitting a broken IPA. The previous 514-import file cannot be assumed identical to
this release. A manifest's combined fat-architecture import count is not evidence
that every ARM64 import is covered.

The installed `DarwinBridge-LoL-first-run.ipa`, installed LiveContainer build and
device trace have not been supplied. No exact last device instruction is claimed.
A lack of log alone cannot distinguish mapping, binding, ObjC registration,
initializer entry, or failure inside the logger.

## Single next device experiment

Apply `DarwinBridge/JIT/darwinbridge-universal.js` to the **currently installed**
black-screen LoL guest, replacing the old script. Keep the IPA unchanged for this
experiment. Enable its normal JIT launch. Export the debugger log containing
`[DB21G ...]` after termination (or the last output if it remains running).

The script logs the initial attach, timestamps, stop packets, PC/x0/x1/x16/LR,
nearby instruction bytes, thread list, dyld state, loaded-image paths/UUIDs and exit.
Where debugserver supports hardware breakpoints it observes the dyld image
notification and arms one-shot initializer/LC_MAIN breakpoints. Unsupported packet
or breakpoint responses are logged as unavailable, not treated as proof of a
boundary. This path does not depend on the faulty guest plugin or its constructors.
A synchronous continue cannot sample a running hang on a timer; the last logged
boundary remains the last proven boundary, not a diagnosis of all later execution.

The corrected DarwinBridge packager is built by the same CI run, but installing it
is not necessary for the first experiment. Do not call the fixture or the packager
IPA a verified full League of Legends port.
