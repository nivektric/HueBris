//
//  Settings.swift
//  HueBris
//
//  Created by Kevin Monahan on 8/4/16.
//  Copyright © 2016 Intrepid Pursuits. All rights reserved.
//

import Foundation

extension PHLightState {
    
    private var minBrightness: Int { return 0 }
    private var maxBrightness: Int { return 254 }
    
    var brightnessPercent: Float {
        get {
            return Float(Int(brightness) - minBrightness) / Float(maxBrightness - minBrightness)
        }
        set {
            brightness = minBrightness + Int(Float(maxBrightness - minBrightness) * newValue)
        }
    }
    
    private var minCT: Int { return 153 }
    private var maxCT: Int { return 454 }
    
    var ctPercent: Float {
        get {
            return Float(Int(ct) - minCT) / Float(maxCT - minCT)
        }
        set {
            ct = minCT + Int(Float(maxCT - minCT) * newValue)
        }
    }
    
}

extension PHGroup {
    
    var identifiers: [String] {
        return lightIdentifiers.flatMap{ $0 as? String }
    }
    
    var lights: [PHLight] {
        return Bridge.sharedInstance.allLights().filter { self.identifiers.contains($0.identifier) }
    }
    
}

class Bridge: NSObject {
    
    private struct PendingCommand {
        
        let sendDate: NSDate
        var state: PHLightState
        
        
    }

    static let GroupsUpdatedNotification = "HueGroupsUpdatedNotification"
    
    static let sharedInstance = Bridge()

    private let bridgeIDKey = "bridgeID"
    private let bridgeIPKey = "bridgeIP"
    private let authenticatedKey = "authenticated"
    private let defaults = NSUserDefaults.standardUserDefaults()
    
    
    
    private var pendingStatesByGroup = [PHGroup : PHLightState]()

    let sdk: PHHueSDK = {
        var sdk = PHHueSDK()
        sdk.enableLogging(true)
        sdk.startUpSDK()
        return sdk
    }()

    var bridgeID: String? {
        get {
            return defaults.stringForKey(bridgeIDKey)
        }
        set {
            defaults.setValue(newValue, forKey: bridgeIDKey)
        }

    }

    var bridgeIP: String? {
        get {
            return defaults.stringForKey(bridgeIPKey)
        }
        set {
            defaults.setValue(newValue, forKey: bridgeIPKey)
        }
    }

    var authenticated: Bool {
        get {
            return defaults.boolForKey(authenticatedKey)
        }
        set {
            defaults.setBool(newValue, forKey: authenticatedKey)
        }
    }

    func connect(done: () -> ()) {
        guard let id = bridgeID, let ip = bridgeIP else { return }
        
        setupConnection(id, ip: ip)
        finishSetupConnection()
    }

    func setAllLightsToColor(color: UIColor) {
        allLights().forEach { self.setState($0, state: self.stateForColor(color, model: $0.modelNumber)) }
    }

    func setAllLightsOn(on: Bool) {
        allLights().forEach { self.setState($0, state: self.stateForOn(on)) }
    }
    
    func setBrightnessForGroup(group: PHGroup, brightnessPercent: Float) {
        setStateForGroup(group, state: stateForBrightnessPercent(brightnessPercent))
    }

    func allLights() -> [PHLight] {
        var lights = [PHLight]()
        for light in PHBridgeResourcesReader.readBridgeResourcesCache().lights.values {
            if let light = light as? PHLight {
                lights.append(light)
            }
        }
        return lights
    }
    
    func allGroups() -> [PHGroup] {
        var groups = [PHGroup]()
        
        // This isn't marked as optional but still sometimes comes back as nil
        guard let groupDictionary = PHBridgeResourcesReader.readBridgeResourcesCache().groups else { return [] }
        
        for group in groupDictionary.values {
            if let group = group as? PHGroup {
                groups.append(group)
            }
        }
        return groups
    }


    func stateForColor(color: UIColor, model: String) -> PHLightState {
        let state = PHLightState()
        let coord = PHUtilities.calculateXY(color, forModel: model)
        state.x = coord.x
        state.y = coord.y
        state.ct = 500
        state.on = true
        return state
    }

    func stateForOn(on: Bool) -> PHLightState {
        let state = PHLightState()
        state.on = on
        return state
    }
    
