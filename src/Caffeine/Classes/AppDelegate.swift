//
//  AppDelegate.swift
//  Caffeine
//
//  Created by Dominic Rodemer on 11.11.25.
//

import Cocoa
import DZFoundation
import Sparkle
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, SPUStandardUserDriverDelegate, SPUUpdaterDelegate {
    /// Make this lazy so `self` can be used safely
    ///
    /// The updater is deliberately never started. This is a fork, and the
    /// only appcast Sparkle ever knew about was upstream's, so a running
    /// updater would replace this build with upstream's.
    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: self,
        userDriverDelegate: self
    )
    private var statusItem: NSStatusItem?
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_: Notification) {
        // Create the menu bar controller
        self.menuBarController = MenuBarController(updaterController: self.updaterController)

        // Hide the dock icon - this is a menu bar only app
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_: Notification) {
        // Clean up
        self.menuBarController?.cleanup()
    }

    // MARK: SPUUpdaterDelegate

    /// Refuse every update check, whatever a stored preference says.
    ///
    /// `SUEnableAutomaticChecks` and friends are only defaults: `SUHost`
    /// reads the user domain first, and any Mac that ran upstream Caffeine
    /// already has them switched on. Only code can turn this off for good.
    func updater(_: SPUUpdater, mayPerform _: SPUUpdateCheck) throws {
        DZLog("Refused an update check: this fork has no update feed")
        throw CocoaError(.featureUnsupported)
    }

    // MARK: SPUStandardUserDriverDelegate

    // MARK: - --

    func supportsGentleScheduledUpdateReminders() -> Bool {
        true
    }
}
