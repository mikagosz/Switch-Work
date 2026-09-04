import Foundation
import ServiceManagement
import os

/// Whether Switch-Work starts itself when the Mac logs in.
///
/// > [!info] Why `SMAppService` and not a login-item plist
/// > The old `LSSharedFileList` API is deprecated and the `~/Library/LaunchAgents`
/// > route needs a second bundle to install. `SMAppService.mainApp` registers *this*
/// > bundle, so there is nothing extra to ship, sign or keep in sync.
///
/// > [!warning] The system owns this switch, not us
/// > macOS lets the user revoke a login item in System Settings → General → Login Items,
/// > and it does that without telling the app. So the menu asks `SMAppService` for the
/// > current state every time it opens instead of caching a `UserDefaults` flag that
/// > would drift out of step with reality within a day.
///
/// Registration fails when the app runs from a place the system will not launch from —
/// a DMG, a Downloads folder still carrying quarantine, or a build sitting in
/// DerivedData. That is not a bug to hide: `enable(_:)` reports it so the caller can
/// say what happened.
enum LoginItem {

    private static let log = Logger(subsystem: "com.mikagosz.SwitchWork", category: "loginitem")

    /// Current state, read from the system every call.
    ///
    /// `.enabled` is the only state that counts as on. `.requiresApproval` means the
    /// registration went through but the user has to allow it in System Settings —
    /// which is *not* the same as being on, and pretending otherwise would leave the
    /// user with a tick next to something that will not happen.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Whether macOS is waiting for the user to approve the item in System Settings.
    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    /// Turns the login item on or off. Returns `nil` on success, or a message to show.
    ///
    /// The message is meant for a person, not a log: `SMAppService` throws `NSError`
    /// with codes like `kSMErrorLaunchDeniedByUser`, which says nothing to anybody
    /// outside the framework.
    @discardableResult
    static func enable(_ on: Bool) -> String? {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            log.info("login item \(on ? "registered" : "unregistered")")
            return nil
        } catch {
            log.error("login item change failed: \(error.localizedDescription)")
            return explain(error, turningOn: on)
        }
    }

    /// Turns a framework error into a sentence that tells the user what to do next.
    private static func explain(_ error: Error, turningOn: Bool) -> String {
        let ns = error as NSError

        // 🔴 The one failure that is not the app's fault and not the user's either:
        // macOS refuses to register a bundle it cannot vouch for. Happens with a build
        // run straight from DerivedData, or an app still carrying the quarantine flag
        // after a download. Moving it to /Applications clears both.
        if ns.domain == NSOSStatusErrorDomain || ns.code == 1 {
            return String(localized: """
                macOS refused to register Switch-Work for launch at login. \
                This usually means the app is not in the Applications folder yet. \
                Move it there and try again.
                """)
        }

        return turningOn
            ? String(format: String(localized: "Could not turn on launch at login: %@"),
                     ns.localizedDescription)
            : String(format: String(localized: "Could not turn off launch at login: %@"),
                     ns.localizedDescription)
    }
}
