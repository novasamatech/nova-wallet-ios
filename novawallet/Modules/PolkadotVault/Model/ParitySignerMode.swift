import Foundation
import SubstrateSdk

enum ParitySignerSigningModeError: Error {
    case unexpectedMode(ParitySignerSigningMode)
}

enum ParitySignerSigningMode {
    struct Extrinsic {
        let extrinsicMemo: ExtrinsicBuilderMemoProtocol
        let codingFactory: RuntimeCoderFactoryProtocol

        var canIncludeProof: Bool {
            codingFactory.supportsMetadataHash()
        }
    }

    case extrinsic(Extrinsic)
    case rawBytes

    func ensureRawBytes() throws {
        switch self {
        case .rawBytes:
            break
        case .extrinsic:
            throw ParitySignerSigningModeError.unexpectedMode(self)
        }
    }

    func ensureExtrinsic() throws -> Extrinsic {
        switch self {
        case .rawBytes:
            throw ParitySignerSigningModeError.unexpectedMode(self)
        case let .extrinsic(params):
            return params
        }
    }
}
