import DeviceActivity
import ManagedSettings

/// Starts and ends scheduled focus sessions.
///
/// The system wakes this extension at the schedule boundaries — Anchor does not
/// need to be running, or even to have been opened that day. It gets a few
/// seconds of runtime, so the work here is deliberately just "flip the shields".
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity == .anchorSchedule else { return }

        ShieldController().apply(AnchorStore.selection)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity == .anchorSchedule else { return }

        // Design decision, and the one most worth revisiting: the scheduled
        // window *is* the session, so reaching its end lifts the block without
        // a puck tap. The puck's job is unlocking early.
        //
        // The stricter alternative — delete this call, so only the puck ever
        // lifts a block — is truer to the "physical friction is the only exit"
        // thesis, but it means a schedule that fires while the puck is at the
        // office locks the phone with no way out until you get home.
        ShieldController().clear()
    }
}
