import UIKit

final class SubtensorSubnetValidatorRowView: UIControl {
    let titleLabel: UILabel = .create { label in
        label.apply(style: .footnoteSecondary)
    }

    let iconView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
    }

    let nameLabel: UILabel = .create { label in
        label.apply(style: .footnotePrimary)
        label.textAlignment = .right
        label.lineBreakMode = .byTruncatingMiddle
    }

    let apyLabel: UILabel = .create { label in
        label.apply(style: .caption1Positive)
        label.textAlignment = .right
    }

    let chevronView: UIImageView = .create { view in
        view.image = R.image.iconChevronRight()?.tinted(with: R.color.colorIconSecondary()!)
        view.contentMode = .scaleAspectFit
    }

    let skeletonView: SubtensorChartLoadingView = .create { view in
        view.layer.cornerRadius = 6
    }

    private var imageViewModel: ImageViewModelProtocol?

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

    func bind(viewModel: SubtensorSubnetValidatorRowViewModel) {
        imageViewModel?.cancel(on: iconView)
        imageViewModel = nil
        iconView.image = nil

        switch viewModel {
        case .loading:
            skeletonView.setLoading(true)
            setValue(hidden: true)
        case let .unselected(title):
            skeletonView.setLoading(false)
            setValue(hidden: false)
            iconView.isHidden = true
            nameLabel.text = title
            apyLabel.isHidden = true
        case let .selected(name, icon, apy):
            skeletonView.setLoading(false)
            setValue(hidden: false)
            iconView.isHidden = icon == nil
            nameLabel.text = name
            apyLabel.text = apy
            apyLabel.isHidden = apy == nil

            imageViewModel = icon
            icon?.loadImage(on: iconView, targetSize: Constants.iconSize, animated: true)
        }
    }
}

private extension SubtensorSubnetValidatorRowView {
    enum Constants {
        static let iconSize = CGSize(width: 20, height: 20)
    }

    func setValue(hidden: Bool) {
        [iconView, nameLabel, apyLabel].forEach { $0.alpha = hidden ? 0 : 1 }
    }

    func setupLayout() {
        let valueStack = UIView.vStack(alignment: .trailing, spacing: 2, [nameLabel, apyLabel])
        let accountStack = UIView.hStack(alignment: .center, spacing: 8, [iconView, valueStack])
        let rowStack = UIView.hStack(alignment: .center, spacing: 8, [titleLabel, UIView(), accountStack, chevronView])
        rowStack.isUserInteractionEnabled = false

        addSubview(rowStack)
        rowStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.bottom.equalToSuperview().inset(10)
            make.height.greaterThanOrEqualTo(24)
        }

        iconView.snp.makeConstraints { make in
            make.size.equalTo(Constants.iconSize)
        }

        chevronView.snp.makeConstraints { make in
            make.size.equalTo(16)
        }

        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        addSubview(skeletonView)
        skeletonView.snp.makeConstraints { make in
            make.trailing.equalTo(chevronView.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 100, height: 12))
        }
    }
}
