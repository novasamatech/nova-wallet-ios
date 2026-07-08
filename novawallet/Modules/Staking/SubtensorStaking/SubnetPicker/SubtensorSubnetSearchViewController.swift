import UIKit
import Foundation_iOS

/// Modal search screen for the subnet picker. Live-filters by name or
/// netuid (digits are matched against the subnet number) and pops back
/// to the picker on selection. Mirrors the validator search modal.
final class SubtensorSubnetSearchViewController: UIViewController {
    private let allSubnets: [SubtensorSubnetInfo]
    private let onSelection: (SubtensorSubnetInfo) -> Void

    private var filtered: [SubtensorSubnetInfo] = []

    let searchBar: UISearchBar = {
        let bar = UISearchBar()
        bar.placeholder = "Search by name or subnet number"
        bar.searchBarStyle = .minimal
        bar.autocapitalizationType = .none
        bar.autocorrectionType = .no
        return bar
    }()

    let tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.backgroundColor = R.color.colorSecondaryScreenBackground()
        table.separatorStyle = .none
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 72
        table.keyboardDismissMode = .onDrag
        table.tableFooterView = UIView()
        table.register(SubtensorSubnetCell.self, forCellReuseIdentifier: SubtensorSubnetCell.reuseId)
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
        allSubnets: [SubtensorSubnetInfo],
        onSelection: @escaping (SubtensorSubnetInfo) -> Void
    ) {
        self.allSubnets = allSubnets
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
        title = R.string(preferredLanguages: Locale.current.rLanguages).localizable.commonSearch()

        setupLayout()
        tableView.dataSource = self
        tableView.delegate = self
        searchBar.delegate = self
        applyEmptyState(forQuery: "")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchBar.becomeFirstResponder()
    }

    @objc func dismissAnimated() { dismiss(animated: true) }

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

    private func runSearch(query rawQuery: String) {
        let query = rawQuery.trimmingCharacters(in: .whitespaces)
        if query.isEmpty {
            filtered = []
        } else {
            let lower = query.lowercased()
            filtered = allSubnets.filter { subnet in
                if let name = subnet.name?.lowercased(), name.contains(lower) {
                    return true
                }
                // Numeric match — both raw "62" and "sn62" prefixes
                if String(subnet.netuid).hasPrefix(query) ||
                    "sn\(subnet.netuid)".lowercased().contains(lower) {
                    return true
                }
                return false
            }
        }
        tableView.reloadData()
        applyEmptyState(forQuery: query)
    }

    private func applyEmptyState(forQuery query: String) {
        let isEmpty = filtered.isEmpty
        tableView.isHidden = isEmpty
        emptyStack.isHidden = !isEmpty
        let languages = Locale.current.rLanguages
        if query.isEmpty {
            emptyImageView.image = R.image.iconStartSearch()
            emptyLabel.text = R.string(preferredLanguages: languages)
                .localizable.commonSearchStartTitle_v2_2_0()
        } else {
            emptyImageView.image = R.image.iconEmptySearch()
            emptyLabel.text = "No subnets match"
        }
    }
}

extension SubtensorSubnetSearchViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int { filtered.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: SubtensorSubnetCell.reuseId,
            for: indexPath
        ) as? SubtensorSubnetCell else {
            return UITableViewCell()
        }
        cell.bind(subnet: filtered[indexPath.row])
        return cell
    }
}

extension SubtensorSubnetSearchViewController: UITableViewDelegate {
    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        onSelection(filtered[indexPath.row])
    }
}

extension SubtensorSubnetSearchViewController: UISearchBarDelegate {
    func searchBar(_: UISearchBar, textDidChange text: String) {
        runSearch(query: text)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
