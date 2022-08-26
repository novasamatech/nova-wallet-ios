import UIKit
import SoraFoundation

final class MessageSheetViewController<
    I: UIView & MessageSheetGraphicsProtocol,
    C: UIView & MessageSheetContentProtocol
>: UIViewController, ViewHolder {
    typealias RootViewType = MessageSheetViewLayout<I, C>

    let presenter: MessageSheetPresenterProtocol
    let viewModel: MessageSheetViewModel<I.GraphicsViewModel, C.ContentViewModel>

    init(
        presenter: MessageSheetPresenterProtocol,
        viewModel: MessageSheetViewModel<I.GraphicsViewModel, C.ContentViewModel>,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.viewModel = viewModel

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = MessageSheetViewLayout<I, C>()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        rootView.graphicsView.bind(messageSheetGraphics: viewModel.graphics, locale: selectedLocale)
        rootView.contentView.bind(messageSheetContent: viewModel.content, locale: selectedLocale)

        rootView.titleLabel.text = viewModel.title.value(for: selectedLocale)
        rootView.detailsLabel.text = viewModel.message.value(for: selectedLocale)

        rootView.actionButton?.imageWithTitleView?.title = R.string.localizable.commonOkBack(
            preferredLanguages: languages
        )

        rootView.actionButton?.invalidateLayout()
    }

    private func setupHandlers() {
        if viewModel.hasAction {
            rootView.setupActionButton()
            rootView.actionButton?.addTarget(self, action: #selector(actionGoBack), for: .touchUpInside)
        }
    }

    @objc private func actionGoBack() {
        presenter.goBack()
    }
}

extension MessageSheetViewController: MessageSheetViewProtocol {}

extension MessageSheetViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
