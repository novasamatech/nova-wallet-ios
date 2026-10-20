import Foundation
import NovaAnalytics

final class SubtensorBrowseAbandonTracker: AnalyticsTracking {
    private var stage = StakingStage.subnetSelect
    private var target: StakingAnalyticsTarget?
    private var isProceeded = false

    deinit {
        guard !isProceeded else {
            return
        }

        trackAnalytics(.subtensorStakingAbandoned(stage: stage, target: target))
    }

    func enter(_ stage: StakingStage, target: StakingAnalyticsTarget?) {
        self.stage = stage
        self.target = target
    }

    func markProceeded() {
        isProceeded = true
    }
}

struct SubtensorValidatorSelectAnalytics {
    let recommendedHotkey: AccountId?
    let abandonTracker: SubtensorBrowseAbandonTracker?
}
