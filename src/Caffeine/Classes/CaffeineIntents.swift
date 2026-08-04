//
//  CaffeineIntents.swift
//  Caffeine
//
//  App Intents exposing Caffeine to Shortcuts and Spotlight.
//

import AppIntents
import Foundation

/// Errors surfaced to Shortcuts when the app is not ready to handle an intent.
enum CaffeineIntentError: Swift.Error, LocalizedError {
    case appNotReady

    var errorDescription: String? {
        switch self {
        case .appNotReady:
            String(localized: "Caffeine is not running")
        }
    }
}

/// Returns the running app's view model, or throws if the app has not finished launching.
@MainActor
private func caffeineViewModel() throws -> CaffeineViewModel {
    guard let viewModel = CaffeineViewModel.shared else {
        throw CaffeineIntentError.appNotReady
    }
    return viewModel
}

/// Activates Caffeine, optionally for a fixed number of minutes.
struct EnableCaffeineIntent: AppIntent {
    static var title: LocalizedStringResource = "Enable Caffeine"
    static var description = IntentDescription("Activate Caffeine to prevent your Mac from sleeping")

    @Parameter(
        title: "Duration (minutes)",
        description: "Number of minutes to keep Caffeine active (0 = forever)",
        default: 0
    )
    var durationMinutes: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let viewModel = try caffeineViewModel()
        viewModel.activate(withTimeout: TimeInterval(max(0, self.durationMinutes) * 60))

        let message: String = if self.durationMinutes > 0 {
            String.localizedStringWithFormat(
                String(localized: "Caffeine is now active for %d minutes"),
                self.durationMinutes
            )
        } else {
            String(localized: "Caffeine is now active indefinitely")
        }
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

/// Deactivates Caffeine.
struct DisableCaffeineIntent: AppIntent {
    static var title: LocalizedStringResource = "Disable Caffeine"
    static var description = IntentDescription("Deactivate Caffeine to allow your Mac to sleep normally")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try caffeineViewModel().deactivate()
        return .result(dialog: IntentDialog(stringLiteral: String(localized: "Caffeine is now inactive")))
    }
}

/// Toggles Caffeine between active and inactive.
struct ToggleCaffeineIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Caffeine"
    static var description = IntentDescription("Toggle Caffeine between active and inactive states")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let viewModel = try caffeineViewModel()
        viewModel.toggleActive()

        let message = viewModel.isActive
            ? String(localized: "Caffeine is now active")
            : String(localized: "Caffeine is now inactive")
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

/// Phrases that expose the intents to Siri and Spotlight.
struct CaffeineShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: EnableCaffeineIntent(),
            phrases: ["Enable \(.applicationName)", "Turn on \(.applicationName)"],
            shortTitle: "Enable Caffeine",
            systemImageName: "cup.and.saucer.fill"
        )
        AppShortcut(
            intent: DisableCaffeineIntent(),
            phrases: ["Disable \(.applicationName)", "Turn off \(.applicationName)"],
            shortTitle: "Disable Caffeine",
            systemImageName: "cup.and.saucer"
        )
        AppShortcut(
            intent: ToggleCaffeineIntent(),
            phrases: ["Toggle \(.applicationName)"],
            shortTitle: "Toggle Caffeine",
            systemImageName: "cup.and.saucer"
        )
    }
}
