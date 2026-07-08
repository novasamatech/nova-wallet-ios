import UIKit
import Foundation_iOS
import UIKit_iOS

final class TokensManageViewController: UIViewController, ViewHolder {
    typealias RootViewType = TokensManageViewLayout

    let presenter: TokensManagePresenterProtocol

    private var sections: [ManageTokenSection] = []

    init(presenter: TokensManagePresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = TokensManageViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTopBar()
        setupSearchField()
        setupFilter()
        setupSegmentedControl()
        setupTableView()
        setupLocalization()

        presenter.setup()
    }

    private func setupTopBar() {
        rootView.selectAllButton.target = self
        rootView.selectAllButton.action = #selector(actionSelectAll)

        rootView.addTokenButton.target = self
        rootView.addTokenButton.action = #selector(actionAddToken)

        navigationItem.rightBarButtonItems = [rootView.addTokenButton, rootView.selectAllButton]
    }

    private func setupFilter() {
        rootView.filterSwitch.addTarget(
            self,
            action: #selector(actionHideZeroBalances),
            for: .valueChanged
        )

        rootView.dustFilterSwitch.addTarget(
            self,
            action: #selector(actionDustFilterChanged),
            for: .valueChanged
        )

        rootView.dustThresholdControl.addTarget(
            self,
            action: #selector(actionDustThresholdChanged),
            for: .valueChanged
        )
    }

    private func setupSearchField() {
        rootView.searchTextField.addTarget(
            self,
            action: #selector(actionSearchEditingChanged),
            for: .editingChanged
        )

        rootView.searchTextField.delegate = self
    }

    private func setupSegmentedControl() {
        rootView.segmentedControl.addTarget(
            self,
            action: #selector(actionSegmentChanged),
            for: .valueChanged
        )
    }

    private func setupTableView() {
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
        rootView.tableView.registerClassForCell(ManageTokenSectionHeaderCell.self)
        rootView.tableView.registerClassForCell(ManageTokenChildItemCell.self)
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string(preferredLanguages: languages).localizable.tokensManageTitle()

        rootView.addTokenButton.title = R.string(preferredLanguages: languages).localizable.commonAddToken()

        rootView.applySegmentTitles(
            tokens: R.string(preferredLanguages: languages).localizable.commonTokens(),
            networks: R.string(preferredLanguages: languages).localizable.commonNetworks()
        )

        let placeholder = R.string(preferredLanguages: languages).localizable.assetsSearchPlaceholder()

        rootView.filterLabel.text = R.string(preferredLanguages: languages).localizable.assetsManageHideZeroBalances()
        rootView.dustFilterLabel.text = R.string(preferredLanguages: languages).localizable.assetsManageHideDust()

        rootView.searchTextField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                NSAttributedString.Key.foregroundColor: R.color.colorHintText()!
            ]
        )
    }

    /// Returns the section index for a given header cell.
    private func sectionIndex(for headerCell: ManageTokenSectionHeaderCell) -> Int? {
        guard let indexPath = rootView.tableView.indexPath(for: headerCell) else {
            return nil
        }

        return sectionIndexFromFlatRow(indexPath.row)
    }

    /// Returns the ManageTokenItem for a given child cell.
    private func childItem(for cell: ManageTokenChildItemCell) -> ManageTokenItem? {
        guard let indexPath = rootView.tableView.indexPath(for: cell) else {
            return nil
        }

        return itemFromFlatRow(indexPath.row)
    }

    // MARK: - Flat row helpers

    /// The total number of flat rows = sum of (1 header + expanded children) per section.
    private func totalFlatRowCount() -> Int {
        sections.reduce(0) { total, section in
            total + 1 + (section.isExpanded ? section.items.count : 0)
        }
    }

    /// Maps a flat row index to either a section header or a child item.
    private enum FlatRowKind {
        case header(sectionIndex: Int)
        case child(sectionIndex: Int, itemIndex: Int)
    }

    private func flatRowKind(for row: Int) -> FlatRowKind? {
        var currentRow = 0

        for (sectionIdx, section) in sections.enumerated() {
            if currentRow == row {
                return .header(sectionIndex: sectionIdx)
            }

            currentRow += 1

            if section.isExpanded {
                for itemIdx in 0 ..< section.items.count {
                    if currentRow == row {
                        return .child(sectionIndex: sectionIdx, itemIndex: itemIdx)
                    }
                    currentRow += 1
                }
            }
        }

        return nil
    }

    private func sectionIndexFromFlatRow(_ row: Int) -> Int? {
        if case let .header(sectionIndex) = flatRowKind(for: row) {
            return sectionIndex
        }
        return nil
    }

    private func itemFromFlatRow(_ row: Int) -> ManageTokenItem? {
        if case let .child(sectionIndex, itemIndex) = flatRowKind(for: row) {
            return sections[sectionIndex].items[itemIndex]
        }
        return nil
    }

    // MARK: - Actions

    @objc private func actionAddToken() {
        presenter.performAddToken()
    }

    @objc private func actionSearchEditingChanged() {
        let query = rootView.searchTextField.text ?? ""
        presenter.search(query: query)
    }

    @objc private func actionHideZeroBalances() {
        presenter.performFilterChange(to: rootView.filterSwitch.isOn)

        // Show/hide dust filter based on zero-balance toggle state
        rootView.updateSearchViewHeight(dustFilterVisible: rootView.filterSwitch.isOn)
        UIView.animate(withDuration: 0.25) {
            self.rootView.layoutIfNeeded()
        }
    }

    @objc private func actionDustFilterChanged() {
        presenter.performDustFilterChange(to: rootView.dustFilterSwitch.isOn)

        // Show/hide threshold picker based on dust filter state
        rootView.updateDustThresholdVisibility(visible: rootView.dustFilterSwitch.isOn)
        UIView.animate(withDuration: 0.25) {
            self.rootView.layoutIfNeeded()
        }
    }

    @objc private func actionDustThresholdChanged() {
        let thresholds: [Decimal] = [1, 5, 10, 50]
        let selectedIndex = rootView.dustThresholdControl.selectedSegmentIndex
        guard selectedIndex >= 0, selectedIndex < thresholds.count else { return }

        presenter.performDustThresholdChange(to: thresholds[selectedIndex])
    }

    @objc private func actionSegmentChanged() {
        guard let tab = ManageTokensTab(rawValue: rootView.segmentedControl.selectedSegmentIndex) else {
            return
        }
        presenter.performTabSwitch(to: tab)
    }

    @objc private func actionSelectAll() {
        presenter.performSelectAll()
    }
}

