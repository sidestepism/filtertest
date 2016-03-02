//
//  ViewController.swift
//  FilterSample
//
//  Created by Ryohei Fushimi on 2016/3/2.
//  Copyright © 2016 R. Fushimi & S. Murakami. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var EffectSlider1: UISlider!
    @IBOutlet weak var EffectSlider2: UISlider!
    @IBOutlet weak var EffectSlider3: UISlider!
    
    @IBOutlet weak var EffectLabel1: UILabel!
    @IBOutlet weak var EffectLabel2: UILabel!
    @IBOutlet weak var EffectLabel3: UILabel!
    
    @IBOutlet weak var WaveformVisualizerSubview: WaveformVisualizerView!
//    let filePath = NSURL(fileURLWithPath: NSTemporaryDirectory() + "/hamigaki.m4a")
    let filePath = NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource("hamigaki", ofType: "m4a")
        ?? NSTemporaryDirectory() + "/recording.wav")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        // 波形をアップデート
        var _ = NSTimer.scheduledTimerWithTimeInterval(0.02,
            target: self, selector: "updateWaveformVisualizer", userInfo: nil, repeats: true)
    }

    func updateWaveformVisualizer() {
        if AudioEngineManager.shared.spectrum.count < 512 {
            return
        }
        if AudioEngineManager.shared.analyzingMutex {
            return
        }
        WaveformVisualizerSubview.data = []
        let stride: Int = AudioEngineManager.shared.spectrum.count / 512

        for i in 0...512 {
            WaveformVisualizerSubview.data.append(AudioEngineManager.shared.spectrum[i * stride])
        }
        WaveformVisualizerSubview.setNeedsDisplay()
        if AudioEngineManager.shared.analyzing {
            EffectLabel1.text = String(format:"%.0f", AudioEngineManager.shared.analyzedPitchshift)
            EffectSlider1.value = Float(AudioEngineManager.shared.analyzedPitchshift)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    @IBAction func EffectSlider1Change(sender: AnyObject) {
        AudioEngineManager.shared.pitchshift = (sender as! UISlider).value
        EffectLabel1.text = String(format:"%.0f", (sender as! UISlider).value)
    }
    @IBAction func EffectSlider2Change(sender: AnyObject) {
        AudioEngineManager.shared.speed = (sender as! UISlider).value
        EffectLabel2.text = String(format:"%.2f", (sender as! UISlider).value)
    }
    @IBAction func EffectSlider3Change(sender: AnyObject) {
        AudioEngineManager.shared.cutofffreq = (sender as! UISlider).value
        EffectLabel3.text = String(format:"%.0f", (sender as! UISlider).value)
    }

    @IBAction func AnalyzeButtonDown(sender: AnyObject) {
        NSLog("AnalyzeButtonDown")
        AudioEngineManager.shared.startAnalyzing()
    }
    
    @IBAction func AnalyzeButtonUp(sender: AnyObject) {
        NSLog("AnalyzeButtonUp")
        AudioEngineManager.shared.stopAnalyzing()
    }
    
    @IBAction func PlayButtonTouch(sender: AnyObject) {
        AudioEngineManager.shared.startPlaying(filePath)
    }

}

