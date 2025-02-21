import Foundation

enum StateCallRpc {
    static var method: String { "state_call" }
    static var feeBuiltInModule: String { "TransactionPaymentApi" }
    static var feeBuiltInMethod: String { "query_info" }
    static var feeBuiltIn: String { "TransactionPaymentApi_query_info" }
    static var feeResultType: String { "RuntimeDispatchInfo" }

    struct Request: Encodable {
        let builtInFunction: String
        let blockHash: BlockHash?
        let paramsClosure: (inout UnkeyedEncodingContainer) throws -> Void

        init(
            builtInFunction: String,
            blockHash: BlockHash? = nil,
            paramsClosure: @escaping (inout UnkeyedEncodingContainer) throws -> Void
        ) {
            self.builtInFunction = builtInFunction
            self.paramsClosure = paramsClosure
            self.blockHash = blockHash
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            try container.encode(builtInFunction)

            try paramsClosure(&container)

            if let blockHash {
                try container.encode(blockHash.withHexPrefix())
            }
        }
    }
}
