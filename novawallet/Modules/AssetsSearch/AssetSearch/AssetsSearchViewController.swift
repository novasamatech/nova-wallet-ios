import UIKit
import Foundation_iOS

class AssetsSearchViewController: UIViewController, ViewHolder {
    typealias RootViewType = BaseAssetsSearchViewLayout

    let presenter: AssetsSearchPresenterProtocol

    var assetGroupsLayoutStyle: AssetListGroupsStyle?

    var collectionViewLayout: UICollectionViewFlowLayout? {
        rootView.collectionView.collectionViewLayout as? UICollectionViewFlowLayout
    }

    var collectionViewManager: AssetsSearchCollectionManagerProtocol?

    var groupsViewModel: AssetListViewModel = .init(
        isFiltered: false,
        listState: .list(groups: []),
        listGroupStyle: .tokens
    )

    private let createViewClosure: () -> BaseAssetsSearchViewLayout
    private let localizableTitle: LocalizableResource<String>?

    let keyboardAppearanceStrategy: KeyboardAppearanceStrategyProtocol

    init(
        presenter: AssetsSearchPresenterProtocol,
        keyboardAppearanceStrategy: KeyboardAppearanceStrategyProtocol,
        createViewClosure: @escaping () -> BaseAssetsSearchViewLayout,
        localizableTitle: LocalizableResource<String>? = nil,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.keyboardAppearanceStrategy = keyboardAppearanceStrategy
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

        setupCollectionView()
        setupSearchBar()
        setupLocalization()
        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        keyboardAppearanceStrategy.onViewWillAppear(for: rootView.searchBar.textField)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        keyboardAppearanceStrategy.onViewDidAppear(for: rootView.searchBar.textField)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        rootView.searchBar.textField.resignFirstResponder()
    }

    func setupCollectionManager() {
        collectionViewManager = AssetsSearchCollectionManager(
            view: rootView,
            groupsViewModel: groupsViewModel,
            delegate: self,
            selectedLocale: selectedLocale
        )
    }

    func setupLocalization() {
        let languages = selectedLocale.rLanguages
        rootView.searchBar.textField.placeholder = R.string(preferredLanguages: languages).localizable.assetsSearchPlaceholder()

        rootView.cancelButton?.imageWithTitleView?.title = R.string(preferredLanguages: languages).localizable.commonCancel()

        rootView.cancelButton?.invalidateLayout()
        localizableTitle.map {
            title = $0.value(for: selectedLocale)
        }
    }

    private func setupCollectionView() {
        setupCollectionManager()

        collectionViewManager?.setupCollectionView()
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

extension AssetsSearchViewController: AssetsSearchCollectionManagerDelegate {
    func selectAsset(for chainAssetId: ChainAssetId) {
        keyboardAppearanceStrategy.onCellSelected(for: rootView.searchBar.textField)
        presenter.selectAsset(for: chainAssetId)
    }

    func selectGroup(with symbol: AssetModel.Symbol) {
        keyboardAppearanceStrategy.onCellSelected(for: rootView.searchBar.textField)
        presenter.selectGroup(with: symbol)
    }
}

extension AssetsSearchViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}

extension AssetsSearchViewController: AssetsSearchViewProtocol {
    func didReceiveList(viewModel: AssetListViewModel) {
        groupsViewModel = viewModel
        collectionViewManager?.updateGroupsViewModel(with: viewModel)

        rootView.collectionView.reloadData()

        collectionViewManager?.updateTokensGroupLayout()
        setupLocalization()
    }

    func didReceiveAssetGroupsStyle(_ style: AssetListGroupsStyle) {
        guard assetGroupsLayoutStyle != style else { return }

        assetGroupsLayoutStyle = style

        setupLocalization()

        rootView.collectionViewLayout.changeGroupLayoutStyle(to: style)
        rootView.collectionView.reloadData()
    }
}

extension AssetsSearchViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            collectionViewManager?.updateSelectedLocale(with: selectedLocale)
            rootView.collectionView.reloadData()
            setupLocalization()
        }
    }
}
