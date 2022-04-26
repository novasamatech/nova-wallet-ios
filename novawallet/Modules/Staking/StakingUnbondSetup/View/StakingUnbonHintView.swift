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
            let bondingDurationHint = R.string.localizable.stakingHintUnstakeFormat_v2_2_0(
                bondingDuration,
                preferredLanguages: locale.rLanguages
            )

            hints.append(bondingDurationHint)
        }

        if shouldResetRewardDestination {
            let killStashHint = R.string.localizable.stakingHintUnbondKillsStash(
                preferredLanguages: locale.rLanguages
            )

            hints.append(killStashHint)
        }

        hints.append(contentsOf: [
            R.string.localizable.stakingHintNoRewards_V2_2_0(preferredLanguages: locale.rLanguages),
            R.string.localizable.stakingHintRedeem_v2_2_0(preferredLanguages: locale.rLanguages)
        ])

        bind(texts: hints)
    }
}
