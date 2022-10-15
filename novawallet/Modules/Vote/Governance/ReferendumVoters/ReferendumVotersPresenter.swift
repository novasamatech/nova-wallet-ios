import Foundation
import SoraFoundation
import BigInt

final class ReferendumVotersPresenter {
    weak var view: ReferendumVotersViewProtocol?
    let wireframe: ReferendumVotersWireframeProtocol
    let interactor: ReferendumVotersInteractorInputProtocol
    let stringFactory: ReferendumDisplayStringFactoryProtocol

    let referendum: ReferendumLocal
    let chain: ChainModel
    let type: ReferendumVotersType
    let logger: LoggerProtocol

    private var model: ReferendumVotersModel?

    private lazy var displayAddressFactory = DisplayAddressViewModelFactory()

    init(
        interactor: ReferendumVotersInteractorInputProtocol,
        wireframe: ReferendumVotersWireframeProtocol,
        type: ReferendumVotersType,
        referendum: ReferendumLocal,
        chain: ChainModel,
        stringFactory: ReferendumDisplayStringFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.type = type
        self.referendum = referendum
        self.stringFactory = stringFactory
        self.chain = chain
        self.logger = logger

        self.localizationManager = localizationManager
    }

    private func updateView() {
        guard let model = model else {
            return
        }

        let viewModels: [ReferendumVotersViewModel] = model.voters.filter { voter in
            switch type {
            case .ayes:
                return voter.vote.ayes > 0
            case .nays:
                return voter.vote.nays > 0
            }
        }.compactMap { voter in
            guard let address = try? voter.accountId.toAddress(using: chain.chainFormat) else {
                return nil
            }

            let displayAddressViewModel: DisplayAddressViewModel

            if let displayName = model.identites[address]?.displayName {
                let displayAddress = DisplayAddress(address: address, username: displayName)
                displayAddressViewModel = displayAddressFactory.createViewModel(from: displayAddress)
            } else {
                displayAddressViewModel = displayAddressFactory.createViewModel(from: address)
            }

            let amountInPlank: BigUInt
            let votes: BigUInt

            switch type {
            case .ayes:
                amountInPlank = voter.vote.ayeBalance
                votes = voter.vote.ayes
            case .nays:
                amountInPlank = voter.vote.nayBalance
                votes = voter.vote.nays
            }

            let votesString = stringFactory.createVotes(from: votes, chain: chain, locale: selectedLocale)
            let details = stringFactory.createVotesDetails(
                from: amountInPlank,
                conviction: voter.vote.conviction,
                chain: chain,
                locale: selectedLocale
            )

            return ReferendumVotersViewModel(
                displayAddress: displayAddressViewModel,
                votes: votesString ?? "",
                preConviction: details ?? ""
            )
        }

        view?.didReceiveViewModels(.loaded(value: viewModels))
    }
}

extension ReferendumVotersPresenter: ReferendumVotersPresenterProtocol {
    func setup() {
        view?.didReceiveViewModels(.loading)

        interactor.setup()
    }

    func selectVoter(at _: Int) {}
}

extension ReferendumVotersPresenter: ReferendumVotersInteractorOutputProtocol {
    func didReceiveVoters(_ voters: ReferendumVotersModel) {
        model = voters

        updateView()
    }

    func didReceiveError(_ error: ReferendumVotersInteractorError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .votersFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.updateView()
            }
        }
    }
}

extension ReferendumVotersPresenter: Localizable {
    func applyLocalization() {
        updateView()
    }
}
