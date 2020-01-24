//
//  ApiUtil.swift
//  MercadoPagoSDK
//
//  Created by Mauro Reverter on 6/14/17.
//  Copyright © 2017 MercadoPago. All rights reserved.
//

import Foundation

internal class ApiUtil {
    enum StatusCodes: Int {
        case INTERNAL_SERVER_ERROR = 500
        case PROCESSING = 499
        case BAD_REQUEST = 400
        case NOT_FOUND = 404
        case OK = 200
    }
    enum ErrorCauseCodes: String {
        case INVALID_IDENTIFICATION_NUMBER = "324"
        case INVALID_ESC = "E216"
        case INVALID_FINGERPRINT = "E217"
        case INVALID_PAYMENT_WITH_ESC = "2107"
        case INVALID_PAYMENT_IDENTIFICATION_NUMBER = "2067"
    }

    enum RequestOrigin: String {
        case GET_PREFERENCE
        case GET_INIT
        case GET_INSTALLMENTS
        case GET_ISSUERS
        case GET_DIRECT_DISCOUNT
        case CREATE_PAYMENT
        case CREATE_TOKEN
        case GET_CUSTOMER
        case GET_CODE_DISCOUNT
        case GET_CAMPAIGNS
        case GET_PAYMENT_METHODS
        case GET_IDENTIFICATION_TYPES
        case GET_BANK_DEALS
        case GET_INSTRUCTIONS
        case ASSOCIATE_TOKEN
    }
}

/**
Advanced configuration provides you support for custom checkout functionality/configure special behaviour when checkout is running.
*/
@objcMembers
open class PXAdvancedConfiguration: NSObject {
	
	internal var productId: String?
	
	// MARK: Public accessors.
	/**
	Advanced UI color customization. Use this config to create your custom UI colors based on PXTheme protocol. Also you can use this protocol to customize your fonts.
	*/
	open var theme: PXTheme?
	
	/**
	Add the possibility to configure ESC behaviour.
	If set as true, then saved cards will try to use ESC feature.
	If set as false, then security code will be always asked.
	*/
	open var escEnabled: Bool = false
	
	/**
	Add the possibility to enabled/disabled express checkout.
	*/
	open var expressEnabled: Bool = false
	
	/**
	Instores usage / money in usage. - Use case: Not all bank deals apply right now to all preferences.
	*/
	open var bankDealsEnabled: Bool = true
	
	/**
	Loyalty usage. - Use case: Show/hide bottom amount row.
	*/
	open var amountRowEnabled: Bool = true
	
	/**
	Enable to preset configurations to customize visualization on the 'Review and Confirm screen'
	*/
	open var reviewConfirmConfiguration: PXReviewConfirmConfiguration = PXReviewConfirmConfiguration()
	
	/**
	Enable to preset configurations to customize visualization on the 'Congrats' screen / 'PaymentResult' screen.
	*/
	open var paymentResultConfiguration: PXPaymentResultConfiguration = PXPaymentResultConfiguration()
	
	/**
	Add dynamic custom views on 'Review and Confirm screen'.
	*/
	open var reviewConfirmDynamicViewsConfiguration: PXReviewConfirmDynamicViewsConfiguration?
	
	/**
	Add dynamic view controllers to flow.
	*/
	open var dynamicViewControllersConfiguration: [PXDynamicViewControllerProtocol] = []
	
	/**
	Set additional data to get discounts
	*/
	open var discountParamsConfiguration: PXDiscountParamsConfiguration? {
		didSet {
			productId = discountParamsConfiguration?.productId
		}
	}
	
	/**
	Set product id
	*/
	open func setProductId(id: String) {
		self.productId = id
	}
}

internal typealias PXDiscountConfigurationType = (discount: PXDiscount?, campaign: PXCampaign?, isNotAvailable: Bool)

/**
Configuration related to Mercadopago discounts and campaigns. More details: `PXDiscount` and `PXCampaign`.
*/
@objcMembers
open class PXDiscountConfiguration: NSObject, Codable {
	private var discount: PXDiscount?
	private var campaign: PXCampaign?
	private var isNotAvailable: Bool = false
	
	internal override init() {
		self.discount = nil
		self.campaign = nil
		isNotAvailable = true
	}
	
