import UIKit

final class ReferendumVotersViewLayout: UIView {
    let totalVotersLabel: BorderedLabelView = .create { view in
        view.backgroundView.fillColor = R.color.colorWhite16()!
        view.titleLabel.apply(style: .init(textColor: R.color.colorWhite80()!, font: .semiBoldFootnote))
    }

    let tableView: UITableView = .create { view in
        view.separatorStyle = .none
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
