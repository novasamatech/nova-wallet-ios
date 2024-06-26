import Foundation

protocol CloudBackupRemindPresentable {
    func showCloudBackupRemind(
        from view: ControllerBackedProtocol?,
        completion: @escaping MessageSheetCallback
    )

    func showRemoveCloudBackupWalletWarning(
        from view: ControllerBackedProtocol?,
        completion: @escaping MessageSheetCallback
    )
}

extension CloudBackupRemindPresentable {
    func showCloudBackupRemind(
        from view: ControllerBackedProtocol?,
        completion: @escaping MessageSheetCallback
    ) {
        guard let result = CloudBackupMessageSheetViewFactory.createBackupRemindSheet(
            completionClosure: completion
        ) else {
            return
        }

        switch result {
        case let .present(messageSheet):
            view?.controller.present(messageSheet.controller, animated: true)
        case .confirmationNotNeeded:
            completion()
        }
    }

    func showRemoveCloudBackupWalletWarning(
        from view: ControllerBackedProtocol?,
        completion: @escaping MessageSheetCallback
    ) {
        guard let messageSheet = CloudBackupMessageSheetViewFactory.createWalletRemoveSheet(
            removeClosure: completion,
            cancelClosure: nil
        ) else {
            return
        }

        view?.controller.present(messageSheet.controller, animated: true)
    }
}
