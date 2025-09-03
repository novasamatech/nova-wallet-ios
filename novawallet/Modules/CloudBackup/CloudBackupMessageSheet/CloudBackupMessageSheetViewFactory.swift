import Foundation
import UIKit
import Foundation_iOS
import Keystore_iOS

enum CloudBackupMessageSheetViewFactory {
    static func createBackupMessageSheet() -> MessageSheetViewProtocol? {
        let messageSheetView = MessageSheetViewFactory.createNoContentView(
            viewModel: .init(
                title: LocalizableResource { locale in
                    R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupCreateBottomSheetTitle()
                },
                message: LocalizableResource { locale in
                    NSAttributedString.coloredItems(
                        [
                            R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupCreateBottomSheetPassword()
                        ],
                        formattingClosure: { items in
                            R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupCreateBottomSheetMessage(
                                items[0]
                            )
                        },
                        color: R.color.colorTextPrimary()!
                    )
                },
                graphics: R.image.imageProtectCloudBackup(),
                content: nil,
                mainAction: .init(
                    title: LocalizableResource { locale in
                        R.string(preferredLanguages: locale.rLanguages).localizable.commonGotIt()
                    },
                    handler: {}
                ),
                secondaryAction: nil
            ),
            allowsSwipeDown: false
        )

        messageSheetView.map { MessageSheetViewFacade.setupBottomSheet(from: $0.controller, preferredHeight: 316) }

        return messageSheetView
    }

    static func createBackupAlreadyExists(
        for recoverClosure: @escaping MessageSheetCallback
    ) -> MessageSheetViewProtocol? {
        let messageSheetView = MessageSheetViewFactory.createNoContentView(
            viewModel: .init(
                title: LocalizableResource { locale in
                    R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupExistingBottomSheetTitle()
                },
                message: LocalizableResource { locale in
                    NSAttributedString.coloredItems(
                        [
                            R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupExistingBottomSheetRecover()
                        ],
                        formattingClosure: { items in
                            R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupExistingBottomSheetMessage(
                                items[0]
                            )
                        },
                        color: R.color.colorTextPrimary()!
                    )
                },
                graphics: R.image.imageActiveCloudBackup(),
                content: nil,
                mainAction: .init(
                    title: LocalizableResource { locale in
                        R.string(preferredLanguages: locale.rLanguages).localizable.commonRecoverWallets()
                    },
                    handler: recoverClosure
                ),
                secondaryAction: .init(
                    title: LocalizableResource { locale in
                        R.string(preferredLanguages: locale.rLanguages).localizable.commonCancel()
                    },
                    handler: {}
                )
            ),
            allowsSwipeDown: false
        )

        messageSheetView.map { MessageSheetViewFacade.setupBottomSheet(from: $0.controller, preferredHeight: 296) }

        return messageSheetView
    }

    static func createNoOrForgotPassword(
        deleteClosure: @escaping MessageSheetCallback,
        cancelClosure: MessageSheetCallback?
    ) -> MessageSheetViewProtocol? {
        let messageSheetView = MessageSheetViewFactory.createNoContentView(
            viewModel: .init(
                title: LocalizableResource { locale in
                    R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupNoPasswordTitle()
                },
                message: LocalizableResource { locale in
                    NSAttributedString.coloredItems(
                        [
                            R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupNoPasswordHighlighted1(),
                            R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupNoPasswordHighlighted2()
                        ],
                        formattingClosure: { items in
                            R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupNoPasswordMessage(
                                items[0],
                                items[1]
                            )
                        },
                        color: R.color.colorTextPrimary()!
                    )
                },
                graphics: R.image.imageNoPasswordCloudBackup(),
                content: nil,
                mainAction: .init(
                    title: LocalizableResource { locale in
                        R.string(preferredLanguages: locale.rLanguages).localizable.commonDeleteBackup()
                    },
                    handler: deleteClosure,
                    actionType: .destructive
                ),
                secondaryAction: .init(
                    title: LocalizableResource { locale in
                        R.string(preferredLanguages: locale.rLanguages).localizable.commonCancel()
                    },
                    handler: {
                        cancelClosure?()
                    }
                )
            ),
            allowsSwipeDown: false
        )

        messageSheetView.map { MessageSheetViewFacade.setupBottomSheet(from: $0.controller, preferredHeight: 368) }

        return messageSheetView
    }

