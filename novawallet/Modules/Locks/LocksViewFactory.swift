import Foundation
import SoraUI
import SoraFoundation

struct LocksViewFactory {
    static func createView(input: LocksViewInput) -> LocksViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }
        let wireframe = LocksWireframe()
        let viewModelFactory = PriceViewModelFactory(
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager),
            assetFormatterFactory: AssetBalanceFormatterFactory(),
            currencyManager: currencyManager
        )
        let presenter = LocksPresenter(
            input: input,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared,
            priceViewModelFactory: viewModelFactory
        )

        let view = LocksViewController(presenter: presenter)

        presenter.view = view
        let maxHeight = ModalSheetPresentationConfiguration.maximumContentHeight
        let preferredContentSize = min(presenter.contentHeight, maxHeight)

        view.preferredContentSize = .init(
            width: 0,
            height: preferredContentSize
        )

        return view
    }
}
