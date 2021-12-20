import UIKit
import SubstrateSdk
import RobinHood

final class DAppOperationConfirmInteractor {
    weak var presenter: DAppOperationConfirmInteractorOutputProtocol?

    let request: DAppOperationRequest

    let connection: ChainConnection
    let signingWrapper: SigningWrapperProtocol
    let priceProviderFactory: PriceProviderFactoryProtocol
    let runtimeProvider: RuntimeProviderProtocol

    private var runtimeCall: RuntimeCall<JSON>?

    init(
        request: DAppOperationRequest,
        runtimeProvider: RuntimeProviderProtocol,
        connection: ChainConnection,
        signingWrapper: SigningWrapperProtocol,
        priceProviderFactory: PriceProviderFactoryProtocol
    ) {
        self.request = request
        self.runtimeProvider = runtimeProvider
        self.connection = connection
        self.signingWrapper = signingWrapper
        self.priceProviderFactory = priceProviderFactory
    }

    private func decodeCallAndContinueSetup(_ hexCall: String) {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let decodingOperation = ClosureOperation<RuntimeCall<JSON>> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let callData = try Data(hexString: hexCall)

            let runtimeContext = codingFactory.createRuntimeJsonContext()
            let decoder = try codingFactory.createDecoder(from: callData)

            return try decoder.read(of: KnownType.call.name, with: runtimeContext.toRawContext())
        }

        decodingOperation.addDependency(codingFactoryOperation)

        decodingOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let call = try decodingOperation.extractNoCancellableResultData()
                    self?.completeSetup(for: call)
                } catch {
                    self?.presenter?.didReceive(modelResult: .failure(error))
                }
            }
        }
    }

    private func completeSetup(for call: RuntimeCall<JSON>) {
        runtimeCall = call

        let confirmationModel = DAppOperationConfirmModel(
            wallet: request.wallet,
            chain: request.chain,
            dApp: request.dApp,
            module: call.moduleName,
            call: call.callName,
            amount: nil
        )

        presenter?.didReceive(modelResult: .success(confirmationModel))

        estimateFee()
    }
}

extension DAppOperationConfirmInteractor: DAppOperationConfirmInteractorInputProtocol {
    func setup() {
        do {
            let extrinsic = try request.operationData.map(to: PolkadotExtensionExtrinsic.self)
            decodeCallAndContinueSetup(extrinsic.method)
        } catch {
            presenter?.didReceive(modelResult: .failure(error))
        }
    }

    func estimateFee() {
        guard let call = runtimeCall else {
            return
        }
    }
}
