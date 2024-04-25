import Foundation
import SoraFoundation

enum CloudBackupMessageSheetViewFactory {
    static func createBackupMessageSheet() -> MessageSheetViewProtocol? {
        MessageSheetViewFactory.createNoContentView(
            viewModel: .init(
                title: LocalizableResource { locale in
                    R.string.localizable.cloudBackupCreateBottomSheetTitle(preferredLanguages: locale.rLanguages)
                },
                message: LocalizableResource { locale in
                    NSAttributedString.coloredItems(
                        [
                            R.string.localizable.cloudBackupCreateBottomSheetPassword(
                                preferredLanguages: locale.rLanguages
                            )
                        ],
                        formattingClosure: { items in
                            R.string.localizable.cloudBackupCreateBottomSheetMessage(
                                items[0],
                                preferredLanguages: locale.rLanguages
                            )
                        },
                        color: R.color.colorTextPrimary()!
                    )
                },
                graphics: R.image.imageCloudBackup(),
                content: nil,
                mainAction: .init(
                    title: LocalizableResource { locale in
                        R.string.localizable.commonGotIt(preferredLanguages: locale.rLanguages)
                    },
                    handler: {}
                ),
                secondaryAction: nil
            ),
            allowsSwipeDown: false
        )
    }
}
