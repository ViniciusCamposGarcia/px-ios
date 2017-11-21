//
//  PXResultViewController.swift
//  MercadoPagoSDK
//
//  Created by Demian Tejo on 20/10/17.
//  Copyright © 2017 MercadoPago. All rights reserved.
//

import UIKit

class PXResultViewController: PXComponentContainerViewController {

    let viewModel: PXResultViewModel
    var headerView = UIView()
    var fooView: UIView!
    var callback: (PaymentResult.CongratsState) -> Void

    init(viewModel: PXResultViewModel, callback : @escaping ( _ status: PaymentResult.CongratsState) -> Void) {
        self.callback = callback
        self.viewModel = viewModel
        super.init()
        self.scrollView.backgroundColor = viewModel.primaryResultColor()

    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func renderViews() {
        for view in contentView.subviews {
            view.removeFromSuperview()
        }
        //Add Header
        headerView = self.buildHeaderView()
        contentView.addSubview(headerView)
        MPLayout.pinTop(view: headerView, to: contentView).isActive = true
        MPLayout.equalizeWidth(view: headerView, to: contentView).isActive = true

        //Add Foo
        fooView = buildFooterView()
        contentView.addSubview(fooView)
        MPLayout.equalizeWidth(view: fooView, to: contentView).isActive = true
        MPLayout.pinBottom(view: fooView, to: contentView).isActive = true
        MPLayout.centerHorizontally(view: fooView, to: contentView).isActive = true
        self.view.layoutIfNeeded()
        MPLayout.setHeight(owner: fooView, height: fooView.frame.height).isActive = true
        
        //Add Body
        let bodyView = buildBodyView()
        contentView.addSubview(bodyView)
        bodyView.translatesAutoresizingMaskIntoConstraints = false
        MPLayout.equalizeWidth(view: bodyView, to: contentView).isActive = true
        MPLayout.put(view: bodyView, onBottomOf: headerView).isActive = true
        MPLayout.put(view: bodyView, aboveOf: fooView).isActive = true

        self.view.layoutIfNeeded()
        self.scrollView.contentSize = CGSize(width: self.scrollView.frame.width, height: self.contentView.frame.height)
    }

    func buildHeaderView() -> UIView {
        let dataHeader = self.viewModel.headerComponentData()
        let componentHeader = HeaderComponent(props: dataHeader)
        let rendererHeader = HeaderRenderer()
        return rendererHeader.render(header: componentHeader)
    }
    func buildFooterView() -> UIView {
        let action1 = FooterAction(label: "boton grande") {
            print("boton grande presionado")
        }
        
        let action2 = FooterAction(label: "boton link") {
            print("boton LINK presionado")
        }
        let dataFoo = FooterProps(buttonAction: action1, linkAction: action2)
        let componentFoo = FooterComponent(props: dataFoo)
        let rendererFoo = FooterRenderer()
        return rendererFoo.render(footer: componentFoo)
    }
    func buildBodyView() -> UIView {
        let instruc = Instruction()
        instruc.info = [
            "Primero sigue estos pasos en el cajero",
            "",
            "1. Ingresa a Pagos",
            "2. Pagos de impuestos y servicios",
            "3. Rubro cobranzas",
            "",
            "Luego te irá pidiendo estos datos"
        ]
        instruc.subtitle = "Paga con estos datos y con estos otros tambien, asi hay 2 renglones"
        instruc.secondaryInfo = ["También enviamos estos datos a tu email", "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc lacinia semper magna id commodo. Integer molestie ligula ut mauris sagittis dapibus. Aenean non enim blandit, rhoncus elit eu, ullamcorper elit. Nulla vitae venenatis elit. Praesent ac lorem accumsan, ultricies odio elementum, eleifend tellus. Donec vitae massa ornare, convallis urna id, posuere diam.", "También enviamos"]
        let refer1 = InstructionReference()
        refer1.label = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc lacinia semper magna id commodo"
        refer1.value = ["1234","1234","1234","1234","1234","1234","1234","1234","1234","1234","1234","1234","1234","1234","1234","1234","1234","1234","1234","1234","1234","1234","1234","1234"]
        refer1.separator = " "
        instruc.references = [refer1,refer1,refer1,refer1]
        let instruction = viewModel.instructionsInfo?.instructions[0]
        let dataBody = BodyProps(status: "ok", statusDetail: "masok", instruction: instruc, processingMode: "aggregator")
        let componentBody = BodyComponent(props: dataBody)
        let rendererBody = BodyRenderer()
        return rendererBody.render(body: componentBody)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self.navigationController != nil && self.navigationController?.navigationBar != nil {
            self.navigationController?.setNavigationBarHidden(true, animated: false)
            ViewUtils.addStatusBar(self.view, color: viewModel.primaryResultColor())
        }
        renderViews()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}
