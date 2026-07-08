protocol StartStakingCriticalNoticeSheetViewProtocol: ControllerBackedProtocol {
    func didStartTimer(totalSeconds: Int)
    func didUpdateTimer(remainingSeconds: Int)
    func didFinishTimer(confirmTitle: String)
}

protocol StartStakingCriticalNoticeSheetPresenterProtocol: AnyObject {
    func setup()
    func cancel()
    func confirm()
}
