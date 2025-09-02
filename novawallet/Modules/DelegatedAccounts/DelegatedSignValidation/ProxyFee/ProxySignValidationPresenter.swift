import Foundation
import Foundation_iOS

final class ProxySignValidationPresenter: DSFeeValidationPresenter {
    let dataValidationFactory: ProxyDataValidatorFactoryProtocol
    let proxyName: String

    init(
        view: ControllerBackedProtocol,
        interactor: DSFeeValidationInteractorInputProtocol,
        wireframe: DSFeeValidationWireframeProtocol,
        proxyName: String,
        dataValidationFactory: ProxyDataValidatorFactoryProtocol,
        chainAsset: ChainAsset,
        completionClosure: @escaping DelegatedSignValidationCompletion,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.dataValidationFactory = dataValidationFactory
        self.proxyName = proxyName

        super.init(
            view: view,
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            completionClosure: completionClosure,
            localizationManager: localizationManager,
            logger: logger
        )
    }

    override func completeValidation() {
        guard let balance = balance, let fee = fee, let balanceExistence = balanceExistence else {
            return
        }

        let locale = localizationManager.selectedLocale

        DataValidationRunner(validators: [
            dataValidationFactory.canPayFeeInPlank(
                balance: balance.transferable,
                fee: fee,
                proxyName: proxyName,
                asset: chainAsset.assetDisplayInfo,
                locale: locale
            ),
            dataValidationFactory.notViolatingMinBalancePaying(
                fee: fee,
                total: balance.balanceCountingEd,
                minBalance: balanceExistence.minBalance,
                asset: chainAsset.assetDisplayInfo,
                locale: locale
            )
        ]).runValidation(
            notifyingOnSuccess: { [weak self] in
                guard let self else { return }

                if let feeAmount = fee.amountForCurrentAccount {
                    interactor.payFee(feeAmount, from: balance)
                }

                completionClosure(true)
            },
            notifyingOnStop: { [weak self] problem in
                switch problem {
                case .error, .warning:
                    self?.completionClosure(false)
                case .asyncProcess:
                    break
                }
            },
            notifyingOnResume: nil
        )
    }
}
