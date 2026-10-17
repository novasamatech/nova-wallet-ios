import BigInt
import Foundation

struct SubtensorCatalogueSubnet: Equatable {
    let netuid: UInt16
    let name: String
    let symbol: String
    let networkRegisteredAt: UInt64
    let taoReserve: Balance
    let alphaReserve: Balance
    let alphaOutstanding: Balance
    let taoPerAlpha: Balance
    let metadataStamp: SubtensorBackendStamp
    let pricesStamp: SubtensorBackendStamp

    var ref: SubtensorSubnetRef {
        SubtensorSubnetRef(netuid: netuid, registeredAt: networkRegisteredAt)
    }

    var stamps: [SubtensorBackendStamp] {
        [metadataStamp, pricesStamp]
    }

    var freshTaoPerAlpha: Balance? {
        pricesStamp.freshness == .fresh ? taoPerAlpha : nil
    }
}

struct SubtensorSubnetCatalogue: Equatable {
    let subnets: [SubtensorCatalogueSubnet]

    var freshTaoPerAlpha: [UInt16: Balance] {
        subnets.reduce(into: [:]) { $0[$1.netuid] = $1.freshTaoPerAlpha }
    }

    func subnet(for netuid: UInt16) -> SubtensorCatalogueSubnet? {
        subnets.first { $0.netuid == netuid }
    }

    func subnet(for ref: SubtensorSubnetRef) -> SubtensorCatalogueSubnet? {
        guard let subnet = subnet(for: ref.netuid), subnet.networkRegisteredAt == ref.registeredAt else {
            return nil
        }

        return subnet
    }
}
