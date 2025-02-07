import Foundation
import SubstrateSdk

enum AvailSignedExtension {
    static let checkAppId = "CheckAppId"

    final class CheckAppId: Codable, OnlyExtrinsicSignedExtending {
        var signedExtensionId: String { AvailSignedExtension.checkAppId }

        let appId: UInt32

        init(appId: UInt32) {
            self.appId = appId
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            appId = try container.decode(StringScaleMapper<UInt32>.self).value
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()

            try container.encode(StringScaleMapper(value: appId))
        }
    }
}

enum AvailSignedExtensionCoders {
    static func getCoders(for metadata: RuntimeMetadataProtocol) -> [ExtrinsicSignedExtensionCoding] {
        let extensionId = AvailSignedExtension.checkAppId

        guard let extraType = metadata.getSignedExtensionType(for: extensionId) else {
            return []
        }

        return [
            DefaultExtrinsicSignedExtensionCoder(
                signedExtensionId: extensionId,
                extraType: extraType
            )
        ]
    }
}
