import UIKit

class BlurredTableViewCell<TContentView>: UITableViewCell where TContentView: UIView {
    let view: TContentView = .init()
    let backgroundBlurView = TriangularedBlurView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        selectedBackgroundView = UIView()
        setupLayout()
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
        backgroundBlurView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
        }

        backgroundBlurView.addSubview(view)
        view.snp.makeConstraints { make in
            make.leading.top.trailing.bottom.equalToSuperview()
        }
    }
}

final class YourContributionsTableViewCell: BlurredTableViewCell<YourContributionsView> {
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)

        backgroundBlurView.overlayView.fillColor = highlighted ?
            R.color.colorAccentSelected()!
            : .clear
    }
}

typealias AboutCrowdloansTableViewCell = BlurredTableViewCell<AboutCrowdloansView>
