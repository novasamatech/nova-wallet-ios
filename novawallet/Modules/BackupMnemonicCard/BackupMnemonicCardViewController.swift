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
        appearanceAnimator: ViewAnimatorProtocol,
        disappearanceAnimator: ViewAnimatorProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.appearanceAnimator = appearanceAnimator
        self.disappearanceAnimator = disappearanceAnimator

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = BackupMnemonicCardViewLayout(
            appearanceAnimator: appearanceAnimator,
            disappearanceAnimator: disappearanceAnimator
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        presenter.setup()
        setupLocalization()
    }
}

extension BackupMnemonicCardViewController: BackupMnemonicCardViewProtocol {
    func update(with viewModel: ViewModel) {
        setupNavigationBarTitle(with: viewModel)

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
        let header = collectionView.dequeueReusableSupplementaryViewWithType(
            TitleCollectionHeaderView.self,
            forSupplementaryViewOfKind: kind,
            for: indexPath
        )!
        header.contentInsets = UIConstants.headerContentInsets
        header.titleLabel.apply(style: .semiboldSubhedlineSecondary)
        header.titleLabel.text = "Please do not share with anyone" // TODO: Localize

        return header
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
        cell.view.view.attributedText = createIndexedWordAttributedString(
            for: words[indexPath.item],
            index: indexPath.item
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

private extension BackupMnemonicCardViewController {
    func setupView() {
        rootView.collectionView.dataSource = self
        rootView.collectionView.delegate = self
        rootView.delegate = self
    }

    func setupNavigationBarTitle(with viewModel: ViewModel) {
        let iconDetailsView: IconDetailsView = .create(with: { view in
            view.iconWidth = UIConstants.walletIconSize.width

            viewModel.walletIcon?.loadImage(
                on: view.imageView,
                targetSize: UIConstants.walletIconSize,
                animated: true
            )
            view.detailsLabel.apply(style: .semiboldBodyPrimary)
            view.detailsLabel.text = viewModel.walletName
        })

        navigationItem.titleView = iconDetailsView
    }

    func createIndexedWordAttributedString(for word: String, index: Int) -> NSAttributedString {
        let buttonTitleStr = NSMutableAttributedString(
            string: "\(index + 1)",
            attributes: [
                .foregroundColor: R.color.colorTextSecondary()!,
                .font: UIFont.p2Paragraph
            ]
        )

        let wordAttributedStr = NSAttributedString(
            string: "  \(word)",
            attributes: [
                .foregroundColor: R.color.colorTextPrimary()!,
                .font: UIFont.p2Paragraph
            ]
        )

        buttonTitleStr.append(wordAttributedStr)

        return buttonTitleStr
    }

    func setupLocalization() {
        rootView.coverMessageView.fView.text = R.string.localizable.mnemonicCardCoverMessageTitle(preferredLanguages: selectedLocale.rLanguages)
        rootView.coverMessageView.sView.text = R.string.localizable.mnemonicCardCoverMessageMessage(preferredLanguages: selectedLocale.rLanguages)
        rootView.titleView.text = R.string.localizable.commonPassphrase(preferredLanguages: selectedLocale.rLanguages)
    }
}

// MARK: Localizable

extension BackupMnemonicCardViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }

        setupLocalization()
    }
}

private extension UIConstants {
    static let walletIconSize = CGSize(width: 28, height: 28)
    static let itemsPerRow: Int = 3
    static let headerContentInsets = UIEdgeInsets(
        top: 12.0,
        left: 12.0,
        bottom: 12.0,
        right: 12.0
    )
    static let wordHeight: CGFloat = 32.0
    static let headerHeight: CGFloat = 20 + headerContentInsets.top + headerContentInsets.top
}
