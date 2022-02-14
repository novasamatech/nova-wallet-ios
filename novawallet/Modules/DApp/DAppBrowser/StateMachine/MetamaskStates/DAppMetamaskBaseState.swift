import Foundation

class DAppMetamaskBaseState {
    weak var stateMachine: DAppMetamaskStateMachineProtocol?

    init(stateMachine: DAppMetamaskStateMachineProtocol?) {
        self.stateMachine = stateMachine
    }

    func provideResponseWithCommands(_ commands: [String], nextState: DAppMetamaskStateProtocol) {
        let content = commands.joined(separator: "")
        let response = DAppScriptResponse(content: content)

        stateMachine?.emit(response: response, nextState: nextState)
    }

    func provideResponse(
        for messageId: MetamaskMessage.Id,
        result: String,
        nextState: DAppMetamaskStateProtocol
    ) throws {
        let content = createResponseCommand(for: messageId, result: result)

        let response = DAppScriptResponse(content: content)

        stateMachine?.emit(response: response, nextState: nextState)
    }

    func createResponseCommand(
        for messageId: MetamaskMessage.Id,
        result: String
    ) -> String {
        String(
            format: "window.ethereum.sendResponse(%ld, \"%@\");", messageId, result
        )
    }

    func provideResponse(
        for messageId: MetamaskMessage.Id,
        results: [String],
        nextState: DAppMetamaskStateProtocol
    ) {
        let content = createResponseCommand(for: messageId, results: results)

        let response = DAppScriptResponse(content: content)

        stateMachine?.emit(response: response, nextState: nextState)
    }

    func createResponseCommand(
        for messageId: MetamaskMessage.Id,
        results: [String]
    ) -> String {
        let list = results.map { String(format: "\"%@\"", $0) }
        return String(
            format: "window.ethereum.sendResponse(%ld, [%@]);", messageId, list.joined(separator: ",")
        )
    }

    func provideError(
        for messageId: MetamaskMessage.Id,
        errorMessage: String,
        nextState: DAppMetamaskStateProtocol
    ) {
        let content = String(
            String(format: "window.ethereum.sendError(%ld, \"%@\")", messageId, errorMessage)
        )

        let response = DAppScriptResponse(content: content)

        stateMachine?.emit(response: response, nextState: nextState)
    }

    func provideNullResponse(to messageId: MetamaskMessage.Id, nextState: DAppMetamaskStateProtocol) {
        let content = createNullResponseCommand(for: messageId)

        let response = DAppScriptResponse(content: content)

        stateMachine?.emit(response: response, nextState: nextState)
    }

    func createNullResponseCommand(for messageId: MetamaskMessage.Id) -> String {
        String(format: "window.ethereum.sendNullResponse(%ld);", messageId)
    }

    func createSetAddressCommand(_ address: AccountAddress) -> String {
        String(format: "window.ethereum.setAddress(\"%@\");", address)
    }

    func createSetChainIdCommand(_ chainId: String) -> String {
        String(format: "window.ethereum.setChainId(\"%@\");", chainId)
    }

    func createSetRpcCommand(_ rpc: String) -> String {
        String(format: "window.ethereum.setRpcUrl(\"%@\");", rpc)
    }

    func createReloadCommand() -> String {
        "window.location.reload();"
    }

    func createEventCommand(_ event: MetamaskEvent) -> String {
        switch event {
        case let .chainChanged(chainId):
            return String(
                format: "window.ethereum.emit(\"chainChanged\", \"%@\");", chainId
            )
        case let .accountsChanged(addresses):
            let addressList = addresses.map { String(format: "\"%@\"", $0) }
            return String(
                format: "window.ethereum.emit(\"accountsChanged\", [%@]);", addressList.joined(separator: ",")
            )
        case let .connect(chainId):
            return String(
                format: "window.ethereum.emit(\"connect\", {chainId: \"%@\"});", chainId
            )
        }
    }
}
