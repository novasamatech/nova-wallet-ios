import Foundation_iOS
import SubstrateSdk
import UIKit
import UIKit_iOS

final class SubtensorValidatorSelectViewController: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorValidatorSelectViewLayout

    let presenter: ValidatorSelectPresenterProtocol
    let isRoot: Bool
    private let iconGenerator = PolkadotIconGenerator()
    private var rows: [SubtensorValidatorRowViewModel] = []
    private var isLoading = true
    private var sort: SubtensorValidatorSort

    private var recommendedRows: [SubtensorValidatorRowViewModel] { rows.filter { $0.item.isNovaPreferred } }
    private var otherRows: [SubtensorValidatorRowViewModel] { rows.filter { !$0.item.isNovaPreferred } }

    init(presenter: ValidatorSelectPresenterProtocol, isRoot: Bool, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        self.isRoot = isRoot
        sort = isRoot ? .totalStaked : .apy
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() { view = SubtensorValidatorSelectViewLayout() }

    override func viewDidLoad() {
        super.viewDidLoad()
        rootView.tableView.registerClassForCell(SubtensorValidatorSelectCell.self)
        rootView.tableView.registerClassForCell(SubtensorValidatorSkeletonCell.self)
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.rowHeight = 58
        rootView.tableView.sectionHeaderHeight = 32
        rootView.searchField.addTarget(self, action: #selector(searchChanged), for: .editingChanged)
        rootView.actionButton.addTarget(self, action: #selector(confirm), for: .touchUpInside)
        rootView.retryButton.addTarget(self, action: #selector(retry), for: .touchUpInside)
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(image: R.image.iconFilter(), style: .plain, target: self, action: #selector(showSort)),
            UIBarButtonItem(
                image: UIImage(systemName: "magnifyingglass"),
                style: .plain,
                target: self,
                action: #selector(toggleSearch)
            )
        ]
        rootView.setSearchVisible(false)
        setupLocalization()
        presenter.setup()
    }

    private func setupLocalization() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable
        title = strings.stakingSubtensorUiValidatorTitle()
        rootView.searchField.placeholder = strings.stakingSubtensorUiValidatorSearch()
        rootView.emptyLabel.text = strings.stakingSubtensorUiValidatorEmpty()
        rootView.errorTitle.text = strings.stakingSubtensorUiValidatorFetchFailed()
        rootView.errorDetail.text = strings.stakingSubtensorUiValidatorFetchFailedDetail()
        rootView.retryButton.setTitle(strings.stakingSubtensorUiValidatorRetry(), for: .normal)
        rootView.tableView.reloadData()
    }

    @objc private func searchChanged() { presenter.search(rootView.searchField.text ?? "") }
    @objc private func confirm() { presenter.confirm() }
    @objc private func retry() {
        rootView.errorCard.isHidden = true
        presenter.retry()
    }

    @objc private func toggleSearch() {
        let show = rootView.searchField.isHidden
        rootView.setSearchVisible(show)
        if show {
            rootView.searchField.becomeFirstResponder()
        } else {
            rootView.searchField.resignFirstResponder()
            rootView.searchField.text = nil
            presenter.search("")
        }
    }

    @objc private func showSort() {
        let sheet = ValidatorSortSheetViewController(
            selected: sort,
            locale: selectedLocale,
            allowsApy: !isRoot
        ) { [weak self] selected in
            self?.sort = selected
            self?.presenter.selectSort(selected)
        }
        present(sheet, animated: true)
    }

    private func model(at indexPath: IndexPath) -> SubtensorValidatorRowViewModel? {
        let sectionRows = indexPath.section == 0 ? recommendedRows : otherRows
        return sectionRows.indices.contains(indexPath.row) ? sectionRows[indexPath.row] : nil
    }
}

extension SubtensorValidatorSelectViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int { 2 }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isLoading { return section == 0 ? 1 : 6 }
        return section == 0 ? recommendedRows.count : otherRows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isLoading {
            return tableView.dequeueReusableCellWithType(SubtensorValidatorSkeletonCell.self)
                ?? SubtensorValidatorSkeletonCell(style: .default, reuseIdentifier: nil)
        }
        let cell = tableView.dequeueReusableCellWithType(SubtensorValidatorSelectCell.self)
            ?? SubtensorValidatorSelectCell(style: .default, reuseIdentifier: nil)
        guard let model = model(at: indexPath) else { return cell }
        cell.bind(model, icon: try? iconGenerator.generateFromAccountId(model.item.hotkey))
        cell.infoAction = { [weak self] in
            guard let self, let index = rows.firstIndex(where: { $0.item.hotkey == model.item.hotkey }) else { return }
            presenter.showInfo(at: index)
        }
        return cell
    }
}

extension SubtensorValidatorSelectViewController: UITableViewDelegate {
    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 0 && recommendedRows.isEmpty && !isLoading ? 0 : 32
    }

    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = R.color.colorSecondaryScreenBackground()
        let label = UILabel()
        label.font = .caption1
        label.textColor = R.color.colorTextSecondary()
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable
        label.text = section == 0
            ? strings.stakingSubtensorUiValidatorRecommended()
            : isLoading
            ? strings.stakingSubtensorUiValidatorLoadingCount()
            : strings.stakingSubtensorUiValidatorCountFormat(rows.count)
        header.addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
        }
        return header
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !isLoading, let model = model(at: indexPath),
              let index = rows.firstIndex(where: { $0.item.hotkey == model.item.hotkey }) else { return }
        presenter.select(at: index)
    }
}

extension SubtensorValidatorSelectViewController: SubtensorValidatorSelectViewProtocol {
    func didReceive(rows: [SubtensorValidatorRowViewModel], isLoading: Bool) {
        self.rows = rows
        self.isLoading = isLoading
        rootView.tableView.reloadData()
        rootView.tableView.isHidden = false
        rootView.emptyLabel.isHidden = isLoading || !rows.isEmpty
        if isLoading || !rows.isEmpty { rootView.errorCard.isHidden = true }
    }

    func didReceive(selectionTitle: String?, isEnabled: Bool) {
        rootView.actionButton.imageWithTitleView?.title = selectionTitle
            ?? R.string(preferredLanguages: selectedLocale.rLanguages).localizable.stakingSubtensorUiValidatorSelect()
        rootView.actionButton.isEnabled = isEnabled
        if isEnabled {
            rootView.actionButton.applyEnabledStyle()
        } else {
            rootView.actionButton.applyDisabledStyle()
        }
        rootView.actionButton.invalidateLayout()
    }

    func didFailDirectory() {
        rootView.errorCard.isHidden = false
        rootView.emptyLabel.isHidden = true
        rootView.tableView.isHidden = true
    }
}

extension SubtensorValidatorSelectViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded { setupLocalization() }
    }
}
