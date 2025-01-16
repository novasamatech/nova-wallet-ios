import Foundation
import UIKit
import UIKit_iOS
import Foundation_iOS

final class AccountCreateViewController: UIViewController, ViewHolder {
    typealias RootViewType = AccountCreateViewLayout

    let presenter: AccountCreatePresenterProtocol

    // MARK: - Lifecycle

    init(
        presenter: AccountCreatePresenterProtocol,
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

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
        setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        presenter.becomeActive()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        presenter.becomeInactive()
    }

    override func loadView() {
        view = AccountCreateViewLayout()
    }

    // MARK: - Setup functions

    private func setup() {
        rootView.mnemonicCardView.delegate = self
        setupNavigationItem()
        setupLocalization()
    }

    private func setupNavigationItem() {
        let advancedBarButtonItem = UIBarButtonItem(
            image: R.image.iconOptions()?.tinted(
                with: R.color.colorIconPrimary()!.withAlphaComponent(1)
            ),
            style: .plain,
            target: self,
            action: #selector(openAdvanced)
        )

        navigationItem.rightBarButtonItem = advancedBarButtonItem
    }

    private func setupLocalization() {
        rootView.titleLabel.text = R.string.localizable
            .accountBackupMnemonicTitle(preferredLanguages: selectedLocale.rLanguages)
    }

    // MARK: - Actions

    @objc private func openAdvanced() {
        presenter.activateAdvanced()
    }
}

// MARK: - AccountCreateViewProtocol

extension AccountCreateViewController: AccountCreateViewProtocol {
    func update(with mnemonicCardViewModel: HiddenMnemonicCardView.State) {
        switch mnemonicCardViewModel {
        case let .mnemonicVisible(model):
            rootView.mnemonicCardView.showMnemonic(model: model)
        case let .mnemonicNotVisible(model):
            rootView.mnemonicCardView.showCover(model: model)
        }
    }

    func update(using checkboxListViewModel: BackupAttentionViewLayout.Model) {
        rootView.bind(checkboxListViewModel)
    }
}

// MARK: HiddenMnemonicCardViewDelegate

extension AccountCreateViewController: HiddenMnemonicCardViewDelegate {
    func didTapCardCover() {
        presenter.provideMnemonic()
    }
}

// MARK: - Localizable

extension AccountCreateViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
