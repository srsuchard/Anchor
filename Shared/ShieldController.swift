import FamilyControls
import ManagedSettings

/// Applies and lifts the actual restrictions.
///
/// Both the app (manual sessions) and the DeviceActivityMonitor extension
/// (scheduled sessions) drive the same store, so this logic lives in one place.
/// If it were duplicated, the two processes could disagree about what "blocked"
/// means — and the extension's copy is the one you can't easily debug.
struct ShieldController {

    private let store = ManagedSettingsStore(named: .anchor)

    /// Shields everything in `selection` and locks the app in place.
    func apply(_ selection: FamilyActivitySelection) {
        store.shield.applications = selection.applicationTokens.isEmpty
            ? nil
            : selection.applicationTokens

        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)

        store.shield.webDomains = selection.webDomainTokens.isEmpty
            ? nil
            : selection.webDomainTokens

        // Without this, the block is trivially defeated by deleting Anchor —
        // uninstalling clears its ManagedSettingsStore along with it. Denying
        // app removal is what makes the puck the path of least resistance.
        store.application.denyAppRemoval = true

        AnchorStore.isBlocking = true
    }

    /// Lifts everything, including the app-removal lock.
    ///
    /// From the app, call this *only* after a verified puck tap — every other
    /// caller is a bypass. The monitor extension also calls it at the end of a
    /// scheduled interval; see `DeviceActivityMonitorExtension`.
    func clear() {
        store.clearAllSettings()
        AnchorStore.isBlocking = false
    }
}

extension ManagedSettingsStore.Name {
    static let anchor = Self("anchor")
}
