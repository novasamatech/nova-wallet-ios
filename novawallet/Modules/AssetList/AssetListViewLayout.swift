import UIKit

final class AssetListViewLayout: UIView {
    let backgroundView = MultigradientView.background

    let collectionNetworkGroupsLayout = AssetListNetworksFlowLayout()
    let collectionTokenGroupsLayout = AssetListTokensFlowLayout()

    var assetGroupsLayoutStyle: AssetListGroupsStyle?

    var collectionViewLayout: AssetListFlowLayout {
        switch assetGroupsLayoutStyle ?? .tokens {
        case .networks: collectionNetworkGroupsLayout
        case .tokens: collectionTokenGroupsLayout
        }
    }

    lazy var collectionView: UICollectionView = {
        let view = UICollectionView(
            frame: .zero,
            collectionViewLayout: collectionViewLayout
        )
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .always
        view.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 16.0, right: 0.0)
        view.refreshControl = UIRefreshControl()

        return view
    }()

    override init(frame _: CGRect) {
        super.init(frame: .zero)

        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setup() {
        setupLayouts()

        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func setupLayouts() {
        [
            collectionNetworkGroupsLayout,
            collectionTokenGroupsLayout
        ].forEach {
            $0.scrollDirection = .vertical
            $0.minimumLineSpacing = 0
            $0.minimumInteritemSpacing = 0
            $0.sectionInset = .zero
        }
    }
}
