import UIKit
import SubstrateSdk
import Foundation_iOS

struct MultisigValidationViewFactory {
    static func createView(
        from viewController: UIViewController,
        resolvedSigner: ExtrinsicSenderResolution.ResolvedDelegate,
        calls: [JSON],
        completionClosure: @escaping DelegatedSignValidationCompletion
    ) -> MultisigValidationPresenterProtocol? {
        let multisigWallet = resolvedSigner.allWallets.first {
            $0.metaId == resolvedSigner.delegatedAccount.metaId
        }
        
        guard
            let multisigWallet,
            let multisigContext = multisigWallet.multisigAccount?.multisig
        else { return nil }
        
        let validationMode = createValidationMode(
            multisigWallet: multisigWallet,
            resolvedSigner: resolvedSigner
        )
        
        guard
            let validationMode,
            let utilityChainAsset = resolvedSigner.chain.utilityChainAsset(),
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(
                resolvedSigner: resolvedSigner,
                validaitonMode: validationMode,
                multisigContext: multisigContext,
                calls: calls
            )
        else {
            return nil
        }

        let wireframe = MultisigValidationWireframe()

        let view = ControllerBacked(controller: viewController)

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let dataValidatorFactory = MultisigDataValidatorFactory(
            presentable: wireframe,
            balanceViewModelFactoryFacade: BalanceViewModelFactoryFacade(
                priceAssetInfoFactory: priceAssetInfoFactory
            )
        )

        dataValidatorFactory.view = view

        let presenter = MultisigValidationPresenter(
            view: view,
            interactor: interactor,
            validationMode: validationMode,
            wireframe: wireframe,
            dataValidationFactory: dataValidatorFactory,
            chainAsset: utilityChainAsset,
            completionClosure: completionClosure,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        interactor.presenter = presenter

        return presenter
    }
    
    private static func createValidationMode(
        multisigWallet: MetaAccountModel,
        resolvedSigner: ExtrinsicSenderResolution.ResolvedDelegate
    ) -> MultisigValidationMode? {
        guard
            let signerResponse = resolvedSigner.delegateAccount,
            let multisigContext = multisigWallet.multisigAccount?.multisig
        else { return nil }
        
        let resolvedSignerId = signerResponse.chainAccount.accountId
        
        let validationMode: MultisigValidationMode
        
        if multisigContext.signatory == resolvedSignerId {
            validationMode = .rootSigner(signer: signerResponse)
        } else {
            let request = resolvedSigner.chain.accountRequest()
            
            guard let signerDelegateResponse = multisigWallet.fetchMetaChainAccount(for: request) else {
                return nil
            }
            
            validationMode = .delegatedSigner(signer: signerResponse, delegate: signerDelegateResponse)
        }
        
        return validationMode
    }

    private static func createInteractor(
        resolvedSigner: ExtrinsicSenderResolution.ResolvedDelegate,
        validaitonMode: MultisigValidationMode,
        multisigContext: DelegatedAccount.MultisigAccountModel,
        calls: [JSON]
    ) -> MultisigValidationInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let chain = resolvedSigner.chain
                
        guard
            let multisigAccount = resolvedSigner.delegateAccount,
            let chainAsset = chain.utilityChainAsset(),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let connection = chainRegistry.getConnection(for: chain.chainId)
        else {
            return nil
        }

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(account: multisigAccount.chainAccount, chain: chain)

        let assetInfoOperationFactory = AssetStorageInfoOperationFactory()

        let balanceQueryFactory = WalletRemoteQueryWrapperFactory(
            requestFactory: StorageRequestFactory(
                remoteFactory: StorageKeyFactory(),
                operationManager: OperationManagerFacade.sharedManager
            ),
            runtimeProvider: runtimeProvider,
            connection: connection,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        return .init(
            validationMode: validaitonMode,
            multisigContext: multisigContext,
            extrinsicService: extrinsicService,
            runtimeProvider: runtimeProvider,
            assetInfoOperationFactory: assetInfoOperationFactory,
            balanceQueryFactory: balanceQueryFactory,
            calls: calls,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            chainAsset: chainAsset
        )
    }
}
