import UIKit
import SnapKit
import UIKit_iOS

class BaseAssetsSearchViewLayout: UIView {
    enum Constants {
        static let searchBarHeight: CGFloat = 54
    }

    lazy var searchView: SearchViewProtocol = createSearchView()

    var searchBar: CustomSearchBar { searchView.searchBar }

    var cancelButton: RoundedButton? { searchView.optionalCancelButton }

    let collectionViewLayout: AssetsSearchFlowLayout = {
        let layout = AssetsSearchFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = .zero

        return layout
    }()

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
