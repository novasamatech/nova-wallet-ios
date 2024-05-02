import Foundation
import SubstrateSdk

enum AvailSignedExtension {
    final class CheckAppId: Codable, ExtrinsicExtension {
        static var name: String { "CheckAppId" }

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
        private func getBaseSignedExtensions() -> [ExtrinsicExtension] {
            [
                ChargeAssetTxPayment()
            ]
        }

        private func getMainSignedExtensions() -> [ExtrinsicExtension] {
            [
                CheckAppId(appId: 0)
            ]
        }

        private func getBaseCoders(for metadata: RuntimeMetadataProtocol) -> [ExtrinsicExtensionCoder] {
            DefaultSignedExtensionCoders.createDefaultCoders(for: metadata)
        }

        private func getMainCoders(for metadata: RuntimeMetadataProtocol) -> [ExtrinsicExtensionCoder] {
            let extensionName = CheckAppId.name

            guard let extraType = metadata.getSignedExtensionType(for: extensionName) else {
                return []
            }

            return [
                DefaultExtrinsicExtensionCoder(
                    name: ChargeAssetTxPayment.name,
                    extraType: extraType
                )
            ]
        }
    }
}

extension AvailSignedExtension.Factory: ExtrinsicSignedExtensionFactoryProtocol {
    func createExtensions() -> [ExtrinsicExtension] {
        getBaseSignedExtensions() + getMainSignedExtensions()
    }

    func createExtensions(payingFeeIn _: AssetConversionPallet.AssetId) -> [ExtrinsicExtension] {
        // Avail doesn't support fee customization via signed extensions - ignore parameter
        createExtensions()
    }

    func createCoders(for metadata: RuntimeMetadataProtocol) -> [ExtrinsicExtensionCoder] {
        getBaseCoders(for: metadata) + getMainCoders(for: metadata)
    }
}
