import UIKit
import SoraUI

final class YourContributionsView: UIView {
    private var skeletonView: SkrullableView?
    private lazy var hidingViews = [
        titleLabel, counterLabel, amountLabel, amountDetailsLabel, navigationImageView
    ]

    let titleLabel: UILabel = .create {
        $0.textColor = R.color.colorWhite64()
        $0.font = .p1Paragraph
        $0.numberOfLines = 1
    }

    let counterLabel: BorderedLabelView = .create {
        $0.titleLabel.textAlignment = .center
        $0.titleLabel.textColor = R.color.colorWhite80()
        $0.titleLabel.font = .semiBoldFootnote
        $0.contentInsets = Constants.counterLabelContentInsets
    }

    let amountLabel: UILabel = .create {
        $0.textColor = R.color.colorWhite()
        $0.font = .boldTitle1
        $0.textAlignment = .center
    }

    let amountDetailsLabel: UILabel = .create {
        $0.textColor = R.color.colorWhite64()
        $0.font = .regularBody
        $0.textAlignment = .center
    }

    let navigationImageView: UIImageView = .create {
        $0.image = R.image.iconSmallArrow()?.withRenderingMode(.alwaysTemplate)
        $0.contentMode = .center
        $0.tintColor = R.color.colorWhite48()
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
        switch model {
        case .loading:
            startLoadingIfNeeded()
        case let .cached(value), let .loaded(value):
            titleLabel.text = value.title
            counterLabel.titleLabel.text = value.count
            counterLabel.isHidden = value.count == nil
            amountLabel.text = value.amount
            amountDetailsLabel.text = value.amountDetails
            stopLoadingIfNeeded()
        }
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
            if !hidingViews.contains(navigationImageView) {
                hidingViews.append(navigationImageView)
            }
        case .readonly:
            navigationImageView.isHidden = true
            hidingViews = hidingViews.filter { $0 != navigationImageView }
        }
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

extension YourContributionsView {
    func startLoadingIfNeeded() {
        guard skeletonView == nil else {
            return
        }

        hidingViews.forEach { $0.alpha = 0 }
        setupSkeleton()
    }

    func stopLoadingIfNeeded() {
        guard skeletonView != nil else {
            return
        }

        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil

        hidingViews.forEach { $0.alpha = 1 }
    }

    private func setupSkeleton() {
        let spaceSize = bounds.size

        guard spaceSize.width > 0, spaceSize.height > 0 else {
            return
        }

        let builder = Skrull(
            size: spaceSize,
            decorations: [],
            skeletons: createSkeletons(for: spaceSize)
        )

        let currentSkeletonView: SkrullableView?

        if let skeletonView = skeletonView {
            currentSkeletonView = skeletonView
            builder.updateSkeletons(in: skeletonView)
        } else {
            let newSkeletonView = builder
                .fillSkeletonStart(R.color.colorSkeletonStart()!)
                .fillSkeletonEnd(color: R.color.colorSkeletonEnd()!)
                .build()
            newSkeletonView.autoresizingMask = []
            insertSubview(newSkeletonView, at: 0)
            skeletonView = newSkeletonView
            newSkeletonView.startSkrulling()
            currentSkeletonView = newSkeletonView
        }

        currentSkeletonView?.frame = CGRect(origin: .zero, size: spaceSize)
    }

    private func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let firstRowSize = CGSize(width: 88, height: 12)
        let secondRowSize = CGSize(width: 120, height: 22)
        let thirdRowSize = CGSize(width: 70, height: 12)

        let firstOffsetY = Constants.topInset + titleLabel.font.lineHeight / 2 - firstRowSize.height / 2
        let space = (spaceSize.height - firstRowSize.height - secondRowSize.height - thirdRowSize.height - Constants.topInset - Constants.bottomInset) / 2
        let secondOffsetY = firstOffsetY + firstRowSize.height / 2 + space + 1
        let thirdOffsetY = secondOffsetY + secondRowSize.height / 2 + space - 1

        let firstOffset = CGPoint(
            x: spaceSize.width / 2.0 - firstRowSize.width / 2.0,
            y: firstOffsetY
        )

        let secondOffset = CGPoint(
            x: spaceSize.width / 2.0 - secondRowSize.width / 2.0,
            y: secondOffsetY
        )

        let thirdOffset = CGPoint(
            x: spaceSize.width / 2.0 - thirdRowSize.width / 2.0,
            y: thirdOffsetY
        )

        return [
            SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: firstOffset,
                size: firstRowSize
            ),
            SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: secondOffset,
                size: secondRowSize
            ),
            SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: thirdOffset,
                size: thirdRowSize
            )
        ]
    }
}
