import Foundation
import Foundation_iOS
import BigInt

final class ReferendumVotersPresenter {
    weak var view: VotesViewProtocol?
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

    private func createViewModel(
        _ model: ReferendumVotersModel,
        voter: ReferendumVoterLocal
    ) -> VotesViewModel? {
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
        case .abstains:
            amountInPlank = voter.vote.abstainBalance
            votes = voter.vote.abstains
        }

        let votesString = stringFactory.createVotes(from: votes, chain: chain, locale: selectedLocale)
        let details = stringFactory.createVotesDetails(
            from: amountInPlank,
            conviction: voter.vote.conviction,
            chain: chain,
            locale: selectedLocale
        )

        return VotesViewModel(
            displayAddress: displayAddressViewModel,
            votes: votesString ?? "",
            votesDetails: details ?? ""
        )
    }

    private func updateView() {
        guard let model = model else {
            return
        }

        let viewModels: [VotesViewModel] = model.voters.filter { voter in
            switch type {
            case .ayes:
                return voter.vote.hasAyeVotes
            case .nays:
                return voter.vote.hasNayVotes
            case .abstains:
                return voter.vote.hasAbstainVotes
            }
        }
        .sorted {
            switch type {
            case .ayes:
                return $0.vote.ayes > $1.vote.ayes
            case .nays:
                return $0.vote.nays > $1.vote.nays
            case .abstains:
                return $0.vote.abstains > $1.vote.abstains
            }
        }
        .compactMap { voter in
            createViewModel(model, voter: voter)
        }

        view?.didReceiveViewModels(.loaded(value: viewModels))
    }

    private var title: LocalizableResource<String> {
        switch type {
        case .ayes:
            return LocalizableResource { locale in
                R.string.localizable.govVotersAye(preferredLanguages: locale.rLanguages)
            }

        case .nays:
            return LocalizableResource { locale in
                R.string.localizable.govVotersNay(preferredLanguages: locale.rLanguages)
            }
        case .abstains:
            return LocalizableResource { locale in
                R.string.localizable.govVotersAbstain(preferredLanguages: locale.rLanguages)
            }
        }
    }

    private var emptyViewTitle: LocalizableResource<String> {
        LocalizableResource { locale in
            R.string.localizable.govVotersEmpty(preferredLanguages: locale.rLanguages)
        }
    }
}

extension ReferendumVotersPresenter: VotesPresenterProtocol {
    func setup() {
        view?.didReceiveViewModels(.loading)
        view?.didReceive(title: title)
        view?.didReceiveEmptyView(title: emptyViewTitle)
        interactor.setup()
    }

    func select(viewModel: VotesViewModel) {
        guard let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: viewModel.displayAddress.address,
            chain: chain,
            locale: selectedLocale
        )
    }
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
                self?.interactor.refreshVoters()
            }
        }
    }
}

extension ReferendumVotersPresenter: Localizable {
    func applyLocalization() {
        updateView()
    }
}
