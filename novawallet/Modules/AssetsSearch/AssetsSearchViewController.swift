import UIKit
import SoraFoundation

final class AssetsSearchViewController: UIViewController, ViewHolder {
    typealias RootViewType = AssetsSearchViewLayout

    let presenter: AssetsSearchPresenterProtocol

    var collectionViewLayout: UICollectionViewFlowLayout? {
        rootView.collectionView.collectionViewLayout as? UICollectionViewFlowLayout
    }

    private var groupsState: WalletListGroupState = .list(groups: [])

    init(presenter: AssetsSearchPresenterProtocol, localizationManager _: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AssetsSearchViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupSearchBar()
        setupCollectionView()
        setupLocalization()
        presenter.setup()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages
        rootView.searchBar.textField.placeholder = R.string.localizable.assetsSearchPlaceholder(
            preferredLanguages: languages
        )

        rootView.cancelButton.imageWithTitleView?.title = R.string.localizable.commonCancel(
            preferredLanguages: languages
        )

        rootView.cancelButton.invalidateLayout()
    }

    private func setupCollectionView() {
        rootView.collectionView.registerCellClass(WalletListAssetCell.self)
        rootView.collectionView.registerCellClass(WalletListEmptyCell.self)
        rootView.collectionView.registerClass(
            WalletListNetworkView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )

        collectionViewLayout?.register(
            TokenGroupDecorationView.self,
            forDecorationViewOfKind: WalletListFlowLayout.assetGroupDecoration
        )

        rootView.collectionView.dataSource = self
        rootView.collectionView.delegate = self
    }

    private func setupSearchBar() {
        rootView.searchBar.textField.addTarget(
            self,
            action: #selector(actionTextFieldChanged),
            for: .editingChanged
        )

        rootView.searchBar.textField.delegate = self
        rootView.searchBar.textField.returnKeyType = .done

        rootView.cancelButton.addTarget(self, action: #selector(actionCancel), for: .touchUpInside)
    }

    @objc private func actionCancel() {
        presenter.cancel()
    }

    @objc private func actionTextFieldChanged() {
        let query = rootView.searchBar.textField.text
        presenter.updateSearch(query: query ?? "")
    }
}

extension AssetsSearchViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout _: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let cellType = AssetsSearchFlowLayout.CellType(indexPath: indexPath)
        return CGSize(width: collectionView.frame.width, height: cellType.height)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout _: UICollectionViewLayout,
        referenceSizeForHeaderInSection section: Int
    ) -> CGSize {
        switch AssetsSearchFlowLayout.SectionType(section: section) {
        case .assetGroup:
            return CGSize(
                width: collectionView.frame.width,
                height: WalletListMeasurement.assetHeaderHeight
            )

        case .technical:
            return .zero
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        let cellType = AssetsSearchFlowLayout.CellType(indexPath: indexPath)

        switch cellType {
        case .emptyState:
            break
        case .asset:
            if let groupIndex = AssetsSearchFlowLayout.SectionType.assetsGroupIndexFromSection(
                indexPath.section
            ) {
                let viewModel = groupsState.groups[groupIndex].assets[indexPath.row]
                presenter.selectAsset(for: viewModel.chainAssetId)
            }
        }
    }

    func collectionView(
        _: UICollectionView,
        layout _: UICollectionViewLayout,
        minimumLineSpacingForSectionAt section: Int
    ) -> CGFloat {
        WalletListFlowLayout.SectionType(section: section).cellSpacing
    }

    func collectionView(
        _: UICollectionView,
        layout _: UICollectionViewLayout,
        insetForSectionAt section: Int
    ) -> UIEdgeInsets {
        WalletListFlowLayout.SectionType(section: section).insets
    }
}

extension AssetsSearchViewController: UICollectionViewDataSource {
    func numberOfSections(in _: UICollectionView) -> Int {
        AssetsSearchFlowLayout.SectionType.assetsStartingSection + groupsState.groups.count
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch AssetsSearchFlowLayout.SectionType(section: section) {
        case .technical:
            return groupsState.isEmpty ? 1 : 0
        case .assetGroup:
            if let groupIndex = WalletListFlowLayout.SectionType.assetsGroupIndexFromSection(section) {
                return groupsState.groups[groupIndex].assets.count
            } else {
                return 0
            }
        }
    }

    private func provideEmptyStateCell(
        _ collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> WalletListEmptyCell {
        let cell = collectionView.dequeueReusableCellWithType(
            WalletListEmptyCell.self,
            for: indexPath
        )!

        cell.locale = selectedLocale

        return cell
    }

    private func provideAssetCell(
        _ collectionView: UICollectionView,
        indexPath: IndexPath,
        assetIndex: Int
    ) -> WalletListAssetCell {
        let assetCell = collectionView.dequeueReusableCellWithType(
            WalletListAssetCell.self,
            for: indexPath
        )!

        if let groupIndex = WalletListFlowLayout.SectionType.assetsGroupIndexFromSection(
            indexPath.section
        ) {
            let viewModel = groupsState.groups[groupIndex].assets[assetIndex]
            assetCell.bind(viewModel: viewModel)
        }

        return assetCell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        switch AssetsSearchFlowLayout.CellType(indexPath: indexPath) {
        case .emptyState:
            return provideEmptyStateCell(collectionView, indexPath: indexPath)
        case let .asset(_, assetIndex):
            return provideAssetCell(collectionView, indexPath: indexPath, assetIndex: assetIndex)
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryViewWithType(
            WalletListNetworkView.self,
            forSupplementaryViewOfKind: kind,
            for: indexPath
        )!

        if let groupIndex = WalletListFlowLayout.SectionType.assetsGroupIndexFromSection(
            indexPath.section
        ) {
            let viewModel = groupsState.groups[groupIndex]
            view.bind(viewModel: viewModel)
        }

        return view
    }
}

extension AssetsSearchViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}

extension AssetsSearchViewController: AssetsSearchViewProtocol {
    func didReceiveGroups(state: WalletListGroupState) {
        groupsState = state

        rootView.collectionView.reloadData()
    }
}

extension AssetsSearchViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            rootView.collectionView.reloadData()
        }
    }
}
