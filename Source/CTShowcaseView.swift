//
//  CTShowcaseView.swift
//  CTShowcase
//
//  Created by Cihan Tek on 17/12/15.
//  Copyright © 2015 Cihan Tek. All rights reserved.
//

import UIKit

/// A class that highligts a given view in the layout
@objcMembers
open class CTShowcaseView: UIView {

    private struct CTGlobalConstants {
        static let DefaultAnimationDuration = 0.5
    }
    
    public struct ButtonConstants {
        /// Title of the dismiss button
        public static let dismissTitle: String = "X"
        /// Margin from the top of the screen to the buttons
        public static let topMargin: CGFloat = 50.0
        /// Margin from the left-right side of the screen to the buttons
        public static let lateralMargin: CGFloat = 25.0
        /// Width and height of the dismiss button
        public static let buttonsHeight: CGFloat = 40.0
        /// Font size of the button titles
        public static let fontSize: CGFloat = 18.0
        /// Corner radius for the dismiss button, dividing side length by two gives a circle
        public static let cornerRadius: CGFloat = buttonsHeight / 2
        /// Width of the action button
        public static let actionButtonWidth: CGFloat = 80.0
    }

    // MARK: Properties
   
    /// Label used to display the title
    public let titleLabel: UILabel
    
    // Label used to display the message
    public let messageLabel: UILabel
    
    // Highlighter object that creates the highlighting effect
    public var highlighter: CTRegionHighlighter = CTStaticGlowHighlighter()
    
    /// X button at the top-right
    public var dismissButton: UIButton?
    
    /// Custom button at the top-left
    public var actionButton: UIButton?
    
    private let containerView: UIView = UIApplication.shared.keyWindow!
    private var targetView: UIView?
    private var targetRect: CGRect = CGRect.zero
    
    private var willShow = true
    private var title = "title"
    private var message = "message"
    private var key: String?
    private var dismissHandler: (() -> ())?
    private var tapInsideHandler: (() -> ())?
    private var hasDismissButton: Bool = false
    
    private var targetOffset = CGPoint.zero
    private var targetMargin: CGFloat = 0
    private var effectLayer : CALayer?
    
    private var previousSize = CGSize.zero
    private var observing = false
    
    private var dismissButtonRect: CGRect {
        typealias Constants = ButtonConstants
        return CGRect(x: containerView.frame.size.width - Constants.lateralMargin - Constants.buttonsHeight,
                      y: Constants.topMargin,
                      width: Constants.buttonsHeight,
                      height: Constants.buttonsHeight)
    }
    
    private var actionButtonRect: CGRect {
        typealias Constants = ButtonConstants
        return CGRect(x: Constants.lateralMargin,
                      y: Constants.topMargin,
                      width: 80.0,
                      height: Constants.buttonsHeight)
    }
    
    // MARK: Class lifecyle
    
    /**
    Setup showcase to highlight a view on the screen
    
    - parameter title: Title to display in the showcase
    - parameter message: Message to display in the showcase
    */
    public convenience init(title: String, message: String) {
        self.init(title: title, message: message, key: nil, dismissHandler: nil)
    }
    
    /**
    Setup showcase to highlight a view on the screen
    
    - parameter title: Title to display in the showcase
    - parameter message: Message to display in the showcase
    - parameter key: An optional key to prevent the showcase from getting displayed again if it was displayed before
    - parameter dismissHandler: An optional handler to be executed after the showcase is dismissed by tapping outside
                                If `showsDismissButton` is set to true, this will be executed when tapping the button.
    - parameter tapInsideHandler: An optional handler to be executed after the showcase is dismissed by tapping inside
    - parameter showsDismissButton: Whether to show a Dismiss button at the top-right of the screen
    */
    public init(title: String,
                message: String,
                key: String?,
                dismissHandler: (() -> Void)?,
                tapInsideHandler: (()->Void)? = nil) {

        titleLabel = UILabel(frame: CGRect.zero)
        messageLabel = UILabel(frame: CGRect.zero)

        super.init(frame: CGRect.zero)
        
        if let storageKey = key, let _ = UserDefaults.standard.object(forKey: storageKey) {
            willShow = false
            return
        }
    
        self.title = title
        self.message = message
        self.key = key
        self.dismissHandler = dismissHandler
        self.tapInsideHandler = tapInsideHandler
        
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.75)
        
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = true
        titleLabel.textColor = UIColor.white
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textAlignment = .center
        titleLabel.text = title
        addSubview(titleLabel)
        
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = true
        messageLabel.textColor = UIColor.lightGray
        messageLabel.font = UIFont.boldSystemFont(ofSize: 18)
        messageLabel.textAlignment = .center
        messageLabel.text = message
        addSubview(messageLabel)
        
        NotificationCenter.default.addObserver(self, selector: #selector(CTShowcaseView.enteredForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented. Should be instantiated from code.")
    }

