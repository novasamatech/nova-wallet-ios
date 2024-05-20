import UIKit
import SoraUI
import SnapKit

protocol BackupMnemonicCardViewLayoutDelegate: AnyObject {
    func didTapCardCover()
}

final class BackupMnemonicCardViewLayout: ScrollableContainerLayoutView {
    typealias Cell = MnemonicWordCollectionCell

    private var appearanceAnimator: ViewAnimatorProtocol?
    private var disappearanceAnimator: ViewAnimatorProtocol?

    weak var delegate: BackupMnemonicCardViewLayoutDelegate?

    let titleView: UILabel = .create { view in
        view.apply(style: .boldTitle3Primary)
        view.textAlignment = .left
    }

    let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = UIConstants.itemsSpacing
        layout.minimumLineSpacing = UIConstants.itemsSpacing
        layout.sectionInset = UIConstants.sectionContentInset

        let collectionView = ContentSizedCollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )
        collectionView.allowsSelection = false
        collectionView.registerCellClass(Cell.self)
        collectionView.registerClass(
            TitleCollectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )

        return collectionView
    }()

    var coverMessageView: GenericPairValueView<UILabel, UILabel> = .create { view in
        view.makeVertical()
        view.spacing = 8
        view.stackView.alignment = .center
        view.fView.apply(style: .semiboldSubhedlinePrimary)
        view.fView.textAlignment = .center
        view.sView.apply(style: .semiboldFootnoteButtonInactive)
        view.sView.textAlignment = .center
        view.sView.numberOfLines = 0
    }

    lazy var coverView: UIView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleToFill
        imageView.image = R.image.cardBlurred()
        imageView.isUserInteractionEnabled = true

        imageView.addSubview(coverMessageView)

        coverMessageView.snp.makeConstraints { make in
            make.centerX.centerY.equalTo(imageView)
            make.leading.trailing.equalTo(imageView).inset(12)
        }

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapCardCover))
        imageView.addGestureRecognizer(tapGesture)

        return imageView
    }()

    convenience init(
        appearanceAnimator: ViewAnimatorProtocol?,
        disappearanceAnimator: ViewAnimatorProtocol?
    ) {
        self.init(frame: .zero)

        self.appearanceAnimator = appearanceAnimator
        self.disappearanceAnimator = disappearanceAnimator
    }

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(titleView, spacingAfter: 16)
    }

    override func setupStyle() {
        super.setupStyle()

        backgroundColor = R.color.colorSecondaryScreenBackground()

        let backgroundImageView = UIImageView()
        backgroundImageView.image = R.image.cardBg()
        backgroundImageView.contentMode = .scaleAspectFill

        collectionView.backgroundColor = .clear
        collectionView.backgroundView = backgroundImageView

        setupStyleForCard(collectionView.backgroundView)
        setupStyleForCard(coverView)
    }

    func setupStyleForCard(_ view: UIView?) {
        view?.layer.borderWidth = 1.0
        view?.layer.borderColor = R.color.colorContainerBorder()?.cgColor
        view?.layer.cornerRadius = UIConstants.cardCornerRadius
        view?.layer.masksToBounds = true
        view?.clipsToBounds = true
    }

    func showMnemonics() {
        disappearanceAnimator?.animate(view: coverView) { [weak self] _ in
            guard let self else { return }

            coverView.removeFromSuperview()

            addArrangedSubview(collectionView)
            collectionView.reloadData()
            appearanceAnimator?.animate(view: collectionView, completionBlock: nil)
        }
    }

    func showCover() {
        collectionView.removeFromSuperview()

        coverView.snp.makeConstraints { make in
            make.height.equalTo(200)
        }

        addArrangedSubview(coverView)
    }

    @objc func didTapCardCover() {
        delegate?.didTapCardCover()
    }
}

// MARK: Model

extension BackupMnemonicCardViewLayout {
    struct Model {
        var walletViewModel: DisplayWalletViewModel
        var state: State
    }

    enum State {
        case mnemonicVisible(words: [String])
        case mnemonicNotVisible
    }
}

// MARK: UIConstants

private extension UIConstants {
    static let itemsSpacing: CGFloat = 4
    static let sectionContentInset = UIEdgeInsets(
        top: 0.0,
        left: 12.0,
        bottom: 12.0,
        right: 12.0
    )
    static let cardCornerRadius: CGFloat = 12.0
}
