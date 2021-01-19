---
title: "Running Racket CS on iOS"
date: 2021-01-19T10:25:00+02:00
slug: "racket-cs-on-ios"
tags: ["racket", "ios"]
---

A couple of weeks ago, I started working on getting Racket CS to
compile and run on iOS and, with a lot of guidance from Matthew Flatt,
I managed to get it working (with some [caveats]).  [Those
changes][pr] have now been merged, so I figured I'd write another one
of these guides while the information is still fresh in my head.


## Compile Racket for macOS and for iOS

You need a recent version of Racket and it's associated fork of Chez
Scheme built for your host machine in order to cross-compile things.
To build both of them, clone the [Racket repository] and follow the
[build instructions].  If you use the default `make` target, then
you'll end up with a host Racket installation overlayed on top of the
`racket/` directory in the repository and with a build of Chez Scheme
at `racket/src/build/cs/c/`.

Next, you can cross-compile Racket CS for iOS by making a new build
directory within `racket/src/` and configuring a cross build by
specifying a custom prefix (so that the `make install` step won't
overwrite the host Racket installation), the target `host`
architecture, a path to the iOS SDK (or the shorthand name "iPhoneOS")
and the paths to the host Racket and Chez Scheme.

```bash
mkdir racket/src/build-ios \
  && cd racket/src/build-ios \
  && ../configure \
    --prefix="$(pwd)/../../../racket-ios" \
    --enable-macprefix \
    --host=aarch64-apple-darwin \
    --enable-ios=iPhoneOS \
    --enable-racket="$(pwd)/../../bin/racket" \
    --enable-scheme="$(pwd)/../build/cs/c" \
  && make \
  && make install
```

After running the above series of commands, you should end up with a
cross-compiled Racket installation at `racket-ios/` inside the source
repository.


## Cross-compile Racket modules for iOS

I added a section on [how to cross-compile Racket
modules][cross-section] to the "Inside Racket" docs so refer to that.
In short, if you save the following module under `app.rkt` somewhere

```racket
#lang racket/base

(provide echo)

(define (echo m)
  (displayln m))
```

then you can run

```bash
/path/to/racket/bin/racket \
  --compile-any \
  --compiled 'compiled_host:tarm64osx' \
  --cross \
  --cross-compiler tarm64osx /path/to/racket/racket-ios/lib \
  --config /path/to/racket/racket-ios/etc \
  --collects /path/to/racket/racket-ios/collects \
  -l- \
  raco ctool --mods app.zo app.rkt
```

to produce `app.zo`, a binary object containing the cross-compiled
code for that module and all of its dependencies.


## Set up your XCode project

To link against and use Racket CS within an XCode project, copy
`racketcs.h`, `racketcsboot.h` and `chezscheme.h` from
`racket-ios/include/` into a sub-directory of your project, then add
that sub-directory to the "Header Search Paths" section under your
project's "Build Settings" tab.

![Headers](/img/racket-cs-on-ios-headers.png)

Then, disable Bitcode from the same section.

![Bitcode](/img/racket-cs-on-ios-bitcode.png)

Next, copy `libracketcs.a`, `petite.boot`, `scheme.boot` and
`racket.boot` from `racket-ios/lib` into a sub-directory of your
project called `vendor/` and drag-and-drop the `vendor/` directory
into your XCode project.  Then, instruct XCode to link `libracketcs.a`
and `libiconv.tbd` with your code from the "Build Phases" tab.  You'll
have to add `libracketcs.a` to your project using the "Add Other..."
sub-menu.

![Link](/img/racket-cs-on-ios-link.png)

Next, add a new C source file called `vendor.c` and answer "yes" if
prompted to create a bridging header for Swift.  I tend to re-name the
bridging header to plain `bridge.h` because I don't like the name that
XCode generates by default.  If you do this, you'll have to update the
"Objective-C Bridging Header" setting in your "Build Settings" tab.
From `bridge.h`, include `vendor.h` and inside `vendor.h` add
definitions for `racket_init` and `echo`

```c
#ifndef vendor_h
#define vendor_h

#include <stdlib.h>

int racket_init(const char *, const char *, const char *, const char *);
void echo(char *);

#endif
```

then, inside of `vendor.c`, implement them

```c
#include <string.h>

#include "chezscheme.h"
#include "racketcs.h"

#include "vendor.h"

int racket_init(const char *petite_path,
                const char *scheme_path,
                const char *racket_path,
                const char *app_path) {
    racket_boot_arguments_t ba;
    memset(&ba, 0, sizeof(ba));
    ba.boot1_path = petite_path;
    ba.boot2_path = scheme_path;
    ba.boot3_path = racket_path;
    ba.exec_file = "example";
    racket_boot(&ba);
    racket_embedded_load_file(app_path, 1);
    ptr mod = Scons(Sstring_to_symbol("quote"), Scons(Sstring_to_symbol("main"), Snil));
    racket_dynamic_require(mod, Sfalse);
    Sdeactivate_thread();
    return 0;
}

void echo(char *message) {
    Sactivate_thread();
    ptr mod = Scons(Sstring_to_symbol("quote"), Scons(Sstring_to_symbol("main"), Snil));
    ptr echo_fn = Scar(racket_dynamic_require(mod, Sstring_to_symbol("echo")));
    racket_apply(fn, Scons(Sstring(message), Snil));
    Sdeactivate_thread();
}
```

Take a look at the [Inside Racket CS] documentation for details on the
embedding interface of Racket CS.  The gist of `racket_init` is that
it takes the paths to `petite.boot`, `scheme.boot`, `racket.boot` and
`app.zo` as arguments in order to initialize Racket and then load the
`app.zo` module, which you can do from the `AppDelegate`'s
`application(_:didFinishLaunchingWithOptions:)` method:

```swift
let vendorPath = Bundle.main.resourcePath!.appending("/vendor")
let ok = racket_init(
    vendorPath.appending("/petite.boot"),
    vendorPath.appending("/scheme.boot"),
    vendorPath.appending("/racket.boot"),
    vendorPath.appending("/app.zo"))
if ok != 0 {
    print("failed to initialize racket")
    exit(1)
}
```

Upon successful initialization, you should be able to call the Racket `echo`
function from Swift:

```swift
echo("Hello from Racket!")
```

Compile and run the project on a device and you should see "Hello from
Racket!" get printed in your debug console.

### Some XCode gotchas

If you copy `vendor/` into your project instead of creating "folder
references" when you drag-and-drop it, then code signing may fail with
an ambiguous error.

Avoid using symbolic links for any of your resources (like the stuff
in `vendor/`).  Doing so makes copying the code over to the device
fail with a "security" error that doesn't mention the root problem at
all.

[caveats]: https://github.com/racket/racket/blob/351c0047d6371e36cf422b4627e020d14e8853fe/racket/src/ChezScheme/c/segment.c#L578-L587
[pr]: https://github.com/racket/racket/pull/3607
[Racket repository]: https://github.com/racket/racket
[build instructions]: https://github.com/racket/racket/blob/08fa24304ebf80a21ade32e8e59bb51b27af1dae/build.md#1-building-racket-from-source
[cross-section]: https://www.cs.utah.edu/plt/snapshots/current/doc/inside/ios-cross-compilation.html?q=inside
[Inside Racket CS]: https://www.cs.utah.edu/plt/snapshots/current/doc/inside/cs.html?q=inside
