protocol BrowserNavigationTaskCleaning {
    func cleanCompletedTask()
}

struct BrowserNavigationTask {
    let tabProvider: () -> DAppBrowserTab?
    let routingClosure: (DAppBrowserTab) -> Void

    func callAsFunction(cleaner: BrowserNavigationTaskCleaning) {
        guard let tab = tabProvider() else {
            return
        }

        routingClosure(tab)
        cleaner.cleanCompletedTask()
    }
}
