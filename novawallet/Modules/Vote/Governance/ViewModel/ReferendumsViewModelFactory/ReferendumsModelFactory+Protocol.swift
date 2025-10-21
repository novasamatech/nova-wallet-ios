import Foundation
import BigInt
import Foundation_iOS

struct ReferendumsModelFactoryParams {
    let referendums: [ReferendumLocal]
    let metadataMapping: [ReferendumIdLocal: ReferendumMetadataLocal]?
    let votes: [ReferendumIdLocal: ReferendumAccountVoteLocal]
    let offchainVotes: GovernanceOffchainVotesLocal?
    let chainInfo: ChainInformation
    let voterName: String?

    struct ChainInformation {
        let chain: ChainModel
        let currentBlock: BlockNumber
        let blockDuration: UInt64
    }
}

struct ReferendumsModelFactoryDetailsParams {
    let referendum: ReferendumLocal
    let metadata: ReferendumMetadataLocal?
    let onchainVotes: ReferendumAccountVoteLocal?
    let offchainVotes: GovernanceOffchainVotesLocal.Single?
    let chainInfo: ReferendumsModelFactoryParams.ChainInformation
}

protocol ReferendumsModelFactoryProtocol {
    func createSections(
        params: ReferendumsModelFactoryParams,
        genericParams: ViewModelFactoryGenericParams
    ) -> [ReferendumsSection]

    func createViewModel(
        params: ReferendumsModelFactoryDetailsParams,
        genericParams: ViewModelFactoryGenericParams
    ) -> ReferendumView.Model

    func createLoadingViewModel(genericParams: ViewModelFactoryGenericParams) -> [ReferendumsSection]

    func filteredSections(
        _ sections: [ReferendumsSection],
        filter: (SecuredViewModel<ReferendumsCellViewModel>) -> Bool
    ) -> [ReferendumsSection]
}

protocol SearchReferendumsModelFactoryProtocol {
    func createReferendumsViewModel(
        params: ReferendumsModelFactoryParams,
        genericParams: ViewModelFactoryGenericParams
    ) -> [ReferendumsCellViewModel]
}

extension ReferendumsModelFactory: ReferendumsModelFactoryProtocol {
    func createLoadingViewModel(genericParams: ViewModelFactoryGenericParams) -> [ReferendumsSection] {
        let cells: [ReferendumsCellViewModel] = (0 ..< 10).map {
            ReferendumsCellViewModel(
                referendumIndex: UInt($0),
                viewModel: .loading
            )
        }

        let viewModel = ReferendumsCellsSectionViewModel(
            titleText: .loading,
            countText: .wrapped("\(cells.count)", with: genericParams.privacyModeEnabled),
            cells: cells.map { .wrapped($0, with: genericParams.privacyModeEnabled) }
        )

        return [.active(viewModel)]
    }

    func createSections(
        params: ReferendumsModelFactoryParams,
        genericParams: ViewModelFactoryGenericParams
    ) -> [ReferendumsSection] {
        let languages = genericParams.locale.rLanguages

        let referendumsCellViewModels = createReferendumsCellViewModels(
            params: params,
            genericParams: genericParams
        )

        let secureCellModels: (
            active: [SecuredViewModel<ReferendumsCellViewModel>],
            completed: [SecuredViewModel<ReferendumsCellViewModel>]
        ) = (
            active: referendumsCellViewModels.active.map { .wrapped($0, with: genericParams.privacyModeEnabled) },
            completed: referendumsCellViewModels.completed.map { .wrapped($0, with: genericParams.privacyModeEnabled) }
        )

        if secureCellModels.active.isEmpty, secureCellModels.completed.isEmpty {
            return [.empty(.referendumsNotFound)]
        }

        var sections: [ReferendumsSection] = []

        if !secureCellModels.active.isEmpty {
            let title = R.string(
                preferredLanguages: languages
            ).localizable.governanceReferendumsActive()
            let countText = "\(secureCellModels.active.count)"
            let viewModel = ReferendumsCellsSectionViewModel(
                titleText: .loaded(value: title),
                countText: .wrapped(countText, with: genericParams.privacyModeEnabled),
                cells: secureCellModels.active
            )
            sections.append(.active(viewModel))
        }
        if !secureCellModels.completed.isEmpty {
            let title = R.string(
                preferredLanguages: languages
            ).localizable.commonCompleted()
            let countText = "\(secureCellModels.completed.count)"
            let viewModel = ReferendumsCellsSectionViewModel(
                titleText: .loaded(value: title),
                countText: .wrapped(countText, with: genericParams.privacyModeEnabled),
                cells: secureCellModels.completed
            )
            sections.append(.completed(viewModel))
        }

        return sections
    }

