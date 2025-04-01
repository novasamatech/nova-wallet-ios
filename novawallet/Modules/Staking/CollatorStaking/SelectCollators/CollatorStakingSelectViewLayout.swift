import UIKit
import UIKit_iOS

final class CollatorStakingSelectViewLayout: UIView {
    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        return tableView
    }()

    let clearButton: RoundedButton = {
        let button = RoundedButton()
        button.applySecondaryStyle()
        return button
    }()

    let searchButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(
            R.image.iconSearchWhite()?.tinted(with: R.color.colorIconPrimary()!),
            for: .normal
        )
        return button
    }()

    let filterButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(
            R.image.iconFilterActive()?.tinted(with: R.color.colorIconPrimary()!),
            for: .normal
        )
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
        addSubview(clearButton)
        clearButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(safeAreaLayoutGuide).offset(8.0)
            make.height.equalTo(32.0)
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(clearButton.snp.bottom).offset(16.0)
            make.bottom.equalToSuperview()
        }
    }
}
