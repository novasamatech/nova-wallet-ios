import Foundation
import SubstrateSdk

extension Multisig {
    struct NewMultisigEvent: Decodable {
        let accountId: AccountId
        let callHash: CallHash
        
        init(from decoder: Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()
            
            _ = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
            accountId = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
            callHash = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
        }
    }
    
    struct MultisigApprovalEvent: Decodable {
        let accountId: AccountId
        let callHash: CallHash
        
        init(from decoder: Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()
            
            _ = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
            _ = try unkeyedContainer.decode(Multisig.MultisigTimepoint.self)
            accountId = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
            callHash = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
        }
    }
}
