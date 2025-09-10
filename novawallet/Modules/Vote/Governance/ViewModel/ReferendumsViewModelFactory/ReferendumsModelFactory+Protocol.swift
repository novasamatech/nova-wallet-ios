import Foundation
import BigInt
import Foundation_iOS

struct ReferendumsModelFactoryInput {
    let referendums: [ReferendumLocal]
    let metadataMapping: [ReferendumIdLocal: ReferendumMetadataLocal]?
    let votes: [ReferendumIdLocal: ReferendumAccountVoteLocal]
    let offchainVotes: GovernanceOffchainVotesLocal?
    let chainInfo: ChainInformation
    let locale: Locale
    let voterName: String?

    struct ChainInformation {
        let chain: ChainModel
        let currentBlock: BlockNumber
        let blockDuration: UInt64
    }
}

struct ReferendumsModelFactoryDetailsInput {
    let referendum: ReferendumLocal
    let metadata: ReferendumMetadataLocal?
    let onchainVotes: ReferendumAccountVoteLocal?
    let offchainVotes: GovernanceOffchainVotesLocal.Single?
    let chainInfo: ReferendumsModelFactoryInput.ChainInformation
    let selectedLocale: Locale
}

protocol ReferendumsModelFactoryProtocol {
    func createSections(input: ReferendumsModelFactoryInput) -> [ReferendumsSection]

    func createViewModel(input: ReferendumsModelFactoryDetailsInput) -> ReferendumView.Model

    func createLoadingViewModel() -> [ReferendumsSection]

    func filteredSections(
        _ sections: [ReferendumsSection],
        filter: (ReferendumsCellViewModel) -> Bool
    ) -> [ReferendumsSection]
}

protocol SearchReferendumsModelFactoryProtocol {
    func createReferendumsViewModel(input: ReferendumsModelFactoryInput) -> [ReferendumsCellViewModel]
}

extension ReferendumsModelFactory: ReferendumsModelFactoryProtocol {
    func createLoadingViewModel() -> [ReferendumsSection] {
        let cells: [ReferendumsCellViewModel] = (0 ..< 10).map {
            ReferendumsCellViewModel(
                referendumIndex: UInt($0),
                viewModel: .loading
            )
        }
        return [ReferendumsSection.active(.loading, cells)]
    }

    func createSections(input: ReferendumsModelFactoryInput) -> [ReferendumsSection] {
        let referendumsCellViewModels = createReferendumsCellViewModels(input: input)

        if referendumsCellViewModels.active.isEmpty, referendumsCellViewModels.completed.isEmpty {
            return [.empty(.referendumsNotFound)]
        }

        var sections: [ReferendumsSection] = []

        if !referendumsCellViewModels.active.isEmpty {
            let title = R.string(
                preferredLanguages: input.locale.rLanguages
            ).localizable.governanceReferendumsActive()
            sections.append(.active(.loaded(value: title), referendumsCellViewModels.active))
        }
        if !referendumsCellViewModels.completed.isEmpty {
            let title = R.string(
                preferredLanguages: input.locale.rLanguages
            ).localizable.commonCompleted()
            sections.append(.completed(.loaded(value: title), referendumsCellViewModels.completed))
        }

        return sections
    }

    func filteredSections(
        _ sections: [ReferendumsSection],
        filter: (ReferendumsCellViewModel) -> Bool
    ) -> [ReferendumsSection] {
        let filteredReferendumsSections = sections.map { section in
            let referendumViewModels = ReferendumsSection.Lens.referendums.get(section)
            let filteredViewModels = referendumViewModels.filter(filter)
            return ReferendumsSection.Lens.referendums.set(filteredViewModels, section)
        }.filter { !ReferendumsSection.Lens.referendums.get($0).isEmpty }

        return filteredReferendumsSections.isEmpty ? [.empty(.filteredListEmpty)] : filteredReferendumsSections
    }

    private func createReferendumsCellViewModels(input: ReferendumsModelFactoryInput) ->
        (active: [ReferendumsCellViewModel], completed: [ReferendumsCellViewModel]) {
        var active: [ReferendumsCellViewModel] = []
        var completed: [ReferendumsCellViewModel] = []

        input.referendums.forEach { referendum in
            let metadata = input.metadataMapping?[referendum.index]

            let params = StatusParams(
                referendum: referendum,
                metadata: metadata,
                chainInfo: input.chainInfo,
                onchainVotes: input.votes[referendum.index],
                offchainVotes: input.offchainVotes?.fetchVotes(for: referendum.index)
            )

            let model = createReferendumCellViewModel(
                state: referendum.state,
                params: params,
                voterName: input.voterName,
                locale: input.locale
            )

            let viewModel = ReferendumsCellViewModel(
                referendumIndex: referendum.index,
                viewModel: .loaded(value: model)
            )

            referendum.state.completed ? completed.append(viewModel) : active.append(viewModel)
        }
        return (active: active, completed: completed)
    }

    func createViewModel(input: ReferendumsModelFactoryDetailsInput) -> ReferendumView.Model {
        let params = StatusParams(
            referendum: input.referendum,
            metadata: input.metadata,
            chainInfo: input.chainInfo,
            onchainVotes: input.onchainVotes,
            offchainVotes: input.offchainVotes
        )

        return createReferendumCellViewModel(
            state: input.referendum.state,
            params: params,
            voterName: nil,
            locale: input.selectedLocale
        )
    }

    private func createReferendumCellViewModel(
        state: ReferendumStateLocal,
        params: StatusParams,
        voterName: String?,
        locale: Locale
    ) -> ReferendumView.Model {
        let status: ReferendumInfoView.Status
        switch state {
        case let .preparing(model):
            return providePreparingReferendumCellViewModel(
                model,
                params: params,
                voterName: voterName,
                locale: locale
            )
        case let .deciding(model):
            return provideDecidingReferendumCellViewModel(
                model,
                params: params,
                voterName: voterName,
                locale: locale
            )
        case .approved:
            return provideApprovedReferendumCellViewModel(params: params, voterName: voterName, locale: locale)
        case .rejected:
            let statusName = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.governanceReferendumsStatusRejected()
            status = .init(name: statusName.uppercased(), kind: .negative)
        case .cancelled:
            let statusName = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.governanceReferendumsStatusCancelled()
            status = .init(name: statusName.uppercased(), kind: .neutral)
        case .timedOut:
            let statusName = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.governanceReferendumsStatusTimedOut()
            status = .init(name: statusName.uppercased(), kind: .neutral)
        case .killed:
            let statusName = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.governanceReferendumsStatusKilled()
            status = .init(name: statusName.uppercased(), kind: .negative)
        case .executed:
            let statusName = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.governanceReferendumsStatusExecuted()
            status = .init(name: statusName.uppercased(), kind: .positive)
        }

        return provideCommonReferendumCellViewModel(
            status: status,
            params: params,
            voterName: voterName,
            locale: locale
        )
    }
}

extension ReferendumsModelFactory: DelegateReferendumsModelFactoryProtocol, SearchReferendumsModelFactoryProtocol {
    func createReferendumsViewModel(input: ReferendumsModelFactoryInput) -> [ReferendumsCellViewModel] {
        let (active, completed) = createReferendumsCellViewModels(input: input)
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
