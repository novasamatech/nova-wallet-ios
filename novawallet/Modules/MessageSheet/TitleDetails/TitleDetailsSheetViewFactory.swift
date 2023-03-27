import Foundation
import SoraFoundation

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
}
