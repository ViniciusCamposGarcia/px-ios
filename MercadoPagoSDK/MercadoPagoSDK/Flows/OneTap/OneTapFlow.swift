//
//  OneTapFlow.swift
//  MercadoPagoSDK
//
//  Created by Eden Torres on 09/05/2018.
//  Copyright © 2018 MercadoPago. All rights reserved.
//

import Foundation

final class OneTapFlow: NSObject, PXFlow {
    var model: OneTapFlowModel
    let pxNavigationHandler: PXNavigationHandler

    weak var resultHandler: PXOneTapResultHandlerProtocol?

    let advancedConfig: PXAdvancedConfiguration

    init(checkoutViewModel: MercadoPagoCheckoutViewModel, search: PXInitDTO, paymentOptionSelected: PaymentMethodOption, oneTapResultHandler: PXOneTapResultHandlerProtocol) {
        pxNavigationHandler = checkoutViewModel.pxNavigationHandler
        resultHandler = oneTapResultHandler
        advancedConfig = checkoutViewModel.getAdvancedConfiguration()
        model = OneTapFlowModel(checkoutViewModel: checkoutViewModel, search: search, paymentOptionSelected: paymentOptionSelected)
        super.init()
        model.oneTapFlow = self
    }

    func update(checkoutViewModel: MercadoPagoCheckoutViewModel, search: PXInitDTO, paymentOptionSelected: PaymentMethodOption) {
        model = OneTapFlowModel(checkoutViewModel: checkoutViewModel, search: search, paymentOptionSelected: paymentOptionSelected)
        model.oneTapFlow = self
    }

    deinit {
        #if DEBUG
        print("DEINIT FLOW - \(self)")
        #endif
    }

    func setPaymentFlow(paymentFlow: PXPaymentFlow) {
        model.paymentFlow = paymentFlow
    }

    func start() {
        executeNextStep()
    }

    func executeNextStep() {
        switch self.model.nextStep() {
        case .screenReviewOneTap:
            self.showReviewAndConfirmScreenForOneTap()
        case .screenSecurityCode:
            self.showSecurityCodeScreen()
        case .serviceCreateESCCardToken:
            self.getTokenizationService().createCardToken()
        case .payment:
            self.startPaymentFlow()
        case .finish:
            self.finishFlow()
        }
        print("")
    }

    func refreshInitFlow(cardId: String) {
        resultHandler?.refreshInitFlow(cardId: cardId)
    }

    // Cancel one tap and go to checkout
    func cancelFlow() {
        model.search.deleteCheckoutDefaultOption()
        resultHandler?.cancelOneTap()
    }

    // Cancel one tap and go to checkout
    func cancelFlowForNewPaymentSelection() {
        model.search.deleteCheckoutDefaultOption()
        resultHandler?.cancelOneTapForNewPaymentMethodSelection()
    }

    // Finish one tap and continue with checkout
    func finishFlow() {
        if let paymentResult = model.paymentResult {
            resultHandler?.finishOneTap(paymentResult: paymentResult, instructionsInfo: model.instructionsInfo, pointsAndDiscounts: model.pointsAndDiscounts)
        } else if let businessResult = model.businessResult {
            resultHandler?.finishOneTap(businessResult: businessResult, paymentData: model.paymentData, splitAccountMoney: model.splitAccountMoney, pointsAndDiscounts: model.pointsAndDiscounts)
        } else {
            resultHandler?.finishOneTap(paymentData: model.paymentData, splitAccountMoney: model.splitAccountMoney, pointsAndDiscounts: model.pointsAndDiscounts)
        }
    }

    // Exit checkout
    func exitCheckout() {
        resultHandler?.exitCheckout()
    }

    func setCustomerPaymentMethods(_ customPaymentMethods: [CustomerPaymentMethod]?) {
        model.customerPaymentOptions = customPaymentMethods
    }

    func setPaymentMethodPlugins(_ plugins: [PXPaymentMethodPlugin]?) {
        model.paymentMethodPlugins = plugins
    }

    func needSecurityCodeValidation() -> Bool {
        model.readyToPay = true
        return model.nextStep() == .screenSecurityCode
    }
}

