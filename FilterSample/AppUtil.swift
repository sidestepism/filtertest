//
//  AppUtil.swift
//  Chattie
//
//  Created by 村上晋太郎 on 2016/02/07.
//  Copyright © 2016年 R. Fushimi and S. Murakami. All rights reserved.
//

import UIKit

class AppUtil: NSObject, UIAlertViewDelegate {
    
    class func alert(title: String?, message: String?) {
        // たまに落ちるのでとりあえずUIAlertViewに
        let alert = UIAlertView(title: title ?? "", message: message ?? "", delegate: AppUtil.shared, cancelButtonTitle: "OK")
        alert.show()
        NSLog(title ?? "")
        NSLog(message ?? "")
    }
    
    class func setTimeout(sec: Double, block: dispatch_block_t) {
        let delta: Int64 = Int64(sec * Double(NSEC_PER_SEC))
        let time = dispatch_time(DISPATCH_TIME_NOW, delta)
        dispatch_after(time, dispatch_get_main_queue(), block)
    }
    
    // メインスレッドで実行
    class func dispatchMain(block: dispatch_block_t) {
        setTimeout(0, block: block)
        
    }
    
    class func dateString() -> String {
        let formatter = NSDateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-hh-mm-ss-SSS"
        return formatter.stringFromDate(NSDate())
    }
    
    
    static let shared = AppUtil()
}
