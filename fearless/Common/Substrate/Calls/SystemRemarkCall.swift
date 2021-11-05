import SubstrateSdk

struct SystemRemarkCall: Codable {
    @BytesCodable var remark: Data
}

struct SystemRemarkWithEventCall: Codable {
    @BytesCodable var remark: Data
}