    static func createEmptyOrBrokenBackup(
        deleteClosure: @escaping MessageSheetCallback,
        cancelClosure: MessageSheetCallback?
    ) -> MessageSheetViewProtocol? {
        let messageSheetView = MessageSheetViewFactory.createNoContentView(
            viewModel: .init(
                title: LocalizableResource { locale in
                    R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupBrokenTitle()
                },
                message: LocalizableResource { locale in
                    NSAttributedString.coloredItems(
                        [
                            R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupNoPasswordHighlighted1()
                        ],
                        formattingClosure: { items in
                            R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupBrokenMessage(
                                items[0]
                            )
                        },
                        color: R.color.colorTextPrimary()!
                    )
                },
                graphics: R.image.imageBrokenCloudBackup(),
                content: nil,
                mainAction: .init(
                    title: LocalizableResource { locale in
                        R.string(preferredLanguages: locale.rLanguages).localizable.commonDeleteBackup()
                    },
                    handler: deleteClosure,
                    actionType: .destructive
                ),
                secondaryAction: .init(
                    title: LocalizableResource { locale in
                        R.string(preferredLanguages: locale.rLanguages).localizable.commonCancel()
                    },
                    handler: {
                        cancelClosure?()
                    }
                )
            ),
            allowsSwipeDown: false
        )

        messageSheetView.map { MessageSheetViewFacade.setupBottomSheet(from: $0.controller, preferredHeight: 332) }

        return messageSheetView
    }

    static func createBackupRemindSheet(
        completionClosure: @escaping MessageSheetCallback
    ) -> CloudBackupRemindPresentationResult? {
        let settings = SettingsManager.shared

        guard !settings.cloudBackupAutoSyncConfirm else {
            return .confirmationNotNeeded
        }

        let wireframe = MessageSheetWireframe()

        let interactor = CloudBackupRemindInteractor(settings: settings)

        let presenter = CloudBackupRemindPresenter(interactor: interactor, wireframe: wireframe)

        let title = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupAutoSyncTitle()
        }