	/**
	Set Mercado Pago discount that will be applied to total amount.
	When you set a discount with its campaign, we do not check in discount service.
	You have to set a payment processor for discount be applied.
	- parameter discount: Mercado Pago discount.
	- parameter campaign: Discount campaign with discount data.
	*/
	public init(discount: PXDiscount, campaign: PXCampaign) {
		self.discount = discount
		self.campaign = campaign
	}
	
	internal init(discount: PXDiscount?, campaign: PXCampaign?, isNotAvailable: Bool) {
		self.discount = discount
		self.campaign = campaign
		self.isNotAvailable = isNotAvailable
	}
	
	public enum PXDiscountConfigurationKeys: String, CodingKey {
		case discount
		case campaign
		case isAvailable =  "is_available"
	}
	
	required public convenience init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: PXDiscountConfigurationKeys.self)
		let discount: PXDiscount? = try container.decodeIfPresent(PXDiscount.self, forKey: .discount)
		let campaign: PXCampaign? = try container.decodeIfPresent(PXCampaign.self, forKey: .campaign)
		let isAvailable: Bool = try container.decode(Bool.self, forKey: .isAvailable)
		self.init(discount: discount, campaign: campaign, isNotAvailable: !isAvailable)
	}
	
	/**
	When you have the user have wasted all the discounts available
	this kind of configuration will show a generic message to the user.
	*/
	public static func initForNotAvailableDiscount() -> PXDiscountConfiguration {
		return PXDiscountConfiguration()
	}
}

// MARK: - Internals
extension PXDiscountConfiguration {
	internal func getDiscountConfiguration() -> PXDiscountConfigurationType {
		return (discount, campaign, isNotAvailable)
	}
}

@objcMembers
open class PXDiscountParamsConfiguration: NSObject, Codable {
	let labels: [String]
	let productId: String
	
	/**
	Set additional data needed to apply a specific discount.
	- parameter labels: Additional data needed to apply a specific discount.
	- parameter productId: Let us to enable discounts for the product id specified.
	*/
	public init(labels: [String], productId: String) {
		self.labels = labels
		self.productId = productId
	}
	
	public enum PXDiscountParamsConfigCodingKeys: String, CodingKey {
		case labels
		case productId = "product_id"
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: PXDiscountParamsConfigCodingKeys.self)
		try container.encodeIfPresent(self.labels, forKey: .labels)
		try container.encodeIfPresent(self.productId, forKey: .productId)
	}
}

@objc public enum PXDynamicViewControllerPosition: Int {
	case DID_ENTER_REVIEW_AND_CONFIRM
	case DID_TAP_ONETAP_HEADER
}

@objc public protocol PXDynamicViewControllerProtocol: NSObjectProtocol {
	@objc func viewController(store: PXCheckoutStore) -> UIViewController?
	@objc func position(store: PXCheckoutStore) -> PXDynamicViewControllerPosition
	@objc optional func navigationHandler(navigationHandler: PXPluginNavigationHandler)
}

internal typealias PXPaymentConfigurationType = (chargeRules: [PXPaymentTypeChargeRule]?, paymentPlugin: PXSplitPaymentProcessor)

/**
Any configuration related to the Payment. You can set you own `PXPaymentProcessor`. Configuration of discounts, charges and custom Payment Method Plugin.
*/
@objcMembers
open class PXPaymentConfiguration: NSObject {
	private let splitPaymentProcessor: PXSplitPaymentProcessor
	private var chargeRules: [PXPaymentTypeChargeRule] = [PXPaymentTypeChargeRule]()
	private var paymentMethodPlugins: [PXPaymentMethodPlugin] = [PXPaymentMethodPlugin]()
	
	// MARK: Init.
	/**
	Builder for `PXPaymentConfiguration` construction.
	- parameter paymentProcessor: Your custom implementation of `PXPaymentProcessor`.
	*/
	public init(paymentProcessor: PXPaymentProcessor) {
		self.splitPaymentProcessor = PXPaymentProcessorAdapter(paymentProcessor: paymentProcessor)
	}
	
	public init(splitPaymentProcessor: PXSplitPaymentProcessor) {
		self.splitPaymentProcessor = splitPaymentProcessor
	}
}

