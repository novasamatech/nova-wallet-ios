import UIKit

class BlurredTableViewCell<TContentView>: UITableViewCell where TContentView: UIView {
    let view: TContentView = .init()
    let backgroundBlurView = BlockBackgroundView()

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

        backgroundBlurView.overlayView?.fillColor = shouldApplyHighlighting && highlighted ?
            R.color.colorCellBackgroundPressed()!
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
