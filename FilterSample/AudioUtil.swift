//
//  AudioUtil.swift
//  Chattie
//
//  Created by 村上晋太郎 on 2016/02/02.
//  Copyright © 2016年 村上晋太郎. All rights reserved.
//

// AudioSessionまわりのオペレーションをwrapする。
// 将来的にはAudioEngineManagerと統合してもいいかもしれない。

import UIKit
import AVFoundation

class AudioUtil: NSObject {
    static var UseBluetooth = true
    
    var changeRounteCompletion: (() -> Void)?
    override init() {
        super.init()
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: "routeChanged",
            name: AVAudioSessionRouteChangeNotification,
            object: nil)
    }
    
    func routeChanged() {
        NSLog("routeChaged")
        if let comp = changeRounteCompletion {
            comp()
            changeRounteCompletion = nil
        }
        AudioEngineManager.shared.startEngine()
    }
    
    class func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            if UseBluetooth {
                try audioSession.setCategory(
                    AVAudioSessionCategoryPlayAndRecord,
                    withOptions: AVAudioSessionCategoryOptions.AllowBluetooth)
            } else {
                try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
            }
            
            try audioSession.setActive(true)
        } catch {
            print("setting up audio session failed...")
            print(error)
        }
    }
    
    class func getPortOfType(portType: String) -> AVAudioSessionPortDescription? {
        let audioSession = AVAudioSession.sharedInstance()
        if let inputs: [AVAudioSessionPortDescription] = audioSession.availableInputs {
            for port: AVAudioSessionPortDescription in inputs {
                if port.portType == portType {
                    return port
                }
            }
        }
        return nil
    }
    
    class func setInputToBluetooth(completion: (() -> Void)? = nil) {
        if UseBluetooth {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                if let bluetoothHFP = AudioUtil.getPortOfType(AVAudioSessionPortBluetoothHFP) {
                    shared.changeRounteCompletion = completion
                    try audioSession.setPreferredInput(bluetoothHFP)
                } else {
                    AppUtil.alert("ERROR", message: "CHAPPETが見つかりません。iphoneモードで起動します。")
                    UseBluetooth = false
                    if let completion = shared.changeRounteCompletion {
                        completion()
                        shared.changeRounteCompletion = nil
                    }
                }
            } catch {
                AppUtil.alert("ERROR", message: "Faild to change route: 音声入出力デバイスの切り替えに失敗しました。")
                shared.changeRounteCompletion = nil
                print(error)
            }
        } else {
            if let comp = completion {
                comp()
                shared.changeRounteCompletion = nil
            }
        }
    }
    
    class func setInputToBuiltInMic(completion: (() -> Void)? = nil ) {
        if UseBluetooth {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                if let builtInMicPort = AudioUtil.getPortOfType(AVAudioSessionPortBuiltInMic) {
                    shared.changeRounteCompletion = completion
                    try audioSession.setPreferredInput(builtInMicPort)
                    // 不安定にになるので一旦コメントアウト
                    //                try audioSession.overrideOutputAudioPort(AVAudioSessionPortOverride.Speaker)
                } else {
                    AppUtil.alert("ERROR", message: "BuiltInMicPort not found: 内蔵マイクが見つかりません。")
                }
            } catch {
                AppUtil.alert("ERROR", message: "Faild to change route: 音声入出力デバイスの切り替えに失敗しました。")
                shared.changeRounteCompletion = nil
                print(error)
            }
        } else {
            if let comp = completion {
                comp()
                shared.changeRounteCompletion = nil
            }
        }
    }
    
    class var recordingURL: NSURL {
        get {
            // 録音用URLを設定
            let dirURL = documentsDirectoryURL()
            let fileName = "recording.caf"
            return dirURL.URLByAppendingPathComponent(fileName)
        }
    }
    
    class func documentsDirectoryURL() -> NSURL {
        let urls = NSFileManager.defaultManager().URLsForDirectory(NSSearchPathDirectory.DocumentDirectory, inDomains: NSSearchPathDomainMask.UserDomainMask)
        if urls.isEmpty {
            fatalError("URLs for directory are empty.")
        }
        return urls[0]
    }
    
    static let shared = AudioUtil()
}
