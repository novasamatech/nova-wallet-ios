import Foundation
import SubstrateSdk

protocol AccountImportJsonFactoryProtocol {
    func createInfo(from definition: KeystoreDefinition) throws -> MetaAccountImportPreferredInfo
}

final class AccountImportJsonFactory {
    func createInfo(from definition: KeystoreDefinition) throws -> MetaAccountImportPreferredInfo {
        let info = try KeystoreInfoFactory().createInfo(from: definition)

        let genesisHash: Data? = {
            if let definitionGenesisHashString = definition.meta?.genesisHash {
                return try? Data(hexString: definitionGenesisHashString)
            } else {
                return nil
            }
        }()

        return MetaAccountImportPreferredInfo(
            username: info.meta?.name,
            cryptoType: MultiassetCryptoType(secretType: info.secretType),
            genesisHash: genesisHash
        )
    }
}
