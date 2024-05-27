import UIKit
import SoraUI
import SoraFoundation

final class BackupMnemonicCardViewController: UIViewController, ViewHolder {
    typealias RootViewType = BackupMnemonicCardViewLayout
    typealias Cell = BackupMnemonicCardViewLayout.Cell
    typealias ViewModel = BackupMnemonicCardViewLayout.Model

    private var appearanceAnimator: ViewAnimatorProtocol?
    private var disappearanceAnimator: ViewAnimatorProtocol?

    var words: [String] = []

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
        case let .mnemonicVisible(words: words):
            self.words = words
            rootView.showMnemonics()
        case .mnemonicNotVisible:
            rootView.showCover()
        }
    }
}

// MARK: Collection view delegates

extension BackupMnemonicCardViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(
        _: UICollectionView,
        numberOfItemsInSection _: Int
    ) -> Int {
        words.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryViewWithType(
            TitleCollectionHeaderView.self,
            forSupplementaryViewOfKind: kind,
            for: indexPath
        )!
        setupCollectionHeader(view)

        return view
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout _: UICollectionViewLayout,
        referenceSizeForHeaderInSection _: Int
    ) -> CGSize {
        CGSize(width: collectionView.bounds.width, height: UIConstants.headerHeight)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithType(Cell.self, for: indexPath)!

        cell.view.view.attributedText = NSAttributedString.coloredItems(
            ["\(indexPath.row + 1)"],
            formattingClosure: { String(format: "%@ \(words[indexPath.row])", $0[0]) },
            color: R.color.colorTextSecondary()!
        )

        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt _: IndexPath
    ) -> CGSize {
        guard let flowLayout = collectionViewLayout as? UICollectionViewFlowLayout else { return CGSize.zero }

        let totalSpace = flowLayout.sectionInset.left
            + flowLayout.sectionInset.right
            + (flowLayout.minimumInteritemSpacing * CGFloat(UIConstants.itemsPerRow - 1))

        let width = Int((collectionView.bounds.width - totalSpace) / CGFloat(UIConstants.itemsPerRow))

        return CGSize(width: CGFloat(width), height: CGFloat(UIConstants.wordHeight))
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
        rootView.collectionView.dataSource = self
        rootView.collectionView.delegate = self
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

    func setupCollectionHeader(_ view: TitleCollectionHeaderView) {
        view.contentInsets = UIConstants.headerContentInsets
        view.titleLabel.apply(style: .semiboldSubhedlineSecondary)
        view.titleLabel.attributedText = NSAttributedString.coloredItems(
            [
                R.string.localizable.mnemonicCardRevealedHeaderMessageHighlighted(
                    preferredLanguages: selectedLocale.rLanguages
                )
            ],
            formattingClosure: { items in
                R.string.localizable.mnemonicCardRevealedHeaderMessage(
                    items[0],
                    preferredLanguages: selectedLocale.rLanguages
                )
            },
            color: R.color.colorTextPrimary()!
        )
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
