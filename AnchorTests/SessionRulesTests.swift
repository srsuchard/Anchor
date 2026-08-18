import FamilyControls
import XCTest

/// These cover the reasoning that survives without a device: what the app is
/// allowed to believe about its own state. Every bug fixed in this area so far
/// has been stored state drifting from system state, so that is what is pinned
/// down here.
final class SessionRulesTests: XCTestCase {

    // MARK: - Believing a stored "blocking" flag

    func testApprovedAuthorizationPreservesStoredState() {
        XCTAssertTrue(SessionRules.reconciledBlocking(stored: true, authorization: .approved))
        XCTAssertFalse(SessionRules.reconciledBlocking(stored: false, authorization: .approved))
    }

    func testRevokedAuthorizationClearsBlocking() {
        // Revoking Screen Time in Settings removes the shields silently. A
        // stored `true` would leave the UI claiming a session that no longer
        // exists, and the puck tap would be theatre.
        XCTAssertFalse(SessionRules.reconciledBlocking(stored: true, authorization: .denied))
        XCTAssertFalse(SessionRules.reconciledBlocking(stored: true, authorization: .notDetermined))
    }

    func testUnauthorizedNeverInventsABlock() {
        XCTAssertFalse(SessionRules.reconciledBlocking(stored: false, authorization: .denied))
        XCTAssertFalse(SessionRules.reconciledBlocking(stored: false, authorization: .notDetermined))
    }

    // MARK: - Starting a session

    func testSessionNeedsBothSelectionAndAuthorization() {
        XCTAssertTrue(SessionRules.canStartSession(hasSelection: true, authorization: .approved))
        XCTAssertFalse(SessionRules.canStartSession(hasSelection: false, authorization: .approved))
        XCTAssertFalse(SessionRules.canStartSession(hasSelection: true, authorization: .denied))
        XCTAssertFalse(SessionRules.canStartSession(hasSelection: false, authorization: .denied))
    }

    // MARK: - Schedule validation

    func testEqualStartAndEndIsRejected() {
        XCTAssertEqual(SessionRules.validateSchedule(startHour: 9, endHour: 9), .sameStartAndEnd)
        XCTAssertEqual(SessionRules.validateSchedule(startHour: 0, endHour: 0), .sameStartAndEnd)
    }

    func testOrdinaryWindowIsValid() {
        XCTAssertEqual(SessionRules.validateSchedule(startHour: 9, endHour: 17), .valid)
    }

    func testWindowWrappingMidnightIsValid() {
        // "Block from 10pm until morning" is a real use, and DeviceActivity
        // handles the wrap. Rejecting it would be a bug, not a safeguard.
        XCTAssertEqual(SessionRules.validateSchedule(startHour: 22, endHour: 6), .valid)
    }
}
