import Foundation
import UIKit
import Foundation_iOS

struct TitleDetailsSheetViewFactory {
    static func createView(
        from viewModel: TitleDetailsSheetViewModel,
        allowsSwipeDown: Bool = true,
        preferredContentSize: CGSize = CGSize(width: 0.0, height: 250.0)
    ) -> MessageSheetViewProtocol {
        let wireframe = MessageSheetWireframe()

        let presenter = MessageSheetPresenter(wireframe: wireframe)

        let view = TitleDetailsSheetViewController(
            presenter: presenter,
            viewModel: viewModel,
            localizationManager: LocalizationManager.shared
        )

        view.allowsSwipeDown = allowsSwipeDown
        view.preferredContentSize = preferredContentSize

        presenter.view = view

        return view
    }

    static func createContentSizedView(
        from viewModel: TitleDetailsSheetViewModel,
        allowsSwipeDown: Bool = true
    ) -> MessageSheetViewProtocol {
        let wireframe = MessageSheetWireframe()

        let presenter = MessageSheetPresenter(wireframe: wireframe)

        let view = TitleDetailsSheetViewController(
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
