import Foundation_iOS

typealias CloudBackupRemindViewModel = MessageSheetViewModel<
    MessageSheetImageView.GraphicsViewModel,
    MessageSheetCheckmarkContentView.ContentViewModel
>

final class CloudBackupRemindViewController: MessageSheetViewController<
    MessageSheetImageView,
    MessageSheetCheckmarkContentView
> {
    var presenter: CloudBackupRemindPresenterProtocol? {
        basePresenter as? CloudBackupRemindPresenterProtocol
    }

    init(
        presenter: CloudBackupRemindPresenterProtocol,
        viewModel: CloudBackupRemindViewModel,
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
