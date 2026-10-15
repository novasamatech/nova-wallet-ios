import UIKit

final class SubtensorPositionNoticeView: UIView {
    let titleLabel: UILabel = .create { label in
        label.apply(style: .semiboldSubhedlinePrimary)
        label.numberOfLines = 0
    }

    let timeLeftLabel: UILabel = .create { label in
        label.font = .caption1
        label.textColor = R.color.colorTextWarning()
        label.textAlignment = .right
    }

    let clockView: UIImageView = .create { view in
        view.image = R.image.iconTimeFilled()?.tinted(with: R.color.colorIconWarning()!)
        view.contentMode = .scaleAspectFit
    }

    let messageLabel: UILabel = .create { label in
        label.apply(style: .caption1Secondary)
        label.numberOfLines = 0
    }

    private lazy var timeLeftView = UIView.hStack(alignment: .center, spacing: 6, [timeLeftLabel, clockView])

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlockBackground()
        layer.cornerRadius = 12

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: SubtensorPositionNoticeViewModel) {
        titleLabel.apply(text: viewModel.title, lineHeight: Constants.titleLineHeight)
        timeLeftLabel.text = viewModel.timeLeft
        timeLeftView.isHidden = viewModel.timeLeft == nil
        messageLabel.apply(text: viewModel.message, lineHeight: Constants.messageLineHeight)
    }
}

private extension SubtensorPositionNoticeView {
    enum Constants {
        static let titleLineHeight: CGFloat = 20
        static let messageLineHeight: CGFloat = 16
    }

    func setupLayout() {
        let headerView = UIView.hStack(alignment: .center, spacing: 8, [titleLabel, UIView(), timeLeftView])
        let contentView = UIView.vStack(spacing: 6, [headerView, messageLabel])

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
        }

        clockView.snp.makeConstraints { make in
            make.size.equalTo(16)
        }

        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        timeLeftView.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
}