// MARK: - UITableViewDataSource

extension TokensManageViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        totalFlatRowCount()
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let kind = flatRowKind(for: indexPath.row) else {
            return UITableViewCell()
        }

        switch kind {
        case let .header(sectionIndex):
            let cell: ManageTokenSectionHeaderCell = tableView.dequeueReusableCell(for: indexPath)
            cell.delegate = self
            cell.bind(section: sections[sectionIndex])
            return cell

        case let .child(sectionIndex, itemIndex):
            let cell: ManageTokenChildItemCell = tableView.dequeueReusableCell(for: indexPath)
            cell.delegate = self
            cell.bind(item: sections[sectionIndex].items[itemIndex])
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension TokensManageViewController: UITableViewDelegate {
    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let kind = flatRowKind(for: indexPath.row) else {
            return 0
        }

        switch kind {
        case .header:
            return 56
        case .child:
            return 48
        }
    }
}

// MARK: - ManageTokenSectionHeaderCellDelegate

extension TokensManageViewController: ManageTokenSectionHeaderCellDelegate {
    func sectionHeaderCellDidTap(_ cell: ManageTokenSectionHeaderCell) {
        guard let sectionIndex = sectionIndex(for: cell) else {
            return
        }

        presenter.performToggleSection(at: sectionIndex)
    }
}

// MARK: - ManageTokenChildItemCellDelegate

extension TokensManageViewController: ManageTokenChildItemCellDelegate {
    func childItemCell(_ cell: ManageTokenChildItemCell, didChangeSwitch enabled: Bool) {
        guard let item = childItem(for: cell) else {
            return
        }

        presenter.performSwitch(for: item, enabled: enabled)
    }
}

// MARK: - TokensManageViewProtocol

extension TokensManageViewController: TokensManageViewProtocol {
    func didReceive(hidesZeroBalances: Bool) {
        rootView.filterSwitch.setOn(
            hidesZeroBalances,
            animated: true
        )

        rootView.updateSearchViewHeight(dustFilterVisible: hidesZeroBalances)
    }

    func didReceive(dustFilterEnabled: Bool) {
        rootView.dustFilterSwitch.setOn(dustFilterEnabled, animated: true)
        rootView.updateDustThresholdVisibility(visible: dustFilterEnabled)
    }

    func didReceive(dustFilterThreshold: Decimal) {
        let thresholds: [Decimal] = [1, 5, 10, 50]
        if let index = thresholds.firstIndex(of: dustFilterThreshold) {
            rootView.dustThresholdControl.selectedSegmentIndex = index
        }
    }

    func didReceive(sections: [ManageTokenSection]) {
        self.sections = sections
        rootView.tableView.reloadData()

        reloadEmptyState(animated: false)
    }

    func didReceive(selectAllTitle: String) {
        rootView.selectAllButton.title = selectAllTitle
    }
}

// MARK: - EmptyState

extension TokensManageViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

extension TokensManageViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        let emptyView = EmptyStateView()
        emptyView.image = R.image.iconLoadingError()!
        emptyView.title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.assetsSearchEmpty()
        emptyView.titleColor = R.color.colorTextSecondary()!
        emptyView.titleFont = .regularFootnote
        return emptyView
    }

    var contentViewForEmptyState: UIView {
        rootView.contentView
    }
}

extension TokensManageViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}

extension TokensManageViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        let hasQuery = !(rootView.searchTextField.text ?? "").isEmpty
        let hasNoItems = sections.isEmpty

        return hasQuery && hasNoItems
    }
}

extension TokensManageViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            reloadEmptyState(animated: false)
        }
    }
}
