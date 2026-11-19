# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

AlgoLogger is a set of iOS (13+) Swift logging libraries built on **XCGLogger**, with tag-based routing. The remote is `Algorigo/AlgoLogger_iOS`. This is the v2 line: work happens on `v2/develop`, and releases go through `v2/release/X.Y.Z` into `v2/master`. The plain `develop`/`master` branches on origin are the old v1 line.

| Module (dir) | Contents | SPM | CocoaPods |
|---|---|---|---|
| `AlgoLoggerCommon` | `Tag`, `LogDelegate`, `_Key` (userInfo keys). No dependencies | yes | `AlgoLoggerCommon.podspec` |
| `AlgoLogger` | `L` facade, `LogManager`, `OsLoggingDestination`, `RotatingFileDestination`, formatters. RxSwift | yes | `AlgoLogger.podspec` |
| `AlgoLoggerAWS` | `CloudWatchDestination`, S3 upload of rotated files. aws-sdk-swift, SQLite.swift | yes | **no**. Its podspec was removed in 2.2.0, so it is SPM only |
| `AlgoLoggerDatadog` | `DataDogLogDelegate`, `DataDogDestination`. dd-sdk-ios 3.x | yes | `AlgoLoggerDatadog.podspec` |

`README.md` (Korean) still shows `AlgoLoggerAWS` pod and lint/push commands. Those are stale.

## Commands

There is no package test target. The two sample apps are the only way to exercise the code. `AlgoLogger.xcworkspace` contains the package root plus both sample projects, which link the package products locally. Schemes aren't committed, so check `xcodebuild -list -workspace AlgoLogger.xcworkspace`.

```bash
xcodebuild -workspace AlgoLogger.xcworkspace -scheme AlgoLogger-Package -destination 'generic/platform=iOS' build
xcodebuild -workspace AlgoLogger.xcworkspace -scheme AlgoLoggerApp -destination 'generic/platform=iOS Simulator' build         # OS log, rotating file, CloudWatch, S3
xcodebuild -workspace AlgoLogger.xcworkspace -scheme AlgoLoggerDatadogApp -destination 'generic/platform=iOS Simulator' build  # Datadog; deployment target iOS 18.2

pod lib lint AlgoLoggerCommon.podspec --allow-warnings
pod lib lint AlgoLogger.podspec --allow-warnings
pod lib lint AlgoLoggerDatadog.podspec --allow-warnings
```

The sample apps leave the AWS keys and the Datadog `clientToken` as empty strings. Supply them locally when testing, and never commit them.

## Releasing

1. `sh adjust_version.sh X.Y.Z` (macOS `sed -i ''`). It rewrites `s.version` in the three podspecs and the `AlgoLoggerCommon` dependency in `AlgoLogger`/`AlgoLoggerDatadog`. Its regex matches the exact alignment `s.version          = '...'`, so keep that spacing.
2. Commit `version name X.Y.Z` on `v2/release/X.Y.Z`. Merge into `v2/master` and `v2/develop`, then tag `X.Y.Z` (no `v`; each podspec's `:tag` is `s.version`). SPM consumers use this tag.
3. `pod trunk push` in dependency order: `AlgoLoggerCommon`, then `AlgoLogger` and `AlgoLoggerDatadog`. Between pushes, run `./check_version.sh AlgoLoggerCommon X.Y.Z`. It loops `pod repo update` + `pod spec which` every 60 s until trunk shows the version, so dependents can lint against it.

Version gotchas:
- SPM requires RxSwift `6.10.2+`, but the podspecs pin `~> 6.9.0` on purpose: trunk only has RxSwift up to 6.9.0. Don't "align" them.
- The podspecs declare `:file => 'LICENSE'`, but no LICENSE file is tracked.
- `AlgoLoggerDatadog` has occasionally been released alone (`c141411`).

## Architecture

**Tags.** `Tag` subclasses are declared as `class _Foo: Tag` plus a global `let Foo = _Foo()`. The name is the class name with `_` removed.
- A child tag sets its parent in `required init() { super.init(parent: _Parent.self) }`, and its `name` becomes `Parent.Child`.
- A tag that doesn't call `init(parent:)` is top-level, even if it's stored as a property of another tag.

**Routing (`LogManager.singleton`).**
- `getLogger(tag)` returns one `XCGLogger` per **top-level** tag (`tag.topParent.name`), created lazily and without default destinations.
- Destinations attach to a root with `destination.addTo(tag:)`. Child tags log through their root's logger.
- `L.debug(tag, msg, error:, callStackSymbols:)` and the other levels put the full dotted tag name, the error, and the stack trace into `userInfo` under the `_Key` keys. Destinations read them from there. `L.assert` logs at `.severe`.
- `LogManager.defaultLogger` is a separate logger created with XCGLogger's default destinations. It is the default `owner` for the Algo destinations, which use it for their own diagnostics.

**`initTags(...)` / `addDelegate(...)`.** `LogDelegate`s (only `DataDogLogDelegate` today) get `initTag(name)` for every registered tag. It is called on `initTags`, and replayed for already-known tags on `addDelegate`.

**Destinations.**
- `AlgorigoLoggingDestination`: base class. Subclasses override `write(level:message:date:)`.
- `OsLoggingDestination`: writes to `os_log`.
- `RotatingFileDestination` (XCGLogger `AutoRotatingFileDestination`):
  - Writes under `Documents/<relativePath>`.
  - Won't rotate again within `rotateCheckInterval` (default 300 s).
  - Exposes archived files as `getLogFileObservable()`.
- `RotatingFileDestination.registerS3Uploader(...)` (AWS module):
  - Uploads every archive whose postfix is empty, including the ones already on disk.
  - Retries every 60 s.
  - On success, renames the file with postfix `s3` so it isn't uploaded again.
- `CloudWatchDestination`:
  - Takes credentials from `CredentialsProviderHolder`: static keys, or a Cognito identity-pool resolver.
  - Creates the log group and stream if needed, and sets retention (default 6 months).
  - With `useQueue`, it buffers to a SQLite file `Documents/android_cloudwatch_log.db` (the name is shared with the Android port). It flushes batches every `sendInterval` (minimum 10 s).
- `DataDogDestination` + `DataDogLogDelegate`:
  - The delegate's `init` itself calls `Datadog.initialize` and `Logs.enable()`. Create it before the destination; the destination's `init` throws if Datadog isn't initialized.
  - One Datadog `Logger` is created per tag in `initTag`. `addDDTag`/`addAttribute` apply only to loggers created afterwards, so call them before `addDelegate`/`initTags`.
  - The destination looks up the Datadog logger by the full tag name, so messages for tags never passed to `initTags` are dropped silently.

## Conventions

- New public API must compile under both SPM and CocoaPods. Pod `source_files` are `<Module>/Classes/**/*`, except `AlgoLoggerCommon/**/*`. A module must import the others by module name (`import AlgoLoggerCommon`).
- Commit messages are mostly Korean.
