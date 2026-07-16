//
//  ContentView.swift
//  pose-for-me
//

import Combine
import SwiftUI

/// Entry gate: onboarding on first launch, main app afterwards.
struct ContentView: View {
    @EnvironmentObject private var settings: UserSettings

    var body: some View {
        if settings.data.hasOnboarded {
            RootView()
                .transition(.opacity)
        } else {
            OnboardingView()
                .transition(.opacity)
        }
    }
}
