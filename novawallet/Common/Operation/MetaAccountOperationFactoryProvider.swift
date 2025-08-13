import Foundation
import Keystore_iOS

protocol MetaAccountOperationFactoryProviding {
    func createFactory(for origin: SecretSource.Origin) -> MetaAccountOperationFactoryProtocol
}

extension MetaAccountOperationFactoryProviding {
    func createAppDefaultFactory() -> MetaAccountOperationFactoryProtocol {
        createFactory(for: .appDefault)
    }
}

final class MetaAccountOperationFactoryProvider {
    let keystore: KeystoreProtocol

    init(keystore: KeystoreProtocol) {
        self.keystore = keystore
    }
}

extension MetaAccountOperationFactoryProvider: MetaAccountOperationFactoryProviding {
    func createFactory(for origin: SecretSource.Origin) -> MetaAccountOperationFactoryProtocol {
        switch origin {
        case .appDefault:
            MetaAccountOperationFactory(keystore: keystore)
        case .trustWallet:
            TrustWalletMetaAccountOperationFactory(keystore: keystore)
        }
    }
}
