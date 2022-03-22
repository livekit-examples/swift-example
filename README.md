# LiveKit SDK Example App for iOS & macOS

This app demonstrates the basic usage of [LiveKit Swift SDK (iOS/macOS)](https://github.com/livekit/client-sdk-swift). See [LiveKit Docs](https://docs.livekit.io/) for more information.

### Compiled version

Precompiled macOS version is available from the [Releases page](https://github.com/livekit/client-example-swift/releases), so you can quickly try out features of the [LiveKit Swift SDK](https://github.com/livekit/client-sdk-swift) or the [LiveKit Server](https://github.com/livekit/livekit-server).

Precompiled iOS version can be downloaded on [Apple TestFlight](https://testflight.apple.com/join/21F6ARiQ). Click on the link from an iOS device and follow the instructions.

### Screenshots
**macOS**
![macOS](https://user-images.githubusercontent.com/548776/150068761-ce8f7d59-72e8-412a-9675-66a2eec9f04f.png)

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

### ⚡️ Connect

1. Prepare & Start [LiveKit Server](https://github.com/livekit/livekit-server). See the [Getting Started page](https://docs.livekit.io/guides/getting-started) for more information.
2. Generate an access token.
3. Enter the **Server URL** and **Access token** to the example app and tap **Connect**.

Server URL would typically look like `ws://localhost:7880` depending on your configuration. It should start with `ws://` for *non-secure* and `wss://` for *secure* connections.

### ✅ Permissions

iOS/macOS will ask you to grant permission when enabling **Camera**, **Microphone** and/or **Screen Share**. Simply allow this to continue publishing the track.

#### macOS Screen Share

Open **Settings** → **Security & Privacy** → **Screen Recording** and make sure **LiveKitExample** has a ✔️ mark. You will need to restart the app.

# Troubleshooting

### Package errors

If you get package syncing errors, try *resetting your package caches* by right clicking **Package Dependencies** and choosing **Reset Package Caches** from the **Navigator**.

# Getting help / Contributing

Please join us on [Slack](https://join.slack.com/t/livekit-users/shared_invite/zt-rrdy5abr-5pZ1wW8pXEkiQxBzFiXPUg) to get help from our [devs](https://github.com/orgs/livekit/teams/devs/members) / community members. We welcome your contributions(PRs) and details can be discussed there.

# Development

For development, open `LiveKitExample-dev.xcworkspace` instead. This workspace will compile with the local `../client-sdk-swift`.
