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
            style: TitleDetailsSheetViewLayout.Style(
                title: .boldTitle3Primary,
                detailsLineHeight: 18,
                spacing: 12,
                actionsBottomInset: 0
            ),
            extraHeight: 24
        )
    }
}
