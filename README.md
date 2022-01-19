# LiveKit SDK Example App for iOS/macOS

This app demonstrates the basic usage of [LiveKit Swift SDK (iOS/macOS)](https://github.com/livekit/client-sdk-ios).

# How to run the example

### Get the code

1. Clone this [LiveKit Swift Example](https://github.com/livekit/client-example-swift) repo.
2. Open `LiveKitExample.xcodeproj` (not the `-dev.xcworkspace`).
3. Wait for packages to sync.

### Change bundle id & code signing information
1. Select the `LiveKitExample` project from the left Navigator.
2. For each **Target**, select **Signing & Capabilities** tab and update your **Team** and **Bundle Identifier** to your preference.

### 🚀 Run
1. Select `LiveKitExample (iOS)` or `LiveKitExample (macOS)` from the **Scheme selector** at the top of Xcode.
2. **Run** the project from the menu **Product** → **Run** or by ⌘R.

If you encounter code signing issues, make sure you change the **Team** and **bundle id** from the previous step.

# Troubleshooting

### Package errors

If you get package syncing errors, try *resetting your package caches* by right clicking **Package Dependencies** and choosing **Reset Package Caches** from the **Navigator**.

# Getting help / Contributing

Please join us on [Slack](https://join.slack.com/t/livekit-users/shared_invite/zt-rrdy5abr-5pZ1wW8pXEkiQxBzFiXPUg) to get help from our (devs)[https://github.com/orgs/livekit/teams/devs/members] / community members. We welcome your contributions(PRs) and details can be discussed there.

# Development

For development, open `LiveKitExample-dev.xcworkspace` instead. This workspace will compile with the local `../client-sdk-ios`.
