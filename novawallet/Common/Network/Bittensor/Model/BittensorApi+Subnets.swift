import Foundation

extension BittensorApi {
    struct SubnetCollection: Decodable, Equatable {
        struct Components: Decodable, Equatable {
            let subnetMetadata: AvailableComponent
            let alphaPrices: AvailableComponent
        }

        struct Meta: Decodable, Equatable {
            let completeness: Completeness
            let components: Components
        }

        let items: [Subnet]
        let meta: Meta
    }

    struct Subnet: Decodable, Equatable {
        let netuid: UInt16
        let name: String
        let symbol: String
        let networkRegisteredAt: UInt64
        let ownerColdkey: String
        let ownerHotkey: String
        let tempo: UInt64
        let githubRepo: String
        let subnetContact: String
        let subnetUrl: String
        let subnetWebsite: String
        let discord: String
        let additional: String
        let reportedRootProportion: String
        let taoReserve: String
        let alphaReserve: String
        let alphaOutstanding: String
        let taoPerAlpha: String
    }
}
