import Foundation
import Foundation_iOS

enum LockType: String {
    case staking
    case vesting
    case democracy = "democrac"
    case elections = "phrelect"
    case governance = "pyconvot"

    static var locksOrder: [Self] = [.vesting, .staking, .democracy, .governance, .elections]

    var displayType: LocalizableResource<String> {
        LocalizableResource<String> { locale in
            switch self {
            case .vesting:
                return R.string(preferredLanguages: locale.rLanguages).localizable.walletAccountLocksVesting()
            case .staking:
                return R.string(preferredLanguages: locale.rLanguages).localizable.stakingTitle()
            case .democracy:
                return R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.walletAccountLocksDemocracyVersion1()
            case .governance:
                return R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.walletAccountLocksDemocracyVersion2()
            case .elections:
                return R.string(preferredLanguages: locale.rLanguages).localizable.walletAccountLocksElections()
            }
        }
    }
}
