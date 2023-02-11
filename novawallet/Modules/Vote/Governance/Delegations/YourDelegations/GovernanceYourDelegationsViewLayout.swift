import UIKit

final class GovernanceYourDelegationsViewLayout: UIView {
    let tableView: UITableView = .create {
        $0.separatorStyle = .none
        $0.backgroundColor = .clear
        $0.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 0, right: 0)
        $0.registerClassForCell(GovernanceYourDelegationCell.self)
        $0.rowHeight = UITableView.automaticDimension
    }

    let addDelegationButton: TriangularedButton = .create {
        $0.applyDefaultStyle()
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

    private func setupLayout() {
        addSubview(tableView)

        tableView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
            make.leading.trailing.bottom.equalToSuperview()
        }

        addSubview(addDelegationButton)

        addDelegationButton.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
        }

        tableView.contentInset = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: UIConstants.actionHeight + 2 * UIConstants.actionBottomInset,
            right: 0
        )
    }
}
