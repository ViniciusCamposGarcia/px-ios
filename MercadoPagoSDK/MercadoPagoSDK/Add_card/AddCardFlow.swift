//
//  AddCardFlow.swift
//  MercadoPagoSDK
//
//  Created by Diego Flores Domenech on 6/9/18.
//  Copyright © 2018 MercadoPago. All rights reserved.
//

import UIKit

@objc public protocol AddCardFlowProtocol {
    func addCardFlowSucceded(result: [String: Any])
    func addCardFlowFailed(shouldRestart: Bool)
}

@objcMembers
public class AddCardFlow: NSObject, PXFlow {

    public weak var delegate: AddCardFlowProtocol?

    private var productId: String?
    private let accessToken: String
    private let model = AddCardFlowModel()
    private let navigationHandler: PXNavigationHandler

    // Change in Q2 when esc info comes from backend
    private let escEnabled: Bool = true
    private let escManager: PXESCManager

    //add card flow should have 'aggregator' processing mode by default
    private lazy var mercadoPagoServicesAdapter = MercadoPagoServicesAdapter(publicKey: "APP_USR-5bd14fdd-3807-446f-babd-095788d5ed4d", privateKey: self.accessToken)

    public convenience init(accessToken: String, locale: String, navigationController: UINavigationController, shouldSkipCongrats: Bool) {
        self.init(accessToken: accessToken, locale: locale, navigationController: navigationController)
        model.skipCongrats = shouldSkipCongrats
    }

