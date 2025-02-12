import Foundation

final class BannersWireframe: BannersWireframeProtocol {
    private let router: URLLocalRouting

    init(router: URLLocalRouting) {
        self.router = router
    }

    func openActionLink(urlString: String) {
        guard
            let url = URL(string: urlString),
            router.canOpenLocalUrl(url)
        else { return }

        router.openLocalUrl(url)
    }
}
