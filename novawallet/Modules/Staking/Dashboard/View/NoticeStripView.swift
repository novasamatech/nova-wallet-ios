import UIKit

final class NoticeStripView: UIView {
    static let stripHeight: CGFloat = 28

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHidden: Bool {
        didSet { invalidateIntrinsicContentSize() }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: isHidden ? 0 : Self.stripHeight)
    }

    func bind(to banner: StakingNoticeBanner?) {
        guard let banner else {
            isHidden = true
            return
        }
        isHidden = false
        let (background, foreground) = banner.severity == .critical
            ? (R.color.colorErrorBlockBackground()!, R.color.colorTextNegative()!)
            : (R.color.colorWarningBlockBackground()!, R.color.colorTextWarning()!)
        backgroundColor = background
        label.textColor = foreground
        label.text = banner.text
    }

    private func configure() {
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.numberOfLines = 1
        label.textAlignment = .center
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
