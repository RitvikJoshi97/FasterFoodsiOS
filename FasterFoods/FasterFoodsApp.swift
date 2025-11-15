//
//  FasterFoodsApp.swift
//  FasterFoods
//
//  Created by Ritvik Joshi on 07/08/25.
//

import SwiftUI
import GoogleSignIn
import Intents

@main
struct FasterFoodsApp: App {
    @StateObject private var app = AppState()

    init() {
        // Configure Google Sign In once at app startup
        if let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String {
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
        }

        INPreferences.requestSiriAuthorization { _ in }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if app.isBootstrapping {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                } else if app.isAuthenticated {
                    HomeView()
                        .transition(.opacity)
                } else {
                    LoginView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: app.isBootstrapping)
            .animation(.easeInOut(duration: 0.4), value: app.isAuthenticated)
            .environmentObject(app)
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}
