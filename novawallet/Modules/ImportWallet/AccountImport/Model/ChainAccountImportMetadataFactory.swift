import Foundation

final class ChainAccountImportMetadataFactory {
    let isEthereumBased: Bool

    init(isEthereumBased: Bool) {
        self.isEthereumBased = isEthereumBased
    }
}

extension ChainAccountImportMetadataFactory: AccountImportMetadataFactoryProtocol {
    func deriveMetadata(for _: SecretSource) -> MetaAccountImportMetadata {
        let availableCryptoTypes: [MultiassetCryptoType] = isEthereumBased ? [.ethereumEcdsa] :
            MultiassetCryptoType.substrateTypeList
        let defaultCryptoType: MultiassetCryptoType = isEthereumBased ? .ethereumEcdsa : .sr25519

        return MetaAccountImportMetadata(
            availableCryptoTypes: availableCryptoTypes,
            defaultCryptoType: defaultCryptoType,
            defaultSubstrateDerivationPath: nil,
            defaultEthereumDerivationPath: DerivationPathConstants.defaultEthereum
        )
    }
}
