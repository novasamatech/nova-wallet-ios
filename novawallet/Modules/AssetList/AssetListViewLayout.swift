import UIKit

final class AssetListViewLayout: UIView {
    let backgroundView = MultigradientView.background

    let collectionNetworkGroupsLayout = AssetListNetworksFlowLayout()
    let collectionTokenGroupsLayout = AssetListTokensFlowLayout()

    let assetGroupsLayoutStyle: AssetListGroupsStyle

    var collectionViewLayout: AssetListFlowLayout {
        switch assetGroupsLayoutStyle {
        case .networks: collectionNetworkGroupsLayout
        case .tokens: collectionTokenGroupsLayout
        }
    }

    lazy var collectionView: UICollectionView = {
        setupLayouts()

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

    init(assetGroupsLayoutStyle: AssetListGroupsStyle) {
        self.assetGroupsLayoutStyle = assetGroupsLayoutStyle

        super.init(frame: .zero)

        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setup() {
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