// MARK: - Builder
extension PXPaymentConfiguration {
	/**
	Add your own payment method option to pay.
	- parameter plugin: Your custom payment method plugin.
	*/
	@available(*, deprecated: 4.5.0, message: "Payment method plugins is no longer available.")
	/// :nodoc
	open func addPaymentMethodPlugin(plugin: PXPaymentMethodPlugin) -> PXPaymentConfiguration {
		return self
	}
	
	/**
	Add extra charges that will apply to total amount.
	- parameter charges: the list (array) of charges that could apply.
	*/
	open func addChargeRules(charges: [PXPaymentTypeChargeRule]) -> PXPaymentConfiguration {
		self.chargeRules.append(contentsOf: charges)
		return self
	}
	
	/**
	`PXDiscountConfiguration` is an object that represents the discount to be applied or error information to present to the user. It's mandatory to handle your discounts by hand if you set a payment processor.
	- parameter config: Your custom discount configuration
	*/
	@available(*, deprecated)
	open func setDiscountConfiguration(config: PXDiscountConfiguration) -> PXPaymentConfiguration {
		return self
	}
}

// MARK: - Internals
extension PXPaymentConfiguration {
	internal func getPaymentConfiguration() -> PXPaymentConfigurationType {
		return (chargeRules, splitPaymentProcessor)
	}
}

/**
This object declares custom preferences (customizations) for "Congrats" screen.
*/
@objcMembers open class PXPaymentResultConfiguration: NSObject {
	// V4 final.
	private var topCustomView: UIView?
	private var bottomCustomView: UIView?
	
	/// :nodoc:
	override init() {}
	
	// MARK: Init.
	/**
	Define your custom UIViews. `topView` and `bottomView` of the screen.
	- parameter topView: Optional custom top view.
	- parameter bottomView: Optional custom bottom view.
	*/
	public init(topView: UIView?  = nil, bottomView: UIView? = nil) {
		self.topCustomView = topView
		self.bottomCustomView = bottomView
	}
	
	// To deprecate post v4. SP integration.
	@available(*, deprecated)
	/// :nodoc:
	public enum ApprovedBadge {
		case pending
		case check
	}
	
	// To deprecate post v4. SP integration.
	private static let PENDING_CONTENT_TITLE = "¿Qué puedo hacer?"
	private static let REJECTED_CONTENT_TITLE = "¿Qué puedo hacer?"
	
	// MARK: FOOTER
	// To deprecate post v4. SP integration.
	internal var approvedSecondaryExitButtonText = ""
	internal var approvedSecondaryExitButtonCallback: ((PaymentResult) -> Void)?
	internal var hidePendingSecondaryButton = false
	internal var pendingSecondaryExitButtonText: String?
	internal var pendingSecondaryExitButtonCallback: ((PaymentResult) -> Void)?
	internal var hideRejectedSecondaryButton = false
	internal var rejectedSecondaryExitButtonText: String?
	internal var rejectedSecondaryExitButtonCallback: ((PaymentResult) -> Void)?
	internal var exitButtonTitle: String?
	
	// MARK: Approved
	// To deprecate post v4. SP integration.
	/// :nodoc:
	@available(*, deprecated)
	open var approvedBadge: ApprovedBadge? = ApprovedBadge.check
	private var _approvedLabelText = ""
	private var _disableApprovedLabelText = true
	internal lazy var approvedTitle = PXHeaderResutlConstants.APPROVED_HEADER_TITLE.localized
	internal var approvedSubtitle = ""
	internal var approvedURLImage: String?
	internal var approvedIconName = "default_item_icon"
	internal var approvedIconBundle = ResourceManager.shared.getBundle()!
	
	// MARK: Pending
	// To deprecate post v4. SP integration.
	private var _pendingLabelText = ""
	private var _disablePendingLabelText = true
	internal lazy var pendingTitle = PXHeaderResutlConstants.PENDING_HEADER_TITLE.localized
	internal var pendingSubtitle = ""
	internal lazy var pendingContentTitle = PXPaymentResultConfiguration.PENDING_CONTENT_TITLE.localized
	internal var pendingContentText = ""
	internal var pendingIconName = "default_item_icon"
	internal var pendingIconBundle = ResourceManager.shared.getBundle()!
	internal var pendingURLImage: String?
	internal var hidePendingContentText = false
	internal var hidePendingContentTitle = false
	