extension OneTapFlow {
    /// Returns a auto selected payment option from a paymentMethodSearch object. If no option can be selected it returns nil
    ///
    /// - Parameters:
    ///   - search: payment method search item
    ///   - paymentMethodPlugins: payment Methods plugins that can be show
    /// - Returns: selected payment option if possible
    static func autoSelectOneTapOption(search: PXInitDTO, customPaymentOptions: [CustomerPaymentMethod]?, paymentMethodPlugins: [PXPaymentMethodPlugin], amountHelper: PXAmountHelper) -> PaymentMethodOption? {
        var selectedPaymentOption: PaymentMethodOption?
        if search.hasCheckoutDefaultOption() {
            // Check if can autoselect plugin
            let paymentMethodPluginsFound = paymentMethodPlugins.filter { (paymentMethodPlugin: PXPaymentMethodPlugin) -> Bool in
                return paymentMethodPlugin.getId() == search.oneTap?.first?.paymentMethodId
            }
            if let paymentMethodPlugin = paymentMethodPluginsFound.first {
                selectedPaymentOption = paymentMethodPlugin
            } else {

                // Check if can autoselect customer card
                guard let customerPaymentMethods = customPaymentOptions else {
                    return nil
                }

                if let suggestedAccountMoney = search.oneTap?.first?.accountMoney {
                    selectedPaymentOption = suggestedAccountMoney
                } else if let firstPaymentMethodId = search.oneTap?.first?.paymentMethodId {
                    let customOptionsFound = customerPaymentMethods.filter { return $0.getPaymentMethodId() == firstPaymentMethodId }
                    if let customerPaymentMethod = customOptionsFound.first {
                        // Check if one tap response has payer costs
                        if let expressNode = search.getPaymentMethodInExpressCheckout(targetId: customerPaymentMethod.getId()).expressNode,
                            let selected = selectPaymentMethod(expressNode: expressNode, customerPaymentMethod: customerPaymentMethod, amountHelper: amountHelper) {
                            selectedPaymentOption = selected
                        }
                    }
                }
            }
        }
        return selectedPaymentOption
    }

    static func selectPaymentMethod(expressNode: PXOneTapDto, customerPaymentMethod: CustomerPaymentMethod, amountHelper: PXAmountHelper) -> PaymentMethodOption? {

        // payment method id and payment type id must coincide between the express node and the customer payment method to continue
        if expressNode.paymentMethodId != customerPaymentMethod.getPaymentMethodId() ||
            expressNode.paymentTypeId != customerPaymentMethod.getPaymentTypeId() {
            return nil
        }

        var selectedPaymentOption: PaymentMethodOption?
        // the selected payment option is a one tap card, therefore has the required node and has related payer costs
        if let expressPaymentMethod = expressNode.oneTapCard, amountHelper.paymentConfigurationService.getSelectedPayerCostsForPaymentMethod(expressPaymentMethod.cardId) != nil {
            selectedPaymentOption = customerPaymentMethod
        }

        // the selected payment option is the credits option
        if expressNode.oneTapCreditsInfo != nil {
            selectedPaymentOption = customerPaymentMethod
        }
        return selectedPaymentOption
    }

    func getCustomerPaymentOption(forId: String) -> PaymentMethodOption? {
        guard let customerPaymentMethods = model.customerPaymentOptions else {
            return nil
        }
        let customOptionsFound = customerPaymentMethods.filter { return $0.id == forId }
        return customOptionsFound.first
    }
}

extension OneTapFlow {
	func startPaymentFlow() {
		guard let paymentFlow = model.paymentFlow else {
			return
		}
		model.invalidESC = false
		paymentFlow.paymentErrorHandler = self
		if isShowingLoading() {
			self.pxNavigationHandler.presentLoading()
		}
		paymentFlow.setData(amountHelper: model.amountHelper, checkoutPreference: model.checkoutPreference, resultHandler: self)
		paymentFlow.start()
	}
	
	func isShowingLoading() -> Bool {
		return pxNavigationHandler.isLoadingPresented() || pxNavigationHandler.isShowingDynamicViewController()
	}
}

extension OneTapFlow: PXPaymentResultHandlerProtocol {
	func finishPaymentFlow(error: MPSDKError) {
		guard let reviewScreen = pxNavigationHandler.navigationController.viewControllers.last as? PXOneTapViewController else {
			return
		}
		reviewScreen.resetButton(error: error)
	}
	
