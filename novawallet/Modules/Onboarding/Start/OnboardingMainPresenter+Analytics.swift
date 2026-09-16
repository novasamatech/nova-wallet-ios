import Foundation
import NovaAnalytics

extension OnboardingMainPresenter: AnalyticsTracking {
    func trackOnboardingStartedIfNeeded() {
        guard !isOnboardingStartedTracked else {
            return
        }

        isOnboardingStartedTracked = true

        trackAnalytics(.onboardingStarted(source: hasExistingWallets ? .addWallet : .freshInstall))
    }
}
