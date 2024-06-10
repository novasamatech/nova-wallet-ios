import Foundation

struct ConnectionTLSSupport {
    let url: URL
    let supportsTLS12: Bool
}

protocol ConnectionTLSSupportProviding: AnyObject {
    func supportTls12(for url: URL) -> Bool

    func add(support: [ConnectionTLSSupport])
}

final class ConnectionTLSSupportProvider {
    private var noTls12Support: Set<URL> = []
}

extension ConnectionTLSSupportProvider: ConnectionTLSSupportProviding {
    func supportTls12(for url: URL) -> Bool {
        !noTls12Support.contains(url)
    }

    func add(support: [ConnectionTLSSupport]) {
        let newUrls = Set(support.compactMap { $0.supportsTLS12 ? nil : $0.url })
        noTls12Support.formUnion(newUrls)
    }
}
