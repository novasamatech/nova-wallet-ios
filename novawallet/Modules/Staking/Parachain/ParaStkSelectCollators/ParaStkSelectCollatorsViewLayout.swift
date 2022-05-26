import UIKit
import SoraUI

final class ParaStkSelectCollatorsViewLayout: UIView {
    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        return tableView
    }()

    let clearButton: RoundedButton = {
        let button = RoundedButton()
        button.applyEnabledStyle()
        return button
    }()

    let searchButton: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: R.image.iconSearchWhite(),
            style: .plain,
            target: nil,
            action: nil
        )
        return item
    }()

    let filterButton: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: R.image.iconFilter(),
            style: .plain,
            target: nil,
            action: nil
        )
        return item
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(clearButton)
        clearButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(safeAreaLayoutGuide).offset(12.0)
            make.height.equalTo(32.0)
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(clearButton.snp.bottom).offset(24.0)
            make.bottom.equalToSuperview()
        }
    }
}
