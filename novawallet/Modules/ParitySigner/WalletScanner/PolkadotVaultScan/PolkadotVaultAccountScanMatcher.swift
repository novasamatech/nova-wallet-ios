import Foundation
import NovaCrypto
import SubstrateSdk

protocol PolkadotVaultScanMatcherProtocol {
    func match(code: String) -> PolkadotVaultAccount?
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

// MARK: - Private

private extension PolkadotVaultAccountScanMatcher {
    func extractAddress(from secret: ScanSecret) throws -> AccountAddress {
        let publicKey = switch secret {
        case let .seed(seed):
            try SR25519KeypairFactory().createKeypairFromSeed(
                seed,
                chaincodeList: []
            ).publicKey()
        case let .keypair(secret):
            try SR25519KeypairFactory().createPublicKeyFromSecret(secret)
        }
        
        return try publicKey.rawData().toAddress(using: .multichainDisplayFormat)
    }
}

// MARK: - PolkadotVaultScanMatcherProtocol

extension PolkadotVaultAccountScanMatcher: PolkadotVaultScanMatcherProtocol {
    func match(code: String) -> PolkadotVaultAccount? {
        if let addressMatch = addressMatcher.match(code: code) {
            .public(addressMatch)
        } else if let secretMatch = secretMatcher.match(code: code),
                  let address = try? extractAddress(code: secretMatch.secret)
        {
            .private(address, secretMatch)
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
