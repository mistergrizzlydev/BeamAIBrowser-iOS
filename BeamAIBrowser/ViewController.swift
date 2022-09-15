//
//  ViewController.swift
//  BeamAIBrowser
//

import UIKit
import WebKit
import AVFoundation
import BeamAISDK

class ViewController: UIViewController {

    // Button pointers
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    
    // Web browsing elements
    @IBOutlet weak var webTextField: UITextField!
    @IBOutlet weak var refreshButton: UIButton!
    @IBOutlet weak var forwardButton: UIButton!
    @IBOutlet weak var backButton: UIButton!
    
    // Stress + HR(V) UI elements
    @IBOutlet weak var stressLabel: UILabel!
    @IBOutlet weak var hrvLabel: UILabel!
    @IBOutlet weak var heartRateLabel: UILabel!
    @IBOutlet weak var stressClassBanner: UIView!
    @IBOutlet weak var stressClassLabel: UILabel!
     
    // Beam AI object and companions
    private var beamAI: BeamAI?
    private var timer: Timer?
    private var counter: Int = 0
    
    // Web and camera preview objects
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var previewView: PreviewView!
    
    // Banner UI elements
    @IBOutlet weak var noFaceDetected: UIView!
    @IBOutlet weak var valuesCanBeNoisyBanner: UIView!
    @IBOutlet weak var waitTenSecondBanner: UIView!
    
    // Timer banner and labels
    @IBOutlet weak var timerBanner: UIView!
    @IBOutlet weak var timerLabel: UILabel!
    
    // Presentables
    @IBOutlet weak var heartRateView: UIView!
    @IBOutlet weak var stressView: UIView!
    @IBOutlet weak var hrvView: UIView!
    @IBOutlet weak var disclaimerBanner: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize Beam AI object
        self.beamAI = try! BeamAI(beamID: "your-20-char-beamID", frameRate: 30, window: 60.0, updateEvery: 1.0)
        
        // Set up camera preview
        self.previewView.session = self.beamAI?.getCameraSession()
        
        // Set up web view
        let defaultPage = "https://www.google.com/"
        self.webView.navigationDelegate = self
        self.webView.load(URLRequest(url: URL.httpURL(withString: defaultPage)!))
        self.webTextField.delegate = self
        self.webTextField.text = URL(string: defaultPage)?.absoluteString
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Set up Beam AI object
        self.beamAI?.startSession()
        // Clear UI elements
        self.moveUIToStoppedUI()
        
        // Set up foreground and background manager
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    @objc func appMovedToBackground() {
        // Reset everything
        self.counter = 0
        self.timer?.invalidate()
        self.beamAI?.stopMonitoring()
        self.moveUIToStoppedUI()
    }
    
