//
//  Multiplatform_SwiftUIApp.swift
//  Shared
//
//  Created by Hiroshi Horie on 2021/10/19.
//

import SwiftUI

@main
struct Multiplatform_SwiftUIApp: App {

    @StateObject private var appState = AppCtrl.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
            //                .foregroundColor(Color.white)
        }
    }
}
