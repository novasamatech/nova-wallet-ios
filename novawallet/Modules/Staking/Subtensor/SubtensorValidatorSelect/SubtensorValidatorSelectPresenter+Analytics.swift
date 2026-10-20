import Foundation
import NovaAnalytics

extension SubtensorValidatorSelectPresenter: AnalyticsTracking {
    func trackValidatorChanged(source: ValidatorChangeSource, unusualApyFilter: Bool) {
        trackAnalytics(
            .validatorChanged(target: target.analyticsTarget, source: source, unusualApyFilter: unusualApyFilter)
        )
    }
}
