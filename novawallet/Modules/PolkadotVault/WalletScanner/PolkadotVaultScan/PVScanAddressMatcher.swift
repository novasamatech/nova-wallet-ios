import Foundation

protocol PVScanAddressMatcherProtocol {
    func match(code: String) -> PolkadotVaultAddress?
}

final class PVScanAddressMatcher {
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

// MARK: - PVScanAddressMatcherProtocol

extension PVScanAddressMatcher: PVScanAddressMatcherProtocol {
    func match(code: String) -> PolkadotVaultAddress? {
        let components = code.components(separatedBy: separator)

        guard
            components.first == prefix,
            components.count >= Constants.minComponents,
            let genesisHash = try? Data(hexString: components[2])
        else { return nil }

        return PolkadotVaultAddress(
            address: components[1],
            genesisHash: genesisHash
        )
    }
}

// MARK: - Constants

private extension PVScanAddressMatcher {
    enum Constants {
        static let minComponents = 3
    }
}