    public init(accessToken: String, locale: String, navigationController: UINavigationController) {
        self.accessToken = accessToken
        self.navigationHandler = PXNavigationHandler(navigationController: navigationController)
        MPXTracker.sharedInstance.startNewSession()
        escManager = PXESCManager(enabled: escEnabled, sessionId: MPXTracker.sharedInstance.getSessionID(), flow: "/card_association")
        super.init()
        Localizator.sharedInstance.setLanguage(string: locale)
        ThemeManager.shared.saveNavBarStyleFor(navigationController: navigationController)
        PXNotificationManager.SuscribeTo.attemptToClose(self, selector: #selector(goBack))
    }

    public func setSiteId(_ siteId: String) {
        let siteFactory = AddCardFlowSiteFactory()
        SiteManager.shared.setSite(site: siteFactory.createSite(siteId))
    }

    /**
            Set product id
        */
    open func setProductId(_ productId: String) {
        self.productId = productId
    }

    public func start() {
        self.executeNextStep()
    }

    public func setTheme(theme: PXTheme) {
        ThemeManager.shared.setTheme(theme: theme)
    }

    func executeNextStep() {
        if self.model.lastStepFailed {
            self.navigationHandler.presentLoading()
        }
        switch self.model.nextStep() {
        case .getPaymentMethods:
            self.getPaymentMethods()
        case .getIdentificationTypes:
            self.getIdentificationTypes()
        case .openCardForm:
            self.openCardForm()
        case .openIdentificationTypes:
            self.openIdentificationTypesScreen()
        case .createToken:
            self.createCardToken()
        case .associateTokenWithUser:
            self.associateTokenWithUser()
        case .showCongrats:
            self.showCongrats()
        case .finish:
            self.finish()
        default:
            break
        }
    }

    func cancelFlow() {
    }

    func finishFlow() {
    }

    func exitCheckout() {
    }

    // MARK: steps

    private func getPaymentMethods() {
        self.navigationHandler.presentLoading()
        let service = PaymentMethodsUserService(accessToken: self.accessToken, productId: self.productId)
        service.getPaymentMethods(success: { [weak self] (paymentMethods) in
            guard let self = self else { return }
            self.model.paymentMethods = paymentMethods
            self.executeNextStep()
            }, failure: { [weak self] (error) in
                guard let self = self else { return }
                self.model.lastStepFailed = true
                if error.code == ErrorTypes.NO_INTERNET_ERROR {
                    let sdkError = MPSDKError.convertFrom(error, requestOrigin: ApiUtil.RequestOrigin.GET_PAYMENT_METHODS.rawValue)
                    self.navigationHandler.showErrorScreen(error: sdkError, callbackCancel: { [weak self] in
                        self?.finish()
                    }, errorCallback: nil)
                } else {
                    self.showErrorScreen()
                }
        })
    }

    private func getIdentificationTypes() {
        self.mercadoPagoServicesAdapter.getIdentificationTypes(callback: { [weak self] identificationTypes in
            guard let self = self else { return }
            self.model.identificationTypes = identificationTypes
            self.executeNextStep()
        }, failure: { [weak self] error in
            guard let self = self else { return }
            self.model.lastStepFailed = true
            if error.code == ErrorTypes.NO_INTERNET_ERROR {
                let sdkError = MPSDKError.convertFrom(error, requestOrigin: ApiUtil.RequestOrigin.GET_IDENTIFICATION_TYPES.rawValue)
                self.navigationHandler.showErrorScreen(error: sdkError, callbackCancel: { [weak self] in
                    self?.finish()
                }, errorCallback: nil)
            } else {
                if let status = error.userInfo["status"] as? Int, status == 404 {
                    self.model.identificationTypes = []
                    self.model.lastStepFailed = false
                    self.executeNextStep()
                } else {
                    self.showErrorScreen()
                }
            }
        })
    }

    private func openCardForm() {
        guard let paymentMethods = self.model.paymentMethods else {
            return
        }
        let cardFormViewModel = CardFormViewModel(paymentMethods: paymentMethods, guessedPaymentMethods: nil, customerCard: nil, token: nil, mercadoPagoServicesAdapter: nil, bankDealsEnabled: false)
        let cardFormViewController = CardFormViewController(cardFormManager: cardFormViewModel, callback: { [weak self] (paymentMethods, cardToken) in
            guard let self = self else { return }
            self.model.cardToken = cardToken
            self.model.selectedPaymentMethod = paymentMethods.first
            self.executeNextStep()
        })
        self.navigationHandler.pushViewController(cleanCompletedCheckouts: false, targetVC: cardFormViewController, animated: true)
    }

    private func openIdentificationTypesScreen() {
        guard let identificationTypes = self.model.supportedIdentificationTypes() else {
            self.showErrorScreen()
            return
        }
        let identificationViewController = IdentificationViewController(identificationTypes: identificationTypes, paymentMethod: model.selectedPaymentMethod, callback: { [weak self] (identification) in
            guard let self = self else { return }
            self.model.cardToken?.cardholder?.identification = identification
            self.executeNextStep()
            }, errorExitCallback: { [weak self] in
                self?.showErrorScreen()
        })
        self.navigationHandler.pushViewController(cleanCompletedCheckouts: false, targetVC: identificationViewController, animated: true)
    }

    private func createCardToken() {
        guard let cardToken = self.model.cardToken else {
            return
        }
        cardToken.requireESC = escEnabled
        self.navigationHandler.presentLoading()

        self.mercadoPagoServicesAdapter.createToken(cardToken: cardToken, callback: { [weak self] (token) in
            guard let self = self else { return }
            self.model.tokenizedCard = token
            if let esc = token.esc {
                self.escManager.saveESC(firstSixDigits: token.firstSixDigits, lastFourDigits: token.lastFourDigits, esc: esc)
            }
            self.executeNextStep()
            }, failure: { [weak self] (error) in
                guard let self = self else { return }
                let reachabilityManager = PXReach()
                if reachabilityManager.connectionStatus().description == ReachabilityStatus.offline.description {
                    self.model.lastStepFailed = true
                    let sdkError = MPSDKError.convertFrom(error, requestOrigin: ApiUtil.RequestOrigin.CREATE_TOKEN.rawValue)
                    self.navigationHandler.showErrorScreen(error: sdkError, callbackCancel: { [weak self] in
                        self?.finish()
                    }, errorCallback: nil)
                } else {
                    self.showErrorScreen()
                }
        })
    }

    private func associateTokenWithUser() {
        guard let selectedPaymentMethod = self.model.selectedPaymentMethod, let token = self.model.tokenizedCard else {
            return
        }
        let associateCardService = AssociateCardService(accessToken: self.accessToken, productId: productId)
        associateCardService.associateCardToUser(paymentMethod: selectedPaymentMethod, cardToken: token, success: { [weak self] (json) in
            guard let self = self else { return }
            self.navigationHandler.dismissLoading()
            self.model.associateCardResult = json
            self.executeNextStep()
            }, failure: { [weak self] (error) in
                guard let self = self else { return }
                if error.code == ErrorTypes.NO_INTERNET_ERROR {
                    self.model.lastStepFailed = true
                    let sdkError = MPSDKError.convertFrom(error, requestOrigin: ApiUtil.RequestOrigin.ASSOCIATE_TOKEN.rawValue)
                    self.navigationHandler.showErrorScreen(error: sdkError, callbackCancel: { [weak self] in
                        self?.finish()
                    }, errorCallback: nil)
                } else {
                    self.showErrorScreen()
                }
        })
    }

    private func showCongrats() {
        let viewModel = PXResultAddCardSuccessViewModel(buttonCallback: { [weak self] in
            self?.executeNextStep()
        })
        let congratsVc = PXResultViewController(viewModel: viewModel) { [weak self]  (_)  in
            self?.finish()
        }
        self.navigationHandler.pushViewController(cleanCompletedCheckouts: false, targetVC: congratsVc, animated: true)
    }

    private func finish() {
        if let associateCardResult = self.model.associateCardResult {
            self.delegate?.addCardFlowSucceded(result: associateCardResult)
        } else {
            self.delegate?.addCardFlowFailed(shouldRestart: false)
        }
        ThemeManager.shared.applyAppNavBarStyle(navigationController: self.navigationHandler.navigationController)
    }

    private func showErrorScreen() {
        let viewModel = PXResultAddCardFailedViewModel(buttonCallback: { [weak self] in
            self?.reset()
            }, linkCallback: { [weak self] in
                self?.finish()
        })
        let failVc = PXResultViewController(viewModel: viewModel) { [weak self]  (_)  in
            self?.finish()
        }
        self.navigationHandler.pushViewController(cleanCompletedCheckouts: false, targetVC: failVc, animated: true)
    }

    private func reset() {
        PXNotificationManager.Post.cardFormReset()
        if let cardForm = self.navigationHandler.navigationController.viewControllers.filter({ $0 is CardFormViewController }).first {
            self.navigationHandler.navigationController.popToViewController(cardForm, animated: true)
            self.model.reset()
        } else {
            self.delegate?.addCardFlowFailed(shouldRestart: true)
            ThemeManager.shared.applyAppNavBarStyle(navigationController: self.navigationHandler.navigationController)
        }
        self.navigationHandler.navigationController.setNavigationBarHidden(false, animated: true)
    }

    @objc private func goBack() {
        PXNotificationManager.UnsuscribeTo.attemptToClose(self)
        self.navigationHandler.popViewController(animated: true)
        ThemeManager.shared.applyAppNavBarStyle(navigationController: self.navigationHandler.navigationController)
    }

}

class AddCardFlowModel: NSObject, PXFlowModel {
	
