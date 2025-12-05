import Foundation

protocol PolkadotVaultScanAddressMatcherProtocol {
    func match(code: String) -> PolkadotVaultAddressScan?
}

final class PolkadotVaultScanAddressMatcher {
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

// MARK: - PolkadotVaultScanAddressMatcherProtocol

extension PolkadotVaultScanAddressMatcher: PolkadotVaultScanAddressMatcherProtocol {
    func match(code: String) -> PolkadotVaultAddressScan? {
        let components = code.components(separatedBy: separator)

        guard
            components.first == prefix,
            components.count >= Constants.minComponents,
            let genesisHash = try? Data(hexString: components[2])
        else { return nil }

        return PolkadotVaultAddressScan(
            address: components[1],
            genesisHash: genesisHash
        )
    }
}

// MARK: - Constants

private extension PolkadotVaultScanAddressMatcher {
    enum Constants {
        static let minComponents = 3
    }
}
