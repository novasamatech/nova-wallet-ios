import UIKit
import UIKit_iOS
import Foundation_iOS

final class BackupAttentionViewController: UIViewController, ViewHolder {
    typealias RootViewType = BackupAttentionViewLayout

    let presenter: BackupAttentionPresenterProtocol

    init(
        presenter: BackupAttentionPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = BackupAttentionViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
        setupLocalization()
    }

    private func setupLocalization() {
        let title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.backupAttentionTitle()
        let description = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.backupAttentionDescription()

        rootView.titleView.titleLabel.text = title
        rootView.titleView.descriptionLabel.text = description
    }
}

extension BackupAttentionViewController: BackupAttentionViewProtocol {
    func update(using viewModel: BackupAttentionViewLayout.Model) {
        rootView.bind(viewModel: viewModel)
    }
}

// MARK: Localizable

extension BackupAttentionViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }

        setupLocalization()
    }
}
