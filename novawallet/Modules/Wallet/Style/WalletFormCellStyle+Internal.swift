import Foundation
import CommonWallet

extension WalletFormCellStyle {
    static var fearless: WalletFormCellStyle {
        let title = WalletTextStyle(
            font: UIFont.p1Paragraph,
            color: R.color.colorTextSecondary()!
        )
        let details = WalletTextStyle(
            font: UIFont.p1Paragraph,
            color: R.color.colorTextPrimary()!
        )

        let link = WalletLinkStyle(
            normal: R.color.colorTextPrimary()!,
            highlighted: R.color.colorIconAccent()!
        )

        return WalletFormCellStyle(
            title: title,
            details: details,
            link: link,
            separator: R.color.colorDivider()!
        )
    }
}
