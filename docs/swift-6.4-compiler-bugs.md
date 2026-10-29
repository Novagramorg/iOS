# Swift 6.4 compiler bugs

> Moved verbatim from the root `CLAUDE.md` on 2026-10-29, which had passed the 150k-character limit. The root file keeps a short summary under the same heading. "Above", "below" and section names refer to the root `CLAUDE.md` unless the section is in this file.

## Swift 6.4: `[weak]` in a local closure that also captures a `var`

Swift 6.4 (Xcode 27) miscompiles this shape, at `-Onone` as well as `-O`: a closure literal stored in
a local `let`, with a `[weak x]`/`[unowned x]` capture list, that **also captures a mutable local** and
never escapes (only called directly). `MandatoryAllocBoxToStack` moves the capture box to the stack and
destroys it right after the closure is formed, before the closure is ever called. For an NSObject-derived
`x` the load then reads a dead slot (on device it had been reused as a `swift_beginAccess` record and
crashed in `objc_msgSend`; macOS 27 traps "not in the weak references table"); for a native Swift class
it silently returns nil, so `guard let x else { return }` skips the work. Closures passed straight to a
non-escaping parameter, or a declared `weak var w = x` captured instead, are compiled correctly.

Write such a closure with a strong capture (`{ [self] i in`), which cannot cycle because it never
escapes. It has bitten twice: `processPollOptionItem` (ComposePollScreen, 2026-09-25) and the
identical `processTodoItemItem` (ComposeTodoScreen, 2026-10-02, App Store crash on 12.10/35210).
In a binary the fingerprint is a weak/unowned `…Init` whose stack slot gets `…Destroy`ed before the
first call to a closure specialized as `Arg[n] = Stack Promoted from Box`; a scan of every binary in
the 2026-10-02 debug build found no other site.

## Swift 6.4: SimplifyCFG crash in release builds only

`BorrowUtils.swift:551: Fatal error: cannot get borrow introducers for unknown guaranteed value`,
in pass `SimplifyCFG` (jump threading), crashes `swift-frontend` at `-Osize` while debug builds of the
same source compile, so it first shows up on CI. Seen 2026-10-15 in `QrStudioCodePaths.init`: a
nested function called from loops, with the cross-module-inlined `QrCodeMatrix.isEye(x:y:)` (an
`&&`/`||` chain reading `self.size` of the borrowed matrix, a struct holding an array). Calling a
static `QrCodeMatrix.isEye(x:y:size:)` with a local `size` avoids it; removing any other construct of
the function on its own did not.

To reproduce, replay the frontend command from the CI log in the bazel execroot. A single file only
reproduces with a caller added, because WMO deletes an internal function nothing calls before
optimizing it. Give the replay its own `-module-cache-path`: the default relative
`bazel-out/…/_swift_module_cache`, run from the workspace instead of the execroot, writes pcms into
bazel's shared cache under a second path (the `bazel-out` symlink), and the next build fails with
"module '_DarwinFoundation1' is defined in both". Delete the hash directory it wrote to recover.
Also, `Make.py build --target` on a bare `swift_library` builds it for the host (`no such module
'UIKit'`); a library gets its iOS configuration only through the app's transition.
