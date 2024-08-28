import UIKit
import SoraUI
import SnapKit

typealias TinderGovBannerTableViewCell = PlainBaseTableViewCell<TindergovBannerView>

extension PlainBaseTableViewCell where C == TindergovBannerView {
    func setupStyle() {
        backgroundColor = .clear
    }
}

final class TindergovBannerView: UIView {
    let gradientBackgroundView: RoundedGradientBackgroundView = .create { view in
        view.cornerRadius = 12
        view.strokeWidth = 1
        view.strokeColor = R.color.colorContainerBorder()!
        view.bind(model: .tinderGovCell())
    }

    let contentView = TindergovBannerContentView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()

        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(gradientBackgroundView)
        gradientBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.bottom.equalToSuperview().inset(15)
        }
    }

    func bind(with viewModel: TinderGovBannerViewModel) {
        contentView.bind(with: viewModel)
    }
}

final class TindergovBannerContentView: GenericPairValueView<
    GenericPairValueView<
        UIImageView,
        GenericPairValueView<
            GenericPairValueView<
                UILabel,
                BorderedLabelView
            >,
            UILabel
        >
    >,
    UIImageView
> {
    var iconView: UIImageView {
        fView.fView
    }

    var titleValueView: GenericPairValueView<
        GenericPairValueView<
            UILabel,
            BorderedLabelView
        >,
        UILabel
    > {
        fView.sView
    }

    var titleLabel: UILabel {
        titleValueView.fView.fView
    }

    var counderLabel: BorderedLabelView {
        titleValueView.fView.sView
    }

    var valueLabel: UILabel {
        titleValueView.sView
    }

    var accessoryView: UIImageView {
        sView
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()

        backgroundColor = .clear
    }

    private func configure() {
        setHorizontalAndSpacing(12.0)
        fView.setHorizontalAndSpacing(12.0)
        titleValueView.setVerticalAndSpacing(9.0)
        titleValueView.stackView.alignment = .leading
        titleValueView.fView.setHorizontalAndSpacing(8.0)
        titleValueView.fView.stackView.distribution = .equalCentering

        titleLabel.apply(style: .regularSubhedlinePrimary)
        titleLabel.numberOfLines = 1

        valueLabel.apply(style: .caption1Secondary)
        valueLabel.numberOfLines = 0

        counderLabel.backgroundView.fillColor = R.color.colorChipsBackground()!
        counderLabel.contentInsets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        counderLabel.backgroundView.cornerRadius = 7

        iconView.snp.makeConstraints { make in
            make.width.height.equalTo(72)
        }
        accessoryView.snp.makeConstraints { make in
            make.width.height.equalTo(24)
        }

        accessoryView.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorIconSecondary()!)
        accessoryView.contentMode = .scaleAspectFit

        iconView.image = R.image.iconTinderGov()
        iconView.contentMode = .scaleAspectFit
    }

    func bind(with viewModel: TinderGovBannerViewModel) {
        titleLabel.text = viewModel.title
        valueLabel.text = viewModel.description
        counderLabel.titleLabel.text = viewModel.referendumCounterText
    }
}

final class RoundedGradientBackgroundView: RoundedView {
    let leftGradientView = MultigradientView()
    let rightGradientView = MultigradientView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()

        backgroundColor = .clear
    }

    override var cornerRadius: CGFloat {
        didSet {
            super.cornerRadius = cornerRadius

            leftGradientView.cornerRadius = cornerRadius
            rightGradientView.cornerRadius = cornerRadius
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(model: GradientBannerModel) {
        leftGradientView.colors = model.left.colors
        leftGradientView.locations = model.left.locations
        leftGradientView.startPoint = model.left.startPoint
        leftGradientView.endPoint = model.left.endPoint

        rightGradientView.colors = model.right.colors
        rightGradientView.locations = model.right.locations
        rightGradientView.startPoint = model.right.startPoint
        rightGradientView.endPoint = model.right.endPoint
    }

    private func setupLayout() {
        addSubview(leftGradientView)
        leftGradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(rightGradientView)
        rightGradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
