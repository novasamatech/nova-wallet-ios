import Foundation
import Foundation_iOS

protocol SubtensorInfoSheetPresentable: AddressOptionsPresentable, ShortTextInfoPresentable {
    func showSubtensorInfo(_ sheet: SubtensorInfoSheet, from view: ControllerBackedProtocol?)
}

extension SubtensorInfoSheetPresentable {
    func showSubtensorInfo(_ sheet: SubtensorInfoSheet, from view: ControllerBackedProtocol?) {
        guard let view else {
            return
        }

        if case let .account(address, chain) = sheet {
            presentAccountOptions(
                from: view,
                address: address,
                chain: chain,
                locale: LocalizationManager.shared.selectedLocale
            )

            return
        }

        let gotItAction = MessageSheetAction(
            title: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.commonGotIt()
            },
            handler: {}
        )

        showInfo(
            from: view,
            title: sheet.title,
            details: sheet.details,
            mainAction: gotItAction,
            titleStyle: .boldTitle3Primary,
            extraHeight: 24
        )
    }
}
