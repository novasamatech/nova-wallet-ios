import Foundation
import UIKit

final class TransferNetworkContainerView: UIView {
    private let tokenLabel: UILabel = TransferNetworkContainerView.createLabel()
    private let fromLabel: UILabel = TransferNetworkContainerView.createLabel()
    private var toLabel: UILabel?

    var horizontalSpacing: CGFloat = 6.0
    var verticalSpacing: CGFloat = 7.0

    let originNetworkView = WalletChainView()
    private(set) var destinationNetworkView: WalletChainControlView?

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                setupLocalization()
            }
        }
    }

    private var calculatedIntrinsicSize: CGSize = .zero

    private var viewModel: TransferNetworkContainerViewModel?

    private var isCrossChain: Bool { viewModel?.destNetwork != nil }

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(tokenLabel)
        addSubview(fromLabel)
        addSubview(originNetworkView)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func createLabel() -> UILabel {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .boldTitle2
        return label
    }

    private func setupLocalization() {
        guard let viewModel = viewModel else {
            return
        }

        let languages = locale.rLanguages

        tokenLabel.text = R.string.localizable.walletTransferTokenFormat_v2_9_1(
            viewModel.assetSymbol,
            preferredLanguages: languages
        )

        if isCrossChain {
            fromLabel.text = R.string.localizable.walletTransferCrossChainFrom(preferredLanguages: languages)
        } else {
            fromLabel.text = R.string.localizable.walletTransferOn(preferredLanguages: languages)
        }

        toLabel?.text = R.string.localizable.walletTransferCrossChainTo(preferredLanguages: languages)

        setNeedsLayout()
    }

    func bind(viewModel: TransferNetworkContainerViewModel) {
        self.viewModel = viewModel

        originNetworkView.bind(viewModel: viewModel.originNetwork)

        if let destViewModel = viewModel.destNetwork {
            setupCrossChain()

            destinationNetworkView?.bind(viewModel: destViewModel)
        } else {
            setupOnChain()
        }

        setupLocalization()
    }

    private func setupOnChain() {
        destinationNetworkView?.removeFromSuperview()
        destinationNetworkView = nil

        toLabel?.removeFromSuperview()
        toLabel = nil
    }

    private func setupCrossChain() {
        guard destinationNetworkView == nil else {
            return
        }

        let label = Self.createLabel()
        addSubview(label)
        toLabel = label

        let destNetworkView = WalletChainControlView()
        addSubview(destNetworkView)
        destinationNetworkView = destNetworkView
    }

    override var intrinsicContentSize: CGSize {
        calculatedIntrinsicSize
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let tokenLabelSize = tokenLabel.intrinsicContentSize
        let fromLabelSize = fromLabel.intrinsicContentSize
        let originViewSize = originNetworkView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)

        let totalOneLineWidth = tokenLabelSize.width + horizontalSpacing + fromLabelSize.width + horizontalSpacing +
            originViewSize.width

        tokenLabel.frame = CGRect(origin: CGPoint(x: bounds.minX, y: bounds.minY), size: tokenLabelSize)

        var intrinsicHeight: CGFloat = 0

        if totalOneLineWidth <= bounds.width {
            fromLabel.frame = CGRect(
                x: tokenLabel.frame.maxX + horizontalSpacing,
                y: tokenLabel.frame.maxY - fromLabelSize.height,
                width: fromLabelSize.width,
                height: fromLabelSize.height
            )

            originNetworkView.frame = CGRect(
                x: fromLabel.frame.maxX + horizontalSpacing,
                y: tokenLabel.frame.midY - originViewSize.height / 2.0,
                width: originViewSize.width,
                height: originViewSize.height
            )

            intrinsicHeight += max(tokenLabelSize.height, originViewSize.height)
        } else {
            fromLabel.frame = CGRect(
                x: tokenLabel.frame.minX,
                y: tokenLabel.frame.maxY + verticalSpacing,
                width: fromLabelSize.width,
                height: fromLabelSize.height
            )

            originNetworkView.frame = CGRect(
                x: fromLabel.frame.maxX + horizontalSpacing,
                y: fromLabel.frame.midY - originViewSize.height / 2.0,
                width: originViewSize.width,
                height: originViewSize.height
            )

            intrinsicHeight += tokenLabelSize.height + verticalSpacing +
                max(fromLabelSize.height, originViewSize.height)
        }

        if let destinationNetworkView = destinationNetworkView, let toLabel = toLabel {
            let toLabelSize = toLabel.intrinsicContentSize
            let destViewSize = destinationNetworkView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)

            toLabel.frame = CGRect(
                x: bounds.minX,
                y: fromLabel.frame.maxY + verticalSpacing,
                width: toLabelSize.width,
                height: toLabelSize.height
            )

            destinationNetworkView.frame = CGRect(
                x: toLabel.frame.maxX + horizontalSpacing,
                y: toLabel.frame.midY - originViewSize.height / 2.0,
                width: destViewSize.width,
                height: destViewSize.height
            )

            intrinsicHeight += verticalSpacing + max(toLabelSize.height, destViewSize.height)
        }

        if abs(calculatedIntrinsicSize.width - bounds.width) > CGFloat.leastNormalMagnitude ||
            abs(calculatedIntrinsicSize.height - intrinsicHeight) > CGFloat.leastNormalMagnitude {
            calculatedIntrinsicSize = CGSize(width: bounds.width, height: intrinsicHeight)

            invalidateIntrinsicContentSize()
        }
    }
}
