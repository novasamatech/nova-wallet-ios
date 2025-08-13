import UIKit
import Foundation_iOS

struct ProxySignValidationViewFactory {
    static func createPresenter(
        from view: ControllerBackedProtocol,
        callSender: MetaChainAccountResponse,
        call: AnyRuntimeCall,
        validationSharedData: DelegatedSignValidationSharedData,
        completionClosure: @escaping DelegatedSignValidationCompletion
    ) -> DSFeeValidationPresenterProtocol? {
        guard
            let chain = ChainRegistryFacade.sharedRegistry.getChain(
                for: callSender.chainAccount.chainId
            ),
            let utilityChainAsset = chain.utilityChainAsset(),
            let currencyManager = CurrencyManager.shared,
            let interactor = DSFeeValidationInteractoryFactory.createInteractor(
                callSender: callSender,
                chain: chain,
                call: call,
                validationSharedData: validationSharedData
            ) else {
            return nil
        }

        let wireframe = ProxySignValidationWireframe()

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let dataValidatorFactory = ProxyDataValidatorFactory(
            presentable: wireframe,
            balanceViewModelFactoryFacade: BalanceViewModelFactoryFacade(
                priceAssetInfoFactory: priceAssetInfoFactory
            )
        )

        dataValidatorFactory.view = view

        let presenter = ProxySignValidationPresenter(
            view: view,
            interactor: interactor,
            wireframe: wireframe,
            proxyName: callSender.chainAccount.name,
            dataValidationFactory: dataValidatorFactory,
            chainAsset: utilityChainAsset,
            completionClosure: completionClosure,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        interactor.presenter = presenter

        return presenter
    }
}
