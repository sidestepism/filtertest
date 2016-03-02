//
//  UIView+parentViewController.swift
//  Chappet
//
//  Created by 村上晋太郎 on 2016/02/23.
//  Copyright © 2016年 R. Fushimi and S. Murakami. All rights reserved.
//

import Foundation
import UIKit

extension UIView {
    var parentViewController: UIViewController? {
        var parentResponder: UIResponder? = self
        while parentResponder != nil {
            parentResponder = parentResponder!.nextResponder()
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
        }
        return nil
    }
}

extension UICollectionViewCell {
    var collectionView: UICollectionView? {
        var superview = self.superview
        
        while let view = superview {
            if let cview = view as? UICollectionView {
                return cview
            }
            superview = view.superview
        }
        return nil
    }
}

extension UIColor {
    convenience init(hex: String, alpha: CGFloat = 1) {
        let hexStr = hex.stringByReplacingOccurrencesOfString("#", withString: "")
        let scanner = NSScanner(string: hexStr)
        var color: UInt32 = 0
        if scanner.scanHexInt(&color) {
            let r = CGFloat((color & 0xFF0000) >> 16) / 255.0
            let g = CGFloat((color & 0x00FF00) >> 8) / 255.0
            let b = CGFloat(color & 0x0000FF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: alpha)
        } else {
            self.init(red: 0, green: 0, blue: 0, alpha: 0)
        }
    }
}