import XCTest
@testable import novawallet

final class AnalyticsConsentPromptTests: XCTestCase {
    private func assertPromptShown(
        _ expected: Bool,
        hasWallet: Bool = true,
        promptSeen: Bool = false,
        isAvailable: Bool = true,
        isEnabled: Bool = false,
        legalStatus: LegalConsentStatus = .notRequired,
        legalShownThisLaunch: Bool = false,
        line: UInt = #line
    ) {
        let shown = AnalyticsConsentPromptGate.isPossible(
            hasWallet: hasWallet,
            isPromptSeen: promptSeen,
            isAvailable: isAvailable,
            isEnabled: isEnabled,
            didPresentLegalConsentThisLaunch: legalShownThisLaunch
        ) && AnalyticsConsentPromptGate.allows(legalStatus: legalStatus)

        XCTAssertEqual(shown, expected, line: line)
    }

    func testPromptShownOnAFreshConsentedInstall() {
        assertPromptShown(true)
    }

    func testNoPromptWithoutAWallet() {
        assertPromptShown(false, hasWallet: false)
    }

    func testNoPromptWhenAlreadySeen() {
        assertPromptShown(false, promptSeen: true)
    }

    func testNoPromptWhenUnavailable() {
        assertPromptShown(false, isAvailable: false)
    }

    func testNoPromptWhenAlreadyEnabled() {
        assertPromptShown(false, isEnabled: true)
    }

    func testNoPromptOnTheLaunchThatShowedTheLegalSheet() {
        assertPromptShown(false, legalShownThisLaunch: true)
    }

    func testNoPromptWhenLegalConsentIsStillRequired() {
        assertPromptShown(false, legalStatus: .required)
    }

    func testNoPromptWhenLegalStatusIsUnavailable() {
        assertPromptShown(false, legalStatus: .unavailable)
    }

    func testTheLegalFetchIsSkippedWhenTheLocalConditionsAlreadyFail() {
        XCTAssertFalse(
            AnalyticsConsentPromptGate.isPossible(
                hasWallet: false,
                isPromptSeen: false,
                isAvailable: true,
                isEnabled: false,
                didPresentLegalConsentThisLaunch: false
            )
        )
    }

    func testTheConsentActionRunsAfterLegalAndBeforePushSetup() {
        let recorder = LaunchQueueRecorder()

        let queue = OnLaunchActionsQueue(
            possibleActions: [
                OnLaunchAction.LegalConsent(),
                OnLaunchAction.AnalyticsConsent(),
                OnLaunchAction.PushNotificationsSetup()
            ]
        )
        queue.delegate = recorder
        recorder.queue = queue

        queue.runNext()

        XCTAssertEqual(recorder.visited, ["legal", "analytics", "push"])
    }
}

// MARK: - Helpers

private final class LaunchQueueRecorder: OnLaunchActionsQueueDelegate {
    var visited: [String] = []
    var queue: OnLaunchActionsQueueProtocol?

    func onLaunchProcessLegalConsent(_: OnLaunchAction.LegalConsent) {
        visited.append("legal")
        queue?.runNext()
    }

    func onLaunchProcessAnalyticsConsent(_: OnLaunchAction.AnalyticsConsent) {
        visited.append("analytics")
        queue?.runNext()
    }

    func onLaunchProccessPushNotificationsSetup(_: OnLaunchAction.PushNotificationsSetup) {
        visited.append("push")
        queue?.runNext()
    }

    func onLaunchProcessMultisigNotificationPromo(_: OnLaunchAction.MultisigNotificationsPromo) {
        visited.append("multisig")
        queue?.runNext()
    }

    func onLaunchProcessAHMInfoSetup(_: OnLaunchAction.AHMInfoSetup) {
        visited.append("ahm")
        queue?.runNext()
    }
}
