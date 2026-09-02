import Foundation
import DeviceCheck

/// The seam that makes App Attest testable: DCAppAttestService.isSupported is false on
/// Simulator, so without this every test of the state machine short-circuits.
protocol DeviceCheckAttesting {
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
