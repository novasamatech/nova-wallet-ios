import UIKit
import SnapKit
import SoraUI

class SettingsBaseTableViewCell<AccessoryView>: UITableViewCell, TableViewCellPositioning where AccessoryView: UIView {
    let iconImageView = UIImageView()

    let titleLabel: UILabel = .create { $0.apply(style: .regularSubhedlinePrimary) }

    private(set) var contentStackView: UIStackView?

    let roundView: RoundedView = .create { view in
        view.fillColor = R.color.colorBlockBackground()!
        view.cornerRadius = 10
        view.shadowOpacity = 0.0
    }

    let separatorView: BorderedContainerView = .create { view in
        view.strokeWidth = 0.5
        view.strokeColor = R.color.colorDivider()!
        view.borderType = .bottom
    }

    let rightView = AccessoryView()

    var accessorySize: CGSize? {
        didSet {
            updateAccessoryViewConstraints()
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        setupStyle()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(titleViewModel: TitleIconViewModel) {
        iconImageView.image = titleViewModel.icon
        titleLabel.text = titleViewModel.title
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)

        roundView.fillColor = highlighted ? R.color.colorCellBackgroundPressed()! : R.color.colorBlockBackground()!
    }

    func setupStyle() {
        backgroundColor = .clear
        selectionStyle = .none
    }

    func apply(position: TableViewCellPosition) {
        switch position {
        case .single:
            roundView.roundingCorners = .allCorners
            separatorView.borderType = .none
        case .top:
            roundView.roundingCorners = [.topLeft, .topRight]
            separatorView.borderType = .bottom
        case .middle:
            roundView.roundingCorners = []
            separatorView.borderType = .bottom
        case .bottom:
            roundView.roundingCorners = [.bottomLeft, .bottomRight]
            separatorView.borderType = .none
        }
    }

    func setupLayout() {
        let content = UIView.hStack(alignment: .center, spacing: 12, [
            iconImageView, titleLabel, UIView(), rightView
        ])

        contentStackView = content

        iconImageView.snp.makeConstraints { $0.size.equalTo(24) }

        roundView.addSubview(content)
        content.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.top.equalToSuperview().inset(12)
        }

        roundView.addSubview(separatorView)
        separatorView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.top.equalToSuperview().inset(separatorView.strokeWidth)
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
