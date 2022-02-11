import UIKit
import SoraFoundation
import SubstrateSdk

final class DAppListViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppListViewLayout

    let presenter: DAppListPresenterProtocol

    var collectionViewLayout: UICollectionViewFlowLayout? {
        rootView.collectionView.collectionViewLayout as? UICollectionViewFlowLayout
    }

    init(presenter: DAppListPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    private var accountIcon: UIImage?

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DAppListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureCollectionView()

        presenter.setup()
    }

    private func configureCollectionView() {
        rootView.collectionView.registerCellClass(DAppListHeaderView.self)
        rootView.collectionView.registerCellClass(DAppCategoriesView.self)
        rootView.collectionView.registerCellClass(DAppListLoadingView.self)
        rootView.collectionView.registerCellClass(DAppListErrorView.self)
        rootView.collectionView.registerCellClass(DAppItemView.self)

        collectionViewLayout?.register(
            DAppListDecorationView.self,
            forDecorationViewOfKind: DAppListFlowLayout.backgroundDecoration
        )

        collectionViewLayout?.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        rootView.collectionView.dataSource = self
        rootView.collectionView.delegate = self
    }

    private func updateIcon(for headerView: DAppListHeaderView, icon _: UIImage?) {
        headerView.accountButton.imageWithTitleView?.iconImage = accountIcon
        headerView.accountButton.invalidateLayout()
    }

    @objc func actionSelectAccount() {
        presenter.activateAccount()
    }

    @objc func actionSearch() {
        presenter.activateSearch()
    }
}

extension DAppListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        guard let cellType = DAppListFlowLayout.CellType(indexPath: indexPath) else {
            return
        }

        switch cellType {
        case .header, .notLoaded, .categories:
            break
        case .dapp:
            break
        }
    }
}

extension DAppListViewController: UICollectionViewDataSource {
    private func setupHeaderView(
        using collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> UICollectionViewCell {
        let view: DAppListHeaderView = collectionView.dequeueReusableCellWithType(
            DAppListHeaderView.self,
            for: indexPath
        )!

        updateIcon(for: view, icon: accountIcon)

        view.accountButton.addTarget(self, action: #selector(actionSelectAccount), for: .touchUpInside)
        view.searchView.addTarget(self, action: #selector(actionSearch), for: .touchUpInside)

        view.selectedLocale = selectedLocale

        return view
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cellType = DAppListFlowLayout.CellType(indexPath: indexPath) else {
            return UICollectionViewCell()
        }

        switch cellType {
        case .header:
            return setupHeaderView(using: collectionView, indexPath: indexPath)
        default:
            return UICollectionViewCell()
        }
    }

    func numberOfSections(in _: UICollectionView) -> Int {
        1
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == DAppListFlowLayout.CellType.header.indexPath.section {
            return 1
        } else {
            return 0
        }
    }
}

extension DAppListViewController: DAppListViewProtocol {
    func didReceiveAccount(icon: DrawableIcon) {
        let iconSize = CGSize(
            width: UIConstants.navigationAccountIconSize,
            height: UIConstants.navigationAccountIconSize
        )

        accountIcon = icon.imageWithFillColor(.clear, size: iconSize, contentScale: UIScreen.main.scale)

        if let headerView = rootView.findHeaderView() {
            updateIcon(for: headerView, icon: accountIcon)
        }
    }
}

extension DAppListViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            rootView.collectionView.reloadData()
        }
    }
}

extension DAppListViewController: HiddableBarWhenPushed {}
