import Foundation
import NovaCrypto

final class SubtensorRecordingSigner: SigningWrapperProtocol {
    private let signer: SigningWrapperProtocol
    private let signedClosure: () -> Void
    private let mutex = NSLock()

    private var signatureCreated = false

    init(signer: SigningWrapperProtocol, signedClosure: @escaping () -> Void) {
        self.signer = signer
        self.signedClosure = signedClosure
    }

    var hasSignature: Bool {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return signatureCreated
    }

    func sign(_ originalData: Data, context: ExtrinsicSigningContext) throws -> IRSignatureProtocol {
        let signature = try signer.sign(originalData, context: context)

        mutex.lock()
        signatureCreated = true
        mutex.unlock()

        signedClosure()

        return signature
    }
}
