//
//  Settings.swift
//  HueBris
//
//  Created by Kevin Monahan on 8/4/16.
//  Copyright © 2016 Intrepid Pursuits. All rights reserved.
//

import Foundation

class Bridge: NSObject {

    static let sharedInstance = Bridge()

    private let bridgeIDKey = "bridgeID"
    private let bridgeIPKey = "bridgeIP"
    private let authenticatedKey = "authenticated"
    private let defaults = NSUserDefaults.standardUserDefaults()

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
        sdk.setBridgeToUseWithId(bridgeID, ipAddress: bridgeIP)
    }

    func setAllLightsToColor(color: UIColor) {
        allLights().forEach { self.setState($0, state: self.stateForColor(color, model: $0.modelNumber)) }
    }

    func setAllLightsOn(on: Bool) {
        allLights().forEach { self.setState($0, state: self.stateForOn(on)) }
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

    func setState(light: PHLight, state: PHLightState) {
        print("settingState = \(state)")
        let api = PHBridgeSendAPI()
        api.updateLightStateForId(light.identifier, withLightState: state) { (response) in
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
            self.bridgeID = key
            self.bridgeIP = value

            self.sdk.setBridgeToUseWithId(key, ipAddress: value)

            let manager = PHNotificationManager.defaultManager()
            manager.registerObject(self, withSelector: #selector(self.authSuccess), forNotification: PUSHLINK_LOCAL_AUTHENTICATION_SUCCESS_NOTIFICATION)
            manager.registerObject(self, withSelector: #selector(self.authFailure), forNotification: PUSHLINK_LOCAL_AUTHENTICATION_FAILED_NOTIFICATION)
            manager.registerObject(self, withSelector: #selector(self.pushlinkNoLocalConnection), forNotification: PUSHLINK_NO_LOCAL_CONNECTION_NOTIFICATION)
            manager.registerObject(self, withSelector: #selector(self.noLocalBridge), forNotification: PUSHLINK_NO_LOCAL_BRIDGE_KNOWN_NOTIFICATION)
            manager.registerObject(self, withSelector: #selector(self.buttonNotPressed), forNotification: PUSHLINK_BUTTON_NOT_PRESSED_NOTIFICATION)
            
            self.sdk.startPushlinkAuthentication()
        }
        
    }

    func authSuccess() {
        print("authSuccess")
        authenticated = true
        authenticatedCallback?()

        let manager = PHNotificationManager.defaultManager()
        manager.registerObject(self, withSelector: #selector(localConnection), forNotification: LOCAL_CONNECTION_NOTIFICATION)
        manager.registerObject(self, withSelector: #selector(noLocalConnection), forNotification: NO_LOCAL_CONNECTION_NOTIFICATION)
        manager.registerObject(self, withSelector: #selector(notAuthenticated), forNotification: NO_LOCAL_AUTHENTICATION_NOTIFICATION)

        sdk.enableLocalConnection()
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

    }

    func noLocalConnection() {
        print("noLocalConnection")
    }

    func notAuthenticated() {
        print("notAuthenticated")
    }

}