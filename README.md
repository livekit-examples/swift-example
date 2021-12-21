# LiveKit SDK Example App for iOS/macOS

This app demonstrates the basic usage of [LiveKit Swift SDK (iOS/macOS)](https://github.com/livekit/client-sdk-ios).

# How to run the example

## Clone both example & SDK repos
Currently, the example app compiles with `main` branch of [LiveKit Swift SDK](https://github.com/livekit/client-sdk-ios) .
Pull both repos into a same parent directory. Then open `client-example-swift/LiveKitExample.xcworkspace` from Xcode.

## Update bundle id & code signing information
1. Select the `LiveKitExample` project from the left Navigator.
2. For each **Target**, select **Signing & Capabilities** tab and update your **Team** and **Bundle Identifier** to your preference.
3. Make sure there are no code signing issues.
4. Select `LiveKitExample (iOS)` or `LiveKitExample (macOS)` from the **Scheme selector** at the top of Xcode.
5. **Run** the project from the menu **Product** → **Run** or by ⌘R.
