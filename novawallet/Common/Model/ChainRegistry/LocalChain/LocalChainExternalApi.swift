import Foundation
import SubstrateSdk

enum LocalChainApiExternalType: String {
    case history
    case staking
    case stakingRewards
    case governance
    case crowdloans
    case governanceDelegations
    case referendumSummary
    case multisig
}

struct LocalChainExternalApi: Equatable, Codable, Hashable {
    let apiType: String
    let serviceType: String
    let url: URL
    let parameters: JSON?

    var identifier: String {
        Self.createId(from: apiType, serviceType: serviceType, url: url)
    }

    static func createId(from apiType: String, serviceType: String, url: URL) -> String {
        apiType + "-" + serviceType + url.absoluteString
    }
}

extension CDChainApi {
    var identifier: String {
        LocalChainExternalApi.createId(
            from: apiType!,
            serviceType: serviceType!,
            url: url!
        )
    }
}

struct LocalChainExternalApiSet: Codable, Equatable, Hashable {
    let apis: Set<LocalChainExternalApi>

    func getApis(for type: LocalChainApiExternalType) -> Set<LocalChainExternalApi>? {
        let targetApis = apis.filter { LocalChainApiExternalType(rawValue: $0.apiType) == type }
        return !targetApis.isEmpty ? Set(targetApis) : nil
    }

    func staking() -> Set<LocalChainExternalApi>? {
        getApis(for: .staking)
    }
    
    func stakingRewards() -> Set<LocalChainExternalApi>? {
        getApis(for: .stakingRewards)
    }

    func history() -> Set<LocalChainExternalApi>? {
        getApis(for: .history)
    }

    func crowdloans() -> Set<LocalChainExternalApi>? {
        getApis(for: .crowdloans)
    }

    func governance() -> Set<LocalChainExternalApi>? {
        getApis(for: .governance)
    }

    func governanceDelegations() -> Set<LocalChainExternalApi>? {
        getApis(for: .governanceDelegations)
    }

    func referendumSummary() -> Set<LocalChainExternalApi>? {
        getApis(for: .referendumSummary)
    }

    func multisig() -> Set<LocalChainExternalApi>? {
        getApis(for: .multisig)
    }

    init(localApis: Set<LocalChainExternalApi>) {
        apis = localApis
    }

    init(remoteApi: RemoteChainExternalApiSet) {
        apis = Set<LocalChainExternalApi>()
            .addingApis(from: remoteApi.staking, apiType: .staking)
            .addingApis(from: remoteApi.history, apiType: .history)
            .addingApis(from: remoteApi.crowdloans, apiType: .crowdloans)
            .addingApis(from: remoteApi.governance, apiType: .governance)
            .addingApis(from: remoteApi.goverananceDelegations, apiType: .governanceDelegations)
            .addingApis(from: remoteApi.referendumSummary, apiType: .referendumSummary)
            .addingApis(from: remoteApi.multisig, apiType: .multisig)
            .addingApis(from: remoteApi.stakingRewards, apiType: .stakingRewards)
    }
}

extension Set where Element == LocalChainExternalApi {
    func addingApis(from remoteApis: [RemoteChainExternalApi]?, apiType: LocalChainApiExternalType) -> Set<Element> {
        guard let remoteApis = remoteApis else {
            return self
        }

        let localApis = remoteApis.map {
            LocalChainExternalApi(
                apiType: apiType.rawValue,
                serviceType: $0.type,
                url: $0.url,
                parameters: $0.parameters
            )
        }

        return union(Set(localApis))
    }
}
