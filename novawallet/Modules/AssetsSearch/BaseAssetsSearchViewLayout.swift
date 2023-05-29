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

    lazy var collectionView: UICollectionView = {
        let flowLayout = AssetsSearchFlowLayout()
        flowLayout.scrollDirection = .vertical
        flowLayout.minimumLineSpacing = 0
        flowLayout.minimumInteritemSpacing = 0
        flowLayout.sectionInset = .zero

        let view = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .always
        view.contentInset = UIEdgeInsets(top: Constants.searchBarHeight, left: 0.0, bottom: 16.0, right: 0.0)

        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

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
}
