import Foundation
import NovaCrypto
import SubstrateSdk

protocol PVScanMatcherProtocol {
    func match(code: String) -> PolkadotVaultAccount?
}

final class PVAccountScanMatcher {
    private let addressMatcher: PVScanAddressMatcherProtocol
    private let secretMatcher: PVScanSecretMatcherProtocol

    init(
        addressMatcher: PVScanAddressMatcherProtocol = PVScanAddressMatcher(
            prefix: Constants.substratePrefix,
            separator: Constants.separator
        ),
        secretMatcher: PVScanSecretMatcherProtocol = PVSecretScanMatcher(
            prefix: Constants.secretPrefix,
            separator: Constants.separator
        )
    ) {
        self.addressMatcher = addressMatcher
        self.secretMatcher = secretMatcher
    }
}

// MARK: - Private

private extension PVAccountScanMatcher {
    func extractAddress(from secret: PolkadotVaultSecret.ScanSecret.SecretType) throws -> AccountAddress {
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

    func extractSecret(
        from scanSecret: PolkadotVaultSecret.ScanSecret
    ) throws -> PolkadotVaultSecret {
        switch scanSecret.secret {
        case let .seed(seed):
            return PolkadotVaultSecret(
                secret: .seed(seed),
                genesisHash: scanSecret.genesisHash,
                username: scanSecret.username
            )
        case let .keypair(secret):
            let keypair = try SR25519KeypairFactory().createKeypairFromSecret(secret)

            return PolkadotVaultSecret(
                secret: .keypair(
                    publicKey: keypair.publicKey().rawData(),
                    secretKey: keypair.privateKey().rawData()
                ),
                genesisHash: scanSecret.genesisHash,
                username: scanSecret.username
            )
        }
    }
}

// MARK: - PVScanMatcherProtocol

extension PVAccountScanMatcher: PVScanMatcherProtocol {
    func match(code: String) -> PolkadotVaultAccount? {
        if let addressMatch = addressMatcher.match(code: code) {
            .public(addressMatch)
        } else if let scanSecret = secretMatcher.match(code: code),
                  let secret = try? extractSecret(from: scanSecret),
                  let address = try? extractAddress(from: scanSecret.secret) {
            .private(address: address, secret: secret)
        } else {
            nil
        }
    }
}

// MARK: Constants

private extension PVAccountScanMatcher {
    enum Constants {
        static let secretPrefix: String = "secret"
        static let substratePrefix: String = "substrate"
        static let separator: String = ":"
    }
}
