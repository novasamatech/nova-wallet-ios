protocol CloudBackupReviewChangesDelegate: AnyObject {
    func cloudBackupReviewerDidApprove(changes: CloudBackupSyncResult.Changes)
}

protocol CloudBackupReviewChangesViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModels: [CloudBackupReviewSectionViewModel])
}

protocol CloudBackupReviewChangesPresenterProtocol: AnyObject {
    func setup()
    func activateNotNow()
    func activateApply()
}

protocol CloudBackupReviewChangesWireframeProtocol: AnyObject {
    func close(view: CloudBackupReviewChangesViewProtocol?, closure: (() -> Void)?)
}
