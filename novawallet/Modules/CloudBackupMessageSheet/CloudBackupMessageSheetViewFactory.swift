import Foundation
import SoraFoundation

enum CloudBackupMessageSheetViewFactory {
    static func createBackupMessageSheet() -> MessageSheetViewProtocol? {
        let messageSheetView = MessageSheetViewFactory.createNoContentView(
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
                graphics: R.image.imageProtectCloudBackup(),
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

        messageSheetView.map { MessageSheetViewFacade.setupBottomSheet(from: $0.controller, preferredHeight: 306) }

        return messageSheetView
    }

    static func createBackupAlreadyExists(
        for recoverClosure: @escaping MessageSheetCallback
    ) -> MessageSheetViewProtocol? {
        let messageSheetView = MessageSheetViewFactory.createNoContentView(
            viewModel: .init(
                title: LocalizableResource { locale in
                    R.string.localizable.cloudBackupExistingBottomSheetTitle(preferredLanguages: locale.rLanguages)
                },
                message: LocalizableResource { locale in
                    NSAttributedString.coloredItems(
                        [
                            R.string.localizable.cloudBackupExistingBottomSheetRecover(
                                preferredLanguages: locale.rLanguages
                            )
                        ],
                        formattingClosure: { items in
                            R.string.localizable.cloudBackupExistingBottomSheetMessage(
                                items[0],
                                preferredLanguages: locale.rLanguages
                            )
                        },
                        color: R.color.colorTextPrimary()!
                    )
                },
                graphics: R.image.imageActiveCloudBackup(),
                content: nil,
                mainAction: .init(
                    title: LocalizableResource { locale in
                        R.string.localizable.commonRecoverWallets(preferredLanguages: locale.rLanguages)
                    },
                    handler: recoverClosure
                ),
                secondaryAction: .init(
                    title: LocalizableResource { locale in
                        R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
                    },
                    handler: {}
                )
            ),
            allowsSwipeDown: false
        )

        messageSheetView.map { MessageSheetViewFacade.setupBottomSheet(from: $0.controller, preferredHeight: 296) }

        return messageSheetView
    }
}
