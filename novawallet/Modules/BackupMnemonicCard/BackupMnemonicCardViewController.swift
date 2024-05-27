import UIKit
import SoraUI
import SoraFoundation

final class BackupMnemonicCardViewController: UIViewController, ViewHolder {
    typealias RootViewType = BackupMnemonicCardViewLayout
    typealias ViewModel = BackupMnemonicCardViewLayout.Model

    private var appearanceAnimator: ViewAnimatorProtocol?
    private var disappearanceAnimator: ViewAnimatorProtocol?

    let presenter: BackupMnemonicCardPresenterProtocol

    init(
        presenter: BackupMnemonicCardPresenterProtocol,
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
        view = BackupMnemonicCardViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        presenter.setup()
        setupLocalization()
        setupBarButtonItem()
    }
}

// MARK: BackupMnemonicCardViewProtocol

extension BackupMnemonicCardViewController: BackupMnemonicCardViewProtocol {
    func update(with viewModel: ViewModel) {
        setupNavigationBarTitle(with: viewModel)

        if let networkViewModel = viewModel.networkViewModel {
            rootView.showNetwork(with: networkViewModel)
        }

        switch viewModel.state {
        case let .mnemonicVisible(model: model):
            rootView.showMnemonics(model: model)
        case .mnemonicNotVisible:
            rootView.showCover()
        }
    }
}

// MARK: BackupMnemonicCardViewLayoutDelegate

extension BackupMnemonicCardViewController: BackupMnemonicCardViewLayoutDelegate {
    func didTapCardCover() {
        presenter.mnemonicCardTapped()
    }
}

// MARK: Private

private extension BackupMnemonicCardViewController {
    func setupView() {
        rootView.delegate = self
    }

    func setupNavigationBarTitle(with viewModel: ViewModel) {
        let iconDetailsView: IconDetailsView = .create(with: { view in
            view.detailsLabel.apply(style: .semiboldBodyPrimary)
            view.detailsLabel.text = viewModel.walletViewModel.name
            view.iconWidth = UIConstants.walletIconSize.width

            viewModel.walletViewModel.imageViewModel?.loadImage(
                on: view.imageView,
                targetSize: UIConstants.walletIconSize,
                animated: true
            )
        })

        navigationItem.titleView = iconDetailsView
    }

    func setupLocalization() {
        rootView.coverMessageView.fView.text = R.string.localizable.mnemonicCardCoverMessageTitle(
            preferredLanguages: selectedLocale.rLanguages
        )
        rootView.coverMessageView.sView.text = R.string.localizable.mnemonicCardCoverMessageMessage(
            preferredLanguages: selectedLocale.rLanguages
        )
        rootView.titleView.text = R.string.localizable.commonPassphrase(
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    func setupBarButtonItem() {
        let advancedItem = UIBarButtonItem(
            image: R.image.iconOptions()?.tinted(with: R.color.colorIconPrimary()!),
            style: .plain,
            target: self,
            action: #selector(advancedTapped)
        )

        navigationItem.rightBarButtonItem = advancedItem
    }

    @objc func advancedTapped() {
        presenter.advancedTapped()
    }
}

// MARK: Localizable

extension BackupMnemonicCardViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }

        setupLocalization()
    }
}

// MARK: UIConstants

private extension UIConstants {
    static let walletIconSize = CGSize(width: 28, height: 28)
    static let itemsPerRow: Int = 3
    static let headerContentInsets = UIEdgeInsets(
        top: 14.0,
        left: 12.0,
        bottom: 14.0,
        right: 12.0
    )
    static let wordHeight: CGFloat = 32.0
    static let headerHeight: CGFloat = 20 + headerContentInsets.top + headerContentInsets.top
}
