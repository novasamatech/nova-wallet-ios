import UIKit
import UIKit_iOS
import SnapKit

protocol AssetDetailsViewLayoutDelegate: AnyObject {
    func didUpdateHeight(_ height: CGFloat)
}

final class AssetDetailsViewLayout: ScrollableContainerLayoutView {
    weak var delegate: AssetDetailsViewLayoutDelegate?

    private let layoutChangesAnimator: BlockViewAnimatorProtocol = BlockViewAnimator(
        duration: 0.2,
        options: [.curveEaseInOut]
    )
    private let alertLayoutChangesAnimator: BlockViewAnimatorProtocol = BlockViewAnimator(
        duration: 0.3,
        delay: 0.2,
        options: [.curveEaseInOut]
    )
    private let alertAppearanceAnimator: ViewAnimatorProtocol = FadeAnimator(
        from: 0.0,
        to: 1.0,
        duration: 0.3,
        options: [.curveEaseInOut]
    )
    private let alertDisappearanceAnimator: ViewAnimatorProtocol = FadeAnimator(
        from: 1.0,
        to: 0.0,
        duration: 0.15,
        options: [.curveLinear]
    )

    lazy var ahmAlertView: AHMAlertView = .create { view in
        view.isHidden = true
    }

    let chartContainerView: UIView = .create { view in
        view.backgroundColor = R.color.colorBlockBackground()
        view.layer.cornerRadius = 12.0
    }

    let backgroundView = MultigradientView.background

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

    lazy var balanceWidget: AssetDetailsBalanceWidget = .create { view in
        view.delegate = self
    }

    let sendButton: RoundedButton = createOperationButton(icon: R.image.iconSend())
    let receiveButton: RoundedButton = createOperationButton(icon: R.image.iconReceive())
    let buySellButton: RoundedButton = createOperationButton(icon: R.image.iconBuy(), enabled: true)
    let swapButton = createOperationButton(icon: R.image.iconActionChange())

    private var currentBalanceHeight: CGFloat = AssetDetailsBalanceWidget.Constants.collapsedStateHeight
    private var currentAHMAlertHeight: CGFloat = .zero

    private lazy var buttonsRow = PayButtonsRow(
        frame: .zero,
        views: [sendButton, receiveButton, swapButton, buySellButton]
    )

    private var chartViewHeight: CGFloat = .zero

    private static func createOperationButton(
        icon: UIImage?,
        enabled: Bool = false
    ) -> RoundedButton {
        let button = RoundedButton()
        button.apply(style: .operation)
        button.imageWithTitleView?.spacingBetweenLabelAndIcon = 8
        button.contentOpacityWhenDisabled = 0.2
        button.changesContentOpacityWhenHighlighted = true
        button.imageWithTitleView?.layoutType = .verticalImageFirst
        button.isEnabled = enabled
        button.imageWithTitleView?.iconImage = icon
        return button
    }

    override func setupLayout() {
        super.setupLayout()

        insertSubview(backgroundView, belowSubview: containerView)

        backgroundView.snp.makeConstraints {
            $0.edges.equalToSuperview()
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
            $0.bottom.equalTo(self.safeAreaLayoutGuide.snp.top).offset(-7.0)
        }

        balanceWidget.snp.makeConstraints { make in
            make.height.equalTo(balanceWidget.state.height)
        }

        containerView.stackView.spacing = Constants.sectionSpace

        addArrangedSubview(balanceWidget)
        addArrangedSubview(buttonsRow)
        addArrangedSubview(chartContainerView)

        chartContainerView.snp.makeConstraints { make in
            make.height.equalTo(chartViewHeight)
        }
    }

    private func hideAlertWithAnimation() {
        alertDisappearanceAnimator.animate(
            view: ahmAlertView,
            completionBlock: nil
        )
        layoutChangesAnimator.animate(
            block: { [weak self] in
                self?.ahmAlertView.isHidden = true
                self?.containerView.stackView.layoutIfNeeded()
            },
            completionBlock: { [weak self] _ in
                self?.ahmAlertView.removeFromSuperview()
            }
        )

        currentAHMAlertHeight = .zero
        delegate?.didUpdateHeight(prefferedHeight)
    }

    private func showAlertWithAnimation() {
        ahmAlertView.alpha = 0

        insertArrangedSubview(
            ahmAlertView,
            before: balanceWidget,
            spacingAfter: Constants.alertSpacingAfter
        )

        alertLayoutChangesAnimator.animate(
            block: { [weak self] in
                guard let self else { return }

                ahmAlertView.isHidden = false
                containerView.stackView.layoutIfNeeded()
            },
            completionBlock: { [weak self] _ in
                guard let self else { return }

                alertAppearanceAnimator.animate(
                    view: ahmAlertView,
                    completionBlock: nil
                )
            }
        )

        currentAHMAlertHeight = ahmAlertView.frame.height
        delegate?.didUpdateHeight(prefferedHeight)
    }

    func set(locale: Locale) {
        let languages = locale.rLanguages

        balanceWidget.set(locale: locale)

        sendButton.imageWithTitleView?.title = R.string(preferredLanguages: languages).localizable.walletSendTitle()
        sendButton.invalidateLayout()

        receiveButton.imageWithTitleView?.title = R.string(
            preferredLanguages: languages
        ).localizable.walletAssetReceive()
        receiveButton.invalidateLayout()

        swapButton.imageWithTitleView?.title = R.string(preferredLanguages: languages).localizable.commonSwapAction()
        swapButton.invalidateLayout()
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

    func setBottomInset(_ inset: CGFloat) {
        containerView.stackView.layoutMargins.bottom = inset + Constants.bottomOffset
    }

    func setAHMAlert(with model: AHMAlertView.Model?) {
        if let model {
            guard ahmAlertView.superview == nil else {
                ahmAlertView.bind(model)
                return
            }

            ahmAlertView.bind(model)

            showAlertWithAnimation()
        } else {
            guard ahmAlertView.superview != nil else {
                return
            }

            hideAlertWithAnimation()
        }
    }

    var prefferedHeight: CGFloat {
        let balanceSectionHeight = Constants.containerViewTopOffset
            + currentBalanceHeight
        let buttonsRowHeight = buttonsRow.preferredHeight ?? 0

        return Constants.containerViewTopOffset
            + containerView.stackView.layoutMargins.top
            + balanceSectionHeight
            + Constants.sectionSpace * 2
            + buttonsRowHeight
            + Constants.chartWidgetInset * 2
            + chartViewHeight
            + Constants.bottomOffset
            + currentAHMAlertHeight
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
        static let bottomOffset: CGFloat = 24
        static let assetImageViewSize: CGFloat = 28
        static let assetIconSize: CGFloat = 21
        static let priceBottomSpace: CGFloat = 8
        static let chartWidgetInset: CGFloat = 16
        static let alertSpacingAfter: CGFloat = 8
    }
}
