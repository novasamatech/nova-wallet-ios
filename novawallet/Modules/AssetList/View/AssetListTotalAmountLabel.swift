import UIKit

final class AssetListTotalAmountLabel: UILabel, SecurableViewProtocol {
    typealias ViewModel = AssetListTotalAmountViewModel
    typealias PrivateContentView = AssetListTotalAmountLabel

    var privateContentView: PrivateContentView { self }

    func update(with viewModel: AssetListTotalAmountViewModel) {
        attributedText = totalAmountString(from: viewModel)
    }

    private func totalAmountString(from model: AssetListTotalAmountViewModel) -> NSAttributedString {
        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorTextPrimary()!,
            .font: UIFont.boldLargeTitle
        ]

        let amount = model.amount

        if
            let lastChar = model.amount.last?.asciiValue,
            !NSCharacterSet.decimalDigits.contains(UnicodeScalar(lastChar)) {
            return .init(string: amount, attributes: defaultAttributes)
        } else {
            guard let decimalSeparator = model.decimalSeparator,
                  let range = amount.range(of: decimalSeparator) else {
                return .init(string: amount, attributes: defaultAttributes)
            }

            let amountAttributedString = NSMutableAttributedString(string: amount)
            let intPartRange = NSRange(amount.startIndex ..< range.lowerBound, in: amount)

            let fractionPartRange = NSRange(range.lowerBound ..< amount.endIndex, in: amount)

            amountAttributedString.setAttributes(
                defaultAttributes,
                range: intPartRange
            )

            amountAttributedString.setAttributes(
                [.foregroundColor: R.color.colorTextSecondary()!,
                 .font: UIFont.boldTitle3],
                range: fractionPartRange
            )

            return amountAttributedString
        }
    }
}
