import RobinHood
import SoraKeystore
import FearlessUtils

protocol ExtrinsicServiceFactoryProtocol {
    func createService(
        accountId: AccountId,
        chainFormat: ChainFormat,
        cryptoType: MultiassetCryptoType
    ) -> ExtrinsicServiceProtocol

    func createSigningWrapper(
        metaId: String,
        account: ChainAccountResponse
    ) -> SigningWrapperProtocol

    func createService(accountItem: AccountItem) -> ExtrinsicServiceProtocol
    func createSigningWrapper(
        accountItem: AccountItem,
        connectionItem: ConnectionItem
    ) -> SigningWrapperProtocol
}

final class ExtrinsicServiceFactory {
    private let runtimeRegistry: RuntimeCodingServiceProtocol
    private let engine: JSONRPCEngine
    private let operationManager: OperationManagerProtocol

    init(
        runtimeRegistry: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine,
        operationManager: OperationManagerProtocol
    ) {
        self.runtimeRegistry = runtimeRegistry
        self.engine = engine
        self.operationManager = operationManager
    }
}

extension ExtrinsicServiceFactory: ExtrinsicServiceFactoryProtocol {
    func createService(
        accountId: AccountId,
        chainFormat: ChainFormat,
        cryptoType: MultiassetCryptoType
    ) -> ExtrinsicServiceProtocol {
        ExtrinsicService(
            accountId: accountId,
            chainFormat: chainFormat,
            cryptoType: cryptoType,
            runtimeRegistry: runtimeRegistry,
            engine: engine,
            operationManager: operationManager
        )
    }

    func createSigningWrapper(
        metaId: String,
        account: ChainAccountResponse
    ) -> SigningWrapperProtocol {
        SigningWrapper(
            keystore: Keychain(),
            metaId: metaId,
            accountResponse: account
        )
    }

    func createService(accountItem: AccountItem) -> ExtrinsicServiceProtocol {
        ExtrinsicService(
            address: accountItem.address,
            cryptoType: accountItem.cryptoType,
            runtimeRegistry: runtimeRegistry,
            engine: engine,
            operationManager: operationManager
        )
    }

    func createSigningWrapper(
        accountItem: AccountItem,
        connectionItem: ConnectionItem
    ) -> SigningWrapperProtocol {
        let settings = InMemorySettingsManager()
        settings.selectedAccount = accountItem
        settings.selectedConnection = connectionItem

        return SigningWrapper(keystore: Keychain(), settings: settings)
    }
}
