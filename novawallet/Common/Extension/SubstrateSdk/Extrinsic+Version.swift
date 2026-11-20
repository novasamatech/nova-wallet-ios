import Foundation
import SubstrateSdk

/**
 *  The numbers a runtime and a dApp name the extrinsic formats and extension sets with.
 */
extension Extrinsic.Version {
    static let legacyFormatNumber: UInt8 = 4
    static let generalFormatNumber: UInt8 = 5

    // legacy extrinsics have no version of the extension set and use the base one
    static let baseExtensionVersion: UInt8 = 0

    var formatNumber: UInt8 {
        switch self {
        case .V4:
            Self.legacyFormatNumber
        case .V5:
            Self.generalFormatNumber
        }
    }

    var extensionVersion: UInt8 {
        switch self {
        case .V4:
            Self.baseExtensionVersion
        case let .V5(extensionVersion):
            extensionVersion
        }
    }
}
