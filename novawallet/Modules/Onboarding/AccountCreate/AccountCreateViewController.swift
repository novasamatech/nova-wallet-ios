import Foundation
import UIKit
import SoraUI
import SoraFoundation

final class AccountCreateViewController: UIViewController, ViewHolder {
    typealias RootViewType = AccountCreateViewLayout

    let presenter: AccountCreatePresenterProtocol
    let appearanceAnimator: ViewAnimatorProtocol

    // MARK: - Lifecycle

    init(
        presenter: AccountCreatePresenterProtocol,
        localizationManager: LocalizationManagerProtocol,
        appearanceAnimator: ViewAnimatorProtocol
    ) {
        self.presenter = presenter
        self.appearanceAnimator = appearanceAnimator
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

        presenter.prepareToDisplayMnemonic()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        rootView.hideMnemonicCard()
    }

    override func loadView() {
        view = AccountCreateViewLayout(appearanceAnimator: appearanceAnimator)
    }

    // MARK: - Setup functions

    private func setup() {
        rootView.mnemonicCardView.delegate = self
        setupNavigationItem()
        setupLocalization()
    }

    private func setupNavigationItem() {
        let advancedBarButtonItem = UIBarButtonItem(
            image: R.image.iconOptions()?.tinted(with: R.color.colorIconChip()!),
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

    func update(with checkboxListViewModel: BackupAttentionViewLayout.Model) {
        rootView.bind(checkboxListViewModel)
    }

    func displayMnemonic() {
        rootView.displayMnemonicCard()
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
