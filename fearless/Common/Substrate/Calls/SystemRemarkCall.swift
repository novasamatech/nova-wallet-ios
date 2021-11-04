import SubstrateSdk

struct SystemRemarkCall: Codable {
    @BytesCodable var remark: Data
}