    deinit {
        if observing {
            targetView?.removeObserver(self, forKeyPath: "frame")
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: Client interface

    /**
    Setup showcase to highlight a view on the screen
    
    - parameter view: View to highlight
    - parameter offset: The offset to apply to the highlight relative to the views location
    - parameter margin: Distance between the highlight border and the view
    */
    @objc(setupForView:offset:margin:)
    public func setup(for view: UIView, offset: CGPoint, margin: CGFloat) {
        guard willShow == true else {return}
        
        targetView = view
        targetOffset = offset
        targetMargin = margin
        
        guard let targetView = targetView else {return}
        
        targetRect = targetView.convert(targetView.bounds, to: containerView)
        targetRect = targetRect.offsetBy(dx: offset.x, dy: offset.y)
        targetRect = targetRect.insetBy(dx: -margin, dy: -margin)
        
        // If less than %75 of the target area is inside the container, dismiss the showcase automatically
        let overlapRegion = containerView.bounds.intersection(targetRect)
        let overlapSize = overlapRegion.width * overlapRegion.height
        let targetSize = targetRect.width * targetRect.height
        
        if overlapSize/targetSize < 0.75 {
            dismiss(withHandler: false)
            return
        }
        
        let (titleRegion, messageRegion) = textRegionsForHighlightedRect(targetRect)
        
        titleLabel.frame = titleRegion
        messageLabel.frame = messageRegion

        updateEffectLayer()
        setNeedsDisplay()
        
        // If the frame of the targetView changes, the showcase needs to be updated accordingly
        if !observing {
            targetView.addObserver(self, forKeyPath: "frame", options: .init(rawValue: 0), context: nil)
            observing = true
        }
    }

    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        setup(for: targetView!, offset: targetOffset, margin: targetMargin)
    }
    
    /**
    Setup showcase to highlight a view on the screen with no offset and margin
     
    - parameter view: View to highlight
    */
    @objc(setupForView:)
    public func setup(for view: UIView) {
        setup(for: view, offset: targetOffset, margin: targetMargin)
    }
    
    /**
    Setup showcase to highlight a UIBarButtonItem on the screen
     
     - parameter barButtonItem: UIBarButtonItem to highlight
     - parameter offset: The offset to apply to the highlight relative to the views location
     - parameter margin: Distance between the highlight border and the view
     */
    @objc(setupForBarButtonItem:offset:margin:)
    public func setup(for barButtonItem: UIBarButtonItem, offset: CGPoint, margin: CGFloat) {
        if let view = barButtonItem.value(forKey: "view") as? UIView {
            setup(for: view, offset: offset, margin: margin)
        }
    }
    
    /**
    Setup showcase to highlight a UIBarButtonItem with no offset and margin
     
    - parameter barButtonItem: UIBarButtonItem to highlight
    */
    @objc(setupForBarButtonItem:)
    public func setup(for barButtonItem: UIBarButtonItem) {
        setup(for: barButtonItem, offset: targetOffset, margin: targetMargin)
    }
    
    
    /// Displays the showcase. The showcase needs to be setup before calling this method using one of the setup methods
    public func show() {
        guard willShow == true else {return}
        
        containerView.addSubview(self)
        
        let views = ["self": self]
        var constraints = NSLayoutConstraint.constraints(withVisualFormat: "|[self]|", options: NSLayoutConstraint.FormatOptions(), metrics: nil, views: views)
        constraints += NSLayoutConstraint.constraints(withVisualFormat: "V:|[self]|", options: NSLayoutConstraint.FormatOptions(), metrics: nil, views: views)
        containerView.addConstraints(constraints)
        
        // Show the showcase with a fade-in animation
        alpha = 0
        UIView.animate(withDuration: CTGlobalConstants.DefaultAnimationDuration, animations: { () -> () in
            self.alpha = 1
        }) 
        
        // Mark the showcase as "displayed" if needed
        if let storageKey = key {
            UserDefaults.standard.set(true, forKey: storageKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    @objc private func dismissWithHandler() {
        self.dismiss(withHandler: true)
    }
    
    @objc open func dismiss(withHandler: Bool = true) {
        UIView.animate(withDuration: CTGlobalConstants.DefaultAnimationDuration, animations: { () -> Void in
            self.alpha = 0
        }, completion: { (finished) -> Void in
            self.removeFromSuperview()
            if withHandler {
                self.dismissHandler?()
            }
        })
    }
    
    /// Adds a dismiss button at the top-right of the view.
    /// - Parameter title: default is "X"
    open func addDismissButton(title: String = ButtonConstants.dismissTitle) {
        let dismissButton = UIButton(frame: self.dismissButtonRect)
        dismissButton.setTitleColor(backgroundColor, for: .normal)
        dismissButton.backgroundColor = .white
        dismissButton.setTitle(ButtonConstants.dismissTitle, for: .normal)
        dismissButton.titleLabel?.font = .boldSystemFont(ofSize: ButtonConstants.fontSize)
        dismissButton.layer.cornerRadius = ButtonConstants.cornerRadius
        dismissButton.addTarget(self, action: #selector(dismissWithHandler), for: .touchDown)
        self.dismissButton = dismissButton
        self.hasDismissButton = true
        addSubview(dismissButton)
    }
    
    /// Adds an action button at the top-left of the view.
    /// - Parameters:
    ///   - title: Title of the button
    ///   - target: target class
    ///   - selector: selector to hit
    open func addActionButton(title: String, target: Any, selector: Selector) {
        let actionButton = UIButton(frame: self.actionButtonRect)
        actionButton.setTitleColor(backgroundColor, for: .normal)
        actionButton.backgroundColor = .white
        actionButton.setTitle(title, for: .normal)
        actionButton.titleLabel?.font = .boldSystemFont(ofSize: ButtonConstants.fontSize)
        actionButton.layer.cornerRadius = ButtonConstants.cornerRadius
        actionButton.addTarget(target, action: selector, for: .touchDown)
        actionButton.addTarget(self, action: #selector(dismiss), for: .touchDown)
        self.actionButton = actionButton
        addSubview(actionButton)
    }

    // MARK: Private methods
    
    private func updateEffectLayer() {
        // Remove the effect layer if exists
        effectLayer?.removeFromSuperlayer()
        
        // Add a new one if the new highlighter provides one
        if let layer = highlighter.layer(for: targetRect){
            self.layer.addSublayer(layer)
            effectLayer = layer
        }
    }
    
    private func textRegionsForHighlightedRect(_ rect: CGRect) -> (CGRect, CGRect) {
    
        var horizontalMargin: CGFloat = 15.0
        let verticalMargin: CGFloat = 15.0
        
        // Handles the "notch" on iPhone X-like devices, adding some additional horizontal margin.
        if #available(iOS 11.0, *),
            let leftInset = UIApplication.shared.keyWindow?.safeAreaInsets.left, leftInset > 0 {
            horizontalMargin += leftInset
        }
        
        let spacingBetweenTitleAndText: CGFloat = 10.0
        
        let titleSize = titleLabel.sizeThatFits(CGSize(width: containerView.frame.size.width - 2 * horizontalMargin,
                                                       height: CGFloat.greatestFiniteMagnitude))
        let messageSize = messageLabel.sizeThatFits(CGSize(width: containerView.frame.size.width - 2 * horizontalMargin,
                                                           height: CGFloat.greatestFiniteMagnitude))
        
        let textRegionWidth = containerView.frame.size.width - 2 * horizontalMargin
        let textRegionHeight = titleSize.height + messageSize.height + spacingBetweenTitleAndText
    
        let spacingBelowHighlight = containerView.frame.size.height - targetRect.origin.y - targetRect.size.height
        var originY :CGFloat
        
        // If there is more space above the highlight than below, then display the text above the highlight, else display it below
        if (targetRect.origin.y > spacingBelowHighlight) {
            originY = targetRect.origin.y - textRegionHeight - verticalMargin * 2
        } else {
            originY = targetRect.origin.y + targetRect.size.height + verticalMargin * 2
        }
        
        let titleRegion = CGRect(x: horizontalMargin,
                                 y: originY,
                                 width: textRegionWidth,
                                 height: titleSize.height)
        let messageRegion = CGRect(x: horizontalMargin,
                                   y: originY + spacingBetweenTitleAndText + titleSize.height,
                                   width: textRegionWidth,
                                   height: messageSize.height)
   
        return (titleRegion, messageRegion)
    }
    
    // MARK: Overridden methods
    
    override open func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let ctx = UIGraphicsGetCurrentContext() else {return}

        // Draw the highlight using the given highlighter
        highlighter.draw(on: ctx, rect: targetRect)
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        
        // Don't do anything unless the bounds have changed
        guard bounds.size.width != previousSize.width || bounds.size.height != previousSize.height else { return }
        
        if let targetView = targetView {
            setup(for: targetView)
            setNeedsDisplay()
        }
        previousSize = bounds.size
    }
    
    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Was a tapInsideHandler set and was the touch inside the highlighted area?
        // If so, run the handler and then dismiss this view.
        if let tapInsideHandler = self.tapInsideHandler,
            let touch = touches.first, isTouchInsideTargetView(touch.location(in: targetView)) {
            tapInsideHandler()
            dismiss(withHandler: false)
            return
        }
        
        // If the dismiss button was enabled, this touch event should be ignored because
        // only the button target can dismiss the view.
        guard !self.hasDismissButton else {
            NSLog("Ignoring touch as the dismiss button is enabled.")
            return
        }
        
        dismiss()
    }
    
    private func isTouchInsideTargetView(_ coordinates: CGPoint) -> Bool {
        return self.targetView?.point(inside: coordinates, with: nil) ?? false
    }
    
    // MARK: Notification handler
    
    @objc public func enteredForeground() {
        updateEffectLayer()
    }
}


