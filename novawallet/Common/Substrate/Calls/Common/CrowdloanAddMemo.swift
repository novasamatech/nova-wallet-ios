import Foundation
import SubstrateSdk

struct CrowdloanAddMemo: Codable {
    @StringCodable var index: ParaId
    @BytesCodable var memo: Data
}
