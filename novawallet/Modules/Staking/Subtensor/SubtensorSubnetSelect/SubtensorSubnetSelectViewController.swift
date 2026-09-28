import Foundation_iOS
import UIKit

final class SubtensorSubnetSelectViewController: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorSubnetSelectViewLayout

    let presenter: SubtensorSubnetSelectPresenterProtocol

    private var viewModels: [SubtensorSubnetSelectViewModel] = []
    private var sort: SubtensorSubnetSort = .favorites
    private var filters = SubtensorSubnetFilters()
    private var isLoading = true

    init(
        presenter: SubtensorSubnetSelectPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SubtensorSubnetSelectViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupSearchField()
        setupTableView()
        setupLocalization()

        presenter.setup()
    }
}

private extension SubtensorSubnetSelectViewController {
    func setupSearchField() {
        rootView.searchTextField.addTarget(
            self,
            action: #selector(actionSearchEditingChanged),
            for: .editingChanged
        )
    }

    func setupTableView() {
        rootView.tableView.rowHeight = 60
        rootView.tableView.sectionHeaderHeight = 36
        rootView.tableView.estimatedSectionHeaderHeight = 36
        rootView.tableView.registerClassForCell(SubtensorSubnetCell.self)
        rootView.tableView.registerClassForCell(SubtensorSubnetSkeletonCell.self)
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
    }

    func setupLocalization() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        title = strings.stakingSubtensorSubnetSelectTitle()

        rootView.emptyLabel.text = strings.stakingSubtensorUiPickerEmpty()

        rootView.searchTextField.attributedPlaceholder = NSAttributedString(
            string: strings.stakingSubtensorSubnetSearchPlaceholder(),
            attributes: [
                NSAttributedString.Key.foregroundColor: R.color.colorHintText() ?? .secondaryLabel
            ]
        )
        rootView.tableView.reloadData()
    }

    @objc func actionSearchEditingChanged() {
        presenter.search(query: rootView.searchTextField.text ?? "")
    }

    @objc func actionSort() {
        let sheet = SubnetOptionsSheetViewController(mode: .sort(sort) { [weak self] selected in
            self?.sort = selected
            self?.presenter.selectSort(selected)
        }, localizationManager: LocalizationManager.shared)
        present(sheet, animated: true)
    }

    @objc func actionFilters() {
        let sheet = SubnetOptionsSheetViewController(mode: .filters(filters) { [weak self] selected in
            self?.filters = selected
            self?.presenter.selectFilters(selected)
        }, localizationManager: LocalizationManager.shared)
        present(sheet, animated: true)
    }

    func model(at indexPath: IndexPath) -> SubtensorSubnetSelectViewModel? {
        if indexPath.section == 0 {
            return viewModels.first(where: { $0.target.isRoot })
        }

        let subnets = viewModels.filter { !$0.target.isRoot }
        return subnets.indices.contains(indexPath.row) ? subnets[indexPath.row] : nil
    }
}

extension SubtensorSubnetSelectViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int { 2 }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isLoading { return section == 0 ? 1 : 8 }

        return section == 0
            ? (viewModels.contains(where: { $0.target.isRoot }) ? 1 : 0)
            : viewModels.filter { !$0.target.isRoot }.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isLoading, indexPath.section == 1 {
            return tableView.dequeueReusableCellWithType(SubtensorSubnetSkeletonCell.self)
                ?? SubtensorSubnetSkeletonCell(style: .default, reuseIdentifier: nil)
        }

        let cell = tableView.dequeueReusableCellWithType(SubtensorSubnetCell.self)
            ?? SubtensorSubnetCell(style: .default, reuseIdentifier: nil)

        if isLoading {
            cell.bindLoadingRoot(locale: selectedLocale)
        } else if let model = model(at: indexPath) {
            cell.bind(viewModel: model, locale: selectedLocale)
            cell.favoriteAction = { [weak self] in
                self?.presenter.toggleFavorite(viewModel: model)
            }
        }

        return cell
    }
}

extension SubtensorSubnetSelectViewController: UITableViewDelegate {
    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat { 36 }

    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = SubtensorSubnetSectionHeaderView(reuseIdentifier: nil)
        let count = viewModels.filter { !$0.target.isRoot }.count
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        header.titleLabel.text = section == 0
            ? strings.stakingSubtensorUiPickerRootHeader()
            : (isLoading
                ? strings.stakingSubtensorUiPickerSubnetsHeader()
                : strings.stakingSubtensorUiPickerSubnetsCountFormat(count))
        header.sortButton.isHidden = section == 0
        header.filterButton.isHidden = section == 0
        header.filterButton.accessibilityLabel = strings.stakingSubtensorUiPickerFilters()
        if section == 1 {
            let title: String
            switch sort {
            case .favorites: title = strings.stakingSubtensorUiPickerFavoriteSort()
            case .sevenDayChange: title = strings.stakingSubtensorUiPickerSevenDay()
            case .thirtyDayChange: title = strings.stakingSubtensorUiPickerThirtyDay()
            case .poolDepth: title = strings.stakingSubtensorUiPickerPoolDepth()
            case .volume: title = strings.stakingSubtensorUiPickerVolume()
            case .age: title = strings.stakingSubtensorUiPickerAge()
            case .name: title = strings.stakingSubtensorUiPickerName()
            case .subnetNumber: title = strings.stakingSubtensorUiPickerNumber()
            }
            header.sortButton.setTitle(title, for: .normal)
            header.sortButton.addTarget(self, action: #selector(actionSort), for: .touchUpInside)
            header.filterButton.setImage(
                filters.isApplied ? R.image.iconFilterActive() : R.image.iconFilter(),
                for: .normal
            )
            header.filterButton.addTarget(self, action: #selector(actionFilters), for: .touchUpInside)
        }
        return header
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard !isLoading else { return }

        if let model = model(at: indexPath) {
            presenter.select(viewModel: model)
        }
    }
}

extension SubtensorSubnetSelectViewController: SubtensorSubnetSelectViewProtocol {
    func didReceive(viewModels: [SubtensorSubnetSelectViewModel]) {
        self.viewModels = viewModels

        rootView.tableView.reloadData()
        rootView.emptyLabel.isHidden = isLoading || !viewModels.isEmpty
    }

    func didReceiveLoading(_ isLoading: Bool) {
        self.isLoading = isLoading
        rootView.tableView.reloadData()
        rootView.emptyLabel.isHidden = isLoading || !viewModels.isEmpty
    }
}

extension SubtensorSubnetSelectViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