	// MARK: Rejected
	// To deprecate post v4. SP integration.
	private var disableRejectedLabelText = false
	internal lazy var rejectedTitle = PXHeaderResutlConstants.REJECTED_HEADER_TITLE.localized
	internal var rejectedSubtitle = ""
	internal var rejectedTitleSetted = false
	internal lazy var rejectedIconSubtext = PXHeaderResutlConstants.REJECTED_ICON_SUBTEXT.localized
	internal var rejectedBolbradescoIconName = "MPSDK_payment_result_bolbradesco_error"
	internal var rejectedPaymentMethodPluginIconName = "MPSDK_payment_result_plugin_error"
	internal var rejectedIconBundle = ResourceManager.shared.getBundle()!
	internal var rejectedDefaultIconName: String?
	internal var rejectedURLImage: String?
	internal var rejectedIconName: String?
	internal lazy var rejectedContentTitle = PXPaymentResultConfiguration.REJECTED_CONTENT_TITLE.localized
	internal var rejectedContentText = ""
	internal var hideRejectedContentText = false
	internal var hideRejectedContentTitle = false
	
	// MARK: Commons
	// To deprecate post v4. SP integration.
	internal var showBadgeImage = true
	internal var showLabelText = true
	internal var pmDefaultIconName = "card_icon"
	internal var pmBolbradescoIconName = "boleto_icon"
	internal var pmIconBundle = ResourceManager.shared.getBundle()!
	internal var statusBackgroundColor: UIColor?
	internal var hideApprovedPaymentBodyCell = false
	internal var hideContentCell = false
	internal var hideAmount = false
	internal var hidePaymentId = false
	internal var hidePaymentMethod = false
}

// MARK: - Internal Getters.
extension PXPaymentResultConfiguration {
	internal func getTopCustomView() -> UIView? {
		return topCustomView
	}
	
	internal func getBottomCustomView() -> UIView? {
		return bottomCustomView
	}
}

// MARK: To deprecate post v4. SP integration.
/** :nodoc: */
extension PXPaymentResultConfiguration {
	@available(*, deprecated)
	open func shouldShowBadgeImage() {
		self.showBadgeImage = true
	}
	
	@available(*, deprecated)
	open func hideBadgeImage() {
		self.showBadgeImage = false
	}
	
	@available(*, deprecated)
	open func shouldShowLabelText() {
		self.showLabelText = true
	}
	
	@available(*, deprecated)
	open func hideLabelText() {
		self.showLabelText = false
	}
	
	@available(*, deprecated)
	open func getApprovedBadgeImage() -> UIImage? {
		guard let badge = approvedBadge else {
			return nil
		}
		if badge == ApprovedBadge.check {
			return ResourceManager.shared.getImage("ok_badge")
		} else if badge == ApprovedBadge.pending {
			return ResourceManager.shared.getImage("pending_badge")
		}
		return nil
	}
	
	@available(*, deprecated)
	open func disableApprovedLabelText() {
		self._disableApprovedLabelText = true
	}
	
	@available(*, deprecated)
	open func setApproved(labelText: String) {
		self._disableApprovedLabelText = false
		self._approvedLabelText = labelText
	}
	
	@available(*, deprecated)
	open func getApprovedLabelText() -> String? {
		if self._disableApprovedLabelText {
			return nil
		} else {
			return self._approvedLabelText
		}
	}
	
	@available(*, deprecated)
	open func setBadgeApproved(badge: ApprovedBadge) {
		self.approvedBadge = badge
	}
	
	@available(*, deprecated)
	open func setApproved(title: String) {
		self.approvedTitle = title
	}
	
	@available(*, deprecated)
	open func setApprovedSubtitle(subtitle: String) {
		self.approvedSubtitle = subtitle
	}
	
	@available(*, deprecated)
	open func setApprovedHeaderIcon(name: String, bundle: Bundle) {
		self.approvedIconName = name
		self.approvedIconBundle = bundle
	}
	
	@available(*, deprecated)
	open func setApprovedHeaderIcon(stringURL: String) {
		self.approvedURLImage = stringURL
	}
	
	@available(*, deprecated)
	open func disablePendingLabelText() {
		self._disablePendingLabelText = true
	}
	
	@available(*, deprecated)
	open func setPending(labelText: String) {
		self._disablePendingLabelText = false
		self._pendingLabelText = labelText
	}
	
