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

extension AvailSignedExtension {
    final class Factory {
        private func getBaseSignedExtensions() -> [ExtrinsicSignedExtending] {
            []
        }

        private func getMainSignedExtensions() -> [ExtrinsicSignedExtending] {
            [
                CheckAppId(appId: 0)
            ]
        }

        private func getBaseCoders(for metadata: RuntimeMetadataProtocol) -> [ExtrinsicSignedExtensionCoding] {
            DefaultSignedExtensionCoders.createDefaultCoders(for: metadata)
        }

        private func getMainCoders(for metadata: RuntimeMetadataProtocol) -> [ExtrinsicSignedExtensionCoding] {
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
}

extension AvailSignedExtension.Factory: ExtrinsicSignedExtensionFactoryProtocol {
    func createExtensions() -> [ExtrinsicSignedExtending] {
        getBaseSignedExtensions() + getMainSignedExtensions()
    }

    func createExtensions(payingFeeIn _: AssetConversionPallet.AssetId) -> [ExtrinsicSignedExtending] {
        // Avail doesn't support fee customization via signed extensions - ignore parameter
        createExtensions()
    }

    func createCoders(for metadata: RuntimeMetadataProtocol) -> [ExtrinsicSignedExtensionCoding] {
        getBaseCoders(for: metadata) + getMainCoders(for: metadata)
    }
}
