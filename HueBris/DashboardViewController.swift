//
//  DashboardViewController.swift
//  HueBris
//
//  Created by Kevin Monahan on 8/4/16.
//  Copyright © 2016 Intrepid Pursuits. All rights reserved.
//

import Foundation

class DashboardViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        Bridge.sharedInstance.connect { 
            print("Done!")
        }
    }
    
    @IBAction func allRed(sender: AnyObject) {
        Bridge.sharedInstance.setAllLightsToColor(UIColor.redColor())
    }

}