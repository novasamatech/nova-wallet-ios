import Foundation

enum StateCallRpc {
    static var method: String { "state_call" }
    static var feeBuiltIn: String { "TransactionPaymentApi_query_info" }
    static var feeResultType: String { "RuntimeDispatchInfo" }

    struct Request: Encodable {
        let builtInFunction: String
        let paramsClosure: (inout UnkeyedEncodingContainer) throws -> Void

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            try container.encode(builtInFunction)

            try paramsClosure(&container)
        }
    }
}
