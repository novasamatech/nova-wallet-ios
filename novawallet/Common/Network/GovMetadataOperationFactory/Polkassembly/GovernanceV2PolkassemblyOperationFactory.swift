import Foundation
import RobinHood
import SubstrateSdk

class GovernanceV2PolkassemblyOperationFactory: BasePolkassemblyOperationFactory {
    override func createPreviewQuery(for _: JSON?) -> String {
        """
        {
         posts(
             where: {type: {id: {_eq: 2}}, onchain_link: {onchain_referendumv2_id: {_is_null: false}}}
         ) {
             title
             onchain_link {
                onchain_referendumv2_id
             }
         }
        }
        """
    }

    override func createDetailsQuery(for referendumId: ReferendumIdLocal, parameters _: JSON?) -> String {
        """
        {
             posts(
                 where: {onchain_link: {onchain_referendumv2_id: {_eq: \(referendumId)}}}
             ) {
                 title
                 content
                 onchain_link {
                    onchain_referendumv2_id
                    proposer_address
                    onchain_referendumv2 {
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

                guard let referendumId = remotePreview.onchain_link?
                    .onchain_referendumv2_id?.unsignedIntValue else {
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

            guard let referendumId = onChainLink?.onchain_referendumv2_id?.unsignedIntValue else {
                return nil
            }

            let proposer = onChainLink?.proposer_address?.stringValue

            let remoteTimeline = onChainLink?.onchain_referendumv2?.arrayValue?.first?.referendumStatus?.arrayValue

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
