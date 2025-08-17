import UIKit
import SubstrateSdk
import Foundation_iOS

struct MultisigOpValidationViewFactory {
    static func createPresenter(
        from view: ControllerBackedProtocol,
        validationNode: DelegatedSignValidationSequence.MultisigOperationNode,
        validationState: DelegatedSignValidationSharedData,
        completionClosure: @escaping DelegatedSignValidationCompletion
    ) -> MultisigOpValidationPresenterProtocol? {
        guard
            let chain = ChainRegistryFacade.sharedRegistry.getChain(
                for: validationNode.multisig.chainId
            ),
            let chainAsset = chain.utilityChainAsset(),
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(
                validationNode: validationNode,
                validationState: validationState,
                chainAsset: chainAsset
            )
        else {
            return nil
        }

        let wireframe = MultisigOpValidationWireframe()

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let dataValidatorFactory = MultisigDataValidatorFactory(
            presentable: wireframe,
            balanceViewModelFactoryFacade: BalanceViewModelFactoryFacade(
                priceAssetInfoFactory: priceAssetInfoFactory
            )
        )

        dataValidatorFactory.view = view

        let presenter = MultisigOpValidationPresenter(
            view: view,
            interactor: interactor,
            wireframe: wireframe,
            dataValidationFactory: dataValidatorFactory,
            chainAsset: chainAsset,
            signatoryName: validationNode.signatory.chainAccount.name,
            multisigName: validationNode.multisig.name,
            completionClosure: completionClosure,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        interactor.presenter = presenter

        return presenter
    }

    private static func createInteractor(
        validationNode: DelegatedSignValidationSequence.MultisigOperationNode,
        validationState: DelegatedSignValidationSharedData,
        chainAsset: ChainAsset
    ) -> MultisigOpValidationInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let balanceQueryFactory = WalletRemoteQueryWrapperFactory(
            chainRegistry: chainRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        return MultisigOpValidationInteractor(
            validationNode: validationNode,
            validationState: validationState,
            chainAsset: chainAsset,
            chainRegistry: chainRegistry,
            assetInfoOperationFactory: AssetStorageInfoOperationFactory(),
            multisigOperationFactory: MultisigStorageOperationFactory(
                storageRequestFactory: storageRequestFactory
            ),
            depositOperationFactory: MultisigDepositOperationFactory(
                chainRegitry: chainRegistry
            ),
            balanceQueryFactory: balanceQueryFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
