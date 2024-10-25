import UIKit
import SnapKit
import SoraUI

class BaseAssetsSearchViewLayout: UIView {
    enum Constants {
        static let searchBarHeight: CGFloat = 54
    }

    lazy var searchView: SearchViewProtocol = createSearchView()

    var searchBar: CustomSearchBar { searchView.searchBar }

    var cancelButton: RoundedButton? { searchView.optionalCancelButton }

    let collectionNetworkGroupsLayout = AssetsSearchNetworksFlowLayout()
    let collectionTokenGroupsLayout = AssetsSearchTokensFlowLayout()

    var assetGroupsLayoutStyle: AssetListGroupsStyle?

    var collectionViewLayout: AssetsSearchFlowLayout {
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
        view.contentInset = UIEdgeInsets(top: Constants.searchBarHeight, left: 0.0, bottom: 16.0, right: 0.0)

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

    func createSearchView() -> SearchViewProtocol {
        fatalError("Must be implemented in child class")
    }

    func setup() {
        setupLayouts()

        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.bottom.equalToSuperview()
        }

        addSubview(searchView)
        searchView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.top).offset(Constants.searchBarHeight)
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
