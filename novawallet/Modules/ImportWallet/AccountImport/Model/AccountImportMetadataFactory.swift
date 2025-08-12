import Foundation

protocol AccountImportMetadataFactoryProtocol {
    func deriveMetadata(for secretSource: SecretSource) -> MetaAccountImportMetadata
}

final class WalletImportMetadataFactory {}

private extension WalletImportMetadataFactory {
    func createAppDefaultMetadata() -> MetaAccountImportMetadata {
        MetaAccountImportMetadata(
            availableCryptoTypes: MultiassetCryptoType.substrateTypeList,
            defaultCryptoType: .sr25519,
            defaultSubstrateDerivationPath: nil,
            defaultEthereumDerivationPath: DerivationPathConstants.defaultEthereum
        )
    }

    func createTrustWalletMetadata() -> MetaAccountImportMetadata {
        MetaAccountImportMetadata(
            availableCryptoTypes: [.ed25519],
            defaultCryptoType: .ed25519,
            defaultSubstrateDerivationPath: DerivationPathConstants.trustWalletSubstrate,
            defaultEthereumDerivationPath: DerivationPathConstants.defaultEthereum
        )
    }
}

extension WalletImportMetadataFactory: AccountImportMetadataFactoryProtocol {
    func deriveMetadata(for secretSource: SecretSource) -> MetaAccountImportMetadata {
        switch secretSource {
        case let .mnemonic(origin):
            if origin == .trustWallet {
                return createTrustWalletMetadata()
            } else {
                return createAppDefaultMetadata()
            }

        case .keystore, .seed:
            return createAppDefaultMetadata()
        }
    }
}
