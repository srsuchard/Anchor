import DeviceActivity
import FamilyControls
import Foundation

/// State shared between the app and its extensions.
///
/// The app and the DeviceActivityMonitor extension are separate processes, so
/// plain `UserDefaults.standard` is invisible across the boundary. Everything
/// both sides need lives in the app group container instead.
enum AnchorStore {

    /// Must match the `com.apple.security.application-groups` entitlement in
    /// both the app and every extension that reads this. Change it here and in
    /// all three .entitlements files together, or writes silently go nowhere.
    static let appGroupID = "group.com.example.Anchor"

    static let defaults: UserDefaults =
        UserDefaults(suiteName: appGroupID) ?? .standard

    private enum Key {
        static let selection = "blockedActivitySelection"
        static let isBlocking = "isBlocking"
        static let scheduleEnabled = "scheduleEnabled"
        static let scheduleStartHour = "scheduleStartHour"
        static let scheduleEndHour = "scheduleEndHour"
    }

    // MARK: - What to block

    static var selection: FamilyActivitySelection {
        get {
            guard let data = defaults.data(forKey: Key.selection),
                  let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            else { return FamilyActivitySelection() }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: Key.selection)
        }
    }

    // MARK: - Whether a block is currently applied

    /// Persisted because the system shield outlives the app process — after a
    /// force-quit or a monitor-triggered start, the app must come back knowing
    /// a session is already running.
    static var isBlocking: Bool {
        get { defaults.bool(forKey: Key.isBlocking) }
        set { defaults.set(newValue, forKey: Key.isBlocking) }
    }

    // MARK: - Schedule

    static var scheduleEnabled: Bool {
        get { defaults.bool(forKey: Key.scheduleEnabled) }
        set { defaults.set(newValue, forKey: Key.scheduleEnabled) }
    }

    static var scheduleStartHour: Int {
        get { defaults.object(forKey: Key.scheduleStartHour) as? Int ?? 9 }
        set { defaults.set(newValue, forKey: Key.scheduleStartHour) }
    }

    static var scheduleEndHour: Int {
        get { defaults.object(forKey: Key.scheduleEndHour) as? Int ?? 17 }
        set { defaults.set(newValue, forKey: Key.scheduleEndHour) }
    }
}

extension DeviceActivityName {
    static let anchorSchedule = Self("anchorSchedule")
}
