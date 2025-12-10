//
//  FasterFoodsApp.swift
//  FasterFoods
//
//  Created by Ritvik Joshi on 07/08/25.
//

import GoogleSignIn
import Intents
import SwiftUI

@main
struct FasterFoodsApp: App {
    @StateObject private var app = AppState()
    @StateObject private var toastService = ToastService()

    init() {
        // Configure Google Sign In once at app startup
        if let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String {
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
        }
        GlassNavigationBar.apply()

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
            .environmentObject(toastService)
            .toastHost(using: toastService)
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}