	@available(*, deprecated)
	open func getPendingLabelText() -> String? {
		if self._disablePendingLabelText {
			return nil
		} else {
			return self._pendingLabelText
		}
	}
	
	@available(*, deprecated)
	open func setPending(title: String) {
		self.pendingTitle = title
	}
	
	@available(*, deprecated)
	open func setPendingSubtitle(subtitle: String) {
		self.pendingSubtitle = subtitle
	}
	
	@available(*, deprecated)
	open func setPendingHeaderIcon(name: String, bundle: Bundle) {
		self.pendingIconName = name
		self.pendingIconBundle = bundle
	}
	
	@available(*, deprecated)
	open func setPendingHeaderIcon(stringURL: String) {
		self.pendingURLImage = stringURL
	}
	
	@available(*, deprecated)
	open func setPendingContentText(text: String) {
		self.pendingContentText = text
	}
	
	@available(*, deprecated)
	open func setPendingContentTitle(title: String) {
		self.pendingContentTitle = title
	}
	
	@available(*, deprecated)
	open func disablePendingSecondaryExitButton() {
		self.hidePendingSecondaryButton = true
	}
	
	@available(*, deprecated)
	open func disablePendingContentText() {
		self.hidePendingContentText = true
	}
	
	@available(*, deprecated)
	open func disablePendingContentTitle() {
		self.hidePendingContentTitle = true
	}
	
	@available(*, deprecated)
	open func setRejected(title: String) {
		self.rejectedTitle = title
		self.rejectedTitleSetted = true
	}
	
	@available(*, deprecated)
	open func setRejectedSubtitle(subtitle: String) {
		self.rejectedSubtitle = subtitle
	}
	
	@available(*, deprecated)
	open func setRejectedHeaderIcon(name: String, bundle: Bundle) {
		self.rejectedIconName = name
		self.rejectedIconBundle = bundle
	}
	
	@available(*, deprecated)
	open func setRejectedHeaderIcon(stringURL: String) {
		self.rejectedURLImage = stringURL
	}
	
	@available(*, deprecated)
	open func setRejectedContentText(text: String) {
		self.rejectedContentText = text
	}
	
	@available(*, deprecated)
	open func setRejectedContentTitle(title: String) {
		self.rejectedContentTitle = title
	}
	
	@available(*, deprecated)
	open func disableRejectedLabel() {
		self.disableRejectedLabelText = true
	}
	
	@available(*, deprecated)
	open func setRejectedIconSubtext(text: String) {
		self.rejectedIconSubtext = text
		if text.count == 0 {
			self.disableRejectedLabelText = true
		}
	}
	
	@available(*, deprecated)
	open func disableRejectdSecondaryExitButton() {
		self.hideRejectedSecondaryButton = true
	}
	
	@available(*, deprecated)
	open func disableRejectedContentText() {
		self.hideRejectedContentText = true
	}
	
	@available(*, deprecated)
	open func disableRejectedContentTitle() {
		self.hideRejectedContentTitle = true
	}
	
	@available(*, deprecated)
	open func setExitButtonTitle(title: String) {
		self.exitButtonTitle = title
	}
	
	@available(*, deprecated)
	open func setStatusBackgroundColor(color: UIColor) {
		self.statusBackgroundColor = color
	}
	
	@available(*, deprecated)
	open func getStatusBackgroundColor() -> UIColor? {
		return statusBackgroundColor
	}
	
	@available(*, deprecated)
	open func disableContentCell() {
		self.hideContentCell = true
	}
	
	@available(*, deprecated)
	open func disableApprovedBodyCell() {
		self.hideApprovedPaymentBodyCell = true
	}
	
	@available(*, deprecated)
	open func disableApprovedAmount() {
		self.hideAmount = true
	}
	
	@available(*, deprecated)
	open func disableApprovedReceipt() {
		self.hidePaymentId = true
	}
	
	@available(*, deprecated)
	open func disableApprovedPaymentMethodInfo() {
		self.hidePaymentMethod = true
	}
	
	@available(*, deprecated)
	open func enableAmount() {
		self.hideAmount = false
	}
	
	@available(*, deprecated)
	open func enableApprovedReceipt() {
		self.hidePaymentId = true
	}
	
	@available(*, deprecated)
	open func enableContnentCell() {
		self.hideContentCell = false
	}
	
