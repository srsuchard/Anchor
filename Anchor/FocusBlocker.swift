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

    @Published private(set) var pairedUIDs: Set<String>
    @Published private(set) var scheduleEnabled: Bool
    @Published var scheduleStartHour: Int {
        didSet {
            AnchorStore.scheduleStartHour = scheduleStartHour
            rescheduleIfEnabled()
        }
    }

    @Published var scheduleEndHour: Int {
        didSet {
            AnchorStore.scheduleEndHour = scheduleEndHour
            rescheduleIfEnabled()
        }
    }

    init() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        isBlocking = AnchorStore.isBlocking
        selection = AnchorStore.selection
        pairedUIDs = AnchorStore.pairedPuckUIDs
        scheduleEnabled = AnchorStore.scheduleEnabled
        scheduleStartHour = AnchorStore.scheduleStartHour
        scheduleEndHour = AnchorStore.scheduleEndHour
    }

    // MARK: - Paired tags

    var hasPairedPuck: Bool { !pairedUIDs.isEmpty }

    /// Whether this tag can end a session.
    func isPaired(_ uid: String) -> Bool { pairedUIDs.contains(uid) }

    /// Adds a tag to the set that can unlock.
    ///
    /// Callers must not offer this while a session is running. Pairing a tag
    /// mid-block would let any tag in a pocket end the session, which is the
    /// bypass the whole device exists to prevent — see `ContentView`, where
    /// pairing is reachable only from the idle screen.
    func pair(_ uid: String) {
        pairedUIDs.insert(uid)
        AnchorStore.pairedPuckUIDs = pairedUIDs
    }

    func forget(_ uid: String) {
        pairedUIDs.remove(uid)
        AnchorStore.pairedPuckUIDs = pairedUIDs
    }

    func forgetAllPucks() {
        pairedUIDs.removeAll()
        AnchorStore.pairedPuckUIDs = pairedUIDs
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

        // Revoking Screen Time access in Settings tears the restrictions down
        // without telling us, so a stored isBlocking would outlive the block it
        // describes — the UI would insist a session was running while nothing
        // was actually shielded, and the puck tap would be theatre.
        let reconciled = SessionRules.reconciledBlocking(
            stored: AnchorStore.isBlocking,
            authorization: authorizationStatus
        )
        if reconciled != AnchorStore.isBlocking {
            AnchorStore.isBlocking = reconciled
        }

        isBlocking = reconciled
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
        guard SessionRules.canStartSession(
            hasSelection: hasSelection,
            authorization: authorizationStatus
        ) else { return }

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
        guard SessionRules.canStartSession(
            hasSelection: hasSelection,
            authorization: authorizationStatus
        ) else { return }

        switch SessionRules.validateSchedule(
            startHour: scheduleStartHour,
            endHour: scheduleEndHour
        ) {
        case .sameStartAndEnd:
            setScheduleEnabled(false)
            scheduleError = "Start and end can't be the same time."
            return
        case .valid:
            break
        }

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
            scheduleError = "Couldn't set that schedule."
        }
    }

    /// Re-registers a live schedule after its hours change.
    ///
    /// Without this the picker and the system silently disagree: the UI reads
    /// "9 to 5" while iOS still enforces whatever window was registered when the
    /// toggle was first flipped.
    private func rescheduleIfEnabled() {
        guard scheduleEnabled else { return }
        enableSchedule()
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
