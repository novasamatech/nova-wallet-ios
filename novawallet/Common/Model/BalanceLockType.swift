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
                return R.string.localizable.walletAccountLocksVesting(
                    preferredLanguages: locale.rLanguages
                )
            case .staking:
                return R.string.localizable.stakingTitle(
                    preferredLanguages: locale.rLanguages
                )
            case .democracy:
                return R.string.localizable.walletAccountLocksDemocracyVersion1(
                    preferredLanguages: locale.rLanguages
                )
            case .governance:
                return R.string.localizable.walletAccountLocksDemocracyVersion2(
                    preferredLanguages: locale.rLanguages
                )
            case .elections:
                return R.string.localizable.walletAccountLocksElections(
                    preferredLanguages: locale.rLanguages
                )
            }
        }
    }
}
