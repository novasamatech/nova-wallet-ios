import UIKit
import SubstrateSdk

final class PolkadotIconDetailsView: UIView {
    let imageView: PolkadotIconView = .create {
        $0.backgroundColor = .clear
        $0.fillColor = .clear
    }

    let titleLabel: UILabel = .create {
        $0.textColor = R.color.colorWhite64()
        $0.font = .regularFootnote
        $0.numberOfLines = 0
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let subtitleView = UIStackView(arrangedSubviews: [
            imageView,
            titleLabel
        ])
        subtitleView.spacing = Constants.horizontalSubtileViewSpace
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        addSubview(subtitleView)

        subtitleView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        imageView.snp.makeConstraints {
            $0.width.equalTo(Constants.subtitleImageViewSize)
            $0.height.equalTo(Constants.subtitleImageViewSize)
        }
    }
}

// MARK: - Constants

extension PolkadotIconDetailsView {
    enum Constants {
        static let subtitleImageViewSize = CGSize(width: 18, height: 18)
        static let horizontalSubtileViewSpace: CGFloat = 4
    }
}
