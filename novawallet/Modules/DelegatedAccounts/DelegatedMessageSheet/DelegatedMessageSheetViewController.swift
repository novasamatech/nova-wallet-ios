import Foundation_iOS

typealias DelegatedMessageSheetViewModel = MessageSheetViewModel<
    MessageSheetImageView.GraphicsViewModel,
    MessageSheetCheckmarkContentView.ContentViewModel
>

final class DelegatedMessageSheetViewController: MessageSheetViewController<
    MessageSheetImageView,
    MessageSheetCheckmarkContentView
> {
    var presenter: DelegatedMessageSheetPresenterProtocol? {
        basePresenter as? DelegatedMessageSheetPresenterProtocol
    }

    init(
        presenter: DelegatedMessageSheetPresenterProtocol,
        viewModel: DelegatedMessageSheetViewModel,
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