	func finishPaymentFlow(paymentResult: PaymentResult, instructionsInfo: PXInstructions?, pointsAndDiscounts: PXPointsAndDiscounts?) {
		self.model.paymentResult = paymentResult
		self.model.instructionsInfo = instructionsInfo
		self.model.pointsAndDiscounts = pointsAndDiscounts
		if isShowingLoading() {
			self.executeNextStep()
		} else {
			PXAnimatedButton.animateButtonWith(status: paymentResult.status, statusDetail: paymentResult.statusDetail)
		}
	}
	
	func finishPaymentFlow(businessResult: PXBusinessResult, pointsAndDiscounts: PXPointsAndDiscounts?) {
		self.model.businessResult = businessResult
		self.model.pointsAndDiscounts = pointsAndDiscounts
		if isShowingLoading() {
			self.executeNextStep()
		} else {
			PXAnimatedButton.animateButtonWith(status: businessResult.getBusinessStatus().getDescription())
		}
	}
}

extension OneTapFlow: PXPaymentErrorHandlerProtocol {
	func escError() {
		model.readyToPay = true
		model.invalidESC = true
		model.escManager?.deleteESC(cardId: model.paymentData.getToken()?.cardId ?? "")
		model.paymentData.cleanToken()
		executeNextStep()
	}
}

extension OneTapFlow {
	func showReviewAndConfirmScreenForOneTap() {
		let callbackPaymentData: ((PXPaymentData) -> Void) = {
			[weak self] (paymentData: PXPaymentData) in
			self?.cancelFlowForNewPaymentSelection()
		}
		let callbackConfirm: ((PXPaymentData, Bool) -> Void) = {
			[weak self] (paymentData: PXPaymentData, splitAccountMoneyEnabled: Bool) in
			self?.model.updateCheckoutModel(paymentData: paymentData, splitAccountMoneyEnabled: splitAccountMoneyEnabled)
			// Deletes default one tap option in payment method search
			self?.executeNextStep()
		}
		let callbackUpdatePaymentOption: ((PaymentMethodOption) -> Void) = {
			[weak self] (newPaymentOption: PaymentMethodOption) in
			if let card = newPaymentOption as? PXCardSliderViewModel, let newPaymentOptionSelected = self?.getCustomerPaymentOption(forId: card.cardId ?? "") {
				// Customer card.
				self?.model.paymentOptionSelected = newPaymentOptionSelected
			} else if newPaymentOption.getId() == PXPaymentTypes.ACCOUNT_MONEY.rawValue ||
				newPaymentOption.getId() == PXPaymentTypes.CONSUMER_CREDITS.rawValue {
				// AM
				self?.model.paymentOptionSelected = newPaymentOption
			}
		}
		let callbackRefreshInit: ((String) -> Void) = {
			[weak self] cardId in
			self?.refreshInitFlow(cardId: cardId)
		}
		let callbackExit: (() -> Void) = {
			[weak self] in
			self?.cancelFlow()
		}
		let finishButtonAnimation: (() -> Void) = {
			[weak self] in
			self?.executeNextStep()
		}
		let viewModel = model.oneTapViewModel()
		let reviewVC = PXOneTapViewController(viewModel: viewModel, timeOutPayButton: model.getTimeoutForOneTapReviewController(), callbackPaymentData: callbackPaymentData, callbackConfirm: callbackConfirm, callbackUpdatePaymentOption: callbackUpdatePaymentOption, callbackRefreshInit: callbackRefreshInit, callbackExit: callbackExit, finishButtonAnimation: finishButtonAnimation)
		
		pxNavigationHandler.pushViewController(viewController: reviewVC, animated: true)
	}
	
	func updateOneTapViewModel(cardId: String) {
		if let oneTapViewController = pxNavigationHandler.navigationController.viewControllers.first(where: { $0 is PXOneTapViewController }) as? PXOneTapViewController {
			let viewModel = model.oneTapViewModel()
			oneTapViewController.update(viewModel: viewModel, cardId: cardId)
		}
	}
	
	func showSecurityCodeScreen() {
		let securityCodeVc = SecurityCodeViewController(viewModel: model.savedCardSecurityCodeViewModel(), collectSecurityCodeCallback: { [weak self] (_, securityCode: String) -> Void in
			self?.getTokenizationService().createCardToken(securityCode: securityCode)
		})
		pxNavigationHandler.pushViewController(viewController: securityCodeVc, animated: true)
	}
}


extension OneTapFlow: TokenizationServiceResultHandler {
	func finishInvalidIdentificationNumber() {
	}
	