	var paymentMethods: [PXPaymentMethod]?
	var identificationTypes: [PXIdentificationType]?
	var cardToken: PXCardToken?
	var selectedPaymentMethod: PXPaymentMethod?
	var tokenizedCard: PXToken?
	var associateCardResult: [String: Any]?
	var lastStepFailed = false
	var skipCongrats = false
	
	enum Steps: Int {
		case start
		case getPaymentMethods
		case getIdentificationTypes
		case openCardForm
		case openIdentificationTypes
		case createToken
		case associateTokenWithUser
		case showCongrats
		case finish
	}
	
	private var currentStep = Steps.start
	
	func nextStep() -> AddCardFlowModel.Steps {
		if lastStepFailed {
			lastStepFailed = false
			return currentStep
		}
		switch currentStep {
		case .start:
			currentStep = .getPaymentMethods
		case .getPaymentMethods:
			currentStep = .getIdentificationTypes
		case .getIdentificationTypes:
			currentStep = .openCardForm
		case .openCardForm:
			if let selectedPaymentMethod = self.selectedPaymentMethod, let identificationTypes = self.identificationTypes, !identificationTypes.isEmpty, selectedPaymentMethod.isIdentificationTypeRequired || selectedPaymentMethod.isIdentificationRequired {
				currentStep = .openIdentificationTypes
			} else {
				currentStep = .createToken
			}
		case .openIdentificationTypes:
			if let idType = self.cardToken?.cardholder?.identification?.type, !idType.isEmpty {
				currentStep = .createToken
			} else {
				currentStep = .openIdentificationTypes
			}
		case .createToken:
			currentStep = .associateTokenWithUser
		case .associateTokenWithUser:
			currentStep = skipCongrats ? .finish : .showCongrats
		case .showCongrats:
			currentStep = .finish
		default:
			break
		}
		return currentStep
	}
	
