import Foundation
import SubstrateSdk

struct RuntimeSnapshot {
    let localCommonHash: String?
    let localChainHash: String?
    let typeRegistryCatalog: TypeRegistryCatalogProtocol
    let specVersion: UInt32
    let txVersion: UInt32
    let metadata: RuntimeMetadataProtocol
}
