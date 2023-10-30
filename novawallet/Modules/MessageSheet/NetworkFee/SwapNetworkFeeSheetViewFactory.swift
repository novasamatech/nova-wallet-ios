import Foundation
import SoraFoundation

struct SwapNetworkFeeSheetViewFactory {
    static func createView(
        from viewModel: SwapNetworkFeeSheetViewModel,
        allowsSwipeDown: Bool = true
    ) -> MessageSheetViewProtocol {
        let wireframe = MessageSheetWireframe()

        let presenter = MessageSheetPresenter(wireframe: wireframe)

        let view = SwapNetworkFeeSheetViewController(
            presenter: presenter,
            viewModel: viewModel,
            localizationManager: LocalizationManager.shared
        )

        view.allowsSwipeDown = allowsSwipeDown
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
