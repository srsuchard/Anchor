import Combine
import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// Owns the screen-time restrictions from the app's side.
///
/// The block itself is enforced by the system, not by this app. Once the shield
/// is applied, iOS holds it even if Anchor is killed, backgrounded, or the phone
/// is rebooted — which is what makes the puck tap meaningful rather than
/// decorative. Scheduled sessions are applied by the monitor extension instead;
/// both paths go through `ShieldController`.
@MainActor
final class FocusBlocker: ObservableObject {

    private let shields = ShieldController()
    private let center = DeviceActivityCenter()

    @Published private(set) var authorizationStatus: AuthorizationStatus
    @Published private(set) var isBlocking: Bool
    @Published var authorizationError: String?
    @Published var scheduleError: String?

    @Published var selection: FamilyActivitySelection {
        didSet { AnchorStore.selection = selection }
    }

    @Published private(set) var scheduleEnabled: Bool
    @Published var scheduleStartHour: Int { didSet { AnchorStore.scheduleStartHour = scheduleStartHour } }
    @Published var scheduleEndHour: Int { didSet { AnchorStore.scheduleEndHour = scheduleEndHour } }

    init() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        isBlocking = AnchorStore.isBlocking
        selection = AnchorStore.selection
        scheduleEnabled = AnchorStore.scheduleEnabled
        scheduleStartHour = AnchorStore.scheduleStartHour
        scheduleEndHour = AnchorStore.scheduleEndHour
    }

    /// True once the user has picked at least one app, category, or domain.
    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty
            || !selection.categoryTokens.isEmpty
            || !selection.webDomainTokens.isEmpty
    }

    /// The monitor extension can start a session while the app is closed, so the
    /// app re-reads shared state whenever it comes back to the foreground.
    func refreshFromSharedState() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        isBlocking = AnchorStore.isBlocking
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

    // MARK: - Manual sessions

    func startBlocking() {
        guard hasSelection else { return }
        shields.apply(selection)
        isBlocking = true
    }

    /// Call this *only* after a verified puck tap — every other caller is a
    /// bypass, which defeats the purpose of the device.
    func stopBlocking() {
        shields.clear()
        isBlocking = false
    }

    // MARK: - Scheduled sessions

    /// Registers the daily window with the system. From here on the monitor
    /// extension applies and lifts the block at the boundaries, with no help
    /// from the app.
    func enableSchedule() {
        guard hasSelection else { return }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: scheduleStartHour, minute: 0),
            intervalEnd: DateComponents(hour: scheduleEndHour, minute: 0),
            repeats: true
        )

        do {
            center.stopMonitoring([.anchorSchedule])
            try center.startMonitoring(.anchorSchedule, during: schedule)
            setScheduleEnabled(true)
            scheduleError = nil
        } catch {
            setScheduleEnabled(false)
            scheduleError = "Couldn't set that schedule. Start and end can't be the same time."
        }
    }

    /// Stops future scheduled sessions. Deliberately does not lift a block that
    /// is already running — that still takes the puck.
    func disableSchedule() {
        center.stopMonitoring([.anchorSchedule])
        setScheduleEnabled(false)
        scheduleError = nil
    }

    private func setScheduleEnabled(_ value: Bool) {
        scheduleEnabled = value
        AnchorStore.scheduleEnabled = value
    }
}
