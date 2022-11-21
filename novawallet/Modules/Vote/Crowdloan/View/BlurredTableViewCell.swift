import UIKit

class BlurredTableViewCell<TContentView>: UITableViewCell where TContentView: UIView {
    let view: TContentView = .init()
    let backgroundBlurView = TriangularedBlurView()

    var shouldApplyHighlighting: Bool = false

    var contentInsets: UIEdgeInsets = .init(top: 0, left: 16, bottom: 0, right: 16) {
        didSet {
            updateLayout()
        }
    }

    var innerInsets: UIEdgeInsets = .zero {
        didSet {
            updateLayout()
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        selectedBackgroundView = UIView()
        setupLayout()
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)

        backgroundBlurView.overlayView.fillColor = shouldApplyHighlighting && highlighted ?
            R.color.colorAccentSelected()!
            : .clear
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        .init(width: UIView.noIntrinsicMetric, height: 123)
    }

    private func setupLayout() {
        contentView.addSubview(backgroundBlurView)
        backgroundBlurView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(contentInsets)
        }

        backgroundBlurView.addSubview(view)
        view.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(innerInsets)
        }
    }

    private func updateLayout() {
        backgroundBlurView.snp.updateConstraints {
            $0.edges.equalToSuperview().inset(contentInsets)
        }
        view.snp.updateConstraints {
            $0.edges.equalToSuperview().inset(innerInsets)
        }
    }
}

final class YourContributionsTableViewCell: BlurredTableViewCell<YourContributionsView> {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        view.apply(style: .navigation)
    }
}

typealias AboutCrowdloansTableViewCell = BlurredTableViewCell<AboutCrowdloansView>

extension BlurredTableViewCell where TContentView == ErrorStateView {
    func applyStyle() {
        view.errorDescriptionLabel.textColor = R.color.colorTextSecondary()
        view.retryButton.titleLabel?.font = .semiBoldSubheadline
        view.stackView.setCustomSpacing(0, after: view.iconImageView)
        view.stackView.setCustomSpacing(8, after: view.errorDescriptionLabel)
        contentInsets = .init(top: 8, left: 16, bottom: 0, right: 16)
        innerInsets = .init(top: 4, left: 0, bottom: 16, right: 0)
    }
}

extension BlurredTableViewCell where TContentView == CrowdloanEmptyView {
    func applyStyle() {
        view.verticalSpacing = 0
        innerInsets = .init(top: 4, left: 0, bottom: 16, right: 0)
        contentInsets = .init(top: 8, left: 16, bottom: 0, right: 16)
    }
}
