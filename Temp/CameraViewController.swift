	  //
	  //  CameraViewController.swift
	  //  Temp
	  //
	  //  Created by René Fokkema on 12/08/2021.
	  //

import UIKit
import AVFoundation
import AVKit
import Photos

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {


	  @IBOutlet weak var viewView: UIView!

	  private enum cameraPosition : Int {
			 case back = 1
			 case front = 2
	  }



	  private var currentView: PreviewView!

			 //@IBOutlet weak var playerView: UIView!

	  var blurView: UIView!
	  var isRecording: Bool = false
	  var isVideoRecording: Bool = false

	  private enum SessionSetupResult {
			 case success
			 case notAuthorized
			 case configurationFailed
	  }

	  private var videoURL:URL?, audioURL:URL?

	  private var videoOutput = AVCaptureVideoDataOutput()
	  private var audioOutput = AVCaptureAudioDataOutput()

	  private var sessionAtSourceTime:CMTime?

	  private var videoWriter:AVAssetWriter?
	  private var audioWriter:AVAssetWriter?

	  private var videoWriterInput: AVAssetWriterInput?
	  private var audioWriterInput: AVAssetWriterInput?

	  private var setupResult: SessionSetupResult = .success

	  override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation { return .slide }

	  var statusBarHidden: Bool = false
	  override var prefersStatusBarHidden: Bool { return statusBarHidden }

	  override var prefersHomeIndicatorAutoHidden: Bool { return true }

	  private var timer:Timer!

	  override func viewDidLoad() {
			 super.viewDidLoad()

			 view.backgroundColor = .random

			 setTapRecognizers()



			 setNeedsStatusBarAppearanceUpdate()
			 setNeedsUpdateOfHomeIndicatorAutoHidden()
	  }



	  private func setTapRecognizers() {


			 newViewTap = UITapGestureRecognizer(target: self, action: #selector(addView))
			 view.addGestureRecognizer(newViewTap)


	  }

	  var newViewTap: UITapGestureRecognizer!

	  @objc func addView(sender: UIGestureRecognizer) {

			 switch sender.state {
			 case  .ended:
					//timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { _ in
						  let orig = sender.location(in: self.view)
						  let rand = CGFloat.random(in: (self.view.frame.width / 3) ... self.view.frame.width)
						  let size = CGSize(width: rand/2, height: rand/2)

						  let frame = CGRect(origin: orig, size: size)
						  let new = PreviewView(frame: frame, controller: self)

						  self.view.insertSubview(new, at: self.view.subviews.count)

						  // DispatchQueue.main.async {
						  UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut,
													 animations: {
										new.bounds = CGRect(x: 0, y: 0,
																				  width: rand,
																				  height: rand)
								 let max = (CGFloat.pi * 100).rounded()
								 let rot = CGFloat.random(in: -max...max) / 100

								 new.transform = new.transform.rotated(by: rot)

								 }, completion: nil)
						  //}
					//})

			 // case .ended: timer.invalidate()

			 default: break

			 }
	  }

	  public func listTempFiles() {
			 let tmpFiles = try? FileManager.default.contentsOfDirectory(at: URL(string: NSTemporaryDirectory())!, includingPropertiesForKeys: .none, options: .skipsHiddenFiles)
			 let docDirURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
			 let docFiles = try? FileManager.default.contentsOfDirectory(at: docDirURL, includingPropertiesForKeys: .none, options: .skipsHiddenFiles)

			 print("temp files \n ---")
			 for url in tmpFiles! {
					/* do {
					 try FileManager.default.removeItem(at: url)
					 print("Removed: \(url)")
					 } catch { print("Not removed: \(url)") } */
					print(url.absoluteString)
			 }
			 if tmpFiles?.count == 0 { print("No files.") }

			 print("")

			 print("doc files \n ---")
			 for url in docFiles! {
					print(url.absoluteString)
			 }
			 if docFiles?.count == 0 { print("No files.") }
					//self.assetURLs.removeAll()

	  }

	  override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
			 if motion == .motionShake {
					print("Status bar disappears!")

					self.statusBarHidden = true
					setNeedsStatusBarAppearanceUpdate()
			 }
	  }


}

