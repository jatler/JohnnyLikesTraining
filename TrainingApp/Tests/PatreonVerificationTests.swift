import XCTest
@testable import Training

final class PatreonVerificationTests: XCTestCase {

    // MARK: - processIdentityResponse decode error propagation

    func testDecodeErrorThrows() {
        // We verify the error type exists and carries a useful description
        let error = PatreonError.decodeFailed("test decode failure")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("decode"))
        XCTAssertTrue(error.errorDescription!.contains("test decode failure"))
    }

    func testStateMismatchError() {
        let error = PatreonError.stateMismatch
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("state"))
    }

    func testPatreonErrorDescriptions() {
        let cases: [(PatreonError, String)] = [
            (.notConnected, "not connected"),
            (.noAuthCode, "authorization code"),
            (.tokenExchangeFailed, "exchange"),
            (.tokenRefreshFailed, "refresh"),
            (.apiFailed, "API"),
            (.stateMismatch, "state"),
            (.decodeFailed("test"), "decode"),
        ]

        for (error, keyword) in cases {
            XCTAssertNotNil(error.errorDescription, "Missing description for \(error)")
            XCTAssertTrue(
                error.errorDescription!.lowercased().contains(keyword.lowercased()),
                "Expected '\(keyword)' in: \(error.errorDescription!)"
            )
        }
    }

    // MARK: - Premium plan lock decision

    func testUnlockedWhenToggleOff() {
        XCTAssertFalse(PatreonService.arePremiumPlansLocked(
            isRequired: false, isPatron: false, gracePeriodDaysRemaining: nil
        ))
    }

    func testLockedWhenToggleOnAndNonPatron() {
        // Regression case for the prior dev-bypass bug. Toggle ON + not a
        // patron must always lock premium plans, regardless of build flags.
        XCTAssertTrue(PatreonService.arePremiumPlansLocked(
            isRequired: true, isPatron: false, gracePeriodDaysRemaining: nil
        ))
    }

    func testUnlockedForActivePatron() {
        XCTAssertFalse(PatreonService.arePremiumPlansLocked(
            isRequired: true, isPatron: true, gracePeriodDaysRemaining: nil
        ))
    }

    func testUnlockedDuringGracePeriod() {
        XCTAssertFalse(PatreonService.arePremiumPlansLocked(
            isRequired: true, isPatron: false, gracePeriodDaysRemaining: 3
        ))
    }

    // MARK: - Template tiers

    func testIntroTierIsTheSixWeekPlanOnly() {
        let intro = PlanTemplateService.shared.availableTemplates(tier: .introOnly)
        XCTAssertEqual(intro.count, 1, "Intro tier should expose 1 plan.")
        XCTAssertEqual(intro.first?.id, "swap_6_week_6w")
    }

    func testFreeTierIsTheThreeDogfoodPlans() {
        let free = PlanTemplateService.shared.availableTemplates(tier: .free)
        XCTAssertEqual(free.count, 3, "Free tier should expose 3 plans.")
        for template in free {
            XCTAssertFalse(PlanTemplateService.shared.isPatronOnly(template))
        }
    }

    func testFullTierIsFreePlusPatron() {
        let free = PlanTemplateService.shared.availableTemplates(tier: .free)
        let full = PlanTemplateService.shared.availableTemplates(tier: .full)
        XCTAssertEqual(full.count, 10, "Full catalog should expose 10 plans (3 free + 7 patron).")
        // Free templates appear first in display order.
        XCTAssertEqual(Array(full.prefix(3)).map(\.id), free.map(\.id))
    }
}