	func finishFlow(token: PXToken) {
		model.updateCheckoutModel(token: token)
		executeNextStep()
	}
	
	func finishWithESCError() {
		executeNextStep()
	}
	
	func finishWithError(error: MPSDKError, securityCode: String? = nil) {
		if isShowingLoading() {
			pxNavigationHandler.showErrorScreen(error: error, callbackCancel: resultHandler?.exitCheckout, errorCallback: { [weak self] () in
				self?.getTokenizationService().createCardToken(securityCode: securityCode)
			})
		} else {
			finishPaymentFlow(error: error)
		}
	}
	
	func getTokenizationService() -> TokenizationService {
		return TokenizationService(paymentOptionSelected: model.paymentOptionSelected, cardToken: nil, escManager: model.escManager, pxNavigationHandler: pxNavigationHandler, needToShowLoading: model.needToShowLoading(), mercadoPagoServicesAdapter: model.mercadoPagoServicesAdapter, gatewayFlowResultHandler: self)
	}
}


final internal class OneTapFlowModel: PXFlowModel {
	enum Steps: String {
		case finish
		case screenReviewOneTap
		case screenSecurityCode
		case serviceCreateESCCardToken
		case payment
	}
	internal var publicKey: String = ""
	internal var privateKey: String?
	internal var siteId: String = ""
	var paymentData: PXPaymentData
	let checkoutPreference: PXCheckoutPreference
	var paymentOptionSelected: PaymentMethodOption
	let search: PXInitDTO
	var readyToPay: Bool = false
	var paymentResult: PaymentResult?
	var instructionsInfo: PXInstructions?
	var pointsAndDiscounts: PXPointsAndDiscounts?
	var businessResult: PXBusinessResult?
	var customerPaymentOptions: [CustomerPaymentMethod]?
	var paymentMethodPlugins: [PXPaymentMethodPlugin]?
	var splitAccountMoney: PXPaymentData?
	var disabledOption: PXDisabledOption?
	
	// Payment flow
	var paymentFlow: PXPaymentFlow?
	weak var paymentResultHandler: PXPaymentResultHandlerProtocol?
	
	// One Tap Flow
	weak var oneTapFlow: OneTapFlow?
	
	var chargeRules: [PXPaymentTypeChargeRule]?
	
	var invalidESC: Bool = false
	
	// In order to ensure data updated create new instance for every usage
	internal var amountHelper: PXAmountHelper {
		return PXAmountHelper(preference: self.checkoutPreference, paymentData: self.paymentData, chargeRules: chargeRules, paymentConfigurationService: self.paymentConfigurationService, splitAccountMoney: splitAccountMoney)
	}
	
	let escManager: MercadoPagoESC?
	let advancedConfiguration: PXAdvancedConfiguration
	let mercadoPagoServicesAdapter: MercadoPagoServicesAdapter
	let paymentConfigurationService: PXPaymentConfigurationServices
	
	init(checkoutViewModel: MercadoPagoCheckoutViewModel, search: PXInitDTO, paymentOptionSelected: PaymentMethodOption) {
		publicKey = checkoutViewModel.publicKey
		privateKey = checkoutViewModel.privateKey
		siteId = checkoutViewModel.checkoutPreference.siteId
		paymentData = checkoutViewModel.paymentData.copy() as? PXPaymentData ?? checkoutViewModel.paymentData
		checkoutPreference = checkoutViewModel.checkoutPreference
		self.search = search
		self.paymentOptionSelected = paymentOptionSelected
		advancedConfiguration = checkoutViewModel.getAdvancedConfiguration()
		chargeRules = checkoutViewModel.chargeRules
		mercadoPagoServicesAdapter = checkoutViewModel.mercadoPagoServicesAdapter
		escManager = checkoutViewModel.escManager
		paymentConfigurationService = checkoutViewModel.paymentConfigurationService
		disabledOption = checkoutViewModel.disabledOption
		
		// Payer cost pre selection.
		let paymentMethodId = search.oneTap?.first?.paymentMethodId
		let firstCardID = search.oneTap?.first?.oneTapCard?.cardId
		let creditsCase = paymentMethodId == PXPaymentTypes.CONSUMER_CREDITS.rawValue
		let cardCase = firstCardID != nil
		
		if cardCase || creditsCase {
			if let pmIdentifier = cardCase ? firstCardID : paymentMethodId,
				let payerCost = amountHelper.paymentConfigurationService.getSelectedPayerCostsForPaymentMethod(pmIdentifier) {
				updateCheckoutModel(payerCost: payerCost)
			}
		}
	}
	public func nextStep() -> Steps {
		if needReviewAndConfirmForOneTap() {
			return .screenReviewOneTap
		}
		if needSecurityCode() {
			return .screenSecurityCode
		}
		if needCreateESCToken() {
			return .serviceCreateESCCardToken
		}
		if needCreatePayment() {
			return .payment
		}
		return .finish
	}
}

