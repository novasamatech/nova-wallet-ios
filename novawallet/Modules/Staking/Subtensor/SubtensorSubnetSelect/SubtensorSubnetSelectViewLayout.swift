import UIKit

final class SubtensorSubnetSelectViewLayout: UIView {
    let searchView = TopCustomSearchView()

    var searchBar: CustomSearchBar {
        searchView.searchBar
    }

    var searchTextField: UITextField {
        searchBar.textField
    }

    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .clear
        view.separatorStyle = .none
        return view
    }()

    let emptyLabel: UILabel = .create { label in
        label.font = .regularBody
        label.textColor = R.color.colorTextSecondary()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
    }

    let activityIndicator: UIActivityIndicatorView = .create { view in
        view.color = R.color.colorIconSecondary()
        view.hidesWhenStopped = true
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
}

private extension SubtensorSubnetSelectViewLayout {
    func setupLayout() {
        addSubview(searchView)
        searchView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.top).offset(Constants.preferredBarHeight)
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(searchView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }

        addSubview(emptyLabel)
        emptyLabel.snp.makeConstraints { make in
            make.center.equalTo(tableView)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { make in
            make.center.equalTo(tableView)
        }
    }

    enum Constants {
        static let preferredBarHeight: CGFloat = 52.0
    }
}

final class SubtensorSubnetSectionHeaderView: UITableViewHeaderFooterView {
    let titleLabel: UILabel = .create { label in
        label.font = .semiBoldCaption1
        label.textColor = R.color.colorTextSecondary()
    }

    let sortButton: UIButton = .create { button in
        button.titleLabel?.font = .caption1
        button.setTitleColor(R.color.colorTextSecondary(), for: .normal)
    }

    let filterButton: UIButton = .create { button in
        button.setImage(R.image.iconFilter(), for: .normal)
    }

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        contentView.backgroundColor = R.color.colorSecondaryScreenBackground()
        contentView.addSubview(titleLabel)
        contentView.addSubview(sortButton)
        contentView.addSubview(filterButton)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Constants.horizontalInset)
            make.centerY.equalToSuperview()
        }

        sortButton.snp.makeConstraints { make in
            make.trailing.equalTo(filterButton.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8)
        }

        filterButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(Constants.horizontalInset)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(28)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private enum Constants {
        static let horizontalInset: CGFloat = 16
    }
}