	func reset() {
		if self.currentStep.rawValue > AddCardFlowModel.Steps.openCardForm.rawValue {
			self.currentStep = .openCardForm
		}
		self.cardToken = nil
		self.selectedPaymentMethod = nil
		self.tokenizedCard = nil
	}
	
	func supportedIdentificationTypes() -> [PXIdentificationType]? {
		return IdentificationTypeValidator().filterSupported(identificationTypes: self.identificationTypes)
	}
}

struct AddCardFlowSiteFactory {
	
	let siteIdsSettings: [String: NSDictionary] = [
		//Argentina
		"MLA": ["language": "es", "currency": "ARS", "termsconditions": "https://www.mercadopago.com.ar/ayuda/terminos-y-condiciones_299"],
		//Brasil
		"MLB": ["language": "pt", "currency": "BRL", "termsconditions": "https://www.mercadopago.com.br/ajuda/termos-e-condicoes_300"],
		//Chile
		"MLC": ["language": "es", "currency": "CLP", "termsconditions": "https://www.mercadopago.cl/ayuda/terminos-y-condiciones_299"],
		//Mexico
		"MLM": ["language": "es-MX", "currency": "MXN", "termsconditions": "https://www.mercadopago.com.mx/ayuda/terminos-y-condiciones_715"],
		//Peru
		"MPE": ["language": "es", "currency": "PEN", "termsconditions": "https://www.mercadopago.com.pe/ayuda/terminos-condiciones-uso_2483"],
		//Uruguay
		"MLU": ["language": "es", "currency": "UYU", "termsconditions": "https://www.mercadopago.com.uy/ayuda/terminos-y-condiciones-uy_2834"],
		//Colombia
		"MCO": ["language": "es-CO", "currency": "COP", "termsconditions": "https://www.mercadopago.com.co/ayuda/terminos-y-condiciones_299"],
		//Venezuela
		"MLV": ["language": "es", "currency": "VES", "termsconditions": "https://www.mercadopago.com.ve/ayuda/terminos-y-condiciones_299"]
	]
	
	func createSite(_ siteId: String) -> PXSite {
		let siteConfig = siteIdsSettings[siteId] ?? siteIdsSettings["MLA"]
		let currencyId = siteConfig?["currency"] as? String ?? "ARS"
		let termsAndConditionsUrl = ""
		return PXSite(id: siteId, currencyId: currencyId, termsAndConditionsUrl: termsAndConditionsUrl, shouldWarnAboutBankInterests: false)
	}
}

final class AssociateCardService: MercadoPagoService {
	
	let uri = "/v1/px_mobile_api/card-association"
	let accessToken: String
	let productId: String?
	
	init(accessToken: String, productId: String?) {
		self.accessToken = accessToken
		self.productId = productId
		super.init(baseURL: PXServicesURLConfigs.MP_API_BASE_URL)
	}
	
