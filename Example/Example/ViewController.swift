//
//  ViewController.swift
//  CTShowcase
//
//  Created by Cihan Tek on 17/12/15.
//  Copyright © 2015 Cihan Tek. All rights reserved.
//

import UIKit
import CTShowcase

class ViewController: UIViewController {

    @IBOutlet weak var button: UIButton!
    
    override func viewDidAppear(_ animated: Bool) {
        let showcase = CTShowcaseView(title: "New Feature!",
                                      message: "Here's a brand new button you can tap!",
                                      key: nil,
                                      dismissHandler: { () -> Void in
                                        print("Dismiss handler")
        },
                                      tapInsideHandler: { () -> Void in
                                        print("Tap inside handler")
        })
        showcase.addDismissButton()
        showcase.addActionButton(title: "Next", target: self, selector: #selector(test))
        
        let highlighter = CTDynamicGlowHighlighter()
        highlighter.highlightColor = UIColor.yellow
        highlighter.animDuration = 0.5
        highlighter.glowSize = 5
        highlighter.maxOffset = 10
        
        
        showcase.highlighter = highlighter
        showcase.titleLabel.textAlignment = .left
        showcase.messageLabel.textAlignment = .left
        showcase.setup(for: self.button, offset: CGPoint.zero, margin: 0)
        showcase.show()
    }
    
    @objc private func test() {
        NSLog("pressed next")
    }
}

