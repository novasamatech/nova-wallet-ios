import Foundation
import SubstrateSdk
import BigInt

enum AssetHubSwapRequestBuilderError: Error {
    case brokenAssetIn(ChainAssetId)
    case brokenAssetOut(ChainAssetId)
}

enum AssetHubSwapRequestSerializerError: Error {
    case undefinedAssetType
    case undefinedBalanceType
    case quoteCalcFailed
}

enum AssetHubSwapRequestSerializer {
    private static func extractAssetType(from codingFactory: RuntimeCoderFactoryProtocol) -> String? {
        guard
            let call = codingFactory.getCall(
                for: AssetConversionPallet.addLiquidityCallPath(for: AssetConversionPallet.name)
            ),
            !call.arguments.isEmpty else {
            return nil
        }

        return call.arguments[0].type
    }

    private static func extractBalanceType(from codingFactory: RuntimeCoderFactoryProtocol) -> String? {
        guard
            let call = codingFactory.getCall(
                for: AssetConversionPallet.addLiquidityCallPath(for: AssetConversionPallet.name)
            ),
            call.arguments.count > 2 else {
            return nil
        }

        return call.arguments[2].type
    }

    static func serialize(
        asset: AssetConversionPallet.AssetId,
        into encoder: inout DynamicScaleEncoding,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws {
        guard let assetType = extractAssetType(from: codingFactory) else {
            throw AssetHubSwapRequestSerializerError.undefinedAssetType
        }

        try encoder.append(asset, ofType: assetType, with: codingFactory.createRuntimeJsonContext().toRawContext())
    }

    static func serialize(
        amount: BigUInt,
        into encoder: inout DynamicScaleEncoding,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws {
        guard let balanceType = extractBalanceType(from: codingFactory) else {
            throw AssetHubSwapRequestSerializerError.undefinedBalanceType
        }

        try encoder.append(
            StringScaleMapper(value: amount),
            ofType: balanceType,
            with: codingFactory.createRuntimeJsonContext().toRawContext()
        )
    }

    static func deserialize(quoteResponse: String, codingFactory: RuntimeCoderFactoryProtocol) throws -> BigUInt {
        guard let balanceType = extractBalanceType(from: codingFactory) else {
            throw AssetHubSwapRequestSerializerError.undefinedBalanceType
        }

        let data = try Data(hexString: quoteResponse)

        let decoder = try codingFactory.createDecoder(from: data)

        let json: JSON = try decoder.readOption(type: balanceType)

        guard json != .null else {
            throw AssetHubSwapRequestSerializerError.quoteCalcFailed
        }

        return try json.map(
            to: StringScaleMapper<BigUInt>.self,
            with: codingFactory.createRuntimeJsonContext().toRawContext()
        ).value
    }
}

final class AssetHubSwapRequestBuilder {
    static let sellQuoteApi = "AssetConversionApi_quote_price_exact_tokens_for_tokens"
    static let buyQuoteApi = "AssetConversionApi_quote_price_tokens_for_exact_tokens"

    let chain: ChainModel

    init(chain: ChainModel) {
        self.chain = chain
    }

    private func createRequest(
        for chain: ChainModel,
        args: AssetConversion.Args,
        builtInFunction: String,
        codingClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        includesFee: Bool
    ) -> StateCallRpc.Request {
        StateCallRpc.Request(builtInFunction: builtInFunction) { container in
            let codingFactory = try codingClosure()

            guard
                let remoteAssetIn = AssetHubTokensConverter.converToMultilocation(
                    chainAssetId: args.assetIn,
                    chain: chain,
                    codingFactory: codingFactory
                ) else {
                throw AssetHubSwapRequestBuilderError.brokenAssetIn(args.assetIn)
            }

            guard
                let remoteAssetOut = AssetHubTokensConverter.converToMultilocation(
                    chainAssetId: args.assetOut,
                    chain: chain,
                    codingFactory: codingFactory
                ) else {
                throw AssetHubSwapRequestBuilderError.brokenAssetIn(args.assetOut)
            }

            var encoder = codingFactory.createEncoder()

            try AssetHubSwapRequestSerializer.serialize(
                asset: remoteAssetIn,
                into: &encoder,
                codingFactory: codingFactory
            )

            try AssetHubSwapRequestSerializer.serialize(
                asset: remoteAssetOut,
                into: &encoder,
                codingFactory: codingFactory
            )

            try AssetHubSwapRequestSerializer.serialize(
                amount: args.amount,
                into: &encoder,
                codingFactory: codingFactory
            )

            try encoder.appendBool(json: .boolValue(includesFee))

            let data = try encoder.encode()

            try container.encode(data.toHex(includePrefix: true))
        }
    }

    func build(
        args: AssetConversion.Args,
        codingClosure: @escaping () throws -> RuntimeCoderFactoryProtocol
    ) -> StateCallRpc.Request {
        let builtInFunction: String

        switch args.direction {
        case .sell:
            builtInFunction = Self.sellQuoteApi
        case .buy:
            builtInFunction = Self.buyQuoteApi
        }

        return createRequest(
            for: chain,
            args: args,
            builtInFunction: builtInFunction,
            codingClosure: codingClosure,
            includesFee: true
        )
    }
}