    func filteredSections(
        _ sections: [ReferendumsSection],
        filter: (SecuredViewModel<ReferendumsCellViewModel>) -> Bool
    ) -> [ReferendumsSection] {
        let filteredReferendumsSections = sections.map { section in
            let referendumViewModels = ReferendumsSection.Lens.referendums.get(section)
            let filteredViewModels = referendumViewModels.filter(filter)
            return ReferendumsSection.Lens.referendums.set(filteredViewModels, section)
        }.filter { !ReferendumsSection.Lens.referendums.get($0).isEmpty }

        return filteredReferendumsSections.isEmpty ? [.empty(.filteredListEmpty)] : filteredReferendumsSections
    }

    private func createReferendumsCellViewModels(
        params: ReferendumsModelFactoryParams,
        genericParams: ViewModelFactoryGenericParams
    ) -> (active: [ReferendumsCellViewModel], completed: [ReferendumsCellViewModel]) {
        var active: [ReferendumsCellViewModel] = []
        var completed: [ReferendumsCellViewModel] = []

        params.referendums.forEach { referendum in
            let metadata = params.metadataMapping?[referendum.index]

            let statusParams = StatusParams(
                referendum: referendum,
                metadata: metadata,
                chainInfo: params.chainInfo,
                onchainVotes: params.votes[referendum.index],
                offchainVotes: params.offchainVotes?.fetchVotes(for: referendum.index)
            )

            let model = createReferendumCellViewModel(
                state: referendum.state,
                voterName: params.voterName,
                params: statusParams,
                genericParams: genericParams
            )

            let viewModel = ReferendumsCellViewModel(
                referendumIndex: referendum.index,
                viewModel: .loaded(value: model)
            )

            referendum.state.completed ? completed.append(viewModel) : active.append(viewModel)
        }
        return (active: active, completed: completed)
    }

    func createViewModel(
        params: ReferendumsModelFactoryDetailsParams,
        genericParams: ViewModelFactoryGenericParams
    ) -> ReferendumView.Model {
        let params = StatusParams(
            referendum: params.referendum,
            metadata: params.metadata,
            chainInfo: params.chainInfo,
            onchainVotes: params.onchainVotes,
            offchainVotes: params.offchainVotes
        )

        return createReferendumCellViewModel(
            state: params.referendum.state,
            voterName: nil,
            params: params,
            genericParams: genericParams
        )
    }

    private func createReferendumCellViewModel(
        state: ReferendumStateLocal,
        voterName: String?,
        params: StatusParams,
        genericParams: ViewModelFactoryGenericParams
    ) -> ReferendumView.Model {
        let languages = genericParams.locale.rLanguages

        let status: ReferendumInfoView.Status
        switch state {
        case let .preparing(model):
            return providePreparingReferendumCellViewModel(
                model,
                params: params,
                voterName: voterName,
                locale: genericParams.locale
            )
        case let .deciding(model):
            return provideDecidingReferendumCellViewModel(
                model,
                params: params,
                voterName: voterName,
                locale: genericParams.locale
            )
        case .approved:
            return provideApprovedReferendumCellViewModel(
                params: params,
                voterName: voterName,
                locale: genericParams.locale
            )
        case .rejected:
            let statusName = R.string(
                preferredLanguages: languages
            ).localizable.governanceReferendumsStatusRejected()
            status = .init(name: statusName.uppercased(), kind: .negative)
        case .cancelled:
            let statusName = R.string(
                preferredLanguages: languages
            ).localizable.governanceReferendumsStatusCancelled()
            status = .init(name: statusName.uppercased(), kind: .neutral)
        case .timedOut:
            let statusName = R.string(
                preferredLanguages: languages
            ).localizable.governanceReferendumsStatusTimedOut()
            status = .init(name: statusName.uppercased(), kind: .neutral)
        case .killed:
            let statusName = R.string(
                preferredLanguages: languages
            ).localizable.governanceReferendumsStatusKilled()
            status = .init(name: statusName.uppercased(), kind: .negative)
        case .executed:
            let statusName = R.string(
                preferredLanguages: languages
            ).localizable.governanceReferendumsStatusExecuted()
            status = .init(name: statusName.uppercased(), kind: .positive)
        }

        return provideCommonReferendumCellViewModel(
            status: status,
            params: params,
            voterName: voterName,
            locale: genericParams.locale
        )
    }
}

extension ReferendumsModelFactory: DelegateReferendumsModelFactoryProtocol, SearchReferendumsModelFactoryProtocol {
    func createReferendumsViewModel(
        params: ReferendumsModelFactoryParams,
        genericParams: ViewModelFactoryGenericParams
    ) -> [ReferendumsCellViewModel] {
        let (active, completed) = createReferendumsCellViewModels(
            params: params,
            genericParams: genericParams
        )
        return active + completed
    }

    func createLoadingViewModel() -> [ReferendumsCellViewModel] {
        let cells: [ReferendumsCellViewModel] = (0 ..< 10).map {
            ReferendumsCellViewModel(
                referendumIndex: UInt($0),
                viewModel: .loading
            )
        }
        return cells
    }
}
