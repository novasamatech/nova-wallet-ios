import Foundation
@testable import novawallet
import NovaCrypto
import Keystore_iOS
import Operation_iOS
import SubstrateSdk

final class AccountCreationHelper {
    static func createMetaAccountFromMnemonic(
        _ mnemonicString: String? = nil,
        cryptoType: MultiassetCryptoType,
        name: String = "novawallet",
        derivationPath: String = "",
        ethereumPath: String = DerivationPathConstants.defaultEthereum,
        keychain: KeystoreProtocol,
        settings: SelectedWalletSettings
    ) throws {
        let mnemonic: IRMnemonicProtocol

        if let mnemonicString = mnemonicString {
            mnemonic = try IRMnemonicCreator().mnemonic(fromList: mnemonicString)
        } else {
            mnemonic = try IRMnemonicCreator().randomMnemonic(.entropy128)
        }

        let request = MetaAccountCreationRequest(
            username: name,
            derivationPath: derivationPath,
            ethereumDerivationPath: ethereumPath,
            cryptoType: cryptoType)

        let operation = MetaAccountOperationFactory(keystore: keychain)
            .newSecretsMetaAccountOperation(request: request, mnemonic: mnemonic)

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        let accountItem = try operation
            .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        try selectMetaAccount(accountItem, settings: settings)
    }
    
    static func addMnemonicChainAccount(
        to wallet: MetaAccountModel,
        chainId: ChainModel.Id,
        mnemonicString: String? = nil,
        cryptoType: MultiassetCryptoType,
        derivationPath: String = "",
        keychain: KeystoreProtocol,
        settings: SelectedWalletSettings
    ) throws {
        let mnemonic: IRMnemonicProtocol

        if let mnemonicString = mnemonicString {
            mnemonic = try IRMnemonicCreator().mnemonic(fromList: mnemonicString)
        } else {
            mnemonic = try IRMnemonicCreator().randomMnemonic(.entropy128)
        }
        
        let request = ChainAccountImportMnemonicRequest(
            mnemonic: mnemonic.toString(),
            derivationPath: derivationPath,
            cryptoType: cryptoType
        )
        
        let operation = MetaAccountOperationFactory(keystore: keychain)
            .replaceChainAccountOperation(
                for: wallet,
                request: request,
                chainId: chainId
            )

        OperationQueue().addOperations([operation], waitUntilFinished: true)
        
        let accountItem = try operation
            .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        try selectMetaAccount(accountItem, settings: settings)
    }
    
    static func addSeedChainAccount(
        to wallet: MetaAccountModel,
        chainId: ChainModel.Id,
        seed: String,
        cryptoType: MultiassetCryptoType,
        derivationPath: String = "",
        keychain: KeystoreProtocol,
        settings: SelectedWalletSettings
    ) throws {
        let request = ChainAccountImportSeedRequest(
            seed: seed,
            derivationPath: derivationPath,
            cryptoType: cryptoType
        )
        
        let operation = MetaAccountOperationFactory(keystore: keychain)
            .replaceChainAccountOperation(
                for: wallet,
                request: request,
                chainId: chainId
            )

        OperationQueue().addOperations([operation], waitUntilFinished: true)
        
        let accountItem = try operation
            .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        try selectMetaAccount(accountItem, settings: settings)
    }

    static func createMetaAccountFromSeed(
        _ seed: String,
        cryptoType: MultiassetCryptoType,
        name: String = "novawallet",
        derivationPath: String = "",
        keychain: KeystoreProtocol,
        settings: SelectedWalletSettings
    ) throws {
        let request = MetaAccountImportSeedRequest(
            seed: seed,
            username: name,
            derivationPath: derivationPath,
            cryptoType: cryptoType
        )

        let operation = MetaAccountOperationFactory(keystore: keychain)
            .newSecretsMetaAccountOperation(request: request)

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        let accountItem = try operation
        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        try selectMetaAccount(accountItem, settings: settings)
    }

