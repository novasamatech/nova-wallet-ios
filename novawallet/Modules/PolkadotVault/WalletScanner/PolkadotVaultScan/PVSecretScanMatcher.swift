import Foundation

protocol PVScanSecretMatcherProtocol {
    func match(code: String) -> PolkadotVaultSecret.ScanSecret?
}

final class PVSecretScanMatcher {
    private let prefix: String
    private let separator: String

    init(
        prefix: String,
        separator: String
    ) {
        self.prefix = prefix
        self.separator = separator
    }
}

// MARK: - PVScanSecretMatcherProtocol

extension PVSecretScanMatcher: PVScanSecretMatcherProtocol {
    func match(code: String) -> PolkadotVaultSecret.ScanSecret? {
        let components = code.components(separatedBy: separator)

        guard
            components.count >= Constants.minComponents,
            components.first == prefix,
            let secretData = try? Data(hexString: components[1]),
            let genesisHash = try? Data(hexString: components[2])
        else { return nil }

        let scanSecret: PolkadotVaultSecret.ScanSecret.SecretType? = if secretData.count == Constants.seedLength {
            .seed(secretData)
        } else if secretData.count == Constants.keypairLength {
            .keypair(secretData)
        } else {
            .none
        }

        guard let scanSecret else { return nil }

        let userName: String? = if components.count == Constants.maxComponents {
            components.last
        } else {
            nil
        }

        return PolkadotVaultSecret.ScanSecret(
            secret: scanSecret,
            genesisHash: genesisHash,
            username: userName
        )
    }
}

// MARK: - Constants

private extension PVSecretScanMatcher {
    enum Constants {
        static let seedLength = 32
        static let keypairLength = 64
        static let minComponents = 3
        static let maxComponents = 4
    }
}
