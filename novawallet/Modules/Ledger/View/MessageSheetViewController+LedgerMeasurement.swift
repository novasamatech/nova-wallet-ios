import Foundation

typealias MultiAddressMessageSheetViewController = MessageSheetViewController<
    MessageSheetImageView, MessageSheetHWAddressContent
>

extension MultiAddressMessageSheetViewController {
    static func measureHeight(for items: [C.ViewModelItem]) -> CGFloat {
        let baseHeight: CGFloat = 338

        return baseHeight + CGFloat(items.count) * C.Constants.sectionHeight +
            CGFloat(items.count - 1) * C.Constants.itemsSpacing
    }
}
