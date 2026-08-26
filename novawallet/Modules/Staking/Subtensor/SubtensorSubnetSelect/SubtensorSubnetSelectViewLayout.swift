import UIKit

final class SubtensorSubnetSelectViewLayout: UIView {
    let searchView = TopCustomSearchView()

    var searchBar: CustomSearchBar {
        searchView.searchBar
    }

    var searchTextField: UITextField {
        searchBar.textField
    }

    let disclaimerLabel: UILabel = {
        let label = UILabel()
        label.font = .caption1
        label.textColor = R.color.colorTextSecondary()
        label.numberOfLines = 0
        return label
    }()

    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .clear
        view.separatorStyle = .none
        return view
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
}

private extension SubtensorSubnetSelectViewLayout {
    func setupLayout() {
        addSubview(searchView)
        searchView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.top).offset(Constants.preferredBarHeight)
        }

        addSubview(disclaimerLabel)
        disclaimerLabel.snp.makeConstraints { make in
            make.top.equalTo(searchView.snp.bottom).offset(8.0)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(disclaimerLabel.snp.bottom).offset(8.0)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    enum Constants {
        static let preferredBarHeight: CGFloat = 52.0
    }
}
