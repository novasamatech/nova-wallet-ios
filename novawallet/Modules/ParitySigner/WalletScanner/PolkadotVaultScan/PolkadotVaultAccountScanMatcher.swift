import Foundation

protocol PolkadotVaultScanMatcherProtocol {
    func match(code: String) -> PolkadotVaultAccountScan?
}

final class PolkadotVaultAccountScanMatcher {
    private let addressMatcher: PolkadotVaultScanAddressMatcherProtocol
    private let secretMatcher: PolkadotVaultScanSecretMatcherProtocol
    
    init(
        addressMatcher: PolkadotVaultScanAddressMatcherProtocol = PolkadotVaultScanAddressMatcher(
            prefix: Constants.substratePrefix,
            separator: Constants.separator
        ),
        secretMatcher: PolkadotVaultScanSecretMatcherProtocol = PolkadotVaultSecretScanMatcher(
            prefix: Constants.secretPrefix,
            separator: Constants.separator
        )
    ) {
        self.addressMatcher = addressMatcher
        self.secretMatcher = secretMatcher
    }
}

// MARK: - PolkadotVaultScanMatcherProtocol

extension PolkadotVaultAccountScanMatcher: PolkadotVaultScanMatcherProtocol {
    func match(code: String) -> PolkadotVaultAccountScan? {
        if let addressMatch = addressMatcher.match(code: code) {
            .public(addressMatch)
        } else if let secretMatch = secretMatcher.match(code: code) {
            .private(secretMatch)
        } else {
            nil
        }
    }
}

// MARK: Constants

private extension PolkadotVaultAccountScanMatcher {
    enum Constants {
        static let secretPrefix: String = "secret"
        static let substratePrefix: String = "substrate"
        static let separator: String = ":"
    }
}
