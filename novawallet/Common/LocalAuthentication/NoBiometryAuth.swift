import Foundation
import Operation_iOS

final class NoBiometryAuth: BiometryAuthProtocol {
    var availableBiometryType: AvailableBiometryType { .none }
    var supportedBiometryType: AvailableBiometryType { .none }

    func authenticate(
        localizedReason _: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (Bool) -> Void
    ) {
        dispatchInQueueWhenPossible(completionQueue) {
            completionBlock(false)
        }
    }
}
