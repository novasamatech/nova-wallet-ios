import UIKit
import UIKit_iOS

final class SubtensorValidatorSelectViewLayout: UIView {
    let searchView: TopCustomSearchView = .create { view in
        view.isHidden = true
    }

    var searchTextField: UITextField {
        searchView.searchBar.textField
    }

    let headerView = SubtensorValidatorSectionHeaderView(reuseIdentifier: nil)

    let tableView: UITableView = .create { view in
        view.backgroundColor = .clear
        view.separatorStyle = .none
        view.keyboardDismissMode = .onDrag
        view.rowHeight = 58
        view.sectionHeaderHeight = 32
        view.sectionFooterHeight = 0
        view.sectionHeaderTopPadding = 0
    }

    let emptyLabel: UILabel = .create { label in
        label.font = .regularFootnote
        label.textColor = R.color.colorTextSecondary()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
    }

    let errorView: WarningView = .create { view in
        view.isHidden = true
        view.contentInsets.bottom = 4
        view.contentView.sView.spacing = 8
        view.contentView.sView.sView.spacing = 0
    }

    let bottomPanel = SubtensorBottomPanelView()

    let actionButton: TriangularedButton = .create { button in
        button.applyDefaultStyle()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSearchVisible(_ visible: Bool) {
        searchView.isHidden = !visible

        headerView.snp.remakeConstraints { make in
            if visible {
                make.top.equalTo(searchView.snp.bottom)
            } else {
                make.top.equalTo(safeAreaLayoutGuide)
            }
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(36)
        }
    }

    func bindError(_ viewModel: SubtensorValidatorErrorViewModel) {
        errorView.bind(WarningView.Model(
            title: viewModel.title,
            message: viewModel.details,
            learnMore: viewModel.retryTitle.map { LearnMoreViewModel(iconViewModel: nil, title: $0) }
        ))
    }

    func bindAction(title: String, isEnabled: Bool) {
        actionButton.imageWithTitleView?.title = title
        actionButton.isEnabled = isEnabled

        if isEnabled {
            actionButton.applyEnabledStyle()
        } else {
            actionButton.applyDisabledStyle()
        }

        actionButton.invalidateLayout()
    }

    private func setupLayout() {
        [searchView, headerView, tableView, emptyLabel, errorView, bottomPanel].forEach(addSubview)
        bottomPanel.contentView.addSubview(actionButton)

        searchView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.top).offset(52)
        }

        headerView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(36)
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomPanel.snp.top)
        }

        emptyLabel.snp.makeConstraints { make in
            make.center.equalTo(tableView)
            make.leading.trailing.equalToSuperview().inset(32)
        }

        errorView.snp.makeConstraints { make in
            make.top.equalTo(headerView).offset(14)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        bottomPanel.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }

        actionButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}

final class SubtensorValidatorSectionHeaderView: UITableViewHeaderFooterView {
    let titleLabel = UILabel(style: .semiboldCaps1Secondary, numberOfLines: 1)

    let detailsLabel = UILabel(style: .semiboldCaps1Secondary, textAlignment: .right, numberOfLines: 1)

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        backgroundView = UIView()
        backgroundView?.backgroundColor = R.color.colorSecondaryScreenBackground()

        contentView.addSubview(titleLabel)
        contentView.addSubview(detailsLabel)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.top.equalToSuperview().inset(14)
        }

        detailsLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8)
            make.top.equalTo(titleLabel)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(title: String, details: String?) {
        titleLabel.applySubtensorCaps(title)
        detailsLabel.applySubtensorCaps(details ?? "")
    }
}
