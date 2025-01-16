import Foundation_iOS

typealias ProxyMessageSheetViewModel = MessageSheetViewModel<
    MessageSheetImageView.GraphicsViewModel,
    MessageSheetCheckmarkContentView.ContentViewModel
>

final class ProxyMessageSheetViewController: MessageSheetViewController<
    MessageSheetImageView,
    MessageSheetCheckmarkContentView
> {
    var presenter: ProxyMessageSheetPresenterProtocol? {
        basePresenter as? ProxyMessageSheetPresenterProtocol
    }

    init(
        presenter: ProxyMessageSheetPresenterProtocol,
        viewModel: ProxyMessageSheetViewModel,
        localizationManager: LocalizationManagerProtocol
    ) {
        super.init(
            presenter: presenter,
            viewModel: viewModel,
            localizationManager: localizationManager
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        rootView.contentOffset = 16
    }

    override func actionMain() {
        presenter?.proceed(
            skipInfoNextTime: rootView.contentView.controlView.isChecked,
            action: viewModel.mainAction
        )
    }
}
