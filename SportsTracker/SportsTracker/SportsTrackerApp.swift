//
//  SportsTrackerApp.swift
//  SportsTracker
//
//  Created by Matúš Selecký on 13/07/2026.
//

import SwiftUI
import FactoryKit
import FirebaseCore

@main
struct SportsTrackerApp: App {
    @State private var router = AppRouter()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            AppFlowView(
                router: router,
                factory: ScreenFactory(container: .shared, router: router)
            )
        }
    }
}
