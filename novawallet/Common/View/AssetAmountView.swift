import UIKit

class AssetAmountView: GenericPairValueView<AssetIconView, UILabel> {
    var assetIconView: AssetIconView { fView }
    var amountLabel: UILabel { sView }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    private func configure() {
        setHorizontalAndSpacing(1)
    }
}
