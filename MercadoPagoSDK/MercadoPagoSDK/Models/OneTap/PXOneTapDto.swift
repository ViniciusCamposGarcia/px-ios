//
//  PXOneTapDto.swift
//  MercadoPagoSDK
//
//  Created by Juan sebastian Sanzone on 23/10/18.
//

import Foundation

/// :nodoc:
open class PXOneTapDto: NSObject, Codable {
    open var paymentMethodId: String
    open var paymentTypeId: String?
    open var oneTapCard: PXOneTapCardDto?
    open var accountMoney: PXAccountMoneyDto?

    public init(paymentMethodId: String, paymentTypeId: String?, oneTapCard: PXOneTapCardDto?, accountMoney: PXAccountMoneyDto?) {
        self.paymentMethodId = paymentMethodId
        self.paymentTypeId = paymentTypeId
        self.oneTapCard = oneTapCard
        self.accountMoney = accountMoney
    }

    public enum PXOneTapDtoKeys: String, CodingKey {
        case paymentMethodId = "payment_method_id"
        case paymentTypeId = "payment_type_id"
        case oneTapCard = "card"
        case accountMoney = "account_money"
    }

    required public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: PXOneTapDtoKeys.self)
        let oneTapCard: PXOneTapCardDto? = try container.decodeIfPresent(PXOneTapCardDto.self, forKey: .oneTapCard)
        let paymentMethodId: String = try container.decode(String.self, forKey: .paymentMethodId)
        let paymentTypeId: String? = try container.decodeIfPresent(String.self, forKey: .paymentTypeId)
        let accountMoney: PXAccountMoneyDto? = try container.decodeIfPresent(PXAccountMoneyDto.self, forKey: .accountMoney)

        self.init(paymentMethodId: paymentMethodId, paymentTypeId: paymentTypeId, oneTapCard: oneTapCard, accountMoney: accountMoney)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: PXOneTapDtoKeys.self)
        try container.encodeIfPresent(self.oneTapCard, forKey: .oneTapCard)
        try container.encodeIfPresent(self.paymentMethodId, forKey: .paymentMethodId)
        try container.encodeIfPresent(self.paymentTypeId, forKey: .paymentTypeId)
        try container.encodeIfPresent(self.accountMoney, forKey: .accountMoney)
    }

    open func toJSONString() throws -> String? {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8)
    }

    open func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(self)
    }

    open class func fromJSON(data: Data) throws -> PXOneTapDto {
        return try JSONDecoder().decode(PXOneTapDto.self, from: data)
    }
}
extension PXOneTapDto {
    func getAccountMoneyForTracking() -> [String: Any] {
        var accountMoneyDic: [String: Any] = [:]
        accountMoneyDic["payment_method_type"] = paymentTypeId
        accountMoneyDic["payment_method_id"] = paymentMethodId
        var extraInfo: [String: Any] = [:]
        extraInfo["balance"] = accountMoney?.availableBalance
        extraInfo["invested"] = accountMoney?.invested
        accountMoneyDic["extra_info"] = extraInfo

        return accountMoneyDic
    }

    func getCardForTracking() -> [String: Any] {
        var savedCardDic: [String: Any] = [:]
        savedCardDic["payment_method_type"] = paymentTypeId
        savedCardDic["payment_method_id"] = paymentMethodId
        var extraInfo: [String: Any] = [:]
        extraInfo["card_id"] = oneTapCard?.cardId
        let cardIdsEsc = PXTrackingStore.sharedInstance.getData(forKey: PXTrackingStore.cardIdsESC) as? [String] ?? []
        extraInfo["has_esc"] = cardIdsEsc.contains(oneTapCard?.cardId ?? "")
        extraInfo["selected_installment"] = oneTapCard?.selectedPayerCost?.getPayerCostForTracking()
        if let issuerId = oneTapCard?.cardUI?.issuerId {
            extraInfo["issuer_id"] = Int(issuerId)
        }
        savedCardDic["extra_info"] = extraInfo
        return savedCardDic
    }
}
