import UIKit

/// Layout for the Subtensor validator picker. Holds:
///   - search bar at the top (filter by name / hotkey)
///   - table view (list of validators)
///   - centered loading indicator (first fetch)
///   - centered empty state ("No validators available")
///   - centered error state with retry button
///
/// All four state views overlap; the controller toggles visibility based on
/// the current `State`. Hardcoded English strings — see Phase E TODOs.
final class SubtensorValidatorPickerViewLayout: UIView {
    let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = R.color.colorSecondaryScreenBackground()
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = R.color.colorContainerBorder()
        tableView.rowHeight = 56
        tableView.estimatedRowHeight = 56
        tableView.keyboardDismissMode = .onDrag
        tableView.tableFooterView = UIView()
        return tableView
    }()

    let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = R.color.colorIconSecondary()
        indicator.hidesWhenStopped = true
        return indicator
    }()

    let emptyLabel: UILabel = {
        let label = UILabel()
        // TODO(phase-e): R.string.localizable.stakingSubtensorPickerEmpty(...)
        label.text = "No validators available"
        label.textColor = R.color.colorTextSecondary()
        label.font = .regularFootnote
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()

    let errorContainer: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.isHidden = true
        return stack
    }()

    let errorLabel: UILabel = {
        let label = UILabel()
        // TODO(phase-e): R.string.localizable.stakingSubtensorPickerError(...)
        label.text = "Unable to load validators"
        label.textColor = R.color.colorTextSecondary()
        label.font = .regularFootnote
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    let retryButton: UIButton = {
        let button = UIButton(type: .system)
        // TODO(phase-e): R.string.localizable.commonRetry(...)
        button.setTitle("Retry", for: .normal)
        button.titleLabel?.font = .semiBoldFootnote
        button.tintColor = R.color.colorButtonTextAccent()
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
        ])

        addSubview(loadingIndicator)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: tableView.centerYAnchor)
        ])

        addSubview(emptyLabel)
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            emptyLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24)
        ])

        errorContainer.addArrangedSubview(errorLabel)
        errorContainer.addArrangedSubview(retryButton)
        addSubview(errorContainer)
        errorContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            errorContainer.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            errorContainer.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
            errorContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            errorContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24)
        ])
    }

    func showState(_ state: PickerState) {
        switch state {
        case .loading:
            tableView.isHidden = true
            emptyLabel.isHidden = true
            errorContainer.isHidden = true
            loadingIndicator.startAnimating()
        case .loaded:
            tableView.isHidden = false
            emptyLabel.isHidden = true
            errorContainer.isHidden = true
            loadingIndicator.stopAnimating()
        case .empty:
            tableView.isHidden = true
            emptyLabel.isHidden = false
            errorContainer.isHidden = true
            loadingIndicator.stopAnimating()
        case .error:
            tableView.isHidden = true
            emptyLabel.isHidden = true
            errorContainer.isHidden = false
            loadingIndicator.stopAnimating()
        }
    }
}

extension SubtensorValidatorPickerViewLayout {
    enum PickerState {
        case loading
        case loaded
        case empty
        case error
    }
}