	func associateCardToUser(paymentMethod: PXPaymentMethod, cardToken: PXToken, success: @escaping ([String: Any]) -> Void, failure: @escaping (PXError) -> Void) {
		let paymentMethodDict: [String: String] = ["id": paymentMethod.id]
		let body: [String: Any] = ["card_token_id": cardToken.id, "payment_method": paymentMethodDict]
		
		let jsonData = try? JSONSerialization.data(withJSONObject: body, options: [])
		
		var headers: [String: String] = [:]
		if let prodId = self.productId {
			headers[MercadoPagoService.HeaderField.productId.rawValue] = prodId
		}
		
		self.request(uri: uri, params: "access_token=\(accessToken)", body: jsonData, method: .post, headers: headers, cache: false, success: { (data) in
			let jsonResult = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments)
			if let jsonResult = jsonResult as? [String: Any] {
				do {
					let apiException = try PXApiException.fromJSON(data: data)
					failure(PXError(domain: "mercadopago.sdk.associateCard", code: ErrorTypes.API_EXCEPTION_ERROR, userInfo: jsonResult, apiException: apiException))
				} catch {
					success(jsonResult)
				}
			}
		}) { (_) in
			failure(PXError(domain: "mercadopago.sdk.associateCard", code: ErrorTypes.NO_INTERNET_ERROR, userInfo: [NSLocalizedDescriptionKey: "Hubo un error", NSLocalizedFailureReasonErrorKey: "Verifique su conexión a internet e intente nuevamente"]))
		}
	}
	
}

class PaymentMethodsUserService: MercadoPagoService {
	
	let uri = "/v1/px_mobile_api/payment_methods/cards"
	let accessToken: String
	let productId: String?
	
	init(accessToken: String, productId: String?) {
		self.accessToken = accessToken
		self.productId = productId
		super.init(baseURL: PXServicesURLConfigs.MP_API_BASE_URL)
	}
	
	func getPaymentMethods(success: @escaping ([PXPaymentMethod]) -> Void, failure: @escaping (PXError) -> Void) {
		
		var headers: [String: String] = [:]
		if let prodId = self.productId {
			headers[MercadoPagoService.HeaderField.productId.rawValue] = prodId
		}
		
		self.request(uri: uri, params: "access_token=\(accessToken)", body: nil, method: .get, headers: headers, success: { (data) in
			do {
				let paymentMethods = try JSONDecoder().decode([PXPaymentMethod].self, from: data)
				success(paymentMethods)
			} catch {
				let apiException = try? PXApiException.fromJSON(data: data)
				let dict = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
				failure(PXError(domain: "mercadopago.sdk.getPaymentMethods", code: ErrorTypes.API_EXCEPTION_ERROR, userInfo: dict ?? [:], apiException: apiException))
			}
		}) { (_) in
			failure(PXError(domain: "mercadopago.sdk.PaymentMethodsUserService.getPaymentMethods", code: ErrorTypes.NO_INTERNET_ERROR, userInfo: [NSLocalizedDescriptionKey: "Hubo un error", NSLocalizedFailureReasonErrorKey: "Verifique su conexión a internet e intente nuevamente"]))
		}
	}
	
}

final class PXResultAddCardFailedViewModel: PXResultViewModelInterface {
	
	let buttonCallback: () -> Void
	let linkCallback: () -> Void
	var callback: ((PaymentResult.CongratsState) -> Void)?
	
	init(buttonCallback: @escaping () -> Void, linkCallback: @escaping () -> Void) {
		self.buttonCallback = buttonCallback
		self.linkCallback = linkCallback
	}
	
	func getPaymentData() -> PXPaymentData {
		return PXPaymentData()
	}
	
	func primaryResultColor() -> UIColor {
		return ThemeManager.shared.warningColor()
	}
	
	func setCallback(callback: @escaping (PaymentResult.CongratsState) -> Void) {
		self.callback = callback
	}
	
	func getPaymentStatus() -> String {
		return ""
	}
	
	func getPaymentStatusDetail() -> String {
		return ""
	}
	
	func getPaymentId() -> String? {
		return nil
	}
	
	func isCallForAuth() -> Bool {
		return false
	}
	
	func buildHeaderComponent() -> PXHeaderComponent {
		let productImage = ResourceManager.shared.getImage("card_icon")
		let statusImage = ResourceManager.shared.getImage("need_action_badge")
		let props = PXHeaderProps(labelText: NSAttributedString(string: "review_and_confirm_toast_error".localized), title: NSAttributedString(string: "add_card_failed_title".localized, attributes: [NSAttributedString.Key.font: UIFont.ml_regularSystemFont(ofSize: 26)]), backgroundColor: ThemeManager.shared.warningColor(), productImage: productImage, statusImage: statusImage, closeAction: { [weak self] in
			if let callback = self?.callback {
				callback(PaymentResult.CongratsState.cancel_EXIT)
			}
		})
		let header = PXHeaderComponent(props: props)
		return header
	}
	
