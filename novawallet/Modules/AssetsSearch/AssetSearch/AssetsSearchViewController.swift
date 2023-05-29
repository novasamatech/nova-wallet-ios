import UIKit
import SoraFoundation

final class AssetsSearchViewController: UIViewController, ViewHolder {
    typealias RootViewType = BaseAssetsSearchViewLayout

    let presenter: AssetsSearchPresenterProtocol

    var collectionViewLayout: UICollectionViewFlowLayout? {
        rootView.collectionView.collectionViewLayout as? UICollectionViewFlowLayout
    }

    private var groupsState: AssetListGroupState = .list(groups: [])
    private let createViewClosure: () -> BaseAssetsSearchViewLayout
    private let localizableTitle: LocalizableResource<String>?

    init(
        presenter: AssetsSearchPresenterProtocol,
        createViewClosure: @escaping () -> BaseAssetsSearchViewLayout,
        localizableTitle: LocalizableResource<String>? = nil,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.createViewClosure = createViewClosure
        self.localizableTitle = localizableTitle
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = createViewClosure()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupSearchBar()
        setupCollectionView()
        setupLocalization()
        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        rootView.searchBar.textField.becomeFirstResponder()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages
        rootView.searchBar.textField.placeholder = R.string.localizable.assetsSearchPlaceholder(
            preferredLanguages: languages
        )

        rootView.cancelButton?.imageWithTitleView?.title = R.string.localizable.commonCancel(
            preferredLanguages: languages
        )

        rootView.cancelButton?.invalidateLayout()
        localizableTitle.map {
            title = $0.value(for: selectedLocale)
        }
    }

    private func setupCollectionView() {
        rootView.collectionView.registerCellClass(AssetListAssetCell.self)
        rootView.collectionView.registerCellClass(AssetListEmptyCell.self)
        rootView.collectionView.registerClass(
            AssetListNetworkView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )

        collectionViewLayout?.register(
            TokenGroupDecorationView.self,
            forDecorationViewOfKind: AssetsSearchFlowLayout.assetGroupDecoration
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

        rootView.cancelButton?.addTarget(self, action: #selector(actionCancel), for: .touchUpInside)
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
                height: AssetListMeasurement.assetHeaderHeight
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
        AssetsSearchFlowLayout.SectionType(section: section).cellSpacing
    }

    func collectionView(
        _: UICollectionView,
        layout _: UICollectionViewLayout,
        insetForSectionAt section: Int
    ) -> UIEdgeInsets {
        AssetsSearchFlowLayout.SectionType(section: section).insets
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
            if let groupIndex = AssetsSearchFlowLayout.SectionType.assetsGroupIndexFromSection(section) {
                return groupsState.groups[groupIndex].assets.count
            } else {
                return 0
            }
        }
    }

    private func provideEmptyStateCell(
        _ collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> AssetListEmptyCell {
        let cell = collectionView.dequeueReusableCellWithType(
            AssetListEmptyCell.self,
            for: indexPath
        )!

        let text = R.string.localizable.assetsSearchEmpty(preferredLanguages: selectedLocale.rLanguages)
        cell.bind(text: text)

        return cell
    }

    private func provideAssetCell(
        _ collectionView: UICollectionView,
        indexPath: IndexPath,
        assetIndex: Int
    ) -> AssetListAssetCell {
        let assetCell = collectionView.dequeueReusableCellWithType(
            AssetListAssetCell.self,
            for: indexPath
        )!

        if let groupIndex = AssetsSearchFlowLayout.SectionType.assetsGroupIndexFromSection(
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
            AssetListNetworkView.self,
            forSupplementaryViewOfKind: kind,
            for: indexPath
        )!

        if let groupIndex = AssetsSearchFlowLayout.SectionType.assetsGroupIndexFromSection(
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
    func didReceiveGroups(state: AssetListGroupState) {
        groupsState = state

        rootView.collectionView.reloadData()
    }
}

extension AssetsSearchViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            rootView.collectionView.reloadData()
            setupLocalization()
        }
    }
}