	@available(*, deprecated)
	open func enableApprovedPaymentBodyCell() {
		self.hideApprovedPaymentBodyCell = false
	}
	
	@available(*, deprecated)
	open func enablePaymentContentText() {
		self.hidePendingContentText = false
	}
	
	@available(*, deprecated)
	open func enablePaymentContentTitle() {
		self.hidePendingContentTitle = false
	}
	
	@available(*, deprecated)
	open func enableApprovedPaymentMethodInfo() {
		self.hidePaymentMethod = false
	}
	
	@available(*, deprecated)
	open func getApprovedTitle() -> String {
		return approvedTitle
	}
	
	@available(*, deprecated)
	open func getApprovedSubtitle() -> String {
		return approvedSubtitle
	}
	
	@available(*, deprecated)
	open func getApprovedSecondaryButtonText() -> String {
		return approvedSecondaryExitButtonText
	}
	
	@available(*, deprecated)
	open func getHeaderApprovedIcon() -> UIImage? {
		if let urlImage = approvedURLImage {
			if let image = ViewUtils.loadImageFromUrl(urlImage) {
				return image
			}
		}
		return ResourceManager.shared.getImage(approvedIconName)
	}
	
	@available(*, deprecated)
	open func getPendingTitle() -> String {
		return pendingTitle
	}
	
	@available(*, deprecated)
	open func getPendingSubtitle() -> String {
		return pendingSubtitle
	}
	
	@available(*, deprecated)
	open func getHeaderPendingIcon() -> UIImage? {
		if let urlImage = self.pendingURLImage {
			if let image = ViewUtils.loadImageFromUrl(urlImage) {
				return image
			}
		}
		return ResourceManager.shared.getImage(pendingIconName)
	}
	
	@available(*, deprecated)
	open func getPendingContetTitle() -> String {
		return pendingContentTitle
	}
	
	@available(*, deprecated)
	open func getPendingContentText() -> String {
		return pendingContentText
	}
	
	@available(*, deprecated)
	open func getPendingSecondaryButtonText() -> String? {
		return pendingSecondaryExitButtonText
	}
	
	@available(*, deprecated)
	open func isPendingSecondaryExitButtonDisable() -> Bool {
		return hidePendingSecondaryButton
	}
	
	@available(*, deprecated)
	open func isPendingContentTextDisable() -> Bool {
		return hidePendingContentText
	}
	
	@available(*, deprecated)
	open func isPendingContentTitleDisable() -> Bool {
		return hidePendingContentTitle
	}
	
	@available(*, deprecated)
	open func getRejectedTitle() -> String {
		return rejectedTitle
	}
	
	@available(*, deprecated)
	open func getRejectedSubtitle() -> String {
		return rejectedSubtitle
	}
	
	@available(*, deprecated)
	open func setHeaderRejectedIcon(name: String, bundle: Bundle) {
		self.rejectedDefaultIconName = name
		self.approvedIconBundle = bundle
	}
	
	@available(*, deprecated)
	open func getHeaderRejectedIcon(_ paymentMethod: PXPaymentMethod?) -> UIImage? {
		if let urlImage = self.rejectedURLImage {
			if let image = ViewUtils.loadImageFromUrl(urlImage) {
				return image
			}
		}
		if rejectedIconName != nil {
			return ResourceManager.shared.getImage(rejectedIconName)
		}
		return getHeaderImageFor(paymentMethod)
	}
	
	@available(*, deprecated)
	open func getHeaderImageFor(_ paymentMethod: PXPaymentMethod?) -> UIImage? {
		guard let paymentMethod = paymentMethod else {
			return ResourceManager.shared.getImage(pmDefaultIconName)
		}
		
		if paymentMethod.isBolbradesco {
			return ResourceManager.shared.getImage(pmBolbradescoIconName)
		}
		
		if paymentMethod.paymentTypeId == PXPaymentTypes.PAYMENT_METHOD_PLUGIN.rawValue {
			return ResourceManager.shared.getImage(rejectedPaymentMethodPluginIconName)
		}
		return ResourceManager.shared.getImage(pmDefaultIconName)
	}
	
	@available(*, deprecated)
	open func getRejectedContetTitle() -> String {
		return rejectedContentTitle
	}
	
