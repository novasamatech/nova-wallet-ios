import Foundation
import Foundation_iOS

struct FeeAssetSelectSheetViewFactory {
    static func createView(from viewModel: FeeAssetSelectSheetViewModel) -> MessageSheetViewProtocol {
        let wireframe = MessageSheetWireframe()

        let presenter = MessageSheetPresenter(wireframe: wireframe)

        let view = FeeAssetSelectSheetViewController(
            presenter: presenter,
            viewModel: viewModel,
            localizationManager: LocalizationManager.shared
        )

        let height = view.rootView.contentHeight(
            model: viewModel,
            locale: LocalizationManager.shared.selectedLocale
        )

        view.preferredContentSize = .init(
            width: UIView.noIntrinsicMetric,
            height: height
        )
        presenter.view = view

        return view
    }
}
