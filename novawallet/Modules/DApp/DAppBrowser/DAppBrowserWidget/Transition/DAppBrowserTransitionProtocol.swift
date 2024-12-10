protocol DAppBrowserTransitionProtocol {
    func start()
    func start(with completion: @escaping () -> Void)
}
