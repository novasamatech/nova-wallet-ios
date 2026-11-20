import UIKit
import UIKit_iOS

final class SwapExecutionStepsView: UIView {
    let backgroundView: RoundedView = .create {
        $0.apply(style: .swapReviewCard)
    }

    let stackView: UIStackView = .create {
        $0.axis = .vertical
        $0.alignment = .fill
    }

    private(set) var rowViews: [SwapExecutionStepRowView] = []

    var viewTransactionButton: RoundedButton? {
        rowViews.first { !$0.linkContainer.isHidden }?.viewTransactionButton
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }

        addSubview(stackView)
        stackView.snp.makeConstraints { $0.edges.equalToSuperview().inset(Constants.contentInsets) }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: [SwapExecutionStepViewModel], locale: Locale) {
        rowViews.forEach { $0.removeFromSuperview() }

        rowViews = viewModel.enumerated().map { index, stepViewModel in
            let rowView = SwapExecutionStepRowView()
            rowView.bind(viewModel: stepViewModel, locale: locale)
            rowView.separatorView.isHidden = index == viewModel.count - 1
            stackView.addArrangedSubview(rowView)
            return rowView
        }
    }
}

extension SwapExecutionStepsView {
    enum Constants {
        static let contentInsets = UIEdgeInsets(top: 1, left: 13, bottom: 1, right: 13)
    }
}

final class SwapExecutionStepRowView: UIView {
    let markView = SwapExecutionStatusMarkView(
        size: Constants.markSize,
        iconSize: Constants.markIconSize
    )

    let numberView: BorderedLabelView = .create {
        $0.apply(style: .stepNumber)
        $0.backgroundView.cornerRadius = Constants.markSize / 2
        $0.titleLabel.textAlignment = .center
        $0.contentInsets = .zero
    }

    let titleLabel: UILabel = .create {
        $0.numberOfLines = 0
    }

    let detailsLabel: UILabel = .create {
        $0.apply(style: .footnoteSecondary)
        $0.numberOfLines = 0
    }

    let fundsLocationLabel: UILabel = .create {
        $0.apply(style: .footnoteSecondary)
        $0.numberOfLines = 0
    }

    let viewTransactionButton: RoundedButton = .create {
        $0.applyIconStyle()
        $0.imageWithTitleView?.layoutType = .horizontalLabelFirst
        $0.imageWithTitleView?.spacingBetweenLabelAndIcon = Constants.linkIconSpacing
        $0.imageWithTitleView?.titleFont = .semiBoldSubheadline
        $0.imageWithTitleView?.titleColor = R.color.colorButtonTextAccent()
        $0.imageWithTitleView?.iconImage = R.image.iconAboutArrow()?.tinted(with: R.color.colorButtonTextAccent()!)
        $0.contentInsets = .zero
    }

    private(set) lazy var linkContainer = UIView.hStack([viewTransactionButton, UIView.spacer()])

    let separatorView: UIView = .create {
        $0.backgroundColor = R.color.colorContainerBorder()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: SwapExecutionStepViewModel, locale: Locale) {
        titleLabel.text = viewModel.title

        switch viewModel.status {
        case .done:
            applyMark(isSuccess: true)
            titleLabel.apply(style: .regularSubhedlinePrimary)
            detailsLabel.isHidden = true
            fundsLocationLabel.isHidden = true
            linkContainer.isHidden = true
        case let .failed(details, fundsLocation, canViewTransaction):
            applyMark(isSuccess: false)
            titleLabel.apply(style: .regularSubhedlinePrimary)
            detailsLabel.text = details
            detailsLabel.isHidden = details == nil
            fundsLocationLabel.text = fundsLocation
            fundsLocationLabel.isHidden = fundsLocation == nil
            linkContainer.isHidden = !canViewTransaction
            viewTransactionButton.imageWithTitleView?.title = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.swapsExecutionViewTransaction()
        case let .notRun(number):
            markView.isHidden = true
            numberView.isHidden = false
            numberView.titleLabel.text = number
            titleLabel.apply(style: .regularSubhedlineSecondary)
            detailsLabel.isHidden = true
            fundsLocationLabel.isHidden = true
            linkContainer.isHidden = true
        }
    }
}

private extension SwapExecutionStepRowView {
    func applyMark(isSuccess: Bool) {
        markView.isHidden = false
        numberView.isHidden = true
        markView.bind(isSuccess: isSuccess)
    }

    func setupLayout() {
        let textStack = UIView.vStack(
            spacing: Constants.textSpacing,
            [titleLabel, detailsLabel, fundsLocationLabel, linkContainer]
        )

        viewTransactionButton.snp.makeConstraints { $0.height.equalTo(Constants.linkHeight) }

        addSubview(markView)
        addSubview(numberView)
        addSubview(textStack)
        addSubview(separatorView)

        markView.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.centerY.equalTo(textStack)
        }

        numberView.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.centerY.equalTo(textStack)
            $0.size.equalTo(Constants.markSize)
        }

        textStack.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(Constants.markSize + Constants.markSpacing)
            $0.trailing.equalToSuperview()
            $0.top.bottom.equalToSuperview().inset(Constants.verticalInset)
        }

        snp.makeConstraints { $0.height.greaterThanOrEqualTo(Constants.minHeight) }

        separatorView.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(Constants.separatorHeight)
        }
    }
}

extension SwapExecutionStepRowView {
    enum Constants {
        static let markSize: CGFloat = 24
        static let markIconSize: CGFloat = 14
        static let markSpacing: CGFloat = 12
        static let textSpacing: CGFloat = 2
        static let linkIconSpacing: CGFloat = 4
        static let linkHeight: CGFloat = 20
        static let verticalInset: CGFloat = 8
        static let minHeight: CGFloat = 52
        static let separatorHeight: CGFloat = 1
    }
}
