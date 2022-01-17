import Foundation
import SubstrateSdk

enum ExtrinsicBuilderExtensionError: Error {
    case invalidRawSignature(data: Data)
}

extension ExtrinsicBuilderProtocol {
    func signing(
        with signingClosure: (Data) throws -> Data,
        chainFormat: ChainFormat,
        cryptoType: MultiassetCryptoType,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> Self {
        switch chainFormat {
        case .ethereum:
            return try signing(
                by: { data in
                    let signature = try signingClosure(data)

                    guard let ethereumSignature = EthereumSignature(rawValue: signature) else {
                        throw ExtrinsicBuilderExtensionError.invalidRawSignature(data: signature)
                    }

                    return try ethereumSignature.toScaleCompatibleJSON(
                        with: codingFactory.createRuntimeJsonContext().toRawContext()
                    )
                },
                using: codingFactory.createEncoder(),
                metadata: codingFactory.metadata
            )
        case .substrate:
            return try signing(
                by: signingClosure,
                of: cryptoType.utilsType,
                using: codingFactory.createEncoder(),
                metadata: codingFactory.metadata
            )
        }
    }
}
