import Foundation
import UIKit

final class GiftSetupNetworkContainerView: UIView {
    private let titleLabel: UILabel = .create { view in
        view.textColor = R.color.colorTextPrimary()
        view.font = .boldTitle3
    }
    
    private let onLabel: UILabel = .create { view in
        view.textColor = R.color.colorTextPrimary()
        view.font = .boldTitle3
    }
    
    private let networkView = AssetListChainView()
    
    private var calculatedIntrinsicSize: CGSize = .zero
    private var viewModel: GiftSetupNetworkContainerViewModel?

    var horizontalSpacing: CGFloat = 6.0
    var verticalSpacing: CGFloat = 7.0

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(titleLabel)
        addSubview(onLabel)
        addSubview(networkView)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: GiftSetupNetworkContainerViewModel) {
        self.viewModel = viewModel

        networkView.bind(viewModel: viewModel.chainAssetModel.networkViewModel)
        
        titleLabel.text = viewModel.titleText
        onLabel.text = viewModel.onText
    }

    override var intrinsicContentSize: CGSize {
        calculatedIntrinsicSize
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let titleLabelSize = titleLabel.intrinsicContentSize
        let onLabelSize = onLabel.intrinsicContentSize
        let networkViewSize = networkView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)

        let totalOneLineWidth = titleLabelSize.width
            + horizontalSpacing
            + onLabelSize.width
            + horizontalSpacing
            + networkViewSize.width

        titleLabel.frame = CGRect(
            origin: CGPoint(x: bounds.minX, y: bounds.minY),
            size: titleLabelSize
        )

        var intrinsicHeight: CGFloat = 0

        if totalOneLineWidth <= bounds.width {
            onLabel.frame = CGRect(
                x: titleLabel.frame.maxX + horizontalSpacing,
                y: titleLabel.frame.maxY - onLabelSize.height,
                width: onLabelSize.width,
                height: onLabelSize.height
            )
            networkView.frame = CGRect(
                x: onLabel.frame.maxX + horizontalSpacing,
                y: titleLabel.frame.midY - networkViewSize.height / 2.0,
                width: networkViewSize.width,
                height: networkViewSize.height
            )

            intrinsicHeight += max(titleLabelSize.height, networkViewSize.height)
        } else {
            onLabel.frame = CGRect(
                x: titleLabel.frame.minX,
                y: titleLabel.frame.maxY + verticalSpacing,
                width: onLabelSize.width,
                height: onLabelSize.height
            )
            networkView.frame = CGRect(
                x: onLabel.frame.maxX + horizontalSpacing,
                y: onLabel.frame.midY - networkViewSize.height / 2.0,
                width: networkViewSize.width,
                height: networkViewSize.height
            )

            intrinsicHeight += titleLabelSize.height
                + verticalSpacing
                + max(onLabelSize.height, networkViewSize.height)
        }

        guard
            abs(calculatedIntrinsicSize.width - bounds.width) > CGFloat.leastNormalMagnitude
            || abs(calculatedIntrinsicSize.height - intrinsicHeight) > CGFloat.leastNormalMagnitude
        else { return }
        
        calculatedIntrinsicSize = CGSize(width: bounds.width, height: intrinsicHeight)
        invalidateIntrinsicContentSize()
    }
}
