import Foundation

/// The row a running chain owns, so the failure handler never asks the identity for a client id —
/// that call mints one.
struct AttestationChainContext {
    let clientId: String
    let rowIdentifier: String
    let epoch: Int
}

/// The pair a request proof is minted from, resolved only once the gateway has said whether this
/// installation still has to register.
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

    /// Whether this attempt's failure actually retired the identity. Retrying without that is a
    /// second run of the byte-identical request the gateway just refused.
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