// MARK: Create view model
internal extension OneTapFlowModel {
	func savedCardSecurityCodeViewModel() -> SecurityCodeViewModel {
		guard let cardInformation = self.paymentOptionSelected as? PXCardInformation else {
			fatalError("Cannot convert payment option selected to CardInformation")
		}
		
		guard let paymentMethod = paymentData.paymentMethod else {
			fatalError("Don't have paymentData to open Security View Controller")
		}
		
		var reason: SecurityCodeViewModel.Reason
		if invalidESC {
			reason = SecurityCodeViewModel.Reason.INVALID_ESC
		} else {
			reason = SecurityCodeViewModel.Reason.SAVED_CARD
		}
		return SecurityCodeViewModel(paymentMethod: paymentMethod, cardInfo: cardInformation, reason: reason)
	}
	
	func oneTapViewModel() -> PXOneTapViewModel {
		let viewModel = PXOneTapViewModel(amountHelper: amountHelper, paymentOptionSelected: paymentOptionSelected, advancedConfig: advancedConfiguration, userLogged: false, disabledOption: disabledOption, escProtocol: escManager, currentFlow: oneTapFlow)
		viewModel.publicKey = publicKey
		viewModel.privateKey = privateKey
		viewModel.siteId = siteId
		viewModel.excludedPaymentTypeIds = checkoutPreference.getExcludedPaymentTypesIds()
		viewModel.expressData = search.oneTap
		viewModel.paymentMethods = search.availablePaymentMethods
		viewModel.items = checkoutPreference.items
		viewModel.additionalInfoSummary = checkoutPreference.pxAdditionalInfo?.pxSummary
		return viewModel
	}
}

// MARK: Update view models
internal extension OneTapFlowModel {
	func updateCheckoutModel(paymentData: PXPaymentData, splitAccountMoneyEnabled: Bool) {
		self.paymentData = paymentData
		
		if splitAccountMoneyEnabled {
			let splitConfiguration = amountHelper.paymentConfigurationService.getSplitConfigurationForPaymentMethod(paymentOptionSelected.getId())
			
			// Set total amount to pay with card without discount
			paymentData.transactionAmount = PXAmountHelper.getRoundedAmountAsNsDecimalNumber(amount: splitConfiguration?.primaryPaymentMethod?.amount)
			
			let accountMoneyPMs = search.availablePaymentMethods.filter { (paymentMethod) -> Bool in
				return paymentMethod.id == splitConfiguration?.secondaryPaymentMethod?.id
			}
			if let accountMoneyPM = accountMoneyPMs.first {
				splitAccountMoney = PXPaymentData()
				// Set total amount to pay with account money without discount
				splitAccountMoney?.transactionAmount = PXAmountHelper.getRoundedAmountAsNsDecimalNumber(amount: splitConfiguration?.secondaryPaymentMethod?.amount)
				splitAccountMoney?.updatePaymentDataWith(paymentMethod: accountMoneyPM)
				
				let campaign = amountHelper.paymentConfigurationService.getDiscountConfigurationForPaymentMethodOrDefault(paymentOptionSelected.getId())?.getDiscountConfiguration().campaign
				let consumedDiscount = amountHelper.paymentConfigurationService.getDiscountConfigurationForPaymentMethodOrDefault(paymentOptionSelected.getId())?.getDiscountConfiguration().isNotAvailable
				if let discount = splitConfiguration?.primaryPaymentMethod?.discount, let campaign = campaign, let consumedDiscount = consumedDiscount {
					paymentData.setDiscount(discount, withCampaign: campaign, consumedDiscount: consumedDiscount)
				}
				if let discount = splitConfiguration?.secondaryPaymentMethod?.discount, let campaign = campaign, let consumedDiscount = consumedDiscount {
					splitAccountMoney?.setDiscount(discount, withCampaign: campaign, consumedDiscount: consumedDiscount)
				}
			}
		} else {
			splitAccountMoney = nil
		}
		
		self.readyToPay = true
	}
	
