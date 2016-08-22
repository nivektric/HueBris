//
//  ViewController.swift
//  HueBris
//
//  Created by Kevin Monahan on 7/29/16.
//  Copyright © 2016 Intrepid Pursuits. All rights reserved.
//

import UIKit

class OnboardViewController: UIViewController {

    @IBOutlet weak var findBridgeButton: UIButton!
    @IBOutlet weak var offButton: UIButton!
    @IBOutlet weak var onButton: UIButton!
    @IBOutlet weak var redButton: UIButton!
    @IBOutlet weak var greenButton: UIButton!
    @IBOutlet weak var blueButton: UIButton!
    @IBOutlet weak var findingBridgeLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    var bridgeSearch: PHBridgeSearching?
    let bridge = Bridge.sharedInstance

    override func viewDidLoad() {
        super.viewDidLoad()
        activityIndicator.startAnimating()
        bridge.findBridge(
            found: {
                self.findingBridgeLabel.text = "Please press the button..."
            },
            authenticated: {
                self.activityIndicator.stopAnimating()

                let sb = UIStoryboard(name: "Dashboard", bundle: nil)
                let vc = sb.instantiateInitialViewController()

                let delegate = UIApplication.sharedApplication().delegate as! AppDelegate
                delegate.window?.rootViewController = vc
            },
            error: { error in
                self.activityIndicator.stopAnimating()
                self.findingBridgeLabel.text = error
            }
        )
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

