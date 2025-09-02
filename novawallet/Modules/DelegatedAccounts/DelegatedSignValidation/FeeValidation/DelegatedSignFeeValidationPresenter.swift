import Foundation
import BigInt
import Foundation_iOS

class DSFeeValidationPresenter {
    let view: ControllerBackedProtocol
    let wireframe: DSFeeValidationWireframeProtocol
    let interactor: DSFeeValidationInteractorInputProtocol

    let chainAsset: ChainAsset
    let localizationManager: LocalizationManagerProtocol
    let logger: LoggerProtocol
    let completionClosure: DelegatedSignValidationCompletion

    var balance: AssetBalance?
    var fee: ExtrinsicFeeProtocol?
    var balanceExistence: AssetBalanceExistence?

    init(
        view: ControllerBackedProtocol,
        interactor: DSFeeValidationInteractorInputProtocol,
        wireframe: DSFeeValidationWireframeProtocol,
        chainAsset: ChainAsset,
        completionClosure: @escaping DelegatedSignValidationCompletion,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.view = view
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.completionClosure = completionClosure
        self.localizationManager = localizationManager
        self.logger = logger
    }

    func completeValidation() {
        fatalError("Must be implemented by subsclasss")
    }
}

extension DSFeeValidationPresenter: DSFeeValidationPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension DSFeeValidationPresenter: DSFeeValidationInteractorOutputProtocol {
    func didReceiveBalance(_ balance: AssetBalance) {
        logger.debug("Did receive balance: \(balance)")

        self.balance = balance

        completeValidation()
    }

    func didReceiveBalanceExistense(_ balanceExistence: AssetBalanceExistence) {
        logger.debug("Did receive min balance: \(balanceExistence)")

        self.balanceExistence = balanceExistence

        completeValidation()
    }

    func didReceiveFee(_ fee: ExtrinsicFeeProtocol) {
        logger.debug("Did receive fee: \(fee)")

        self.fee = fee

        completeValidation()
    }

    func didReceiveError(_ error: Error) {
        logger.error("Did receive error: \(error)")

        let locale = localizationManager.selectedLocale

        if !wireframe.present(error: error, from: view, locale: locale) {
            _ = wireframe.present(error: CommonError.undefined, from: view, locale: locale)
        }

        completionClosure(false)
    }
}
