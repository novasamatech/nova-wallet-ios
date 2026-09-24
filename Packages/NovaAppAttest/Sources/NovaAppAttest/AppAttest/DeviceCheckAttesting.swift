import Foundation
import DeviceCheck

/// App Attest operations; `DCAppAttestService` reports unsupported on Simulator.
public protocol DeviceCheckAttesting {
    var isSupported: Bool { get }

    func generateKey(completionHandler: @escaping (String?, Error?) -> Void)

    func attestKey(
        _ keyId: String,
        clientDataHash: Data,
        completionHandler: @escaping (Data?, Error?) -> Void
    )

    func generateAssertion(
        _ keyId: String,
        clientDataHash: Data,
        completionHandler: @escaping (Data?, Error?) -> Void
    )
}

extension DCAppAttestService: DeviceCheckAttesting {}
