import Foundation

struct SubtensorSubnetLinks: Equatable {
    let githubRepo: String
    let subnetContact: String
    let subnetUrl: String
    let subnetWebsite: String
    let discord: String
    let additional: String
}

struct SubtensorCatalogueSubnet: Equatable {
    let netuid: UInt16
    let name: String
    let symbol: String
    let networkRegisteredAt: UInt64
    let tempo: UInt64
    let ownerColdkey: String
    let ownerHotkey: String
    let links: SubtensorSubnetLinks
    let taoReserve: Balance
    let alphaReserve: Balance
    let alphaOutstanding: Balance
    let taoPerAlpha: Balance
    let metadataStamp: SubtensorBackendStamp
    let pricesStamp: SubtensorBackendStamp

    var ref: SubtensorSubnetRef {
        SubtensorSubnetRef(netuid: netuid, registeredAt: networkRegisteredAt)
    }
}

struct SubtensorSubnetCatalogue: Equatable {
    let subnets: [SubtensorCatalogueSubnet]

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
