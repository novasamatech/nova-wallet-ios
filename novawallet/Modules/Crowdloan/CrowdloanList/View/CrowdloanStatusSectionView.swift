import UIKit

final class CrowdloanStatusSectionView: UITableViewHeaderFooterView {
    let titleLabel: UILabel = .create {
        $0.textColor = R.color.colorWhite()
        $0.font = .h3Title
    }

    let countView: BorderedLabelView = .create {
        $0.titleLabel.textColor = R.color.colorWhite80()
        $0.titleLabel.font = .p2Paragraph
        $0.contentInsets = UIEdgeInsets(top: 2, left: 8, bottom: 3, right: 8)
    }

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
            make.top.equalToSuperview().inset(24)
            make.leading.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().inset(16)
        }

        contentView.addSubview(countView)
        countView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(8)
            make.height.equalTo(21)
            make.centerY.equalTo(titleLabel.snp.centerY)
        }
    }

    func bind(title: String, count: Int) {
        titleLabel.text = title
        countView.titleLabel.text = count.description
    }
}
