import UIKit

final class CrowdloanYourContributionsViewLayout: UIView {
    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .clear
        view.tableFooterView = UIView()
        view.separatorStyle = .none
        view.allowsSelection = false
        return view
    }()

    let unlockButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
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
        tableView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.bottom.trailing.equalToSuperview()
        }

        addSubview(unlockButton)
        unlockButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        updateTableViewInsets()
    }

    private func updateTableViewInsets() {
        if unlockButton.isHidden {
            tableView.contentInset = .zero
        } else {
            tableView.contentInset = UIEdgeInsets(
                top: 0,
                left: 0,
                bottom: UIConstants.actionHeight + 2 * UIConstants.actionBottomInset,
                right: 0
            )
        }
    }

    func setHasUnlocks(_ hasUnlocks: Bool) {
        unlockButton.isHidden = !hasUnlocks

        updateTableViewInsets()
    }
}