        let message = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupAutoSyncDescription()
        }

        let text = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.delegatedSigningCheckmarkTitle()
        }

        let viewModel = MessageSheetViewModel<UIImage, MessageSheetCheckmarkContentViewModel>(
            title: title,
            message: message,
            graphics: R.image.imageNewBackupWallet(),
            content: MessageSheetCheckmarkContentViewModel(checked: false, text: text),
            mainAction: .continueAction(for: completionClosure),
            secondaryAction: .cancelAction(for: {})
        )

        let view = CloudBackupRemindViewController(
            presenter: presenter,
            viewModel: viewModel,
            localizationManager: LocalizationManager.shared
        )

        view.allowsSwipeDown = false

        presenter.view = view

        MessageSheetViewFacade.setupBottomSheet(from: view, preferredHeight: 370)

        return .present(view: view)
    }

    static func createUnsyncedChangesSheet(
        completionClosure: @escaping MessageSheetCallback,
        cancelClosure: MessageSheetCallback?
    ) -> MessageSheetViewProtocol? {
        let messageSheetView = MessageSheetViewFactory.createNoContentView(
            viewModel: .init(
                title: LocalizableResource { locale in
                    R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupUnsyncedChangesTitle()
                },
                message: LocalizableResource { locale in
                    R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupUnsyncedChangesMessage()
                },
                graphics: R.image.imageUnsyncedCloudBackup(),
                content: nil,
                mainAction: .init(
                    title: LocalizableResource { locale in
                        R.string(preferredLanguages: locale.rLanguages).localizable.commonReviewUpdates()
                    },
                    handler: completionClosure,
                    actionType: .normal
                ),
                secondaryAction: .init(
                    title: LocalizableResource { locale in
                        R.string(preferredLanguages: locale.rLanguages).localizable.commonNotNow()
                    },
                    handler: {
                        cancelClosure?()
                    }
                )
            ),
            allowsSwipeDown: false
        )

        messageSheetView.map { MessageSheetViewFacade.setupBottomSheet(from: $0.controller, preferredHeight: 296) }

        return messageSheetView
    }

    static func createPasswordChangedSheet(
        completionClosure: @escaping MessageSheetCallback,
        cancelClosure: MessageSheetCallback?
    ) -> MessageSheetViewProtocol? {
        let messageSheetView = MessageSheetViewFactory.createNoContentView(
            viewModel: .init(
                title: LocalizableResource { locale in
                    R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupSheetPasswordChangedTitle()
                },
                message: LocalizableResource { locale in
                    NSAttributedString.coloredItems(
                        [
                            R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupSheetPasswordChangedEnterNew()
                        ],
                        formattingClosure: { items in
                            R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupSheetPasswordChangedMessage(
                                items[0]
                            )
                        },
                        color: R.color.colorTextPrimary()!
                    )
                },
                graphics: R.image.imageNoPasswordCloudBackup(),
                content: nil,
                mainAction: .init(
                    title: LocalizableResource { locale in
                        R.string(preferredLanguages: locale.rLanguages).localizable.commonEnterPasswordButton()
                    },
                    handler: completionClosure,
                    actionType: .normal
                ),
                secondaryAction: .init(
                    title: LocalizableResource { locale in
                        R.string(preferredLanguages: locale.rLanguages).localizable.commonNotNow()
                    },
                    handler: {
                        cancelClosure?()
                    }
                )
            ),
            allowsSwipeDown: false
        )

        messageSheetView.map { MessageSheetViewFacade.setupBottomSheet(from: $0.controller, preferredHeight: 314) }

        return messageSheetView
    }

    static func createCloudBackupUpdateFailedSheet(
        completionClosure: @escaping MessageSheetCallback,
        cancelClosure: MessageSheetCallback?
    ) -> MessageSheetViewProtocol? {
        let messageSheetView = MessageSheetViewFactory.createNoContentView(
            viewModel: .init(
                title: LocalizableResource { locale in
                    R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupSyncFailedTitle()
                },
                message: LocalizableResource { locale in
                    R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupSyncFailedMessage()
                },
                graphics: R.image.imageUnsyncedCloudBackup(),
                content: nil,
                mainAction: .init(
                    title: LocalizableResource { locale in
                        R.string(preferredLanguages: locale.rLanguages).localizable.commonReviewIssue()
                    },
                    handler: completionClosure,
                    actionType: .normal
                ),
                secondaryAction: .init(
                    title: LocalizableResource { locale in
                        R.string(preferredLanguages: locale.rLanguages).localizable.commonNotNow()
                    },
                    handler: {
                        cancelClosure?()
                    }
                )
            ),
            allowsSwipeDown: false
        )

        messageSheetView.map { MessageSheetViewFacade.setupBottomSheet(from: $0.controller, preferredHeight: 296) }

        return messageSheetView
    }

    static func createWalletRemoveSheet(
        removeClosure: @escaping MessageSheetCallback,
        cancelClosure: MessageSheetCallback?
    ) -> MessageSheetViewProtocol? {
        let messageSheetView = MessageSheetViewFactory.createNoContentView(
            viewModel: .init(
                title: LocalizableResource { locale in
                    R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupRemoveWalletTitle()
                },
                message: LocalizableResource { locale in
                    R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupRemoveWalletMessage()
                },
                graphics: R.image.imageRemoveWalletCloudBackup(),
                content: nil,
                mainAction: .init(
                    title: LocalizableResource { locale in
                        R.string(preferredLanguages: locale.rLanguages).localizable.commonRemove()
                    },
                    handler: removeClosure,
                    actionType: .destructive
                ),
                secondaryAction: .init(
                    title: LocalizableResource { locale in
                        R.string(preferredLanguages: locale.rLanguages).localizable.commonCancel()
                    },
                    handler: {
                        cancelClosure?()
                    }
                )
            ),
            allowsSwipeDown: false
        )

        messageSheetView.map { MessageSheetViewFacade.setupBottomSheet(from: $0.controller, preferredHeight: 320) }

        return messageSheetView
    }

    static func createDeleteBackupSheet(
        deleteClosure: @escaping MessageSheetCallback,
        cancelClosure: MessageSheetCallback?
    ) -> MessageSheetViewProtocol? {
        let messageSheetView = MessageSheetViewFactory.createNoContentView(
            viewModel: .init(
                title: LocalizableResource { locale in
                    R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupWillDeleteTitle()
                },
                message: LocalizableResource { locale in
                    NSAttributedString.coloredItems(
                        [
                            R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupWillDeleteHighlighted()
                        ],
                        formattingClosure: { items in
                            R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupWillDeleteMessage(
                                items[0]
                            )
                        },
                        color: R.color.colorTextPrimary()!
                    )
                },
                graphics: R.image.imageBrokenCloudBackup(),
                content: nil,
                mainAction: .init(
                    title: LocalizableResource { locale in
                        R.string(preferredLanguages: locale.rLanguages).localizable.commonDeleteBackup()
                    },
                    handler: deleteClosure,
                    actionType: .destructive
                ),
                secondaryAction: .init(
                    title: LocalizableResource { locale in
                        R.string(preferredLanguages: locale.rLanguages).localizable.commonCancel()
                    },
                    handler: {
                        cancelClosure?()
                    }
                )
            ),
            allowsSwipeDown: false
        )

        messageSheetView.map { MessageSheetViewFacade.setupBottomSheet(from: $0.controller, preferredHeight: 342) }

        return messageSheetView
    }
}
