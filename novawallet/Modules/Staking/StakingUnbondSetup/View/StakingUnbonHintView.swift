import UIKit

final class StakingUnbondHintView: HintListView {
    var bondingDuration: String? {
        didSet {
            if bondingDuration != oldValue {
                applyHints()
            }
        }
    }

    var shouldResetRewardDestination: Bool = false {
        didSet {
            if shouldResetRewardDestination != oldValue {
                applyHints()
            }
        }
    }

    var locale = Locale.current {
        didSet {
            if oldValue != locale {
                applyHints()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        applyHints()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyHints() {
        var hints: [String] = []

        if let bondingDuration = bondingDuration {
            let bondingDurationHint = R.string(preferredLanguages: locale.rLanguages).localizable.stakingHintUnstakeFormat_v2_2_0(bondingDuration)

            hints.append(bondingDurationHint)
        }

        if shouldResetRewardDestination {
            let killStashHint = R.string(preferredLanguages: locale.rLanguages).localizable.stakingHintUnbondKillsStash()

            hints.append(killStashHint)
        }

        hints.append(contentsOf: [
            R.string(preferredLanguages: locale.rLanguages).localizable.stakingHintNoRewards_v2_2_0(),
            R.string(preferredLanguages: locale.rLanguages).localizable.stakingHintRedeem_v2_2_0()
        ])

        bind(texts: hints)
    }
}
