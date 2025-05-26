import Foundation
import Foundation_iOS
import Keystore_iOS

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

        messageSheetView.map { MessageSheetViewFacade.setupBottomSheet(from: $0.controller, preferredHeight: 316) }

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

    static func createNoOrForgotPassword(
        deleteClosure: @escaping MessageSheetCallback,
        cancelClosure: MessageSheetCallback?
    ) -> MessageSheetViewProtocol? {
        let messageSheetView = MessageSheetViewFactory.createNoContentView(
            viewModel: .init(
                title: LocalizableResource { locale in
                    R.string.localizable.cloudBackupNoPasswordTitle(preferredLanguages: locale.rLanguages)
                },
                message: LocalizableResource { locale in
                    NSAttributedString.coloredItems(
                        [
                            R.string.localizable.cloudBackupNoPasswordHighlighted1(
                                preferredLanguages: locale.rLanguages
                            ),
                            R.string.localizable.cloudBackupNoPasswordHighlighted2(
                                preferredLanguages: locale.rLanguages
                            )
                        ],
                        formattingClosure: { items in
                            R.string.localizable.cloudBackupNoPasswordMessage(
                                items[0],
                                items[1],
                                preferredLanguages: locale.rLanguages
                            )
                        },
                        color: R.color.colorTextPrimary()!
                    )
                },
                graphics: R.image.imageNoPasswordCloudBackup(),
                content: nil,
                mainAction: .init(
                    title: LocalizableResource { locale in
                        R.string.localizable.commonDeleteBackup(preferredLanguages: locale.rLanguages)
                    },
                    handler: deleteClosure,
                    actionType: .destructive
                ),
                secondaryAction: .init(
                    title: LocalizableResource { locale in
                        R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
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
                    R.string.localizable.cloudBackupBrokenTitle(preferredLanguages: locale.rLanguages)
                },
                message: LocalizableResource { locale in
                    NSAttributedString.coloredItems(
                        [
                            R.string.localizable.cloudBackupNoPasswordHighlighted1(
                                preferredLanguages: locale.rLanguages
                            )
                        ],
                        formattingClosure: { items in
                            R.string.localizable.cloudBackupBrokenMessage(
                                items[0],
                                preferredLanguages: locale.rLanguages
                            )
                        },
                        color: R.color.colorTextPrimary()!
                    )
                },
                graphics: R.image.imageBrokenCloudBackup(),
                content: nil,
                mainAction: .init(
                    title: LocalizableResource { locale in
                        R.string.localizable.commonDeleteBackup(preferredLanguages: locale.rLanguages)
                    },
                    handler: deleteClosure,
                    actionType: .destructive
                ),
                secondaryAction: .init(
                    title: LocalizableResource { locale in
                        R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
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
            R.string.localizable.cloudBackupAutoSyncTitle(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource { locale in
            R.string.localizable.cloudBackupAutoSyncDescription(preferredLanguages: locale.rLanguages)
        }

        let text = LocalizableResource { locale in
            R.string.localizable.delegatedSigningCheckmarkTitle(
                preferredLanguages: locale.rLanguages
            )
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
                    R.string.localizable.cloudBackupUnsyncedChangesTitle(preferredLanguages: locale.rLanguages)
                },
                message: LocalizableResource { locale in
                    R.string.localizable.cloudBackupUnsyncedChangesMessage(preferredLanguages: locale.rLanguages)
                },
                graphics: R.image.imageUnsyncedCloudBackup(),
                content: nil,
                mainAction: .init(
                    title: LocalizableResource { locale in
                        R.string.localizable.commonReviewUpdates(preferredLanguages: locale.rLanguages)
                    },
                    handler: completionClosure,
                    actionType: .normal
                ),
                secondaryAction: .init(
                    title: LocalizableResource { locale in
                        R.string.localizable.commonNotNow(preferredLanguages: locale.rLanguages)
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
                    R.string.localizable.cloudBackupSheetPasswordChangedTitle(preferredLanguages: locale.rLanguages)
                },
                message: LocalizableResource { locale in
                    NSAttributedString.coloredItems(
                        [
                            R.string.localizable.cloudBackupSheetPasswordChangedEnterNew(
                                preferredLanguages: locale.rLanguages
                            )
                        ],
                        formattingClosure: { items in
                            R.string.localizable.cloudBackupSheetPasswordChangedMessage(
                                items[0],
                                preferredLanguages: locale.rLanguages
                            )
                        },
                        color: R.color.colorTextPrimary()!
                    )
                },
                graphics: R.image.imageNoPasswordCloudBackup(),
                content: nil,
                mainAction: .init(
                    title: LocalizableResource { locale in
                        R.string.localizable.commonEnterPasswordButton(preferredLanguages: locale.rLanguages)
                    },
                    handler: completionClosure,
                    actionType: .normal
                ),
                secondaryAction: .init(
                    title: LocalizableResource { locale in
                        R.string.localizable.commonNotNow(preferredLanguages: locale.rLanguages)
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
                    R.string.localizable.cloudBackupSyncFailedTitle(preferredLanguages: locale.rLanguages)
                },
                message: LocalizableResource { locale in
                    R.string.localizable.cloudBackupSyncFailedMessage(preferredLanguages: locale.rLanguages)
                },
                graphics: R.image.imageUnsyncedCloudBackup(),
                content: nil,
                mainAction: .init(
                    title: LocalizableResource { locale in
                        R.string.localizable.commonReviewIssue(preferredLanguages: locale.rLanguages)
                    },
                    handler: completionClosure,
                    actionType: .normal
                ),
                secondaryAction: .init(
                    title: LocalizableResource { locale in
                        R.string.localizable.commonNotNow(preferredLanguages: locale.rLanguages)
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
                    R.string.localizable.cloudBackupRemoveWalletTitle(preferredLanguages: locale.rLanguages)
                },
                message: LocalizableResource { locale in
                    R.string.localizable.cloudBackupRemoveWalletMessage(preferredLanguages: locale.rLanguages)
                },
                graphics: R.image.imageRemoveWalletCloudBackup(),
                content: nil,
                mainAction: .init(
                    title: LocalizableResource { locale in
                        R.string.localizable.commonRemove(preferredLanguages: locale.rLanguages)
                    },
                    handler: removeClosure,
                    actionType: .destructive
                ),
                secondaryAction: .init(
                    title: LocalizableResource { locale in
                        R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
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
                    R.string.localizable.cloudBackupWillDeleteTitle(preferredLanguages: locale.rLanguages)
                },
                message: LocalizableResource { locale in
                    NSAttributedString.coloredItems(
                        [
                            R.string.localizable.cloudBackupWillDeleteHighlighted(
                                preferredLanguages: locale.rLanguages
                            )
                        ],
                        formattingClosure: { items in
                            R.string.localizable.cloudBackupWillDeleteMessage(
                                items[0],
                                preferredLanguages: locale.rLanguages
                            )
                        },
                        color: R.color.colorTextPrimary()!
                    )
                },
                graphics: R.image.imageBrokenCloudBackup(),
                content: nil,
                mainAction: .init(
                    title: LocalizableResource { locale in
                        R.string.localizable.commonDeleteBackup(preferredLanguages: locale.rLanguages)
                    },
                    handler: deleteClosure,
                    actionType: .destructive
                ),
                secondaryAction: .init(
                    title: LocalizableResource { locale in
                        R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
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
