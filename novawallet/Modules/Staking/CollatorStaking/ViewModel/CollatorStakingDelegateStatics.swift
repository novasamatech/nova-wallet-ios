import Foundation
import Foundation_iOS

struct CollatorStakingDelegateStatics {
    let delegateTitle: LocalizableResource<String>
    let selectDelegateTitle: LocalizableResource<String>
    let selectDelegateHint: LocalizableResource<String>
    let newDelegateTitle: LocalizableResource<String>

    static var collator: CollatorStakingDelegateStatics {
        CollatorStakingDelegateStatics(
            delegateTitle: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.parachainStakingCollator()
            },
            selectDelegateTitle: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.parachainStakingSelectCollator()
            },
            selectDelegateHint: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.parachainStakingHintSelectCollator()
            },
            newDelegateTitle: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.commonNewCollator()
            }
        )
    }

    static var subtensorValidator: CollatorStakingDelegateStatics {
        CollatorStakingDelegateStatics(
            delegateTitle: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.stakingRewardDetailsValidator()
            },
            selectDelegateTitle: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorSelectValidator()
            },
            selectDelegateHint: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorSelectValidatorHint()
            },
            newDelegateTitle: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorNewValidator()
            }
        )
    }
}
