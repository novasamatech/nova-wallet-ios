import Foundation
import UIKit

final class TransferNetworkContainerView: UIView {
    private let tokenLabel: UILabel = TransferNetworkContainerView.createLabel()
    private let fromLabel: UILabel = TransferNetworkContainerView.createLabel()
    private var toLabel: UILabel?

    var horizontalSpacing: CGFloat = 6.0
    var verticalSpacing: CGFloat = 7.0

    let staticNetworkView = AssetListChainView()
    private(set) var selectableNetworkView: AssetListChainControlView?

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                setupLocalization()
            }
        }
    }

    private var calculatedIntrinsicSize: CGSize = .zero

    private var viewModel: TransferNetworkContainerViewModel?

    private var isCrossChain: Bool { viewModel?.isCrosschain ?? false }

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(tokenLabel)
        addSubview(fromLabel)
        addSubview(staticNetworkView)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func createLabel() -> UILabel {
        let label = UILabel()
        label.textColor = R.color.colorTextPrimary()
        label.font = .boldTitle3
        return label
    }

    private func setupLocalization() {
        guard let viewModel = viewModel else {
            return
        }

        let languages = locale.rLanguages

        tokenLabel.text = R.string(
            preferredLanguages: languages
        ).localizable.walletTransferTokenFormat_v2_9_1(viewModel.assetSymbol)

        if isCrossChain {
            fromLabel.text = R.string(preferredLanguages: languages).localizable.walletTransferCrossChainFrom()
        } else {
            fromLabel.text = R.string(preferredLanguages: languages).localizable.walletTransferOn()
        }

        toLabel?.text = R.string(preferredLanguages: languages).localizable.walletTransferCrossChainTo()

        setNeedsLayout()
    }

    func bind(viewModel: TransferNetworkContainerViewModel) {
        self.viewModel = viewModel

        switch viewModel.mode {
        case let .onchain(networkViewModel):
            setupOnChain()

            staticNetworkView.bind(viewModel: networkViewModel)
        case let .selectableOrigin(origin, destination):
            setupCrossChain()

            staticNetworkView.bind(viewModel: destination)
            selectableNetworkView?.bind(viewModel: origin)
        case let .selectableDestination(origin, destination):
            setupCrossChain()

            staticNetworkView.bind(viewModel: origin)
            selectableNetworkView?.bind(viewModel: destination)
        }

        setupLocalization()
    }

    private func setupOnChain() {
        selectableNetworkView?.removeFromSuperview()
        selectableNetworkView = nil

        toLabel?.removeFromSuperview()
        toLabel = nil
    }

    private func setupCrossChain() {
        guard selectableNetworkView == nil else {
            return
        }

        let label = Self.createLabel()
        addSubview(label)
        toLabel = label

        let networkView = AssetListChainControlView()
        addSubview(networkView)
        selectableNetworkView = networkView
    }

    override var intrinsicContentSize: CGSize {
        calculatedIntrinsicSize
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let originView: UIView?
        let destinationView: UIView?

        if case .selectableOrigin = viewModel?.mode, let selectableNetworkView = selectableNetworkView {
            originView = selectableNetworkView
            destinationView = staticNetworkView
        } else {
            originView = staticNetworkView
            destinationView = selectableNetworkView
        }

        let tokenLabelSize = tokenLabel.intrinsicContentSize
        let fromLabelSize = fromLabel.intrinsicContentSize
        let originViewSize = originView?.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize) ?? .zero

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

            originView?.frame = CGRect(
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

            originView?.frame = CGRect(
                x: fromLabel.frame.maxX + horizontalSpacing,
                y: fromLabel.frame.midY - originViewSize.height / 2.0,
                width: originViewSize.width,
                height: originViewSize.height
            )

            intrinsicHeight += tokenLabelSize.height + verticalSpacing +
                max(fromLabelSize.height, originViewSize.height)
        }

        if let destinationView = destinationView, let toLabel = toLabel {
            let toLabelSize = toLabel.intrinsicContentSize
            let destViewSize = destinationView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)

            toLabel.frame = CGRect(
                x: bounds.minX,
                y: fromLabel.frame.maxY + verticalSpacing,
                width: toLabelSize.width,
                height: toLabelSize.height
            )

            destinationView.frame = CGRect(
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
