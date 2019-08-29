//
//  PXNewResultHeader.swift
//  MercadoPagoSDK
//
//  Created by AUGUSTO COLLERONE ALFONSO on 28/08/2019.
//

import UIKit

struct PXNewResultHeaderData {
    let color: UIColor?
    let title: NSAttributedString?
    let icon: UIImage?
    let iconURL: String?
    let badgeImage: UIImage?
    let closeAction: (() -> Void)?
}

class PXNewResultHeader: UITableViewCell {

    var data: PXNewResultHeaderData?

    //Image
    let IMAGE_WIDTH: CGFloat = 45.0
    let IMAGE_HEIGHT: CGFloat = 45.0

    //Badge Image
    let BADGE_IMAGE_SIZE: CGFloat = 15.0
    let BADGE_HORIZONTAL_OFFSET: CGFloat = -6.0
    let BADGE_VERTICAL_OFFSET: CGFloat = 0.0

    //Close Button
    let CLOSE_BUTTON_SIZE: CGFloat = 35

    //Text
    static let TITLE_FONT_SIZE: CGFloat = PXLayout.L_FONT

    var iconImageView: PXUIImageView?
    var badgeImageView: PXAnimatedImageView?
    var closeButton: UIButton?
    var titleLabel: UILabel?

    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
        render()
        animate()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    func setData(data: PXNewResultHeaderData) {
        self.data = data

        render()
        animate()
    }

    func render() {
        removeAllSubviews()
        self.backgroundColor = data?.color
        let pxContentView = UIView()
        pxContentView.backgroundColor = .clear
        addSubview(pxContentView)
        PXLayout.pinAllEdges(view: pxContentView, withMargin: PXLayout.ZERO_MARGIN)
        PXLayout.setHeight(owner: pxContentView, height: 120).isActive = true

        //Image
        if let imageURL = data?.iconURL, imageURL.isNotEmpty {
            let pximage = PXUIImage(url: imageURL)
            iconImageView = buildCircleImage(with: pximage)
        } else {
            iconImageView = buildCircleImage(with: data?.icon)
        }
        if let circleImage = iconImageView {
            pxContentView.addSubview(circleImage)
            PXLayout.centerVertically(view: circleImage, withMargin: PXLayout.ZERO_MARGIN).isActive = true
            PXLayout.pinRight(view: circleImage, withMargin: PXLayout.L_MARGIN).isActive = true
        }

        //Badge Image
        let bagdeView = buildBadgeImage(with: data?.badgeImage)
        badgeImageView = bagdeView
        pxContentView.addSubview(bagdeView)
        PXLayout.pinRight(view: bagdeView, to: iconImageView!, withMargin: BADGE_HORIZONTAL_OFFSET).isActive = true
        PXLayout.pinBottom(view: bagdeView, to: iconImageView!, withMargin: BADGE_VERTICAL_OFFSET).isActive = true

        //Close button
        if let closeAction = data?.closeAction {
            let button = buildCloseButton()
            closeButton = button
            pxContentView.addSubview(button)
            button.add(for: .touchUpInside, {
//                headerView.delegate?.didTapCloseButton()
                closeAction()
            })
            PXLayout.setHeight(owner: button, height: CLOSE_BUTTON_SIZE).isActive = true
            PXLayout.setWidth(owner: button, width: CLOSE_BUTTON_SIZE).isActive = true
            PXLayout.pinTop(view: button, withMargin: PXLayout.ZERO_MARGIN).isActive = true
            PXLayout.pinLeft(view: button, withMargin: PXLayout.XXXS_MARGIN).isActive = true
        }

        //Title Label
        if let title = data?.title {
            let label = buildMessageLabel(with: title)
            titleLabel = label
            pxContentView.addSubview(label)

            PXLayout.centerVertically(view: label, withMargin: PXLayout.ZERO_MARGIN).isActive = true
            PXLayout.pinLeft(view: label, withMargin: PXLayout.M_MARGIN).isActive = true

            if let iconImageView = iconImageView {
                PXLayout.put(view: label, leftOf: iconImageView, withMargin: PXLayout.S_MARGIN, relation: .equal).isActive = true
            } else {
                PXLayout.pinRight(view: label, withMargin: PXLayout.M_MARGIN).isActive = true
            }
        }

        self.layoutIfNeeded()
    }

    func buildBadgeImage(with image: UIImage?) -> PXAnimatedImageView {
        let imageView = PXAnimatedImageView(image: image, size: CGSize(width: BADGE_IMAGE_SIZE, height: BADGE_IMAGE_SIZE))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }

    func buildCloseButton() -> UIButton {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        let image = ResourceManager.shared.getImage("close-button")
        let margin: CGFloat = PXLayout.XS_MARGIN
        button.contentEdgeInsets = UIEdgeInsets(top: margin, left: margin, bottom: margin, right: margin)
        button.setImage(image, for: .normal)
        button.accessibilityIdentifier = "result_close_button"
        return button
    }

    func buildCircleImage(with image: UIImage?) -> PXUIImageView {
        let circleImage = PXUIImageView(frame: CGRect(x: 0, y: 0, width: IMAGE_WIDTH, height: IMAGE_HEIGHT))
        circleImage.layer.masksToBounds = false
        circleImage.layer.cornerRadius = circleImage.frame.height / 2
        circleImage.clipsToBounds = true
        circleImage.translatesAutoresizingMaskIntoConstraints = false
        circleImage.enableFadeIn()
        circleImage.contentMode = .scaleAspectFill
        circleImage.image = image
        circleImage.backgroundColor = .clear
        PXLayout.setHeight(owner: circleImage, height: IMAGE_WIDTH).isActive = true
        PXLayout.setWidth(owner: circleImage, width: IMAGE_HEIGHT).isActive = true
        return circleImage
    }

    func buildMessageLabel(with text: NSAttributedString) -> UILabel {
        let messageLabel = UILabel()
        messageLabel.textAlignment = .left
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.attributedText = text
        messageLabel.textColor = .white
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.numberOfLines = 2
        messageLabel.lineBreakMode = .byTruncatingTail
        return messageLabel
    }

    func animate() {
        badgeImageView?.animate(duration: 0.2)
    }

}