	func buildFooterComponent() -> PXFooterComponent {
		let buttonAction = PXAction(label: "add_card_try_again".localized, action: self.buttonCallback)
		let linkAction = PXAction(label: "add_card_go_to_my_cards".localized, action: self.linkCallback)
		let props = PXFooterProps(buttonAction: buttonAction, linkAction: linkAction, primaryColor: UIColor.ml_meli_blue(), animationDelegate: nil)
		let footer = PXFooterComponent(props: props)
		return footer
	}
	
	func buildReceiptComponent() -> PXReceiptComponent? {
		return nil
	}
	
	func buildBodyComponent() -> PXComponentizable? {
		return nil
	}
	
	func buildTopCustomView() -> UIView? {
		return nil
	}
	
	func buildBottomCustomView() -> UIView? {
		return nil
	}
	
	func getTrackingProperties() -> [String: Any] {
		return [:]
	}
	
	func getTrackingPath() -> String {
		return ""
	}
	
	func getFooterPrimaryActionTrackingPath() -> String {
		return ""
	}
	
	func getFooterSecondaryActionTrackingPath() -> String {
		return ""
	}
	
	func getHeaderCloseButtonTrackingPath() -> String {
		return ""
	}
}

final class PXResultAddCardSuccessViewModel: PXResultViewModelInterface {
	
	let buttonCallback: () -> Void
	var callback: ((PaymentResult.CongratsState) -> Void)?
	
	init(buttonCallback: @escaping () -> Void) {
		self.buttonCallback = buttonCallback
	}
	
	func getPaymentData() -> PXPaymentData {
		return PXPaymentData()
	}
	
	func primaryResultColor() -> UIColor {
		return ThemeManager.shared.successColor()
	}
	
	func setCallback(callback: @escaping (PaymentResult.CongratsState) -> Void) {
		self.callback = callback
	}
	
	func getPaymentStatus() -> String {
		return ""
	}
	
	func getPaymentStatusDetail() -> String {
		return ""
	}
	
	func getPaymentId() -> String? {
		return nil
	}
	
	func isCallForAuth() -> Bool {
		return false
	}
	
	func buildHeaderComponent() -> PXHeaderComponent {
		let productImage = ResourceManager.shared.getImage("card_icon")
		let statusImage = ResourceManager.shared.getImage("ok_badge")
		
		let props = PXHeaderProps(labelText: nil, title: NSAttributedString(string: "add_card_congrats_title".localized, attributes: [NSAttributedString.Key.font: UIFont.ml_regularSystemFont(ofSize: 26)]), backgroundColor: ThemeManager.shared.successColor(), productImage: productImage, statusImage: statusImage, closeAction: { [weak self] in
			if let callback = self?.callback {
				callback(PaymentResult.CongratsState.cancel_EXIT)
			}
		})
		let header = PXHeaderComponent(props: props)
		return header
	}
	
	func buildFooterComponent() -> PXFooterComponent {
		let buttonAction = PXAction(label: "add_card_go_to_my_cards".localized, action: self.buttonCallback)
		let props = PXFooterProps(buttonAction: buttonAction, linkAction: nil, primaryColor: UIColor.ml_meli_blue(), animationDelegate: nil)
		let footer = PXFooterComponent(props: props)
		return footer
	}
	
	func buildReceiptComponent() -> PXReceiptComponent? {
		return nil
	}
	
	func buildBodyComponent() -> PXComponentizable? {
		return nil
	}
	
	func buildTopCustomView() -> UIView? {
		return nil
	}
	
	func buildBottomCustomView() -> UIView? {
		return nil
	}
	
	func getTrackingProperties() -> [String: Any] {
		return [:]
	}
	
	func getTrackingPath() -> String {
		return ""
	}
	
	func getFooterPrimaryActionTrackingPath() -> String {
		return ""
	}
	
	func getFooterSecondaryActionTrackingPath() -> String {
		return ""
	}
	
	func getHeaderCloseButtonTrackingPath() -> String {
		return ""
	}
}

