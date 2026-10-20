import Foundation

enum SubtensorShieldEligibility {
    static func supports(walletType: MetaAccountModelType) -> Bool {
        walletType == .secrets
    }
}