    func stateForBrightnessPercent(brightnessPercent: Float) -> PHLightState {
        let state = PHLightState()
        state.brightnessPercent = brightnessPercent
        return state
    }

    func setState(light: PHLight, state: PHLightState) {
        print("settingState = \(state)")
        let api = PHBridgeSendAPI()
        api.updateLightStateForId(light.identifier, withLightState: state) { response in
            print("Response: \(response)")
        }
    }
    
    func setStateForGroup(group: PHGroup, state: PHLightState) {
        
        print("settingState for group: \(group), state: \(state)")
        let api = PHBridgeSendAPI()
        
        api.setLightStateForGroupWithId(group.identifier, lightState: state) { response in
            print("Response: \(response)")
        }
    }
    
    

    // MARK: - SDK

    private var authenticatedCallback: (() -> ())?
    private var errorCallback: ((String) -> ())?

    func findBridge(found found: () -> (), authenticated: () -> (), error: (String) -> ()) {
        authenticatedCallback = authenticated
        errorCallback = error
        let bridgeSearch = PHBridgeSearching(upnpSearch: true, andPortalSearch: true, andIpAdressSearch: false)
        bridgeSearch.startSearchWithCompletionHandler { (dict) in
            print("Received bridges: \(dict)")

            guard let key = dict.keys.first as? String,
                let value = dict[key] as? String
                where dict.keys.count > 0 else {
                    error("Error - no bridge found.")
                    return
            }

            found()
            self.setupConnection(key, ip: value)

            let manager = PHNotificationManager.defaultManager()
            manager.registerObject(self, withSelector: #selector(self.authSuccess), forNotification: PUSHLINK_LOCAL_AUTHENTICATION_SUCCESS_NOTIFICATION)
            manager.registerObject(self, withSelector: #selector(self.authFailure), forNotification: PUSHLINK_LOCAL_AUTHENTICATION_FAILED_NOTIFICATION)
            manager.registerObject(self, withSelector: #selector(self.pushlinkNoLocalConnection), forNotification: PUSHLINK_NO_LOCAL_CONNECTION_NOTIFICATION)
            manager.registerObject(self, withSelector: #selector(self.noLocalBridge), forNotification: PUSHLINK_NO_LOCAL_BRIDGE_KNOWN_NOTIFICATION)
            manager.registerObject(self, withSelector: #selector(self.buttonNotPressed), forNotification: PUSHLINK_BUTTON_NOT_PRESSED_NOTIFICATION)
            self.sdk.startPushlinkAuthentication()
        }
        
    }
    
    private func setupConnection(id: String, ip: String) {
        bridgeID = id
        bridgeIP = ip
        sdk.setBridgeToUseWithId(bridgeID, ipAddress: bridgeIP)
        
        let manager = PHNotificationManager.defaultManager()
        manager.registerObject(self, withSelector: #selector(self.groupsUpdated), forNotification: GROUPS_CACHE_UPDATED_NOTIFICATION)
    }
    
    private func finishSetupConnection() {
        let manager = PHNotificationManager.defaultManager()
        manager.registerObject(self, withSelector: #selector(localConnection), forNotification: LOCAL_CONNECTION_NOTIFICATION)
        manager.registerObject(self, withSelector: #selector(noLocalConnection), forNotification: NO_LOCAL_CONNECTION_NOTIFICATION)
        manager.registerObject(self, withSelector: #selector(notAuthenticated), forNotification: NO_LOCAL_AUTHENTICATION_NOTIFICATION)
        
        sdk.enableLocalConnection()
    }

    func authSuccess() {
        print("authSuccess")
        authenticated = true
        authenticatedCallback?()

        finishSetupConnection()
    }

    func authFailure() {
        errorCallback?("Failed to authenticate with bridge")
    }

    func pushlinkNoLocalConnection() {
        print("noLocalConnection")
    }

    func noLocalBridge() {
        print("noLocalBridge")
    }

    func buttonNotPressed() {
        errorCallback?("Button wasn't pressed")
        print("buttonNotPressed")
    }

    func localConnection() {
        print("localConnection")
        groupsUpdated()
    }

    func noLocalConnection() {
        print("noLocalConnection")
    }

    func notAuthenticated() {
        print("notAuthenticated")
    }
    
    func groupsUpdated() {
        NSNotificationCenter.defaultCenter().postNotificationName(Bridge.GroupsUpdatedNotification, object: self)
    }

}