    static func createMetaAccountFromKeystore(
        _ filename: String,
        password: String,
        keychain: KeystoreProtocol,
        settings: SelectedWalletSettings
    ) throws {
        guard let url = Bundle(for: AccountCreationHelper.self)
                .url(forResource: filename, withExtension: "json") else { return }

        let data = try Data(contentsOf: url)

        let definition = try JSONDecoder().decode(KeystoreDefinition.self, from: data)

        let info = try AccountImportJsonFactory().createInfo(from: definition)
        let cryptoType = info.cryptoType ?? .sr25519

        return try createMetaAccountFromKeystoreData(
            data,
            password: password,
            keychain: keychain,
            settings: settings,
            cryptoType: cryptoType
        )
    }

    static func createMetaAccountFromKeystoreData(
        _ data: Data,
        password: String,
        keychain: KeystoreProtocol,
        settings: SelectedWalletSettings,
        cryptoType: MultiassetCryptoType,
        username: String = "username"
    ) throws {
        guard let keystoreString = String(data: data, encoding: .utf8) else { return }

        let request = MetaAccountImportKeystoreRequest(
            keystore: keystoreString,
            password: password,
            username: username,
            cryptoType: cryptoType
        )

        let operation = MetaAccountOperationFactory(keystore: keychain)
            .newSecretsMetaAccountOperation(request: request)

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        let accountItem = try operation
        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        try selectMetaAccount(accountItem, settings: settings)
    }

    static func createSubstrateLedgerAccount(
        from app: SupportedLedgerApp,
        keychain: KeystoreProtocol,
        settings: SelectedWalletSettings,
        username: String = "username",
        accountIndex: UInt32 = 0
    ) throws {
        let accountId = AccountId.random(of: 32)!
        
        let derivationPath = LedgerPathBuilder().appendingStandardJunctions(
            coin: app.coin,
            accountIndex: accountIndex
        ).build()
        
        let chainAccount = ChainAccountModel(
            chainId: app.chainId,
            accountId: accountId,
            publicKey: accountId,
            cryptoType: LedgerConstants.defaultCryptoScheme.walletCryptoType.rawValue,
            proxy: nil
        )
        
        let metaAccount = MetaAccountModel(
            metaId: UUID().uuidString,
            name: username,
            substrateAccountId: nil,
            substrateCryptoType: nil,
            substratePublicKey: nil,
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            chainAccounts: [chainAccount],
            type: .ledger
        )
        
        let derivPathTag = KeystoreTagV2.substrateDerivationTagForMetaId(
            metaAccount.identifier,
            accountId: accountId
        )
        
        try keychain.saveKey(derivationPath, with: derivPathTag)
        
        try selectMetaAccount(metaAccount, settings: settings)
    }
    
    static func createSubstrateGenericLedgerWallet(
        keychain: KeystoreProtocol,
        settings: SelectedWalletSettings,
        username: String = "username",
        accountIndex: UInt32 = 0
    ) throws {
        let accountId = AccountId.random(of: 32)!
        
        let derivationPath = LedgerPathBuilder().appendingStandardJunctions(
            coin: GenericLedgerPolkadotApplication.coin,
            accountIndex: accountIndex
        ).build()
        
        let factory = GenericLedgerWalletOperationFactory()
        
        let operation = factory.createSaveOperation(
            for: .init(
                accountId: accountId,
                publicKey: accountId,
                cryptoType: LedgerConstants.defaultCryptoScheme.walletCryptoType,
                derivationPath: derivationPath
            ),
            name: username,
            keystore: keychain,
            settings: settings
        )
        
        let operationQueue = OperationQueue()
        
        operationQueue.addOperations([operation], waitUntilFinished: true)
        
        _ = try operation.extractNoCancellableResultData()
    }
    
    static func createWatchOnlyMetaAccount(
        from substrateAddress: AccountAddress,
        ethereumAddress: AccountAddress?,
        settings: SelectedWalletSettings,
        username: String = "username"
    ) throws {
        let request = WatchOnlyWallet(
            name: username,
            substrateAddress: substrateAddress,
            evmAddress: ethereumAddress
        )
        
        let factory = WatchOnlyWalletOperationFactory()
        
        let operation = factory.newWatchOnlyWalletOperation(for: request)
        
        let operationQueue = OperationQueue()
        
        operationQueue.addOperation(operation)
        
        let wallet = try operation.extractNoCancellableResultData()
        
        try selectMetaAccount(wallet, settings: settings)
    }
    
    static func selectMetaAccount(_ accountItem: MetaAccountModel, settings: SelectedWalletSettings) throws {
        settings.save(value: accountItem)
        settings.setup()
    }
}
