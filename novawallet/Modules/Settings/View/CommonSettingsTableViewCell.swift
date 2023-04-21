import UIKit
import SnapKit
import SoraUI

protocol RoundableTableViewCell: UITableViewCell {
    var roundView: RoundedView { get }
}

class CommonSettingsTableViewCell<AccessoryView>: UITableViewCell, RoundableTableViewCell where AccessoryView: UIView {
    let iconImageView = UIImageView()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextPrimary()
        label.font = .p1Paragraph
        return label
    }()

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextSecondary()
        label.font = .p1Paragraph
        return label
    }()

    let rightView = AccessoryView()

    let roundView: RoundedView = {
        let view = RoundedView()
        view.fillColor = R.color.colorBlockBackground()!
        view.cornerRadius = 10
        view.shadowOpacity = 0.0
        return view
    }()

    var accessorySize: CGSize? {
        didSet {
            updateAccessoryViewConstraints()
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear

        selectionStyle = .none
        separatorInset = .init(top: 0, left: 32, bottom: 0, right: 32)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)

        roundView.fillColor = highlighted ? R.color.colorCellBackgroundPressed()! : R.color.colorBlockBackground()!
    }

    private func setupLayout() {
        let content = UIView.hStack(alignment: .center, spacing: 12, [
            iconImageView, titleLabel, UIView(), subtitleLabel, rightView
        ])
        iconImageView.snp.makeConstraints { $0.size.equalTo(24) }

        roundView.addSubview(content)
        content.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.top.equalToSuperview().inset(12)
        }

        contentView.addSubview(roundView)
        roundView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.bottom.equalToSuperview()
        }
    }

    private func updateAccessoryViewConstraints() {
        if let accessoryViewSize = accessorySize {
            rightView.snp.remakeConstraints { $0.size.equalTo(accessoryViewSize) }
        } else {
            rightView.snp.removeConstraints()
        }
    }
}
