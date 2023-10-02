import Foundation
import SoraFoundation

final class SwapSetupPresenter {
    weak var view: SwapSetupViewProtocol?
    let wireframe: SwapSetupWireframeProtocol
    let interactor: SwapSetupInteractorInputProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryFacadeProtocol

    init(
        interactor: SwapSetupInteractorInputProtocol,
        wireframe: SwapSetupWireframeProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryFacadeProtocol,
        localizationManager _: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.balanceViewModelFactory = balanceViewModelFactory
    }
}

extension SwapSetupPresenter: SwapSetupPresenterProtocol {
    func setup() {
        view?.didReceiveButtonState(title: "Enter amount", enabled: false)
        view?.didReceiveInputChainAsset(payViewModel: dotModel())
        view?.didReceiveAmount(payInputViewModel: amount())
        view?.didReceiveAmountInputPrice(payViewModel: "$0")
        view?.didReceiveInputChainAsset(receiveViewModel: nil)
    }

    func dotModel() -> SwapsAssetViewModel {
        let dotImage = RemoteImageViewModel(url: URL(string: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/icons/chains/white/Polkadot.svg")!)
        let hubImage = RemoteImageViewModel(url: URL(string: "https://parachains.info/images/parachains/1688559044_assethub.svg")!)
        return SwapsAssetViewModel(
            symbol: "DOT",
            imageViewModel: dotImage,
            hub: .init(
                name: "Polkadot Asset Hub",
                icon: hubImage
            )
        )
    }

    func amount() -> AmountInputViewModelProtocol {
        let targetAssetInfo = AssetBalanceDisplayInfo(
            displayPrecision: 2,
            assetPrecision: 10,
            symbol: "DOT",
            symbolValueSeparator: "",
            symbolPosition: .suffix,
            icon: nil
        )
        return balanceViewModelFactory.createBalanceInputViewModel(
            targetAssetInfo: targetAssetInfo,
            amount: 0
        ).value(for: selectedLocale)
    }

    func selectPayToken() {
        print("SELECT PAY TOKEN")
    }

    func selectReceiveToken() {
        print("SELECT RECEIVE TOKEN")
    }
}

extension SwapSetupPresenter: SwapSetupInteractorOutputProtocol {}

extension SwapSetupPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            setup()
        }
    }
}
