import UIKit

final class ReferendumVotersViewLayout: UIView {
    let totalVotersLabel: BorderedLabelView = .create { view in
        view.backgroundView.fillColor = R.color.colorWhite16()!
        view.titleLabel.apply(style: .init(textColor: R.color.colorWhite80()!, font: .semiBoldFootnote))
        view.contentInsets = UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)
        view.backgroundView.cornerRadius = 6.0
    }

    let tableView: UITableView = .create { view in
        view.separatorStyle = .none
        view.backgroundColor = .clear
        view.contentInset = UIEdgeInsets(top: 8.0, left: 0, bottom: 0, right: 0)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()!

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
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}
