import UIKit

class BlurredTableViewCell<TContentView>: UITableViewCell where TContentView: UIView {
    let view: TContentView = .init()

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
        let textBlur = TriangularedBlurView()
        contentView.addSubview(textBlur)
        textBlur.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
        }

        textBlur.addSubview(view)
        view.snp.makeConstraints { make in
            make.leading.top.trailing.bottom.equalToSuperview()
        }
    }
}

typealias YourContributionsTableViewCell = BlurredTableViewCell<YourContributionsView>
typealias AboutCrowdloansTableViewCell = BlurredTableViewCell<AboutCrowdloansView>
