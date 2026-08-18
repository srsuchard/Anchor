import FamilyControls
import Foundation

/// Decisions that touch nothing outside their arguments.
///
/// The rest of Anchor is hard to verify without hardware: NFC needs a phone,
/// Screen Time needs authorization, the shields live in another process. These
/// rules are the part that can be pinned down by tests, so they are kept
/// separate rather than buried inside `FocusBlocker`.
enum SessionRules {

    /// Whether a stored "a session is running" flag should still be believed.
    ///
    /// Revoking Screen Time access in Settings tears the restrictions down
    /// without notifying anyone, so stored state can outlive the block it
    /// describes. Losing authorization means nothing is shielded, whatever the
    /// flag says.
    static func reconciledBlocking(stored: Bool, authorization: AuthorizationStatus) -> Bool {
        guard authorization == .approved else { return false }
        return stored
    }

    /// Whether starting a session would actually do anything.
    ///
    /// Without authorization the shields silently no-op, so flipping the flag
    /// would leave the UI claiming a block that does not exist.
    static func canStartSession(hasSelection: Bool, authorization: AuthorizationStatus) -> Bool {
        hasSelection && authorization == .approved
    }

    enum ScheduleValidation: Equatable {
        case valid
        case sameStartAndEnd
    }

    /// Checked before registering rather than inferred from a thrown error, so
    /// the UI only blames equal times when that is genuinely the cause.
    ///
    /// A window that wraps midnight (22 to 6) is valid — `DeviceActivity`
    /// handles it, and "block from 10pm until morning" is a real use.
    static func validateSchedule(startHour: Int, endHour: Int) -> ScheduleValidation {
        startHour == endHour ? .sameStartAndEnd : .valid
    }
}
