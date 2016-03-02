//
//  WaveformVisualizerView.swift
//  Chattie
//
//  Created by Ryohei Fushimi on 2016/2/11.
//  Copyright © 2016 R. Fushimi and S. Murakami. All rights reserved.
//

import UIKit

// ガウス関数を包絡線とするいいかんじにニセ波形を描くビュー
// volume: 波形の縦幅 size: 横のサイズ

class WaveformVisualizerView: UIView {

    var volume: Double = 1.0
    var size: Double = 1.0
    var active = false
    var data = [Float](count: 512, repeatedValue: 0.0)

    override func drawRect(rect: CGRect) {
        if data.count < 512 {
            return
        }

        //             trying to solve this error
        //                <Error>: Error: this application, or a library it uses, has passed an invalid numeric value (NaN, or not-a-number) to CoreGraphics API and this value is being ignored.Please fix this problem.
        if !volume.isFinite || !size.isFinite || !self.bounds.height.isFinite || size == 0 {
            return
        }
        
        let context = UIGraphicsGetCurrentContext()
        let height:Double = Double(self.bounds.height)
        let width:Double = Double(self.bounds.width)
        
        CGContextMoveToPoint(context, 0, CGFloat(height/2))
        for i in 0 ..< 512 {
//            if first {
//                first = false
//            } else {
                // random value from -1 to 1
                let x = width * Double(i) / 512
                let y = height/2 - Double(data[i]) * height / 3000000
//                NSLog("%4.4f", data[i])
                CGContextAddLineToPoint(context, CGFloat(x), CGFloat(y))
//            }
        }
        
        CGContextSetStrokeColorWithColor(context, active ? UIColor.redColor().CGColor : UIColor.lightGrayColor().CGColor)
        CGContextStrokePath(context)
        super.drawRect(rect)

    }

    func gauss(x: Double, average: Double, distribution:Double) -> Double{
        return exp(-pow(x - average, 2) / 2 / pow(distribution, 2)) / sqrt(2 * M_PI) / distribution
    }
    
    /*
    // Only override drawRect: if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func drawRect(rect: CGRect) {
        // Drawing code
    }
    */

}
