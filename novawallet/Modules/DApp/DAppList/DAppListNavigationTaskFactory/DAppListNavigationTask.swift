protocol DAppListNavigationTaskCleaning {
    func cleanCompletedTask()
}

struct DAppListNavigationTask {
    let tabProvider: () -> DAppBrowserTab?
    let routingClosure: (DAppBrowserTab, ControllerBackedProtocol?) -> Void

    func callAsFunction(
        cleaner: DAppListNavigationTaskCleaning,
        view: ControllerBackedProtocol?
    ) {
        guard let tab = tabProvider() else {
            return
        }

        routingClosure(tab, view)
        cleaner.cleanCompletedTask()
    }
}