    private func showValidationErrorMessage() {
        let alert = UIAlertController(title: "Validation Failed", message: "Beam AI SDK validation was not successful. You will not be able to continue monitoring your stress, heart rate and heart rate variability. If you have an invalid beamID, please obtain a valid beamID. If you don't have internet connection, please connect to the internet and restart the app.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            // Do nothing
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func startButtonClicked(_ sender: Any) {
        
        // Reset timer object
        self.timer?.invalidate()
        self.counter = 0
        
        // Move UI elements
        self.moveUIToRecordingUI()
        do {
            try self.beamAI?.startMonitoring()
        } catch {
            self.counter = 0
            self.timer?.invalidate()
            self.beamAI?.stopMonitoring()
            self.moveUIToStoppedUI()
            self.showValidationErrorMessage()
            return
        }
        
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            let output = self.beamAI?.getEstimates()
            
            // Validation has failed or another issue has happened and monitoring cannot progress
            if (output!["CODE"] as! String == "S1-SDKIsNotMonitoring") ||
                (output!["CODE"] as! String == "E1-SDKValidationRejected") ||
                (output!["CODE"] as! String == "E2-CameraSessionNotRunning")
            {
                self.counter = 0
                self.timer?.invalidate()
                self.beamAI?.stopMonitoring()
                self.moveUIToStoppedUI()
                
                if (output!["CODE"] as! String == "E1-SDKValidationRejected") {
                    self.showValidationErrorMessage()
                }
            }
            
            if (output!["CODE"] as! String == "S2-NoFaceDetected") {
                
                self.waitTenSecondBanner.isHidden = true
                self.valuesCanBeNoisyBanner.isHidden = true
                self.noFaceDetected.isHidden = false
                self.clearLabels()
                self.counter = 0
                
            } else if (output!["CODE"] as! String == "S3-NotEnoughFramesProcessed") {
                
                // Update timer
                self.counter += 1
                let hoursTime = self.counter / 3600
                let minutesTime = (self.counter % 3600) / 60
                let secondsTime = self.counter % 60
                self.timerLabel.text = String(format: "%02d", hoursTime) + ":" + String(format: "%02d", minutesTime) + ":" + String(format: "%02d", secondsTime)
                
                // Update banners
                self.waitTenSecondBanner.isHidden = false
                self.valuesCanBeNoisyBanner.isHidden = true
                self.noFaceDetected.isHidden = true
                
            } else if (output!["CODE"] as! String == "S4-NotFullWindow") ||
                (output!["CODE"] as! String == "S5-FullResults") {
                
                // Update timer
                self.counter += 1
                let hoursTime = self.counter / 3600
                let minutesTime = (self.counter % 3600) / 60
                let secondsTime = self.counter % 60
                self.timerLabel.text = String(format: "%02d", hoursTime) + ":" + String(format: "%02d", minutesTime) + ":" + String(format: "%02d", secondsTime)
                
                // Update values
                self.updateHeartRate(heartRate: output!["HEARTRATE"] as! Double)
                self.updateHRV(heartRateVariability: output!["HRV"] as! Double)
                self.updateStress(stress: output!["STRESS"] as! Double)
                
                if (output!["CODE"] as! String == "S4-NotFullWindow") {
                    
                    // Update banners
                    self.waitTenSecondBanner.isHidden = true
                    self.valuesCanBeNoisyBanner.isHidden = false
                    self.noFaceDetected.isHidden = true
                    
                } else {
                    
                    // Update banners
                    self.waitTenSecondBanner.isHidden = true
                    self.valuesCanBeNoisyBanner.isHidden = true
                    self.noFaceDetected.isHidden = true
                    
                }
                
            }
        }
        
    }
    
    private func updateHeartRate(heartRate: Double) {
        if heartRate < 0 { return }
        
        if heartRate.isNaN {
            self.heartRateLabel.text = "NaN"
        } else {
            self.heartRateLabel.text = "\(round(heartRate * 10) / 10)"
        }
    }
    
    private func updateHRV(heartRateVariability: Double) {
        if heartRateVariability < 0 { return }
        
        if heartRateVariability.isNaN {
            self.hrvLabel.text = "NaN"
        } else {
            self.hrvLabel.text = "\(Int(round(heartRateVariability * 1000)))"
        }
    }
    
    private func updateStress(stress: Double) {
        if stress < 0 { return }
        
        if stress.isNaN {
            
            self.stressLabel.text = "NaN"
            self.stressClassLabel.text = "---"
            self.stressClassBanner.backgroundColor = .black
            
        } else {
        
            let stressRounded = round(stress * 100) / 100
            self.stressLabel.text = "\(stressRounded)"
        
            if (stressRounded < 1.5) {
                self.stressClassLabel.text = "Normal"
                self.stressClassBanner.backgroundColor = UIColor(red: 12/256, green: 128/256, blue: 42/256, alpha: 1.0)
            } else if (1.5 <= stressRounded) && (stressRounded < 2.5) {
                self.stressClassLabel.text = "Mild"
                self.stressClassBanner.backgroundColor = .blue
            } else if (2.5 <= stressRounded) && (stressRounded < 3.5) {
                self.stressClassLabel.text = "High"
                self.stressClassBanner.backgroundColor = .orange
            } else if (3.5 <= stressRounded)  {
                self.stressClassLabel.text = "Very High"
                self.stressClassBanner.backgroundColor = .red
            }
            
        }
    }
    
    @IBAction func stopButtonClicked(_ sender: Any) {
        self.moveUIToStoppedUI()
        self.beamAI?.stopMonitoring()
        self.timer?.invalidate()
        self.counter = 0
    }
    
    private func moveUIToStoppedUI() {
        
        // Switch buttons
        self.stopButton.isHidden = true
        self.startButton.isHidden = false
        
        // Reset values
        self.clearLabels()
        
        // Hide Banners
        self.waitTenSecondBanner.isHidden = true
        self.valuesCanBeNoisyBanner.isHidden = true
        self.noFaceDetected.isHidden = true
        
        // Hide display data
        self.stressView.isHidden = true
        self.hrvView.isHidden = true
        self.heartRateView.isHidden = true
        self.timerBanner.isHidden = true
        self.disclaimerBanner.isHidden = true
    }
    
    private func clearLabels() {
        // Reset values
        self.stressLabel.text = "----"
        self.hrvLabel.text = "----"
        self.heartRateLabel.text = "----"
        
        // Reset stress classification banner
        self.stressClassBanner.backgroundColor = .black
        self.stressClassLabel.text = "----"
        
        // Reset timer label
        self.timerLabel.text = "00:00:00"
    }
    
    private func moveUIToRecordingUI() {
        // Switch buttons
        self.stopButton.isHidden = false
        self.startButton.isHidden = true
        
        // Display presentables
        self.stressView.isHidden = false
        self.hrvView.isHidden = false
        self.heartRateView.isHidden = false
        self.timerBanner.isHidden = false
        self.disclaimerBanner.isHidden = false
    }
    
    private func updatePreviewLayer(layer: AVCaptureConnection, orientation: AVCaptureVideoOrientation) {
        layer.videoOrientation = orientation
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if let connection = self.previewView.videoPreviewLayer.connection {
            let currentDevice = UIDevice.current
            let orientation: UIDeviceOrientation = currentDevice.orientation
            let previewLayerConnection: AVCaptureConnection = connection
            
            if previewLayerConnection.isVideoOrientationSupported {
                switch orientation {
                case .portrait: self.updatePreviewLayer(layer: previewLayerConnection, orientation: .portrait)
                case .landscapeRight: self.updatePreviewLayer(layer: previewLayerConnection, orientation: .landscapeLeft)
                case .landscapeLeft: self.updatePreviewLayer(layer: previewLayerConnection, orientation: .landscapeRight)
                case .portraitUpsideDown: self.updatePreviewLayer(layer: previewLayerConnection, orientation: .portraitUpsideDown)
                default: self.updatePreviewLayer(layer: previewLayerConnection, orientation: .portrait)
                }
            }
        }
    }
    
    // Webview handling of actions
    @IBAction func backWebButtonPressed(_ sender: Any) {
        if self.webView.canGoBack {
            self.webView.stopLoading()
            self.webView.goBack()
        }
    }
    @IBAction func forwardWebButtonPressed(_ sender: Any) {
        if self.webView.canGoForward {
            self.webView.stopLoading()
            self.webView.goForward()
        }
    }
    @IBAction func refreshWebButtonPressed(_ sender: Any) { self.webView.reload() }
}

// Web and text field extensions
extension ViewController: WKNavigationDelegate, UITextFieldDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.webTextField.text = webView.url?.absoluteString
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.webView.load(URLRequest(url: URL.httpURL(withString: textField.text!)!))
        self.webTextField.resignFirstResponder()
        return true
    }
}
