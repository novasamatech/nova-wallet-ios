import UIKit
import SoraUI

final class YourContributionsView: UIView {
    let titleLabel: UILabel = .create {
        $0.textColor = R.color.colorTransparentText()
        $0.font = .regularSubheadline
        $0.numberOfLines = Constants.TitleLabel.numberOfLines
    }

    let counterLabel: BorderedLabelView = .create {
        $0.titleLabel.textAlignment = .center
        $0.contentInsets = UIEdgeInsets(top: 2, left: 8, bottom: 3, right: 8)
    }

    let amountLabel: UILabel = .create {
        $0.textColor = R.color.colorWhite()
        $0.font = .boldLargeTitle
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

    private var skeletonView: SkrullableView?
    private lazy var skeletonableViews: [LoadableView] = [titleLabel, counterLabel, amountLabel, amountDetailsLabel]

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

        if skeletonView != nil {
            setupSkeleton()
        }
    }

    func bind(model: LoadableViewModelState<YourContributionsViewModel>) {
        switch model {
        case let .loaded(state), let .cached(state):
            titleLabel.text = state.title
            counterLabel.titleLabel.text = state.count
            amountLabel.text = state.amount
            amountDetailsLabel.text = state.amountDetails
            stopLoadingIfNeeded()
        case .loading:
            skeletonableViews.forEach {
                $0.clear()
            }
            startLoadingIfNeeded()
        }
    }

    private func setupLayout() {
        let titleView = UIView()
        titleView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.bottom.leading.equalToSuperview()
        }
        titleView.addSubview(counterLabel)
        counterLabel.snp.makeConstraints {
            $0.leading.equalTo(titleLabel.snp.trailing).offset(8)
            $0.top.trailing.bottom.equalToSuperview()
        }
        let contentStackView = UIStackView(arrangedSubviews: [
            titleView,
            amountLabel,
            amountDetailsLabel
        ])
        contentStackView.spacing = 4
        contentStackView.axis = .vertical
        contentStackView.distribution = .fillProportionally
        contentStackView.alignment = .center

        addSubview(contentStackView)
        contentStackView.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.bottom.equalToSuperview().inset(20)
        }
        addSubview(navigationImageView)
        navigationImageView.snp.makeConstraints {
            $0.leading.greaterThanOrEqualTo(contentStackView.snp.trailing).inset(4)
            $0.centerY.equalTo(titleView.snp.centerY)
            $0.trailing.equalToSuperview().inset(16)
            $0.width.equalTo(24)
            $0.height.equalTo(24)
        }
    }

    func startLoadingIfNeeded() {
        guard skeletonView == nil else {
            return
        }

        skeletonableViews.forEach {
            $0.alpha = 0
        }

        setupSkeleton()
    }

    func stopLoadingIfNeeded() {
        guard skeletonView != nil else {
            return
        }

        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil

        skeletonableViews.forEach {
            $0.alpha = 1
        }
    }

    private func setupSkeleton() {
        let spaceSize = frame.size

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
            let view = builder
                .fillSkeletonStart(R.color.colorSkeletonStart()!)
                .fillSkeletonEnd(color: R.color.colorSkeletonEnd()!)
                .build()
            view.autoresizingMask = []
            insertSubview(view, aboveSubview: self)

            skeletonView = view

            view.startSkrulling()

            currentSkeletonView = view
        }

        currentSkeletonView?.frame = CGRect(origin: .zero, size: spaceSize)
    }

    private func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let bigRowSize = CGSize(width: 96.0, height: 16.0)

        let offsetY = spaceSize.height - Constants.bottomInset - amountLabel.font.lineHeight / 2.0 -
            bigRowSize.height / 2.0

        let offset = CGPoint(
            x: spaceSize.width / 2.0 - bigRowSize.width / 2.0,
            y: offsetY
        )

        return [
            SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: offset,
                size: bigRowSize
            )
        ]
    }
}

extension YourContributionsView {
    private enum Constants {
        static let bottomInset: CGFloat = 16
        static let blurViewSideLength: CGFloat = 12

        enum TitleLabel {
            static let spacing: CGFloat = 4
            static let numberOfLines = 1
        }
    }
}

struct YourContributionsViewModel {
    let title: String
    let count: String
    let amount: String
    let amountDetails: String
}

protocol LoadableView: UIView {
    func clear()
}

extension UILabel: LoadableView {
    func clear() {
        text = ""
    }
}

extension BorderedLabelView: LoadableView {
    func clear() {
        titleLabel.text = ""
    }
}