	func updateCheckoutModel(token: PXToken) {
		self.paymentData.updatePaymentDataWith(token: token)
	}
	
	func updateCheckoutModel(payerCost: PXPayerCost) {
		
		let isCredits = paymentOptionSelected.getId() == PXPaymentTypes.CONSUMER_CREDITS.rawValue
		if paymentOptionSelected.isCard() || isCredits {
			self.paymentData.updatePaymentDataWith(payerCost: payerCost)
			self.paymentData.cleanToken()
		}
	}
}

// MARK: Flow logic
internal extension OneTapFlowModel {
	func needReviewAndConfirmForOneTap() -> Bool {
		if readyToPay {
			return false
		}
		
		if paymentData.isComplete(shouldCheckForToken: false) {
			return true
		}
		
		return false
	}
	
	func needSecurityCode() -> Bool {
		guard let paymentMethod = self.paymentData.getPaymentMethod() else {
			return false
		}
		
		if !readyToPay {
			return false
		}
		
		let hasInstallmentsIfNeeded = paymentData.hasPayerCost() || !paymentMethod.isCreditCard
		let isCustomerCard = paymentOptionSelected.isCustomerPaymentMethod() && paymentOptionSelected.getId() != PXPaymentTypes.ACCOUNT_MONEY.rawValue && paymentOptionSelected.getId() != PXPaymentTypes.CONSUMER_CREDITS.rawValue
		
		if isCustomerCard && !paymentData.hasToken() && hasInstallmentsIfNeeded && !hasSavedESC() {
			return true
		}
		return false
	}
	
	func needCreateESCToken() -> Bool {
		guard let paymentMethod = self.paymentData.getPaymentMethod() else {
			return false
		}
		
		let hasInstallmentsIfNeeded = self.paymentData.getPayerCost() != nil || !paymentMethod.isCreditCard
		let savedCardWithESC = !paymentData.hasToken() && paymentMethod.isCard && hasSavedESC() && hasInstallmentsIfNeeded
		
		return savedCardWithESC
	}
	
	func needCreatePayment() -> Bool {
		if !readyToPay {
			return false
		}
		return paymentData.isComplete(shouldCheckForToken: false) && paymentFlow != nil && paymentResult == nil && businessResult == nil
	}
	
	func hasSavedESC() -> Bool {
		if let card = paymentOptionSelected as? PXCardInformation {
			return escManager?.getESC(cardId: card.getCardId(), firstSixDigits: card.getFirstSixDigits(), lastFourDigits: card.getCardLastForDigits()) == nil ? false : true
		}
		return false
	}
	
	func needToShowLoading() -> Bool {
		guard let paymentMethod = paymentData.getPaymentMethod() else {
			return true
		}
		if let paymentFlow = paymentFlow, paymentMethod.isAccountMoney || hasSavedESC() {
			return paymentFlow.hasPaymentPluginScreen()
		}
		return true
	}
	
	func getTimeoutForOneTapReviewController() -> TimeInterval {
		if let paymentFlow = paymentFlow {
			paymentFlow.model.amountHelper = amountHelper
			let tokenTimeOut: TimeInterval = mercadoPagoServicesAdapter.getTimeOut()
			// Payment Flow timeout + tokenization TimeOut
			return paymentFlow.getPaymentTimeOut() + tokenTimeOut
		}
		return 0
	}
	
}

internal protocol PXOneTapResultHandlerProtocol: NSObjectProtocol {
	func finishOneTap(paymentResult: PaymentResult, instructionsInfo: PXInstructions?, pointsAndDiscounts: PXPointsAndDiscounts?)
	func finishOneTap(businessResult: PXBusinessResult, paymentData: PXPaymentData, splitAccountMoney: PXPaymentData?, pointsAndDiscounts: PXPointsAndDiscounts?)
	func finishOneTap(paymentData: PXPaymentData, splitAccountMoney: PXPaymentData?, pointsAndDiscounts: PXPointsAndDiscounts?)
	func refreshInitFlow(cardId: String)
	func cancelOneTap()
	func cancelOneTapForNewPaymentMethodSelection()
	func exitCheckout()
}
