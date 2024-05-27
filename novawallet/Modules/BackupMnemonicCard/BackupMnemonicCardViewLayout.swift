import UIKit
import SoraUI
import SnapKit

protocol BackupMnemonicCardViewLayoutDelegate: AnyObject {
    func didTapCardCover()
}

final class BackupMnemonicCardViewLayout: ScrollableContainerLayoutView {
    typealias Cell = MnemonicWordCollectionCell

    weak var delegate: BackupMnemonicCardViewLayoutDelegate?

    lazy var networkView = AssetListChainView()
    lazy var networkContainerView: UIView = .create { [weak self] view in
        guard let self else { return }

        view.addSubview(networkView)

        networkView.snp.makeConstraints { make in
            make.leading.bottom.top.equalToSuperview()
        }
    }

    let titleView: UILabel = .create { view in
        view.apply(style: .boldTitle3Primary)
        view.textAlignment = .left
    }

    let cardContainerView: UIView = .create { view in
        view.isUserInteractionEnabled = true
    }

    let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = Constants.itemsSpacing
        layout.minimumLineSpacing = Constants.itemsSpacing
        layout.sectionInset = Constants.sectionContentInset

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

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(titleView, spacingAfter: 16)
        addArrangedSubview(cardContainerView)
        stackView.alignment = .fill
    }

    override func setupStyle() {
        super.setupStyle()

        backgroundColor = R.color.colorSecondaryScreenBackground()

        let backgroundImageView = UIImageView()
        backgroundImageView.image = R.image.cardBg()
        backgroundImageView.contentMode = .scaleToFill

        collectionView.backgroundColor = .clear
        collectionView.backgroundView = backgroundImageView

        setupStyleForCard(collectionView.backgroundView)
        setupStyleForCard(coverView)
    }

    func setupStyleForCard(_ view: UIView?) {
        view?.layer.borderWidth = 1.0
        view?.layer.borderColor = R.color.colorContainerBorder()?.cgColor
        view?.layer.cornerRadius = Constants.cardCornerRadius
        view?.layer.masksToBounds = true
        view?.clipsToBounds = true
    }

    func showMnemonics() {
        cardContainerView.addSubview(collectionView)

        collectionView.snp.makeConstraints { make in
            make.width.height.equalToSuperview()
        }

        addArrangedSubview(cardContainerView)

        collectionView.reloadData()

        UIView.transition(
            from: coverView,
            to: collectionView,
            duration: 0.5,
            options: [.transitionFlipFromLeft, .curveEaseInOut]
        ) { [weak self] _ in
            self?.coverView.removeFromSuperview()
        }
    }

    func showCover() {
        collectionView.removeFromSuperview()
        cardContainerView.removeFromSuperview()

        cardContainerView.addSubview(coverView)

        coverView.snp.makeConstraints { make in
            make.height.equalTo(200)
            make.width.height.equalToSuperview()
        }

        addArrangedSubview(cardContainerView)
    }

    func showNetwork(with viewModel: NetworkViewModel) {
        var subviews: [UIView] = []

        stackView.arrangedSubviews.forEach { view in
            subviews.append(view)
            view.removeFromSuperview()
        }

        addArrangedSubview(
            networkContainerView,
            spacingAfter: Constants.stackSpacing
        )

        networkView.bind(viewModel: viewModel)

        subviews.forEach { view in
            self.addArrangedSubview(
                view,
                spacingAfter: Constants.stackSpacing
            )
        }
    }

    @objc func didTapCardCover() {
        delegate?.didTapCardCover()
    }
}

// MARK: Model

extension BackupMnemonicCardViewLayout {
    struct Model {
        var walletViewModel: DisplayWalletViewModel
        var networkViewModel: NetworkViewModel?
        var state: State
    }

    enum State {
        case mnemonicVisible(words: [String])
        case mnemonicNotVisible
    }
}

// MARK: Constants

private extension BackupMnemonicCardViewLayout {
    enum Constants {
        static let itemsSpacing: CGFloat = 4
        static let stackSpacing: CGFloat = 16
        static let sectionContentInset = UIEdgeInsets(
            top: 0.0,
            left: 12.0,
            bottom: 14.0,
            right: 12.0
        )
        static let cardCornerRadius: CGFloat = 12.0
    }
}
