import Foundation
import IrohaCrypto

enum NoSigningSupportType {
    case paritySigner
    case ledger
}

enum NoSigningSupportError: Error {
    case notSupported(type: NoSigningSupportType)
}

final class NoSigningSupportWrapper: SigningWrapperProtocol {
    let type: NoSigningSupportType

    init(type: NoSigningSupportType) {
        self.type = type
    }

    func sign(_: Data) throws -> IRSignatureProtocol {
        throw NoSigningSupportError.notSupported(type: type)
    }
}
