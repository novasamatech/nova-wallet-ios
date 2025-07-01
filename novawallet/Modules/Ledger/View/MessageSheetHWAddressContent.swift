import UIKit
import Foundation_iOS

final class MessageSheetHWAddressContent: UIView, MessageSheetContentProtocol {
    typealias ContentViewModel = [ViewModelItem]

    private var contentView: UIView?

    func bind(messageSheetContent: ContentViewModel?, locale: Locale) {
        contentView?.removeFromSuperview()

        guard let items = messageSheetContent else {
            return
        }

        let stackItems = items.map { item in
            createView(for: item, locale: locale)
        }

        let view = UIView.vStack(
            alignment: .center,
            distribution: .fill,
            spacing: Constants.itemsSpacing,
            margins: nil,
            stackItems
        )

        contentView = view

        addSubview(view)

        view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

private extension MessageSheetHWAddressContent {
    func createView(for item: ViewModelItem, locale: Locale) -> UIView {
        let view = MultiValueView()
        view.valueTop.textAlignment = .center
        view.valueTop.apply(style: .footnotePrimary)
        view.valueTop.numberOfLines = 1

        view.valueBottom.textAlignment = .center
        view.valueBottom.apply(style: .footnoteSecondary)
        view.valueBottom.numberOfLines = 2

        view.bind(
            topValue: item.scheme.createTitle(for: locale),
            bottomValue: item.address.twoLineAddress
        )

        view.spacing = Constants.titleAddressSpacing

        return view
    }
}

extension MessageSheetHWAddressContent {
    struct ViewModelItem {
        let scheme: HardwareWalletAddressScheme
        let address: AccountAddress
    }

    enum Constants {
        static let titleAddressSpacing: CGFloat = 4
        static let itemsSpacing: CGFloat = 12
        static let sectionHeight: CGFloat = 58
    }
}
