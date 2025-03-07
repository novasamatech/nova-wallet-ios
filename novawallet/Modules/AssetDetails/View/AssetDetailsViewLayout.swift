import UIKit
import SoraUI
import SnapKit

protocol AssetDetailsViewLayoutDelegate: AnyObject {
    func didUpdateHeight(_ height: CGFloat)
}

final class AssetDetailsViewLayout: UIView {
    weak var delegate: AssetDetailsViewLayoutDelegate?

    private let layoutChangesAnimator: BlockViewAnimatorProtocol = BlockViewAnimator(
        duration: 0.2,
        options: [.curveEaseInOut]
    )

    let chartContainerView: UIView = .create { view in
        view.backgroundColor = R.color.colorBlockBackground()
        view.layer.cornerRadius = 12.0
    }

    let backgroundView = MultigradientView.background
    let chainView = AssetListChainView()
    let topBackgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))

    let assetIconView: AssetIconView = .create {
        $0.backgroundView.cornerRadius = 14
        $0.backgroundView.apply(style: .assetContainer)
    }

    let assetLabel = UILabel(
        style: .init(
            textColor: R.color.colorTextPrimary(),
            font: .semiBoldBody
        ),
        textAlignment: .center
    )

    let priceLabel = UILabel(style: .footnoteSecondary, textAlignment: .right)
    let priceChangeLabel = UILabel(style: .init(textColor: .clear, font: .regularFootnote))

    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 6, left: 16, bottom: 24, right: 16)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    lazy var balanceWidget: AssetDetailsBalanceWidget = .create { view in
        view.delegate = self
    }

    let sendButton: RoundedButton = createOperationButton(icon: R.image.iconSend())
    let receiveButton: RoundedButton = createOperationButton(icon: R.image.iconReceive())
    let buyButton: RoundedButton = createOperationButton(icon: R.image.iconBuy())
    let swapButton = createOperationButton(icon: R.image.iconActionChange())

    private var currentBalanceHeight = AssetDetailsBalanceWidget.Constants.collapsedStateHeight

    private lazy var buttonsRow = PayButtonsRow(
        frame: .zero,
        views: [sendButton, receiveButton, swapButton, buyButton]
    )

    private var chartViewHeight: CGFloat = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func createOperationButton(icon: UIImage?) -> RoundedButton {
        let button = RoundedButton()
        button.apply(style: .operation)
        button.imageWithTitleView?.spacingBetweenLabelAndIcon = 8
        button.contentOpacityWhenDisabled = 0.2
        button.changesContentOpacityWhenHighlighted = true
        button.imageWithTitleView?.layoutType = .verticalImageFirst
        button.isEnabled = false
        button.imageWithTitleView?.iconImage = icon
        return button
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        addSubview(topBackgroundView)

        let priceStack = UIStackView(arrangedSubviews: [priceLabel, priceChangeLabel])
        priceStack.spacing = 4

        addSubview(priceStack)
        priceStack.snp.makeConstraints {
            $0.leading.greaterThanOrEqualToSuperview()
            $0.trailing.lessThanOrEqualToSuperview()
            $0.centerX.equalToSuperview()
            $0.height.equalTo(Constants.priceStackHeight)
            $0.top.equalTo(self.safeAreaLayoutGuide.snp.top)
        }

        topBackgroundView.snp.makeConstraints {
            $0.leading.trailing.top.equalToSuperview()
            $0.bottom.equalTo(priceStack.snp.bottom).offset(Constants.priceBottomSpace)
        }

        let assetView = UIStackView(arrangedSubviews: [assetIconView, assetLabel])
        assetView.spacing = 8
        addSubview(assetView)

        assetIconView.setContentHuggingPriority(.low, for: .horizontal)
        assetLabel.setContentHuggingPriority(.low, for: .horizontal)

        assetIconView.snp.makeConstraints {
            $0.width.height.equalTo(Constants.assetImageViewSize)
        }

        assetView.snp.makeConstraints {
            $0.leading.greaterThanOrEqualToSuperview()
            $0.centerX.equalToSuperview()
            $0.height.equalTo(Constants.assetHeight)
            $0.bottom.equalTo(priceStack.snp.top).offset(-7)
        }

        addSubview(chainView)
        chainView.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-16)
            $0.leading.greaterThanOrEqualTo(assetView.snp.trailing).offset(8)
            $0.centerY.equalTo(assetView.snp.centerY)
        }
        addSubview(containerView)
        containerView.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.top.equalTo(priceStack.snp.bottom).offset(Constants.containerViewTopOffset)
        }

        balanceWidget.snp.makeConstraints { make in
            make.height.equalTo(balanceWidget.state.height)
        }

        containerView.stackView.spacing = Constants.sectionSpace
        containerView.stackView.addArrangedSubview(balanceWidget)
        containerView.stackView.addArrangedSubview(buttonsRow)
        containerView.stackView.addArrangedSubview(chartContainerView)

        chartContainerView.snp.makeConstraints { make in
            make.height.equalTo(chartViewHeight)
        }
    }

    func set(locale: Locale) {
        let languages = locale.rLanguages

        balanceWidget.set(locale: locale)

        sendButton.imageWithTitleView?.title = R.string.localizable.walletSendTitle(
            preferredLanguages: languages
        )
        sendButton.invalidateLayout()

        receiveButton.imageWithTitleView?.title = R.string.localizable.walletAssetReceive(
            preferredLanguages: languages
        )
        receiveButton.invalidateLayout()

        swapButton.imageWithTitleView?.title = R.string.localizable.commonSwapAction(
            preferredLanguages: languages
        )
        swapButton.invalidateLayout()

        buyButton.imageWithTitleView?.title = R.string.localizable.walletAssetBuy(
            preferredLanguages: languages
        )
        buyButton.invalidateLayout()
    }

    func set(assetDetailsModel: AssetDetailsModel) {
        assetDetailsModel.assetIcon?.cancel(on: assetIconView.imageView)
        assetIconView.imageView.image = nil

        let iconSize = Constants.assetIconSize
        assetDetailsModel.assetIcon?.loadImage(
            on: assetIconView.imageView,
            targetSize: CGSize(width: iconSize, height: iconSize),
            animated: true
        )
        assetLabel.text = assetDetailsModel.tokenName
        chainView.bind(viewModel: assetDetailsModel.network)

        guard let priceModel = assetDetailsModel.price else {
            priceChangeLabel.text = ""
            priceLabel.text = ""
            return
        }

        priceLabel.text = priceModel.amount

        switch priceModel.change {
        case let .increase(value):
            priceChangeLabel.text = value
            priceChangeLabel.textColor = R.color.colorTextPositive()
        case let .decrease(value):
            priceChangeLabel.text = value
            priceChangeLabel.textColor = R.color.colorTextNegative()
        }
    }

    func setChartViewHeight(_ height: CGFloat) {
        guard
            chartContainerView.superview != nil,
            height != chartViewHeight
        else { return }

        chartViewHeight = height

        chartContainerView.snp.updateConstraints { make in
            make.height.equalTo(height)
        }

        chartContainerView.isHidden = !(height > 0)

        layoutIfNeeded()
    }

    var prefferedHeight: CGFloat {
        let balanceSectionHeight = Constants.containerViewTopOffset
            + currentBalanceHeight
        let buttonsRowHeight = buttonsRow.preferredHeight ?? 0

        return priceLabel.font.lineHeight
            + balanceSectionHeight
            + Constants.sectionSpace
            + buttonsRowHeight
            + Constants.bottomOffset
            + chartViewHeight
    }
}

extension AssetDetailsViewLayout: AssetDetailsBalanceWidgetDelegate {
    func didChangeState(to state: AssetDetailsBalanceWidget.State) {
        currentBalanceHeight = state.height

        balanceWidget.snp.updateConstraints { make in
            make.height.equalTo(state.height)
        }

        layoutChangesAnimator.animate(
            block: { [weak self] in self?.containerView.layoutIfNeeded() },
            completionBlock: nil
        )

        delegate?.didUpdateHeight(prefferedHeight)
    }
}

extension AssetDetailsViewLayout {
    enum Constants {
        static let priceStackHeight: CGFloat = 26
        static let assetHeight: CGFloat = 28
        static let containerViewTopOffset: CGFloat = 12
        static let sectionSpace: CGFloat = 8
        static let bottomOffset: CGFloat = 46
        static let assetImageViewSize: CGFloat = 28
        static let assetIconSize: CGFloat = 21
        static let priceBottomSpace: CGFloat = 8
        static let chartWidgetInset: CGFloat = 16
    }
}
