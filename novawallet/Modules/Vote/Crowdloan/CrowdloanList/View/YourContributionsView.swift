import UIKit
import UIKit_iOS

final class YourContributionsView: UIView {
    var skeletonView: SkrullableView?
    var hidingViews: [UIView] {
        switch style {
        case .navigation:
            return [titleLabel, counterLabel, amountLabel, amountDetailsLabel, navigationImageView]
        case .readonly:
            return [titleLabel, counterLabel, amountLabel, amountDetailsLabel]
        }
    }

    let titleLabel: UILabel = .create {
        $0.textColor = R.color.colorTextSecondary()
        $0.font = .p1Paragraph
        $0.numberOfLines = 1
    }

    let counterLabel: BorderedLabelView = .create {
        $0.titleLabel.textAlignment = .center
        $0.titleLabel.textColor = R.color.colorChipText()
        $0.titleLabel.font = .semiBoldFootnote
        $0.contentInsets = Constants.counterLabelContentInsets
    }

    let amountLabel: UILabel = .create {
        $0.textColor = R.color.colorTextPrimary()
        $0.font = .boldTitle1
        $0.textAlignment = .center
    }

    let amountDetailsLabel: UILabel = .create {
        $0.textColor = R.color.colorTextSecondary()
        $0.font = .regularBody
        $0.textAlignment = .center
    }

    let navigationImageView: UIImageView = .create {
        $0.image = R.image.iconSmallArrow()?.withRenderingMode(.alwaysTemplate)
        $0.contentMode = .center
        $0.tintColor = R.color.colorIconSecondary()
    }

    private var style: Style = .navigation
    private var viewModel: LoadableViewModelState<Model>?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // as we have dynamic cell we could fail to create skeleton view on init
        if skeletonView == nil, viewModel?.isLoading == true {
            updateLoadingState()
        }
    }

    private func setupLayout() {
        let titleView = UIStackView(arrangedSubviews: [
            titleLabel,
            counterLabel
        ])
        titleView.spacing = Constants.counterTitleSpace
        titleView.setContentHuggingPriority(.required, for: .horizontal)
        titleView.setContentCompressionResistancePriority(.required, for: .horizontal)

        let contentStackView = UIStackView(arrangedSubviews: [
            titleView,
            amountLabel,
            amountDetailsLabel
        ])
        contentStackView.spacing = Constants.verticalSpace
        contentStackView.axis = .vertical
        contentStackView.distribution = .fillProportionally
        contentStackView.alignment = .center

        addSubview(contentStackView)
        contentStackView.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalToSuperview().inset(Constants.topInset)
            $0.bottom.equalToSuperview().inset(Constants.bottomInset)
        }

        addSubview(navigationImageView)
        navigationImageView.snp.makeConstraints {
            $0.leading.greaterThanOrEqualTo(contentStackView.snp.trailing)
            $0.centerY.equalTo(titleView.snp.centerY)
            $0.trailing.equalToSuperview().inset(Constants.navigationImageViewRightOffset)
            $0.width.equalTo(Constants.navigationImageViewSize.width)
            $0.height.equalTo(Constants.navigationImageViewSize.height)
        }
    }
}

// MARK: - Bind

extension YourContributionsView {
    struct Model {
        let title: String
        let count: String?
        let amount: String
        let amountDetails: String
    }

    func bind(model: LoadableViewModelState<Model>) {
        viewModel = model
        model.value.map(bind)
    }

    func bind(model: Model) {
        titleLabel.text = model.title
        counterLabel.titleLabel.text = model.count
        counterLabel.isHidden = model.count == nil
        amountLabel.text = model.amount
        amountDetailsLabel.text = model.amountDetails
    }
}

// MARK: - Style

extension YourContributionsView {
    enum Style {
        case navigation
        case readonly
    }

    func apply(style: Style) {
        switch style {
        case .navigation:
            navigationImageView.isHidden = false
        case .readonly:
            navigationImageView.isHidden = true
        }
        self.style = style
    }
}

// MARK: - Constants

extension YourContributionsView {
    private enum Constants {
        static let blurViewSideLength: CGFloat = 12
        static let counterLabelContentInsets = UIEdgeInsets(top: 2, left: 8, bottom: 3, right: 8)
        static let counterTitleSpace: CGFloat = 8
        static let verticalSpace: CGFloat = 4
        static let topInset: CGFloat = 21
        static let bottomInset: CGFloat = 20
        static let navigationImageViewSize = CGSize(width: 24, height: 24)
        static let navigationImageViewRightOffset: CGFloat = 16
    }
}

// MARK: - Skeletons

extension YourContributionsView: SkeletonableView {
    var skeletonSuperview: UIView {
        self
    }

    func updateLoadingState() {
        if viewModel?.isLoading == false {
            stopLoadingIfNeeded()
        } else {
            startLoadingIfNeeded()
        }
    }

    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let titleSkeletonSize = CGSize(width: 88, height: 12)
        let amountSkeletonSize = CGSize(width: 120, height: 22)
        let priceSkeletonSize = CGSize(width: 70, height: 12)

        let titleSkeletonOffsetY = Constants.topInset + titleLabel.font.lineHeight / 2 - titleSkeletonSize.height / 2
        let bottomInset = spaceSize.height - Constants.bottomInset
        let priceSkeletonOffsetY = bottomInset - amountDetailsLabel.font.lineHeight / 2 - priceSkeletonSize.height / 2
        let filledSpace = titleSkeletonSize.height + amountSkeletonSize.height
        let emptySpace = priceSkeletonOffsetY - titleSkeletonOffsetY - filledSpace
        let amountSkeletonOffsetY = titleSkeletonOffsetY + titleSkeletonSize.height + emptySpace / 2

        let titleSkeletonOffset = CGPoint(
            x: spaceSize.width / 2 - titleSkeletonSize.width / 2,
            y: titleSkeletonOffsetY
        )

        let amountSkeletonOffset = CGPoint(
            x: spaceSize.width / 2 - amountSkeletonSize.width / 2,
            y: amountSkeletonOffsetY
        )

        let priceSkeletonOffset = CGPoint(
            x: spaceSize.width / 2 - priceSkeletonSize.width / 2,
            y: priceSkeletonOffsetY
        )

        return [
            SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: titleSkeletonOffset,
                size: titleSkeletonSize
            ),
            SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: amountSkeletonOffset,
                size: amountSkeletonSize
            ),
            SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: priceSkeletonOffset,
                size: priceSkeletonSize
            )
        ]
    }
}