	@available(*, deprecated)
	open func getRejectedContentText() -> String {
		return rejectedContentText
	}
	
	@available(*, deprecated)
	open func getRejectedIconSubtext() -> String {
		return rejectedIconSubtext
	}
	
	@available(*, deprecated)
	open func getRejectedSecondaryButtonText() -> String? {
		return rejectedSecondaryExitButtonText
	}
	
	@available(*, deprecated)
	open func isRejectedSecondaryExitButtonDisable() -> Bool {
		return hideRejectedSecondaryButton
	}
	
	@available(*, deprecated)
	open func isRejectedContentTextDisable() -> Bool {
		return hideRejectedContentText
	}
	
	@available(*, deprecated)
	open func isRejectedContentTitleDisable() -> Bool {
		return hideRejectedContentTitle
	}
	
	@available(*, deprecated)
	open func getExitButtonTitle() -> String? {
		if let title = exitButtonTitle {
			return title.localized
		}
		return nil
	}
	
	@available(*, deprecated)
	open func isContentCellDisable() -> Bool {
		return hideContentCell
	}
	
	@available(*, deprecated)
	open func isApprovedPaymentBodyDisableCell() -> Bool {
		return hideApprovedPaymentBodyCell
	}
	
	@available(*, deprecated)
	open func isPaymentMethodDisable() -> Bool {
		return hidePaymentMethod
	}
	
	@available(*, deprecated)
	open func isAmountDisable() -> Bool {
		return hideAmount
	}
	
	@available(*, deprecated)
	open func isPaymentIdDisable() -> Bool {
		return hidePaymentId
	}
}


/**
This object declares custom preferences (customizations) for "Review and Confirm" screen.
*/
@objcMembers open class PXReviewConfirmConfiguration: NSObject {
	private static let DEFAULT_AMOUNT_TITLE = "Precio Unitario: ".localized
	private static let DEFAULT_QUANTITY_TITLE = "Cantidad: ".localized
	
	private var itemsEnabled: Bool = true
	private var topCustomView: UIView?
	private var bottomCustomView: UIView?
	
	// For only 1 PM Scenario. (Internal)
	private var changePaymentMethodsEnabled: Bool = true
	
	/// :nodoc:
	override init() {}
	
	// MARK: Init.
	/**
	- parameter itemsEnabled: Determinate if items view should be display or not.
	- parameter topView: Optional custom top view.
	- parameter bottomView: Optional custom bottom view.
	*/
	public init(itemsEnabled: Bool, topView: UIView? = nil, bottomView: UIView? = nil) {
		self.itemsEnabled = itemsEnabled
		self.topCustomView = topView
		self.bottomCustomView = bottomView
	}
	
	// MARK: To deprecate post v4. SP integration.
	internal var summaryTitles: [SummaryType: String] {
		get {
			return [SummaryType.PRODUCT: "Producto".localized,
					SummaryType.ARREARS: "Mora".localized,
					SummaryType.CHARGE: "Cargos".localized,
					SummaryType.DISCOUNT: String(format: "discount".localized, 2),
					SummaryType.TAXES: "Impuestos".localized,
					SummaryType.SHIPPING: "Envío".localized]
		}
	}
	
	internal var details: [SummaryType: SummaryDetail] = [SummaryType: SummaryDetail]()
}

// MARK: - Internal Getters.
extension PXReviewConfirmConfiguration {
	internal func hasItemsEnabled() -> Bool {
		return itemsEnabled
	}
	
	internal func getTopCustomView() -> UIView? {
		return self.topCustomView
	}
	
	internal func getBottomCustomView() -> UIView? {
		return self.bottomCustomView
	}
}

/** :nodoc: */
// Payment method.
// MARK: To deprecate post v4. SP integration.
internal extension PXReviewConfirmConfiguration {
	func isChangeMethodOptionEnabled() -> Bool {
		return changePaymentMethodsEnabled
	}
	
	func disableChangeMethodOption() {
		changePaymentMethodsEnabled = false
	}
}

/** :nodoc: */
// Amount.
// MARK: To deprecate post v4. SP integration.
internal extension PXReviewConfirmConfiguration {
	func shouldShowAmountTitle() -> Bool {
		return true
	}
	
	func getAmountTitle() -> String {
		return PXReviewConfirmConfiguration.DEFAULT_AMOUNT_TITLE
	}
}

