import Foundation
import Foundation_iOS
import BigInt

final class ReferendumsModelFactory {
    typealias Params = ReferendumsModelFactoryParams
    typealias Strings = R.string.localizable

    struct StatusParams {
        let referendum: ReferendumLocal
        let metadata: ReferendumMetadataLocal?
        let chainInfo: Params.ChainInformation
        let onchainVotes: ReferendumAccountVoteLocal?
        let offchainVotes: GovernanceOffchainVotesLocal.Single?
    }

    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let localizedPercentFormatter: LocalizableResource<NumberFormatter>
    let localizedIndexFormatter: LocalizableResource<NumberFormatter>
    let localizedQuantityFormatter: LocalizableResource<NumberFormatter>
    let statusViewModelFactory: ReferendumStatusViewModelFactoryProtocol
    let referendumMetadataViewModelFactory: ReferendumMetadataViewModelFactoryProtocol
    let stringDisplayViewModelFactory: ReferendumDisplayStringFactoryProtocol

    init(
        referendumMetadataViewModelFactory: ReferendumMetadataViewModelFactoryProtocol,
        statusViewModelFactory: ReferendumStatusViewModelFactoryProtocol,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        stringDisplayViewModelFactory: ReferendumDisplayStringFactoryProtocol,
        percentFormatter: LocalizableResource<NumberFormatter>,
        indexFormatter: LocalizableResource<NumberFormatter>,
        quantityFormatter: LocalizableResource<NumberFormatter>
    ) {
        self.referendumMetadataViewModelFactory = referendumMetadataViewModelFactory
        self.statusViewModelFactory = statusViewModelFactory
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
        self.stringDisplayViewModelFactory = stringDisplayViewModelFactory
        localizedPercentFormatter = percentFormatter
        localizedIndexFormatter = indexFormatter
        localizedQuantityFormatter = quantityFormatter
    }

    func createTrackViewModel(
        from track: GovernanceTrackLocal,
        params: StatusParams,
        locale: Locale
    ) -> ReferendumInfoView.Track? {
        // display track name if more than 1 track in the network
        guard track.totalTracksCount > 1 else {
            return nil
        }

        return ReferendumTrackType.createViewModel(from: track.name, chain: params.chainInfo.chain, locale: locale)
    }
}
