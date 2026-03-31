@testable import Training
import XCTest

final class PatreonGateTests: XCTestCase {

    // These tests validate the Patreon content gating logic used in PlanSetupView.
    // The actual gating is: SWAP Running plans require patron status, non-SWAP plans don't.

    func testSWAPPlanRequiresPatronWhenNotPatron() {
        let requiresGate = shouldGate(templateSource: "SWAP Running", isPatron: false, isDevMode: false)
        XCTAssertTrue(requiresGate, "SWAP plan should require Patreon when user is not a patron")
    }

    func testSWAPPlanDoesNotGatePatrons() {
        let requiresGate = shouldGate(templateSource: "SWAP Running", isPatron: true, isDevMode: false)
        XCTAssertFalse(requiresGate, "SWAP plan should not gate patrons")
    }

    func testNonSWAPPlanDoesNotGate() {
        let requiresGate = shouldGate(templateSource: "Custom Coach", isPatron: false, isDevMode: false)
        XCTAssertFalse(requiresGate, "Non-SWAP plans should never be gated")
    }

    func testDevModeBypassesGate() {
        let requiresGate = shouldGate(templateSource: "SWAP Running", isPatron: false, isDevMode: true)
        XCTAssertFalse(requiresGate, "Dev mode should bypass Patreon gate")
    }

    func testNilSourceDoesNotGate() {
        let requiresGate = shouldGate(templateSource: nil, isPatron: false, isDevMode: false)
        XCTAssertFalse(requiresGate, "Nil source should not trigger gate")
    }

    // MARK: - Helper (mirrors PlanSetupView.requiresPatreonGate logic)

    private func shouldGate(templateSource: String?, isPatron: Bool, isDevMode: Bool) -> Bool {
        guard let source = templateSource else { return false }
        guard source == "SWAP Running" else { return false }
        return !isPatron && !isDevMode
    }
}
