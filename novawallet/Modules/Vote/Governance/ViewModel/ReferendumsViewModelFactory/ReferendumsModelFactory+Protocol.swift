import Foundation
import BigInt
import SoraFoundation

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
        var sections: [ReferendumsSection] = []

        let referendumsCellViewModels = createReferendumsCellViewModels(input: input)
        if !referendumsCellViewModels.active.isEmpty || referendumsCellViewModels.completed.isEmpty {
            // still add empty section to display empty state
            let title = Strings.governanceReferendumsActive(preferredLanguages: input.locale.rLanguages)
            sections.append(.active(.loaded(value: title), referendumsCellViewModels.active))
        }
        if !referendumsCellViewModels.completed.isEmpty {
            let title = Strings.commonCompleted(preferredLanguages: input.locale.rLanguages)
            sections.append(.completed(.loaded(value: title), referendumsCellViewModels.completed))
        }
        return sections
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
            let statusName = Strings.governanceReferendumsStatusRejected(preferredLanguages: locale.rLanguages)
            status = .init(name: statusName.uppercased(), kind: .negative)
        case .cancelled:
            let statusName = Strings.governanceReferendumsStatusCancelled(preferredLanguages: locale.rLanguages)
            status = .init(name: statusName.uppercased(), kind: .neutral)
        case .timedOut:
            let statusName = Strings.governanceReferendumsStatusTimedOut(preferredLanguages: locale.rLanguages)
            status = .init(name: statusName.uppercased(), kind: .neutral)
        case .killed:
            let statusName = Strings.governanceReferendumsStatusKilled(preferredLanguages: locale.rLanguages)
            status = .init(name: statusName.uppercased(), kind: .negative)
        case .executed:
            let statusName = Strings.governanceReferendumsStatusExecuted(preferredLanguages: locale.rLanguages)
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
