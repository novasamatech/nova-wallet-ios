import UIKit

protocol BannersViewLayoutDelegate: AnyObject {
    func didInvalidateVisibleItems(
        _ items: [NSCollectionLayoutVisibleItem],
        offset: CGPoint,
        environment: NSCollectionLayoutEnvironment
    )
}

final class BannersViewLayout: UIView {
    weak var delegate: BannersViewLayoutDelegate?

    let containerView: UIView = .create { view in
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
    }

    let backgroundView = BannerBackgroundView()

    lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        layout.sectionInset = .zero

        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )
        collectionView.backgroundColor = .clear
        collectionView.bounces = false
        collectionView.alwaysBounceVertical = false
        collectionView.alwaysBounceHorizontal = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.isPagingEnabled = true

        return collectionView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        collectionView.backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Private

private extension BannersViewLayout {
    func setupLayout() {
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        containerView.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(8)
        }

        containerView.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

// MARK: Internal

extension BannersViewLayout {
    func setBackgroundImage(_ image: UIImage?) {
        backgroundView.setBackground(image)
    }

    func setLoading() {}

    func setDisplayContent() {}
}
