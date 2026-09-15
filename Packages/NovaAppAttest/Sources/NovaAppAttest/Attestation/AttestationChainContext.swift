import Foundation

// Capture the owned identity so failure handling cannot create a replacement during cleanup.
struct AttestationChainContext {
    let clientId: String
    let rowIdentifier: String
    let epoch: Int
}

struct AttestationCredentials {
    let challenge: String
    let keyId: AppAttestKeyId
}

final class AttestationChainContextBox {
    private let mutex = NSLock()
    private var stored: AttestationChainContext?
    private var retired: Bool = false

    var value: AttestationChainContext? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return stored
    }

    var didRetire: Bool {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return retired
    }

    func store(_ context: AttestationChainContext) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        stored = context
    }

    func markRetired() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        retired = true
    }
}
