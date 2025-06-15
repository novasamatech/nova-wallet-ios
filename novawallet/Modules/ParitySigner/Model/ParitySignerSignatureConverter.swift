import Foundation
import BigInt
import SubstrateSdk

public enum ParitySignerSignatureConverter {
    /**
     *  Cuts prefix bytes of the input payload which represent length of the call in compact format
     */
    public static func convertParitySignerSignaturePayloadToRegular(
        _ payload: Data,
        shouldConvertToRegular: Bool
    ) throws -> Data {
        let decoder = try ScaleDecoder(data: payload)
        _ = try BigUInt(scaleDecoder: decoder)

        let extrinsicPayload = payload.suffix(decoder.remained)

        if shouldConvertToRegular {
            return try ExtrinsicSignatureConverter.convertExtrinsicPayloadToRegular(extrinsicPayload)
        } else {
            return extrinsicPayload
        }
    }
}
