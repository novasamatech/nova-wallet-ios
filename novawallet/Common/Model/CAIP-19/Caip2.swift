enum Caip2 {}

extension Caip2 {
    struct ChainId {
        let namespace: String
        let reference: String
    }
}

extension Caip2 {
    enum RegisteredChain: Equatable {
        case polkadot(genesisHash: String)
        case eip155(id: Int)

        static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case let (.polkadot(hash), .polkadot(otherHash)):
                return hash == otherHash
            case let (.eip155(id), .eip155(otherId)):
                return id == otherId
            default:
                return false
            }
        }
    }
}

extension Caip2.ChainId {
    var knownChain: Caip2.RegisteredChain? {
        switch namespace {
        case "eip155":
            guard let id = Int(reference) else {
                return nil
            }
            return .eip155(id: id)
        case "polkadot":
            return .polkadot(genesisHash: reference)
        default:
            return nil
        }
    }
}
