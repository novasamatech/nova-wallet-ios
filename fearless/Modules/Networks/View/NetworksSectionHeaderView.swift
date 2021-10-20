import UIKit

final class NetworksSectionHeaderView: UITableViewHeaderFooterView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .capsTitle
        label.textColor = R.color.colorLightGray()
        return label
    }()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        backgroundView = UIView()
        backgroundView?.backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(12)
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview().inset(3)
        }
    }

    func highlight(_ highlight: Bool) {
        titleLabel.textColor = highlight ? R.color.colorLightGray() : R.color.colorStrokeGray()
    }
}
