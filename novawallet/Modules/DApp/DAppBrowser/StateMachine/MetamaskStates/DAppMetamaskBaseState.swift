import Foundation

class DAppMetamaskBaseState {
    weak var stateMachine: DAppMetamaskStateMachineProtocol?
    let chain: MetamaskChain

    init(stateMachine: DAppMetamaskStateMachineProtocol?, chain: MetamaskChain) {
        self.stateMachine = stateMachine
        self.chain = chain
    }

    func switchChain(
        from message: MetamaskMessage,
        nextStateSuccessClosure: (MetamaskChain) -> DAppMetamaskStateProtocol,
        nextStateFailureClosure: (MetamaskError) -> DAppMetamaskStateProtocol
    ) {
        guard let request = try? message.object?.map(to: MetamaskSwitchChain.self) else {
            let error = MetamaskError.invalidParams(with: "can't parse chain")
            let nextState = nextStateFailureClosure(error)
            provideError(for: message.identifier, error: error, nextState: nextState)
            return
        }

        guard request.chainId != chain.chainId else {
            let nextState = nextStateSuccessClosure(chain)
            provideNullResponse(to: message.identifier, nextState: nextState)
            return
        }

        let ethereumChain = MetamaskChain.etheremChain

        if request.chainId == ethereumChain.chainId {
            let changeChainCommands = createChangeChainCommands(
                for: ethereumChain.chainId,
                rpcUrl: ethereumChain.rpcUrls.first
            )

            let responseCommand = createNullResponseCommand(for: message.identifier)

            let content = createContentWithCommands(changeChainCommands + [responseCommand])

            let response = DAppScriptResponse(content: content)

            let nextState = nextStateSuccessClosure(ethereumChain)
            stateMachine?.emitReload(with: response, nextState: nextState)
        } else {
            let error = MetamaskError.noChainSwitch

            let nextState = nextStateFailureClosure(error)
            provideError(for: message.identifier, error: error, nextState: nextState)
        }
    }

    func addChain(
        from message: MetamaskMessage,
        nextStateSuccessClosure: (MetamaskChain) -> DAppMetamaskStateProtocol,
        nextStateFailureClosure: (MetamaskError) -> DAppMetamaskStateProtocol
    ) {
        guard let newChain = try? message.object?.map(to: MetamaskChain.self) else {
            let error = MetamaskError.invalidParams(with: "can't parse chain")

            let nextState = nextStateFailureClosure(error)
            provideError(for: message.identifier, error: error, nextState: nextState)
            return
        }

        if newChain.chainId != chain.chainId {
            let changeChainCommands = createChangeChainCommands(
                for: newChain.chainId,
                rpcUrl: newChain.rpcUrls.first
            )

            let responseCommand = createNullResponseCommand(for: message.identifier)

            let content = createContentWithCommands(changeChainCommands + [responseCommand])

            let response = DAppScriptResponse(content: content)

            let nextState = nextStateSuccessClosure(newChain)
            stateMachine?.emitReload(with: response, nextState: nextState)
        } else {
            let nextState = nextStateSuccessClosure(chain)
            provideNullResponse(to: message.identifier, nextState: nextState)
        }
    }

    func createContentWithCommands(_ commands: [String]) -> String {
        commands.joined(separator: "")
    }

    func provideResponseWithCommands(_ commands: [String], nextState: DAppMetamaskStateProtocol) {
        let content = createContentWithCommands(commands)
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
        error: MetamaskError,
        nextState: DAppMetamaskStateProtocol
    ) {
        let content = String(
            String(
                format: "window.ethereum.sendRpcError(%ld, %d, \"%@\")",
                messageId,
                error.code,
                error.message
            )
        )

        let response = DAppScriptResponse(content: content)

        stateMachine?.emit(response: response, nextState: nextState)
    }

    func provideNullResponse(to messageId: MetamaskMessage.Id, nextState: DAppMetamaskStateProtocol) {
        let content = createNullResponseCommand(for: messageId)

        let response = DAppScriptResponse(content: content)

        stateMachine?.emit(response: response, nextState: nextState)
    }

    func createChangeChainCommands(for chainId: String, rpcUrl: String?) -> [String] {
        var commands = [createSetChainIdCommand(chainId)]

        if let rpcUrl = rpcUrl {
            commands.append(createSetRpcCommand(rpcUrl))
            commands.append(createEventCommand(.connect(chainId: chainId)))
        }

        commands.append(createEventCommand(.chainChanged(chainId: chainId)))

        return commands
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
