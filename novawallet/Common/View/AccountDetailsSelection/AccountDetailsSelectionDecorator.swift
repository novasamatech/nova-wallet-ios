import Foundation

protocol AccountDetailsSelectionDecorator {
    static func decorate(viewModel: TitleWithSubtitleViewModel, enabled: Bool) -> NSAttributedString
}

struct AccountDetailsBalanceDecorator: AccountDetailsSelectionDecorator {
    static func decorate(viewModel: TitleWithSubtitleViewModel, enabled: Bool) -> NSAttributedString {
        let titleColor = R.color.colorTextSecondary()!

        let attributedString = NSMutableAttributedString(
            string: viewModel.title,
            attributes: [
                .foregroundColor: titleColor
            ]
        )

        let subtitleColor = enabled ? R.color.colorTextPrimary()! : R.color.colorTextSecondary()!

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
                .foregroundColor: R.color.colorTextPositive()!
            ]
        )

        guard hasSubtitle else {
            return attributedString
        }

        let subtitleAttributedString = NSAttributedString(
            string: " " + viewModel.subtitle,
            attributes: [
                .foregroundColor: R.color.colorTextSecondary()!
            ]
        )

        attributedString.append(subtitleAttributedString)

        return attributedString
    }
}
