import UIKit
import SoraUI
import SoraFoundation

final class BackupAttentionViewController: UIViewController, ViewHolder {
    typealias RootViewType = BackupAttentionViewLayout

    let presenter: BackupAttentionPresenterProtocol

    private var appearanceAnimator: ViewAnimatorProtocol?
    private var disappearanceAnimator: ViewAnimatorProtocol?

    init(
        presenter: BackupAttentionPresenterProtocol,
        localizationManager: LocalizationManagerProtocol,
        appearanceAnimator: ViewAnimatorProtocol?,
        disappearanceAnimator: ViewAnimatorProtocol?
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
        self.appearanceAnimator = appearanceAnimator
        self.disappearanceAnimator = disappearanceAnimator
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = BackupAttentionViewLayout(
            appearanceAnimator: appearanceAnimator,
            disappearanceAnimator: disappearanceAnimator
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
        setupLocalization()
    }

    private func setupLocalization() {
        let title = R.string.localizable.backupAttentionTitle(preferredLanguages: selectedLocale.rLanguages)
        let description = R.string.localizable.backupAttentionDescription(preferredLanguages: selectedLocale.rLanguages)

        rootView.checkBoxScrollableView.titleView.titleLabel.text = title
        rootView.checkBoxScrollableView.titleView.descriptionLabel.text = description
    }
}

extension BackupAttentionViewController: BackupAttentionViewProtocol {
    func didReceive(_ viewModel: BackupAttentionViewLayout.Model) {
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
