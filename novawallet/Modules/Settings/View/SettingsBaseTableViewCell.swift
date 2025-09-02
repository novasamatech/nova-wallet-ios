import UIKit
import SnapKit
import UIKit_iOS

class SettingsBaseTableViewCell<AccessoryView>: UITableViewCell, TableViewCellPositioning, ActivatableTableViewCell where AccessoryView: UIView {
    let iconImageView = UIImageView()

    let titleLabel: UILabel = .create {
        $0.apply(style: .regularSubhedlinePrimary)
        $0.setContentCompressionResistancePriority(.high, for: .horizontal)
    }

    private(set) var contentStackView: UIStackView?
    private var imageViewModel: ImageViewModelProtocol?

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
        if let icon = titleViewModel.icon {
            iconImageView.image = icon
            iconImageView.isHidden = false
        } else {
            iconImageView.isHidden = true
        }

        titleLabel.text = titleViewModel.title
        setNeedsLayout()
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)

        guard selectionStyle != .none else {
            return
        }

        roundView.fillColor = highlighted ? R.color.colorCellBackgroundPressed()! : R.color.colorBlockBackground()!
    }

    override func prepareForReuse() {
        imageViewModel?.cancel(on: iconImageView)
        super.prepareForReuse()
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

        roundView.addSubview(separatorView)
        separatorView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.top.equalToSuperview().inset(separatorView.strokeWidth)
        }
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

    func hideImageViewIfNeeded(titleViewModel: TitleIconViewModel) {
        iconImageView.isHidden = titleViewModel.icon == nil
    }

    func bind(icon: ImageViewModelProtocol?, title: String) {
        iconImageView.isHidden = false

        imageViewModel?.cancel(on: iconImageView)
        icon?.loadImage(
            on: iconImageView,
            settings: .init(targetSize: .init(width: 24, height: 24)),
            animated: true
        )
        imageViewModel = icon
        titleLabel.text = title

        setNeedsLayout()
    }

    func set(active: Bool) {
        isUserInteractionEnabled = active
        titleLabel.apply(style: active ? .regularSubhedlinePrimary : .regularSubhedlineInactive)
    }
}
