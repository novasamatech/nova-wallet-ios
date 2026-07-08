import UIKit
import Foundation_iOS

/// Modal search screen presented from the validator picker — mirrors the
/// Polkadot `ValidatorSearch` flow visually (search field at top, empty state
/// graphic, live filtering) but stays single-select. Tapping a row returns
/// the chosen validator via `onSelection` and dismisses; the empty state uses
/// Nova's shared `iconStartSearch` / `iconEmptySearch` assets so it matches
/// other search screens in the app.
final class SubtensorValidatorSearchViewController: UIViewController {
    private let allValidators: [SubtensorValidator]
    private let netuid: UInt16
    private let cellViewModelFactory: SubtensorValidatorCellViewModelFactory
    private let onSelection: (SubtensorValidator) -> Void

    private var filteredValidators: [SubtensorValidator] = []
    private var filteredViewModels: [SubtensorValidatorCellViewModel] = []

    let searchBar: UISearchBar = {
        let bar = UISearchBar()
        bar.placeholder = "Search by address or name"
        bar.searchBarStyle = .minimal
        bar.autocapitalizationType = .none
        bar.autocorrectionType = .no
        return bar
    }()

    let tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.backgroundColor = R.color.colorSecondaryScreenBackground()
        table.separatorStyle = .singleLine
        table.separatorColor = R.color.colorContainerBorder()
        table.rowHeight = 56
        table.estimatedRowHeight = 56
        table.keyboardDismissMode = .onDrag
        table.tableFooterView = UIView()
        return table
    }()

    private let emptyImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .center
        return view
    }()

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorTextSecondary()
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let emptyStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 26
        return stack
    }()

    init(
        prefetched: [SubtensorValidator],
        netuid: UInt16,
        cellViewModelFactory: SubtensorValidatorCellViewModelFactory,
        onSelection: @escaping (SubtensorValidator) -> Void
    ) {
        allValidators = prefetched
        self.netuid = netuid
        self.cellViewModelFactory = cellViewModelFactory
        self.onSelection = onSelection
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = R.color.colorSecondaryScreenBackground()
        title = R.string(preferredLanguages: Locale.current.rLanguages)
            .localizable.commonSearch()

        setupLayout()
        setupTable()
        searchBar.delegate = self
        applyEmptyStateForCurrentQuery()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchBar.becomeFirstResponder()
    }

    @objc func dismissAnimated() {
        dismiss(animated: true)
    }

    private func setupLayout() {
        view.addSubview(searchBar)
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        emptyStack.addArrangedSubview(emptyImageView)
        emptyStack.addArrangedSubview(emptyLabel)
        view.addSubview(emptyStack)
        emptyStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            emptyStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStack.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
            emptyStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            emptyStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func setupTable() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(
            SubtensorValidatorTableViewCell.self,
            forCellReuseIdentifier: SubtensorValidatorTableViewCell.reuseId
        )
    }

    private func runSearch(query rawQuery: String) {
        let query = rawQuery.trimmingCharacters(in: .whitespaces)

        if query.isEmpty {
            filteredValidators = []
            filteredViewModels = []
        } else {
            let lower = query.lowercased()
            filteredValidators = allValidators.filter { validator in
                if let name = validator.identity?.lowercased(), name.contains(lower) {
                    return true
                }
                return validator.hotkey.toHex().lowercased().contains(lower)
            }
            filteredViewModels = filteredValidators.map {
                cellViewModelFactory.create(from: $0, netuid: netuid)
            }
        }

        tableView.reloadData()
        applyEmptyState(forQuery: query)
    }

    private func applyEmptyStateForCurrentQuery() {
        applyEmptyState(forQuery: (searchBar.text ?? "").trimmingCharacters(in: .whitespaces))
    }

    private func applyEmptyState(forQuery query: String) {
        let isResultsEmpty = filteredViewModels.isEmpty
        let languages = Locale.current.rLanguages

        tableView.isHidden = isResultsEmpty
        emptyStack.isHidden = !isResultsEmpty

        if query.isEmpty {
            emptyImageView.image = R.image.iconStartSearch()
            emptyLabel.text = R.string(preferredLanguages: languages)
                .localizable.commonSearchStartTitle_v2_2_0()
        } else {
            emptyImageView.image = R.image.iconEmptySearch()
            emptyLabel.text = R.string(preferredLanguages: languages)
                .localizable.stakingValidatorSearchEmptyTitle()
        }
    }
}

// MARK: - UITableViewDataSource

extension SubtensorValidatorSearchViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        filteredViewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: SubtensorValidatorTableViewCell.reuseId,
            for: indexPath
        ) as? SubtensorValidatorTableViewCell else {
            return UITableViewCell()
        }
        cell.bind(viewModel: filteredViewModels[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate

extension SubtensorValidatorSearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let validator = filteredValidators[indexPath.row]
        onSelection(validator)
    }
}

// MARK: - UISearchBarDelegate

extension SubtensorValidatorSearchViewController: UISearchBarDelegate {
    func searchBar(_: UISearchBar, textDidChange text: String) {
        runSearch(query: text)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
