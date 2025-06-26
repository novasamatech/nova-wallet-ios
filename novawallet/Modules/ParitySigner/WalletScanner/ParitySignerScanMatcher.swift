import Foundation
import SubstrateSdk

protocol ParitySignerScanMatcherProtocol {
    func match(code: QRCodeData) -> PolkadotVaultWalletUpdate?
}

final class ParitySignerScanMatcher {
    private enum Constants {
        static let type: String = "substrate"
        static let separator: String = ":"
    }

    private func matchHardwareAddressScheme(for type: String) -> HardwareWalletAddressScheme? {
        switch type {
        case "substrate":
            HardwareWalletAddressScheme.substrate
        case "ethereum":
            HardwareWalletAddressScheme.evm
        default:
            nil
        }
    }

    private func match(code: String) -> PolkadotVaultWalletUpdate? {
        let components = code.components(separatedBy: Constants.separator)

        guard components.count >= 3 else {
            return nil
        }

        guard let scheme = matchHardwareAddressScheme(for: components[0]) else {
            return nil
        }

        guard let genesisHash = try? Data(hexString: components[2]) else {
            return nil
        }

        let publicKey: Data? = if components.count >= 4 {
            try? Data(hexString: components[3])
        } else {
            nil
        }

        guard let accountId = try? components[1].toAccountId() else {
            return nil
        }

        return PolkadotVaultWalletUpdate(
            addressItems: [
                PolkadotVaultWalletUpdate.AddressItem(
                    accountId: accountId,
                    genesisHash: genesisHash,
                    scheme: scheme,
                    publicKey: publicKey
                )
            ]
        )
    }

    private func match(rawData: Data) -> PolkadotVaultWalletUpdate? {
        do {
            guard rawData.count > 3 else {
                return nil
            }

            guard ParitySignerNetworkType(rawValue: rawData[0]) == .substrate else {
                return nil
            }

            guard ParitySignerMessageType(rawValue: rawData[2]) == .ddExportKeyset else {
                return nil
            }

            let encodedRecords = rawData.subdata(in: 3 ..< rawData.count)

            let scaleDecoder = try ScaleDecoder(data: encodedRecords)

            let info = try ParitySignerExportAddress(scaleDecoder: scaleDecoder)

            let addressItems = try info.keysets.first?.derivedKeys.map { key in
                switch key.encryption {
                case .ed25519, .sr25519:
                    let accountId = try key.publicKeyOrAddress.toAccountId()

                    return PolkadotVaultWalletUpdate.AddressItem(
                        accountId: accountId,
                        genesisHash: key.genesisHash.value,
                        scheme: .substrate,
                        publicKey: accountId
                    )
                case .substrateEcdsa:
                    let publicKey = try Data(hexString: key.publicKeyOrAddress)
                    let accountId = try publicKey.publicKeyToAccountId()

                    return PolkadotVaultWalletUpdate.AddressItem(
                        accountId: accountId,
                        genesisHash: key.genesisHash.value,
                        scheme: .substrate,
                        publicKey: publicKey
                    )
                case .ethereumEcdsa:
                    let publicKey = try Data(hexString: key.publicKeyOrAddress)
                    let accountId = try publicKey.ethereumAddressFromPublicKey()

                    return PolkadotVaultWalletUpdate.AddressItem(
                        accountId: accountId,
                        genesisHash: key.genesisHash.value,
                        scheme: .evm,
                        publicKey: publicKey
                    )
                }
            }

            return addressItems.map { PolkadotVaultWalletUpdate(addressItems: $0) }
        } catch {
            return nil
        }
    }
}

extension ParitySignerScanMatcher: ParitySignerScanMatcherProtocol {
    func match(code: QRCodeData) -> PolkadotVaultWalletUpdate? {
        switch code {
        case let .plain(plainText):
            match(code: plainText)
        case let .raw(rawData):
            match(rawData: rawData)
        }
    }
}
