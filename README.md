<img src="assets/logo.png" alt="FinderSearch logo" width="80" height="80">

# FinderSearch

This personal fork adds **Enter → Open Selected**, **F2 → Rename**, and
**Copy Path → Shift-Command-C**, with 25 customizable shortcuts in
**FinderSearch → Settings** and a brief confirmation after copying a path. It
opens application bundles instead of browsing their contents. It is based on
[zeusinsight/FinderSearch](https://github.com/zeusinsight/FinderSearch).
Build and launch this fork with `./script/build_and_run.sh`.
Choose a startup folder or restore your last session in **Settings → General**.
Settings opens inside the browser as a modal with General, Appearance, Search,
and Keyboard shortcuts pages. It uses larger system text and keeps the browser
inactive while open. Shortcut changes update the menu bindings; duplicate keys
are rejected before saving.
Set default views and sorting, remember per-folder choices, and configure search scope
and exclusion patterns. Press **Command-L** to edit the folder address.

A native Mac file browser with fast, fuzzy filename search. Browse folders,
preview files, and manage your files in a familiar macOS interface.

**[Download for Apple Silicon](https://github.com/gityeop/FinderSearch/releases/latest)**
· macOS 15+
· [Usage & shortcuts](docs/USAGE.md)
· [Release notes](https://github.com/gityeop/FinderSearch/releases)

![FinderSearch demo with the sidebar visible: type a filename and see search results narrow](docs/images/findersearch-demo.gif)

[Still preview](docs/images/findersearch-icons.jpeg)

## Features

- **Find files quickly.** Fuzzy matching, relevance ranking, folder scope, and
  filters like `ext:pdf` and `mtime:<7d`.
- **Browse your way.** Icon, list, column, and gallery views, Quick Look previews,
  and tabs that restore when you reopen the app.
- **Get file work done.** Drag selection, copy and move, batch rename, ZIP tools,
  tags, sharing, Trash, and undo.
- **Stay in control.** Transfer progress, cancellation, and clear choices when
  files conflict.

Built with SwiftUI and AppKit, powered by
[fsearch](https://github.com/noahdunnagan/fsearch). Search runs locally;
your files aren't uploaded.

## Install

1. Download the DMG and drag **FinderSearch** into **Applications**.
   When updating, quit the old app first and replace it.
2. Eject the disk image and open FinderSearch.
3. Enable **Full Disk Access** in **System Settings → Privacy & Security** to
   search protected folders, then quit and reopen the app.

Published DMG and ZIP releases are Developer ID-signed and notarized by Apple.
Allow the first search index to finish building.

[Permissions and troubleshooting →](docs/USAGE.md#permissions-and-indexing)

## Performance

In three warm, exact-filename benchmarks over 10,000 generated files, fsearch
returned results in **0.49–1.14 ms**, versus **7.06–7.30 ms** for Spotlight
(median times on an Apple M4).

These measure the search backend, including its IPC round trip, rather than
rendered UI latency. FinderSearch waits 50 ms after typing stops; Return submits
a pending search immediately.

[Benchmark method, results, and reproduction →](docs/benchmarks/README.md)

## Build from source

Requires **macOS 15+**, **Xcode 16+ or compatible Command Line Tools**, and
**Rust 1.85+ / Cargo**.

```sh
git clone https://github.com/gityeop/FinderSearch.git
cd FinderSearch
./scripts/build.sh
open dist/FinderSearch.app
```

The build bundles fsearch automatically. Run tests with `swift test -c release`.
See [CONTRIBUTING.md](CONTRIBUTING.md) for development checks and the code layout.
Apple Silicon is verified; Intel builds remain unverified.

## Build a release

Set `APPLE_SIGN_IDENTITY` to your Developer ID Application identity and
`APPLE_NOTARY_PROFILE` to your notarytool keychain profile, then run
`./scripts/release.sh`. It signs the app and helper with Hardened Runtime,
notarizes and staples the app and DMG, and writes DMG, ZIP, and SHA-256 checksums
to `dist/`. The ordinary build script uses ad-hoc signing for local development.

## Current limits

FinderSearch is still early. Content search, AirDrop, Finder extensions, saved
smart folders, folder merging, and persistent undo history aren't supported yet.
Slow disks and cloud providers can still take time.

## License & credits

[MIT](LICENSE). The search engine is [fsearch](https://github.com/noahdunnagan/fsearch)
by [Noah Dunnagan](https://github.com/noahdunnagan), vendored at v0.2.0 with a
documented Rust build fix
under its MIT license. FinderSearch adds the native interface and file workflows.
See [third-party notices](THIRD_PARTY_NOTICES.md).
