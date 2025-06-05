import Foundation
import SubstrateSdk
import web3swift
import Core

final class MoonbeamEvmMintedEventMatcher: TokenDepositEventMatching {
    let logger: LoggerProtocol
    let contractAccountId: AccountId

    init(contractAccountId: AccountId, logger: LoggerProtocol) {
        self.contractAccountId = contractAccountId
        self.logger = logger
    }

    func matchDeposit(
        event: Event,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) -> TokenDepositEvent? {
        do {
            guard codingFactory.metadata.eventMatches(event, path: MoonbeamEvmPallet.logEventPath) else {
                return nil
            }

            logger.debug("Moonbean evm log event detected")

            let mintedEvent = try event.params.map(
                to: MoonbeamEvmPallet.LogEvent.self,
                with: codingFactory.createRuntimeJsonContext().toRawContext()
            )

            logger.debug("Moonbean evm log event parsed")

            let eventLog = mintedEvent.log

            let topics = eventLog.topics.map(\.wrappedValue)

            guard contractAccountId == eventLog.address else {
                return nil
            }

            let erc20Abi = try EthereumContract(Web3.Utils.erc20ABI)

            guard let event = erc20Abi.events[ERC20TransferEvent.name] else {
                return nil
            }

            guard let dict = ABIDecoder.decodeLog(
                event: event,
                eventLogTopics: topics,
                eventLogData: eventLog.data
            ) else {
                return nil
            }

            logger.debug("Moonbeam minted event \(dict)")

            guard
                let sender = dict["_from"] as? EthereumAddress,
                sender.addressData == ChainModel.getEvmNullAccountId(),
                let receiver = dict["_to"] as? EthereumAddress,
                let amount = dict["_value"] as? Balance else {
                return nil
            }

            logger.debug("Moonbeam mint event detected")

            return TokenDepositEvent(accountId: receiver.addressData, amount: amount)
        } catch {
            logger.error("Parsing failed: \(error)")

            return nil
        }
    }
}
