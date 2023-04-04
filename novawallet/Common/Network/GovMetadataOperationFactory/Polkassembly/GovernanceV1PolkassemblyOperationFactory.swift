import Foundation
import RobinHood
import SubstrateSdk

final class GovernanceV1PolkassemblyOperationFactory: BasePolkassemblyOperationFactory {
    private func createPreviewConditions(for parameters: JSON?) -> String {
        if let network = parameters?.network?.stringValue {
            return """
                {
                    type: {id: {_eq: 2}},
                    network: {_eq: \(network)},
                    onchain_link: {onchain_network_referendum_id: {_is_null: false}}
                }
            """
        } else {
            return "{type: {id: {_eq: 2}}, onchain_link: {onchain_referendum_id: {_is_null: false}}}"
        }
    }

    override func createPreviewQuery(for parameters: JSON?) -> String {
        let whereCondition = createPreviewConditions(for: parameters)
        return """
        {
         posts(
             where: \(whereCondition)
         ) {
             title
             onchain_link {
                onchain_referendum {
                    referendumId
                }
             }
         }
        }
        """
    }

    private func createDetailsConditions(for referendumId: ReferendumIdLocal, parameters: JSON?) -> String {
        if let network = parameters?.network?.stringValue {
            return "{onchain_link: {onchain_network_referendum_id: {_eq: \(network)_\(referendumId)}}}"
        } else {
            return "{onchain_link: {onchain_referendum_id: {_eq: \(referendumId)}}}"
        }
    }

    override func createDetailsQuery(for referendumId: ReferendumIdLocal, parameters: JSON?) -> String {
        let whereCondition = createDetailsConditions(for: referendumId, parameters: parameters)
        return """
        {
             posts(
                 where: \(whereCondition)
             ) {
                 title
                 content
                 onchain_link {
                      proposer_address
                    onchain_referendum {
                      referendumId
                      referendumStatus {
                        blockNumber {
                          startDateTime
                        }
                        status
                      }
                    }
                 }
             }
        }
        """
    }

    override func createPreviewResultFactory(
        for chainId: ChainModel.Id
    ) -> AnyNetworkResultFactory<[ReferendumMetadataPreview]> {
        AnyNetworkResultFactory<[ReferendumMetadataPreview]> { data in
            let resultData = try JSONDecoder().decode(JSON.self, from: data)
            let nodes = resultData.data?.posts?.arrayValue ?? []

            return nodes.compactMap { remotePreview in
                let title = remotePreview.title?.stringValue

                let onChainLink = remotePreview.onchain_link
                let optOnchainReferendum = onChainLink?.onchain_referendum?.arrayValue?.first

                guard let referendumId = optOnchainReferendum?.referendumId?.unsignedIntValue else {
                    return nil
                }

                return .init(
                    chainId: chainId,
                    referendumId: ReferendumIdLocal(referendumId),
                    title: title
                )
            }
        }
    }

    override func createDetailsResultFactory(
        for chainId: ChainModel.Id
    ) -> AnyNetworkResultFactory<ReferendumMetadataLocal?> {
        AnyNetworkResultFactory<ReferendumMetadataLocal?> { data in
            let resultData = try JSONDecoder().decode(JSON.self, from: data)
            guard let remoteDetails = resultData.data?.posts?.arrayValue?.first else {
                return nil
            }

            let title = remoteDetails.title?.stringValue
            let content = remoteDetails.content?.stringValue
            let onChainLink = remoteDetails.onchain_link

            let optOnchainReferendum = onChainLink?.onchain_referendum?.arrayValue?.first

            guard let referendumId = optOnchainReferendum?.referendumId?.unsignedIntValue else {
                return nil
            }

            let proposer = onChainLink?.proposer_address?.stringValue

            let remoteTimeline = optOnchainReferendum?.referendumStatus?.arrayValue

            let timeline: [ReferendumMetadataLocal.TimelineItem]?
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            timeline = remoteTimeline?.compactMap { item in
                guard
                    let timeString = item.blockNumber?.startDateTime?.stringValue,
                    let time = isoFormatter.date(from: timeString),
                    let status = item.status?.stringValue else {
                    return nil
                }

                return .init(time: time, status: status)
            }

            return .init(
                chainId: chainId,
                referendumId: ReferendumIdLocal(referendumId),
                title: title,
                content: content,
                proposer: proposer,
                timeline: timeline
            )
        }
    }
}
