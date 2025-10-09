import UIKit

final class AssetListAssetBalanceLabel: UILabel {
    private func createAttributedText(from value: String) -> NSAttributedString {
        NSAttributedString.styledAmountString(
            from: value,
            intPartFont: .semiBoldBody,
            fractionFont: .semiBoldSubheadline,
            decimalSeparator: String(String.Separator.dot.rawValue)
        )
    }
}

extension AssetListAssetBalanceLabel {
    func bind(_ viewModel: String) {
        attributedText = createAttributedText(from: viewModel)
    }
}