/** :nodoc: */
// Collector icon.
// MARK: To deprecate post v4. SP integration.
internal extension PXReviewConfirmConfiguration {
	func getCollectorIcon() -> UIImage? {
		return nil
	}
}

/** :nodoc: */
// Quantity row.
// MARK: To deprecate post v4. SP integration.
internal extension PXReviewConfirmConfiguration {
	func shouldShowQuantityRow() -> Bool {
		return true
	}
	
	func getQuantityLabel() -> String {
		return PXReviewConfirmConfiguration.DEFAULT_QUANTITY_TITLE
	}
}

/** :nodoc: */
// Disclaimer text.
// MARK: To deprecate post v4. SP integration.
internal extension PXReviewConfirmConfiguration {
	func getDisclaimerText() -> String? {
		return nil
	}
	
	func getDisclaimerTextColor() -> UIColor {
		return ThemeManager.shared.noTaxAndDiscountLabelTintColor()
	}
}

/** :nodoc: */
// Summary.
// MARK: To deprecate post v4. SP integration.
internal extension PXReviewConfirmConfiguration {
	// Not in Android.
	func addSummaryProductDetail(amount: Double) {
		self.addDetail(detail: SummaryItemDetail(amount: amount), type: SummaryType.PRODUCT)
	}
	
	func addSummaryDiscountDetail(amount: Double) {
		self.addDetail(detail: SummaryItemDetail(amount: amount), type: SummaryType.DISCOUNT)
	}
	
	func addSummaryTaxesDetail(amount: Double) {
		self.addDetail(detail: SummaryItemDetail(amount: amount), type: SummaryType.TAXES)
	}
	
	func addSummaryShippingDetail(amount: Double) {
		self.addDetail(detail: SummaryItemDetail(amount: amount), type: SummaryType.SHIPPING)
	}
	
	func addSummaryArrearsDetail(amount: Double) {
		self.addDetail(detail: SummaryItemDetail(amount: amount), type: SummaryType.ARREARS)
	}
	
	func setSummaryProductTitle(productTitle: String) {
		self.updateTitle(type: SummaryType.PRODUCT, title: productTitle)
	}
	
	private func updateTitle(type: SummaryType, title: String) {
		if self.details[type] != nil {
			self.details[type]?.title = title
		} else {
			self.details[type] = SummaryDetail(title: title, detail: nil)
		}
		if type == SummaryType.DISCOUNT {
			self.details[type]?.titleColor = UIColor.mpGreenishTeal()
			self.details[type]?.amountColor = UIColor.mpGreenishTeal()
		}
	}
	
	private func getOneWordDescription(oneWordDescription: String) -> String {
		if oneWordDescription.count <= 0 {
			return ""
		}
		if let firstWord = oneWordDescription.components(separatedBy: " ").first {
			return firstWord
		} else {
			return oneWordDescription
		}
	}
	
	private func addDetail(detail: SummaryItemDetail, type: SummaryType) {
		if self.details[type] != nil {
			self.details[type]?.details.append(detail)
		} else {
			guard let title = self.summaryTitles[type] else {
				self.details[type] = SummaryDetail(title: "", detail: detail)
				return
			}
			self.details[type] = SummaryDetail(title: title, detail: detail)
		}
		if type == SummaryType.DISCOUNT {
			self.details[type]?.titleColor = UIColor.mpGreenishTeal()
			self.details[type]?.amountColor = UIColor.mpGreenishTeal()
		}
	}
	
	func getSummaryTotalAmount() -> Double {
		var totalAmount = 0.0
		guard let productDetail = details[SummaryType.PRODUCT] else {
			return 0.0
		}
		if productDetail.getTotalAmount() <= 0 {
			return 0.0
		}
		for summaryType in details.keys {
			if let detailAmount = details[summaryType]?.getTotalAmount() {
				if summaryType == SummaryType.DISCOUNT {
					totalAmount -= detailAmount
				} else {
					totalAmount += detailAmount
				}
			}
		}
		return totalAmount
	}
}


@objc public protocol PXReviewConfirmDynamicViewsConfiguration: NSObjectProtocol {
	@objc func topCustomViews(store: PXCheckoutStore) -> [UIView]?
	@objc func bottomCustomViews(store: PXCheckoutStore) -> [UIView]?
}
