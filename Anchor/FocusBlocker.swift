import Combine
import FamilyControls
import ManagedSettings
import SwiftUI

/// Owns the screen-time restrictions: which apps are blocked, and whether the
/// block is currently applied.
///
/// The block itself is enforced by the system, not by this app. Once
/// `ManagedSettingsStore.shield` is populated, iOS shields those apps even if
/// Anchor is killed, backgrounded, or the phone is rebooted. Clearing the store
/// is the *only* way to lift it from here — which is what makes the puck tap
/// meaningful rather than decorative.
@MainActor
final class FocusBlocker: ObservableObject {

    /// A named store keeps Anchor's restrictions separate from any other app's.
    private let store = ManagedSettingsStore(named: .anchor)

    @Published private(set) var authorizationStatus: AuthorizationStatus
    @Published private(set) var isBlocking: Bool
    @Published var selection: FamilyActivitySelection {
        didSet { persistSelection() }
    }

    /// Non-nil when the last authorization attempt failed, for display.
    @Published var authorizationError: String?

    private let defaults = UserDefaults.standard
    private static let selectionKey = "blockedActivitySelection"
    private static let blockingKey = "isBlocking"

    init() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        isBlocking = UserDefaults.standard.bool(forKey: Self.blockingKey)
        selection = Self.loadSelection() ?? FamilyActivitySelection()
    }

    /// True once the user has picked at least one app, category, or domain.
    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty
            || !selection.categoryTokens.isEmpty
            || !selection.webDomainTokens.isEmpty
    }

    // MARK: - Authorization

    /// Prompts for Screen Time permission. iOS shows this once — if the user
    /// denies it, the only way back is Settings, so the UI should say so.
    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorizationError = nil
        } catch {
            authorizationError = "Screen Time permission was declined. "
                + "Enable it in Settings › Screen Time to use Anchor."
        }
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    // MARK: - Blocking

    /// Applies the shield. Takes effect immediately and survives app termination.
    func startBlocking() {
        guard hasSelection else { return }

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

        setBlocking(true)
    }

    /// Lifts the shield. Call this *only* after a verified puck tap — every
    /// other caller is a bypass, which defeats the purpose of the device.
    func stopBlocking() {
        store.clearAllSettings()
        setBlocking(false)
    }

    private func setBlocking(_ value: Bool) {
        isBlocking = value
        defaults.set(value, forKey: Self.blockingKey)
    }

    // MARK: - Persistence

    private func persistSelection() {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        defaults.set(data, forKey: Self.selectionKey)
    }

    private static func loadSelection() -> FamilyActivitySelection? {
        guard let data = UserDefaults.standard.data(forKey: selectionKey) else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }
}

extension ManagedSettingsStore.Name {
    static let anchor = Self("anchor")
}
