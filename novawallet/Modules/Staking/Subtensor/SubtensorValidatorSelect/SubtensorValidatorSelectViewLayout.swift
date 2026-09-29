import UIKit
import UIKit_iOS

final class SubtensorValidatorSelectViewLayout: UIView {
    let searchField: UITextField = .create { field in
        field.backgroundColor = R.color.colorBlockBackground()
        field.textColor = R.color.colorTextPrimary()
        field.font = .regularSubheadline
        field.layer.cornerRadius = 10
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        field.leftViewMode = .always
        field.returnKeyType = .search
        field.isHidden = true
    }

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

    let errorView: InlineAlertView = .create { view in
        view.apply(style: .warning)
        view.isHidden = true
    }

    let bottomBar: UIView = .create { view in
        view.backgroundColor = R.color.colorSecondaryScreenBackground()
    }

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
        searchField.isHidden = !visible

        tableView.snp.remakeConstraints { make in
            if visible {
                make.top.equalTo(searchField.snp.bottom).offset(12)
            } else {
                make.top.equalTo(safeAreaLayoutGuide)
            }

            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomBar.snp.top)
        }
    }

    func bindError(_ viewModel: SubtensorValidatorErrorViewModel) {
        let text = NSMutableAttributedString(
            string: viewModel.title,
            attributes: [.font: UIFont.semiBoldCaption1, .foregroundColor: R.color.colorTextPrimary()!]
        )

        text.append(NSAttributedString(string: "\n"))

        text.append(NSAttributedString(
            string: viewModel.details,
            attributes: [.font: UIFont.caption1, .foregroundColor: R.color.colorTextSecondary()!]
        ))

        errorView.contentView.detailsLabel.attributedText = text
        errorView.setLink(title: viewModel.retryTitle)
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
        [searchField, tableView, emptyLabel, errorView, bottomBar].forEach(addSubview)
        bottomBar.addSubview(actionButton)

        searchField.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).offset(12)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(40)
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomBar.snp.top)
        }

        emptyLabel.snp.makeConstraints { make in
            make.center.equalTo(tableView)
            make.leading.trailing.equalToSuperview().inset(32)
        }

        errorView.snp.makeConstraints { make in
            make.top.equalTo(tableView.snp.top).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        bottomBar.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }

        actionButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(52)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(12)
        }
    }
}

final class SubtensorValidatorSectionHeaderView: UITableViewHeaderFooterView {
    let titleLabel: UILabel = .create { label in
        label.font = .semiBoldCaps1
        label.textColor = R.color.colorTextSecondary()
    }

    let detailsLabel: UILabel = .create { label in
        label.font = .semiBoldCaps1
        label.textColor = R.color.colorTextSecondary()
        label.textAlignment = .right
    }

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        backgroundView = UIView()
        backgroundView?.backgroundColor = R.color.colorSecondaryScreenBackground()

        contentView.addSubview(titleLabel)
        contentView.addSubview(detailsLabel)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
        }

        detailsLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8)
            make.centerY.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(title: String, details: String?) {
        titleLabel.text = title
        detailsLabel.text = details
    }
}
