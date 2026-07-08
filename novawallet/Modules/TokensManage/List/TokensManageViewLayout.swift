import UIKit

final class TokensManageViewLayout: UIView {
    let segmentedControl: UISegmentedControl = {
        let control = UISegmentedControl()
        control.insertSegment(withTitle: "", at: 0, animated: false)
        control.insertSegment(withTitle: "", at: 1, animated: false)
        control.selectedSegmentIndex = 0
        return control
    }()

    let searchView = TokensManageSearchView()

    var searchBar: CustomSearchBar {
        searchView.searchBar
    }

    var filterSwitch: UISwitch {
        searchView.zeroBalanceFilterSwitch
    }

    var filterLabel: UILabel {
        searchView.zeroBalanceFilterLabel
    }

    var dustFilterSwitch: UISwitch {
        searchView.dustFilterSwitch
    }

    var dustFilterLabel: UILabel {
        searchView.dustFilterLabel
    }

    var dustThresholdControl: UISegmentedControl {
        searchView.dustThresholdControl
    }

    var searchTextField: UITextField {
        searchBar.textField
    }

    let addTokenButton: UIBarButtonItem = {
        let button = UIBarButtonItem()
        button.style = .plain

        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorButtonTextAccent()!,
            .font: UIFont.regularSubheadline
        ]

        button.setTitleTextAttributes(attributes, for: .normal)
        button.setTitleTextAttributes(attributes, for: .highlighted)

        return button
    }()

    let selectAllButton: UIBarButtonItem = {
        let button = UIBarButtonItem()
        button.style = .plain

        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorButtonTextAccent()!,
            .font: UIFont.regularSubheadline
        ]

        button.setTitleTextAttributes(attributes, for: .normal)
        button.setTitleTextAttributes(attributes, for: .highlighted)

        return button
    }()

    let contentView: UIView = .create {
        $0.backgroundColor = .clear
    }

    let tableView: UITableView = .create {
        $0.backgroundColor = .clear
        $0.separatorStyle = .none
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

    func applySegmentTitles(tokens: String, networks: String) {
        segmentedControl.setTitle(tokens, forSegmentAt: 0)
        segmentedControl.setTitle(networks, forSegmentAt: 1)
    }

    private func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(searchView)

        searchView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview()
        }

        // Pin the controls stack top to the safe area so content starts
        // below the status bar / navigation bar area.
        searchView.controlsStackView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(4)
        }

        addSubview(segmentedControl)

        segmentedControl.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(searchView.snp.bottom).offset(8)
            make.height.equalTo(32)
        }

        contentView.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(segmentedControl.snp.bottom).offset(8)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}

extension TokensManageViewLayout {
    func updateSearchViewHeight(dustFilterVisible: Bool) {
        searchView.setDustFilterVisible(dustFilterVisible)
    }

    func updateDustThresholdVisibility(visible: Bool) {
        searchView.setDustThresholdVisible(visible)
    }
}
