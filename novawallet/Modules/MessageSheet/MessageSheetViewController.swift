import UIKit
import SoraFoundation

final class MessageSheetViewController: UIViewController, ViewHolder {
    typealias RootViewType = MessageSheetViewLayout

    let presenter: MessageSheetPresenterProtocol
    let viewModel: MessageSheetViewModel

    init(
        presenter: MessageSheetPresenterProtocol,
        viewModel: MessageSheetViewModel,
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
        view = MessageSheetViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupIcon()
        setupHandlers()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        rootView.titleLabel.text = viewModel.title.value(for: selectedLocale)
        rootView.detailsLabel.text = viewModel.message.value(for: selectedLocale)

        rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonOkBack(
            preferredLanguages: languages
        )
        rootView.actionButton.invalidateLayout()
    }

    private func setupIcon() {
        rootView.iconView.image = viewModel.icon
    }

    private func setupHandlers() {
        rootView.actionButton.addTarget(self, action: #selector(actionGoBack), for: .touchUpInside)
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
