import Foundation

protocol ConnectionTLSSupportProviding: AnyObject {
    func supportTls12(for url: URL) -> Bool

    func add(support: [ConnectionCreationParams])
}

final class ConnectionTLSSupportProvider {
    private var noTls12Support: Set<URL> = []
}

extension ConnectionTLSSupportProvider: ConnectionTLSSupportProviding {
    func supportTls12(for url: URL) -> Bool {
        !noTls12Support.contains(url)
    }

    func add(support: [ConnectionCreationParams]) {
        let newUrls = Set(support.compactMap { $0.supportsTLS12 ? nil : $0.url })
        noTls12Support.formUnion(newUrls)
    }
}
