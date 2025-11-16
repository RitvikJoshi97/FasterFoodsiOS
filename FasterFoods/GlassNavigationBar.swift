//
//  GlassNavigationBar.swift
//  FasterFoods
//
//  Created by AI Assistant on 05/26/24.
//

import SwiftUI

enum GlassNavigationBar {
    static func apply() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
            ? UIColor.black.withAlphaComponent(0.28)
            : UIColor.white.withAlphaComponent(0.45)
        }
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]

        let navigationBar = UINavigationBar.appearance()
        navigationBar.standardAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.tintColor = UIColor.label

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        tabAppearance.backgroundColor = appearance.backgroundColor
        tabAppearance.shadowColor = .clear
        tabAppearance.stackedLayoutAppearance.selected.iconColor = UIColor.label
        tabAppearance.inlineLayoutAppearance.selected.iconColor = UIColor.label
        tabAppearance.compactInlineLayoutAppearance.selected.iconColor = UIColor.label
        tabAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.label]
        
        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = tabAppearance
        tabBar.scrollEdgeAppearance = tabAppearance
        tabBar.tintColor = UIColor.label
        tabBar.isTranslucent = true
    }
}
