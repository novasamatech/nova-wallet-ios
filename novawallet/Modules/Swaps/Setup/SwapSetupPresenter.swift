import Foundation
import SoraFoundation
import BigInt

final class SwapSetupPresenter {
    weak var view: SwapSetupViewProtocol?
    let wireframe: SwapSetupWireframeProtocol
    let interactor: SwapSetupInteractorInputProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryFacadeProtocol

    init(
        interactor: SwapSetupInteractorInputProtocol,
        wireframe: SwapSetupWireframeProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryFacadeProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.balanceViewModelFactory = balanceViewModelFactory
        self.localizationManager = localizationManager
    }
}

extension SwapSetupPresenter: SwapSetupPresenterProtocol {
    func setup() {
        let mock = MockViewModelFactory()
        let buttonState = mock.buttonState()
        view?.didReceiveButtonState(
            title: buttonState.title.value(for: selectedLocale),
            enabled: buttonState.enabled
        )
        view?.didReceiveTitle(payViewModel: mock.payTitleModel(locale: selectedLocale))
        view?.didReceiveInputChainAsset(payViewModel: mock.payModel())
        view?.didReceiveAmount(payInputViewModel: mock.payAmount(
            locale: selectedLocale,
            balanceViewModelFactory: balanceViewModelFactory
        ))
        view?.didReceiveAmountInputPrice(payViewModel: mock.payPriceModel())
        view?.didReceiveTitle(receiveViewModel: mock.receiveTitleModel(locale: selectedLocale))
        view?.didReceiveInputChainAsset(receiveViewModel: mock.receiveModel(locale: selectedLocale))
    }

    // TODO: navigate to select token screen
    func selectPayToken() {}

    // TODO: navigate to select token screen
    func selectReceiveToken() {}

    // TODO: implement
    func swap() {}

    // TODO: navigate to confirm screen
    func proceed() {}
}

extension SwapSetupPresenter: SwapSetupInteractorOutputProtocol {
    func didReceive(error _: SwapSetupError) {}

    func didReceive(quote _: AssetConversion.Quote) {}

    func didReceive(fee _: BigUInt?) {}
}

extension SwapSetupPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            setup()
        }
    }
}
