import FamilyControls
import XCTest

/// Exercises the app-group store against a throwaway suite.
///
/// This is the boundary the app and the monitor extension both read through, so
/// a defect here shows up as two processes disagreeing about whether a block is
/// running — with no error anywhere.
final class AnchorStoreTests: XCTestCase {

    private static let suiteName = "com.example.Anchor.tests"
    private var suite: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suite = try XCTUnwrap(UserDefaults(suiteName: Self.suiteName))
        suite.removePersistentDomain(forName: Self.suiteName)
        AnchorStore.defaults = suite
    }

    override func tearDown() {
        suite.removePersistentDomain(forName: Self.suiteName)
        super.tearDown()
    }

    // MARK: - Paired tags

    func testNoTagsPairedInitially() {
        XCTAssertTrue(AnchorStore.pairedPuckUIDs.isEmpty)
    }

    func testPairedTagsRoundTrip() {
        AnchorStore.pairedPuckUIDs = ["04A23F91B2C3D4", "0499887766554433"]
        XCTAssertEqual(AnchorStore.pairedPuckUIDs, ["04A23F91B2C3D4", "0499887766554433"])
    }

    func testPairingTheSameTagTwiceKeepsOneEntry() {
        var uids = AnchorStore.pairedPuckUIDs
        uids.insert("04A23F91B2C3D4")
        uids.insert("04A23F91B2C3D4")
        AnchorStore.pairedPuckUIDs = uids
        XCTAssertEqual(AnchorStore.pairedPuckUIDs.count, 1)
    }

    func testForgettingOneTagLeavesTheOthers() {
        AnchorStore.pairedPuckUIDs = ["AAAA", "BBBB"]
        var uids = AnchorStore.pairedPuckUIDs
        uids.remove("AAAA")
        AnchorStore.pairedPuckUIDs = uids
        XCTAssertEqual(AnchorStore.pairedPuckUIDs, ["BBBB"])
    }

    // MARK: - Blocking flag

    func testNotBlockingInitially() {
        XCTAssertFalse(AnchorStore.isBlocking)
    }

    func testBlockingFlagPersists() {
        AnchorStore.isBlocking = true
        XCTAssertTrue(AnchorStore.isBlocking)
        AnchorStore.isBlocking = false
        XCTAssertFalse(AnchorStore.isBlocking)
    }

    // MARK: - Schedule

    func testScheduleDefaultsToNineToFive() {
        XCTAssertEqual(AnchorStore.scheduleStartHour, 9)
        XCTAssertEqual(AnchorStore.scheduleEndHour, 17)
        XCTAssertFalse(AnchorStore.scheduleEnabled)
    }

    func testMidnightIsStoredRatherThanTreatedAsUnset() {
        // Hour 0 is a legitimate value. Reading through `integer(forKey:)` with
        // a fallback would silently turn midnight back into the 9am default,
        // so this pins the distinction between "unset" and "set to zero".
        AnchorStore.scheduleStartHour = 0
        XCTAssertEqual(AnchorStore.scheduleStartHour, 0)
    }

    func testScheduleHoursPersist() {
        AnchorStore.scheduleStartHour = 22
        AnchorStore.scheduleEndHour = 6
        XCTAssertEqual(AnchorStore.scheduleStartHour, 22)
        XCTAssertEqual(AnchorStore.scheduleEndHour, 6)
    }

    // MARK: - Selection

    func testSelectionIsEmptyBeforeAnythingIsChosen() {
        let selection = AnchorStore.selection
        XCTAssertTrue(selection.applicationTokens.isEmpty)
        XCTAssertTrue(selection.categoryTokens.isEmpty)
        XCTAssertTrue(selection.webDomainTokens.isEmpty)
    }

    func testSelectionSurvivesARoundTrip() {
        AnchorStore.selection = FamilyActivitySelection()
        let restored = AnchorStore.selection
        XCTAssertTrue(restored.applicationTokens.isEmpty)
        XCTAssertTrue(restored.categoryTokens.isEmpty)
    }

    func testCorruptSelectionDataFallsBackToEmpty() {
        // Decoding failures must not crash the app on launch; an empty
        // selection just means nothing is blocked yet.
        suite.set(Data("not json".utf8), forKey: "blockedActivitySelection")
        XCTAssertTrue(AnchorStore.selection.applicationTokens.isEmpty)
    }
}
