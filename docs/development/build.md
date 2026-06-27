# Build Notes

## Verified Command

```bash
xcodebuild -project apps/ios/SmartSchedule.xcodeproj \
  -target SmartSchedule \
  -sdk iphoneos26.5 \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Result on 2026-06-27: `BUILD SUCCEEDED`.

## Notes

- Target build with `-sdk iphoneos26.5` was verified.
- Building through `-scheme SmartSchedule` or with `-destination ...` can fail if Xcode cannot resolve installed device runtimes.
- SwiftData macros require Swift plugin execution. If builds fail with `swift-plugin-server` sandbox errors, run the build outside a restrictive sandbox.
- The asset catalog exists but is not part of the target in 0.1.0-beta because local `actool` tried to access unavailable simulator services during verification.

## Requirements

- Xcode 26.5 or newer.
- iOS 26.5 SDK.
- Swift 6.3 or newer.
