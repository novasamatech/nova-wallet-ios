import Foundation

protocol AccountDetailsSelectionDecorator {
    static func decorate(viewModel: TitleWithSubtitleViewModel, enabled: Bool) -> NSAttributedString
}

struct AccountDetailsBalanceDecorator: AccountDetailsSelectionDecorator {
    static func decorate(viewModel: TitleWithSubtitleViewModel, enabled: Bool) -> NSAttributedString {
        let titleColor = enabled ? R.color.colorTransparentText()! : R.color.colorWhite32()!

        let attributedString = NSMutableAttributedString(
            string: viewModel.title,
            attributes: [
                .foregroundColor: titleColor
            ]
        )

        let subtitleColor = enabled ? R.color.colorWhite()! : R.color.colorWhite32()!

        let subtitleAttributedString = NSAttributedString(
            string: " " + viewModel.subtitle,
            attributes: [
                .foregroundColor: subtitleColor
            ]
        )

        attributedString.append(subtitleAttributedString)

        return attributedString
    }
}

struct AccountDetailsYieldBoostDecorator: AccountDetailsSelectionDecorator {
    static func decorate(viewModel: TitleWithSubtitleViewModel, enabled _: Bool) -> NSAttributedString {
        let hasSubtitle = !viewModel.subtitle.isEmpty

        let title = hasSubtitle ? viewModel.title + "," : viewModel.title

        let attributedString = NSMutableAttributedString(
            string: title,
            attributes: [
                .foregroundColor: R.color.colorGreen()!
            ]
        )

        guard hasSubtitle else {
            return attributedString
        }

        let subtitleAttributedString = NSAttributedString(
            string: " " + viewModel.subtitle,
            attributes: [
                .foregroundColor: R.color.colorTransparentText()!
            ]
        )

        attributedString.append(subtitleAttributedString)

        return attributedString
    }
}
