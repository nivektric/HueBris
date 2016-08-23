//
//  GroupControlViewController.swift
//  HueBris
//
//  Created by Kevin Monahan on 8/21/16.
//  Copyright © 2016 Intrepid Pursuits. All rights reserved.
//

import Foundation
import UIKit

class GroupControlViewController: UIViewController {
    
    @IBOutlet private weak var onOffSwitch: UISwitch!
    @IBOutlet private weak var brightnessSlider: UISlider!
    @IBOutlet private weak var temperatureSlider: UISlider!
    
    let bridge = Bridge.sharedInstance
    
    let minCommandInterval: NSTimeInterval = 0.5
    var lastCommandDate: NSDate?
    
    var group: PHGroup!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let name = group.name else { return }
        
        title = name
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        brightnessSlider.value = group.lights.first?.lightState.brightnessPercent ?? 1
        onOffSwitch.on = group.lights.first?.lightState.on == 1 ?? false
        temperatureSlider.value = group.lights.first?.lightState.ctPercent ?? 1
    }
    
    @IBAction func sliderValueChanged(sender: UISlider) {
        if lastCommandDate == nil || NSDate().timeIntervalSinceDate(lastCommandDate!) >= minCommandInterval {
            lastCommandDate = NSDate()
            Bridge.sharedInstance.setBrightnessForGroup(group, brightnessPercent: sender.value)
        }
    }
    
    @IBAction func onOffStateChanged(sender: UISwitch) {
        Bridge.sharedInstance.setStateForGroup(group, state: {
            let state = PHLightState()
            state.on = sender.on
            return state
            }())
    }
    
    @IBAction func colorButtonTapped(sender: UIButton) {
        guard let model = group.lights.first,
            let color = sender.backgroundColor else { return }
        bridge.setStateForGroup(group, state: bridge.stateForColor(color, model: model.modelNumber))
    }
    
    @IBAction func temperatureValueChanged(sender: UISlider) {
        if lastCommandDate == nil || NSDate().timeIntervalSinceDate(lastCommandDate!) >= minCommandInterval {
            
            lastCommandDate = NSDate()
            bridge.setStateForGroup(group, state: {
                let state = PHLightState()
                state.ctPercent = sender.value
                return state
                }())
        }
    }
    
}
