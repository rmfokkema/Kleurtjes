//
//  CameraViewController.swift
//  Temp
//
//  Created by René Fokkema on 12/08/2021.
//

class CameraViewController: UIViewController, AVCaptureFileOutputRecordingDelegate {

	private enum cameraPosition : Int {
		//case unspecified = 0
		case back = 1
		case front = 2
	}

	private var currentPosition: cameraPosition = .back

	var assetURLs = [URL]() //Videos Array

	var windowOrientation: UIInterfaceOrientation {
		return view.window?.windowScene?.interfaceOrientation ?? .unknown
	}

	private let session = AVCaptureSession()
	private var isSessionRunning = false
	private var selectedSemanticSegmentationMatteTypes = [AVSemanticSegmentationMatte.MatteType]()
	private let sessionQueue = DispatchQueue(label: "session queue")
	@objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
	@IBOutlet private weak var previewView: PreviewView!

	var blurView: UIView!
	var isRecording: Bool = false

	private var movieFileOutput: AVCaptureMovieFileOutput?
	private var backgroundRecordingID: UIBackgroundTaskIdentifier?

	private enum SessionSetupResult {
		case success
		case notAuthorized
		case configurationFailed
	}



	private var setupResult: SessionSetupResult = .success


	// MARK: View Controller Life Cycle

	override func viewDidLoad() {

		super.viewDidLoad()


		self.setOverlay()
		self.setTapRecognizers()

		previewView.session = session



		sessionQueue.async {
			self.configureSession()
		}

	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		print("viewWillAppear")


		sessionQueue.async {
			switch self.setupResult {
			case .success:
				// Only setup observers and start the session if setup succeeded.
				//self.addObservers()

				self.session.startRunning()
				self.isSessionRunning = self.session.isRunning

			case .notAuthorized:
				DispatchQueue.main.async {
					let changePrivacySetting = "AVCam doesn't have permission to use the camera, please change privacy settings"
					let message = NSLocalizedString(changePrivacySetting, comment: "Alert message when the user has denied access to the camera")
					let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)

					alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
															style: .cancel,
															handler: nil))

					alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"),
															style: .`default`,
															handler: { _ in
																UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
																						  options: [:],
																						  completionHandler: nil)
															}))

					self.present(alertController, animated: true, completion: nil)
				}

			case .configurationFailed:
				DispatchQueue.main.async {
					let alertMsg = "Alert message when something goes wrong during capture session configuration"
					let message = NSLocalizedString("Unable to capture media", comment: alertMsg)
					let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)

					alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
															style: .cancel,
															handler: nil))

					self.present(alertController, animated: true, completion: nil)
				}
			}
		}
	}

	override func viewWillDisappear(_ animated: Bool) {

		print("viewWillDisappear")
		sessionQueue.async {
			if self.setupResult == .success {
				self.session.stopRunning()
				self.isSessionRunning = self.session.isRunning
				// self.removeObservers()
			}
		}

		super.viewWillDisappear(animated)
	}

	private func setOverlay() {
		if !UIAccessibility.isReduceTransparencyEnabled {
			let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
			blurView = UIVisualEffectView(effect: blurEffect)
		} else {
			blurView = UIView()
			blurView.backgroundColor = .black
			blurView.alpha = 0.5
		}

		blurView.frame = self.view.bounds
		blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		view.addSubview(blurView)
	}

	private func setTapRecognizers() {
		let singleTap = UITapGestureRecognizer(target: self, action: #selector(toggleRecording))
		let doubleTap = UITapGestureRecognizer(target: self, action: #selector(changeCamera))

		singleTap.numberOfTapsRequired = 1
		singleTap.require(toFail: doubleTap)
		view.addGestureRecognizer(singleTap)

		doubleTap.numberOfTapsRequired = 2
		view.addGestureRecognizer(doubleTap)
	}




	private func configureSession() {
		/// - Tag: ConfigureSession

		/* DispatchQueue.main.async {

		let videoURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("09.17.31.mov")
		//let asset = AVAsset(url: videoURL)
		self.player = AVQueuePlayer()
		self.playerLooper = AVPlayerLooper(player: self.player, templateItem: AVPlayerItem(url: videoURL))

		self.player.isMuted = true
		let playerLayer = AVPlayerLayer(player: self.player)
		playerLayer.frame = self.playerView.bounds
		self.playerView.layer.addSublayer(playerLayer)
		self.player.play()
		} */

		print("configureSession")


		if setupResult != .success {
			return
		}

		session.beginConfiguration()

		session.sessionPreset = .high

		do {
			var defaultVideoDevice: AVCaptureDevice?
			defaultVideoDevice = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back)
			guard let videoDevice = defaultVideoDevice else {
				print("Default video device is unavailable.")
				setupResult = .configurationFailed
				session.commitConfiguration()
				return
			}
			let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)

			if session.canAddInput(videoDeviceInput) {
				session.addInput(videoDeviceInput)
				self.videoDeviceInput = videoDeviceInput

				DispatchQueue.main.async {
					1/*var initialVideoOrientation: AVCaptureVideoOrientation = .portrait
					if self.windowOrientation != .unknown {
					if let videoOrientation = AVCaptureVideoOrientation(interfaceOrientation: self.windowOrientation) {
					initialVideoOrientation = videoOrientation
					}
					}

					self.previewView.videoPreviewLayer.connection?.videoOrientation = initialVideoOrientation
					*/
					self.previewView.videoPreviewLayer.videoGravity = .resizeAspectFill
				}
			} else {
				print("Couldn't add video device input to the session.")
				setupResult = .configurationFailed
				session.commitConfiguration()
				return
			}
		} catch {
			print("Couldn't create video device input: \(error)")
			setupResult = .configurationFailed
			session.commitConfiguration()
			return
		}

		do {
			let audioDevice = AVCaptureDevice.default(for: .audio)
			let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice!)

			if session.canAddInput(audioDeviceInput) {
				session.addInput(audioDeviceInput)
			} else {
				print("Could not add audio device input to the session")
			}
		} catch {
			print("Could not create audio device input: \(error)")
		}

		let movieFileOutput = AVCaptureMovieFileOutput()

		//self.session.beginConfiguration()
		self.session.addOutput(movieFileOutput)
		//self.session.sessionPreset = .high

		if let connection = movieFileOutput.connection(with: .video) {
			if connection.isVideoStabilizationSupported {
				connection.preferredVideoStabilizationMode = .auto
			}
		}
		self.session.commitConfiguration()

		self.movieFileOutput = movieFileOutput
	}


	@objc private func toggleOverlay() {
		guard let blurView = self.blurView else { return }

		DispatchQueue.main.async {
			UIView.animate(withDuration: 0.4) {
				blurView.alpha = (blurView.alpha > 0.0) ? 0.0 : 1.0
			}
		}
	}

	@objc private func toggleRecording() {
		print("toggleRecording")

		guard let movieFileOutput = self.movieFileOutput else {
			return
		}

		/*
		Disable the Camera button until recording finishes, and disable
		the Record button until recording starts or finishes.

		See the AVCaptureFileOutputRecordingDelegate methods.
		*/
		// cameraButton.isEnabled = false

		//let videoPreviewLayerOrientation = previewView.videoPreviewLayer.connection?.videoOrientation

		sessionQueue.async {
			if !movieFileOutput.isRecording {
				self.toggleOverlay()

				if UIDevice.current.isMultitaskingSupported {
					self.backgroundRecordingID = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
					print("bg started")
				}

				// Update the orientation on the movie file output video connection before recording.
				let movieFileOutputConnection = movieFileOutput.connection(with: .video)
				//movieFileOutputConnection?.videoOrientation = videoPreviewLayerOrientation!

				let availableVideoCodecTypes = movieFileOutput.availableVideoCodecTypes

				if availableVideoCodecTypes.contains(.hevc) {
					movieFileOutput.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.hevc], for: movieFileOutputConnection!)
				}

				// Start recording video to a temporary file.
				let outputFileName = NSUUID().uuidString
				let outputFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((outputFileName as NSString).appendingPathExtension("mov")!)
				movieFileOutput.startRecording(to: URL(fileURLWithPath: outputFilePath), recordingDelegate: self)

				self.isRecording = true
			} else {
				self.isRecording = false
				movieFileOutput.stopRecording()
				self.toggleOverlay()
			}
		}


	}




	/// - Tag: ChangeCamera
	@objc private func changeCamera() {
		print("changeCamera")

		sessionQueue.async {
			if self.isRecording { self.movieFileOutput!.stopRecording() }

			let newVideoDevice = (self.currentPosition == .back) ? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) : AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back)

			self.session.beginConfiguration()
			self.session.removeInput(self.videoDeviceInput)
			let videoDeviceInput = try? AVCaptureDeviceInput(device: newVideoDevice!)
			self.session.addInput(videoDeviceInput!)
			self.videoDeviceInput = videoDeviceInput!
			self.session.commitConfiguration()

			self.currentPosition = (self.currentPosition == .back) ? .front : .back

			if self.isRecording {
				let outputFileName = UUID().uuidString
				let outputFilePath = NSTemporaryDirectory().appending(outputFileName).appending(".mov")
				self.movieFileOutput!.startRecording(to: URL(fileURLWithPath: outputFilePath), recordingDelegate: self)
			}
		}

	}



	// MARK: KVO and Notifications
	/*
	private var keyValueObservations = [NSKeyValueObservation]()
	/// - Tag: ObserveInterruption
	private func addObservers() {

	print("addObservers")

	let systemPressureStateObservation = observe(\.videoDeviceInput.device.systemPressureState, options: .new) { _, change in
	guard let systemPressureState = change.newValue else { return }
	//print(String(describing: systemPressureState.level))
	self.setRecommendedFrameRateRangeForPressureState(systemPressureState: systemPressureState)
	}
	keyValueObservations.append(systemPressureStateObservation)

	NotificationCenter.default.addObserver(self,
	selector: #selector(sessionRuntimeError),
	name: .AVCaptureSessionRuntimeError,
	object: session)

	NotificationCenter.default.addObserver(self,
	selector: #selector(sessionWasInterrupted),
	name: .AVCaptureSessionWasInterrupted,
	object: session)
	NotificationCenter.default.addObserver(self,
	selector: #selector(sessionInterruptionEnded),
	name: .AVCaptureSessionInterruptionEnded,
	object: session)
	}

	private func removeObservers() {

	print("removeObservers")

	NotificationCenter.default.removeObserver(self)

	for keyValueObservation in keyValueObservations {
	keyValueObservation.invalidate()
	}
	keyValueObservations.removeAll()
	}

	/// - Tag: HandleRuntimeError
	@objc
	func sessionRuntimeError(notification: NSNotification) {

	print("sessionRuntimeError")

	guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else { return }

	print("Capture session runtime error: \(error)")
	// If media services were reset, and the last start succeeded, restart the session.
	if error.code == .mediaServicesWereReset {
	sessionQueue.async {
	if self.isSessionRunning {
	self.session.startRunning()
	self.isSessionRunning = self.session.isRunning
	}
	}
	}
	}

	/// - Tag: HandleSystemPressure
	private func setRecommendedFrameRateRangeForPressureState(systemPressureState: AVCaptureDevice.SystemPressureState) {

	//print("setRecommendedFrameRateRangeForPressureState")

	/*
	The frame rates used here are only for demonstration purposes.
	Your frame rate throttling may be different depending on your app's camera configuration.
	*/
	let pressureLevel = systemPressureState.level
	if pressureLevel == .serious || pressureLevel == .critical {
	if self.movieFileOutput == nil || self.movieFileOutput?.isRecording == false {
	do {
	try self.videoDeviceInput.device.lockForConfiguration()
	print("WARNING: Reached elevated system pressure level: \(pressureLevel). Throttling frame rate.")
	self.videoDeviceInput.device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 20)
	self.videoDeviceInput.device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 15)
	self.videoDeviceInput.device.unlockForConfiguration()
	} catch {
	print("Could not lock device for configuration: \(error)")
	}
	}
	} else if pressureLevel == .shutdown {
	print("Session stopped running due to shutdown system pressure level.")
	}
	}

	/// - Tag: HandleInterruption
	@objc
	func sessionWasInterrupted(notification: NSNotification) {

	print("sessionWasInterrupted")

	if let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
	let reasonIntegerValue = userInfoValue.integerValue,
	let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue) {

	if reason == .videoDeviceNotAvailableDueToSystemPressure {
	print("Session stopped running due to shutdown system pressure level.")
	}
	}
	}

	@objc
	func sessionInterruptionEnded(notification: NSNotification) {

	print("sessionInterruptionEnded")
	}
	*/

	func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {

		self.assetURLs.append(outputFileURL)

		if !self.isRecording {

			if let currentBackgroundRecordingID = backgroundRecordingID {
				backgroundRecordingID = UIBackgroundTaskIdentifier.invalid

				if currentBackgroundRecordingID != UIBackgroundTaskIdentifier.invalid {
					UIApplication.shared.endBackgroundTask(currentBackgroundRecordingID)
					print("bg ended.")

				}
			}

			self.doMerge()


			print("Merge!")
			for url in self.assetURLs { print(String(describing: url)) }
			print("Done!")
		}

	}

	private func doMerge() -> Void {
		var insertTime = CMTime.zero
		var arrayLayerInstructions:[AVMutableVideoCompositionLayerInstruction] = []
		//var outputSize = CGSize(width: 0, height: 0)
		var outputSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
		//Determine video output size

		/*let videoAsset = AVAsset(url: self.assetURLs.first!)
		let videoTrack = videoAsset.tracks(withMediaType: AVMediaType.video)[0]

		let assetInfo = orientationFromTransform(transform: videoTrack.preferredTransform)

		var videoSize = videoTrack.naturalSize
		if assetInfo.isPortrait == true {
		videoSize.width = videoTrack.naturalSize.height
		videoSize.height = videoTrack.naturalSize.width
		}*/

		/*if videoSize.height > outputSize.height {
		outputSize = videoSize
		}

		if outputSize.width == 0 || outputSize.height == 0 {
		outputSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
		}
		*/

		// Silence sound (in case of video has no sound track)
		//let silenceURL = Bundle.main.url(forResource: "silence", withExtension: "mp3")
		//let silenceAsset = AVAsset(url:silenceURL!)
		//let silenceSoundTrack = silenceAsset.tracks(withMediaType: AVMediaType.audio).first

		// Init composition
		let mixComposition = AVMutableComposition()

		for url in self.assetURLs {
			// Get video track
			let videoAsset = AVAsset(url: url)
			guard let videoTrack = videoAsset.tracks(withMediaType: AVMediaType.video).first else { continue }

			// Get audio track
			var audioTrack:AVAssetTrack?
			if videoAsset.tracks(withMediaType: AVMediaType.audio).count > 0 {
				audioTrack = videoAsset.tracks(withMediaType: AVMediaType.audio).first
			}
			//else {
			//	audioTrack = silenceSoundTrack
			//}

			// Init video & audio composition track
			let videoCompositionTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.video,
																	   preferredTrackID: Int32(kCMPersistentTrackID_Invalid))

			let audioCompositionTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.audio,
																	   preferredTrackID: Int32(kCMPersistentTrackID_Invalid))

			do {
				let startTime = CMTime.zero
				let duration = videoAsset.duration

				// Add video track to video composition at specific time
				try videoCompositionTrack?.insertTimeRange(CMTimeRangeMake(start: startTime, duration: duration),
														   of: videoTrack,
														   at: insertTime)

				// Add audio track to audio composition at specific time
				if let audioTrack = audioTrack {
					try audioCompositionTrack?.insertTimeRange(CMTimeRangeMake(start: startTime, duration: duration),
															   of: audioTrack,
															   at: insertTime)
				}

				// Add instruction for video track
				/*let layerInstruction = videoCompositionInstructionForTrack(track: videoCompositionTrack!,
				asset: videoAsset,
				standardSize: outputSize,
				atTime: insertTime) */
				let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoCompositionTrack!)

				let transform = videoTrack.preferredTransform
				let aspectFillRatio = UIScreen.main.bounds.height / videoTrack.naturalSize.width
				let scaleFactor = CGAffineTransform(scaleX: aspectFillRatio, y: aspectFillRatio)


				layerInstruction.setTransform(transform.concatenating(scaleFactor), at: CMTime.zero)

				// Hide video track before changing to new track
				let endTime = CMTimeAdd(insertTime, duration)

				/* if animation {
				let timeScale = videoAsset.duration.timescale
				let durationAnimation = CMTime.init(seconds: 1, preferredTimescale: timeScale)

				layerInstruction.setOpacityRamp(fromStartOpacity: 1.0, toEndOpacity: 0.0, timeRange: CMTimeRange.init(start: endTime, duration: durationAnimation))
				} else { */
				layerInstruction.setOpacity(0, at: endTime)
				//}

				arrayLayerInstructions.append(layerInstruction)

				// Increase the insert time
				insertTime = CMTimeAdd(insertTime, duration)
			}
			catch {
				print("Load track error")
			}
		}

		// Main video composition instruction
		let mainInstruction = AVMutableVideoCompositionInstruction()
		mainInstruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: insertTime)
		mainInstruction.layerInstructions = arrayLayerInstructions

		// Main video composition
		let mainComposition = AVMutableVideoComposition()
		mainComposition.instructions = [mainInstruction]
		mainComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
		mainComposition.renderSize = outputSize

		// Export to file
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "HH.mm.ss"
		let date = dateFormatter.string(from: Date())
		let path = NSTemporaryDirectory().appending("\(date).mp4")
		let exportURL = URL.init(fileURLWithPath: path)

		// Remove file if existed
		//FileManager.default.removeItemIfExisted(exportURL)

		// Init exporter
		let exporter = AVAssetExportSession.init(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)
		exporter?.outputURL = exportURL
		exporter?.outputFileType = AVFileType.mp4
		exporter?.shouldOptimizeForNetworkUse = true
		exporter?.videoComposition = mainComposition

		// Do export
		exporter?.exportAsynchronously(completionHandler: {
			DispatchQueue.main.async {
				self.exportDidFinish(exporter!)
			}
		})

	}


	func exportDidFinish(_ session: AVAssetExportSession) {
		guard
			session.status == AVAssetExportSession.Status.completed,
			let outputURL = session.outputURL
		else { return }

		let saveVideoToPhotos = {
			let changes: () -> Void = {
				PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
			}
			PHPhotoLibrary.shared().performChanges(changes) { saved, error in
				DispatchQueue.main.async {
					let success = saved && (error == nil)

					if success {
						UIApplication.shared.openURL(URL(string: "photos-redirect://")!)
						return
					}

					//let title = success ? "Success" : "Error"
					//let message = success ? "Video saved" : "Failed to save video"

					let alert = UIAlertController(
						title: "Error",
						message: String("This happened: \(error)"),
						preferredStyle: .alert)
					alert.addAction(UIAlertAction(
										title: "OK",
										style: UIAlertAction.Style.cancel,
										handler: nil))
					self.present(alert, animated: true, completion: nil)
				}
			}
		}

		// Ensure permission to access Photo Library
		if PHPhotoLibrary.authorizationStatus() != .authorized {
			PHPhotoLibrary.requestAuthorization { status in
				if status == .authorized {
					saveVideoToPhotos()
				}
			}
		} else {
			saveVideoToPhotos()
		}

		cleanup()

	}

	private func cleanup() {
		/*for path in self.assetPaths {

		if FileManager.default.fileExists(atPath: path) {
		do {
		try FileManager.default.removeItem(atPath: path)
		print("Removed: \(path)")
		} catch {
		print("Could not remove file at url: \(path)")
		}
		}
		}*/

		self.assetURLs.removeAll()
	}

	/* Key-value observations.

	private var keyValueObservations = [NSKeyValueObservation]()
	/// - Tag: ObserveInterruption
	private func addObservers() {
	let systemPressureStateObservation = observe(\.videoDeviceInput.device.systemPressureState, options: .new) { _, change in
	guard let systemPressureState = change.newValue else { return }
	//print(String(describing: systemPressureState.level))
	self.setRecommendedFrameRateRangeForPressureState(systemPressureState: systemPressureState)
	}
	keyValueObservations.append(systemPressureStateObservation)

	NotificationCenter.default.addObserver(self,
	selector: #selector(sessionRuntimeError),
	name: .AVCaptureSessionRuntimeError,
	object: session)

	NotificationCenter.default.addObserver(self,
	selector: #selector(sessionWasInterrupted),
	name: .AVCaptureSessionWasInterrupted,
	object: session)
	NotificationCenter.default.addObserver(self,
	selector: #selector(sessionInterruptionEnded),
	name: .AVCaptureSessionInterruptionEnded,
	object: session)
	}

	private func removeObservers() {
	NotificationCenter.default.removeObserver(self)

	for keyValueObservation in keyValueObservations {
	keyValueObservation.invalidate()
	}
	keyValueObservations.removeAll()
	}

	@objc func sessionRuntimeError(notification: NSNotification) {
	guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else { return }

	// If media services were reset, and the last start succeeded, restart the session.
	if error.code == .mediaServicesWereReset {
	sessionQueue.async {
	if self.isSessionRunning {
	self.session.startRunning()
	self.isSessionRunning = self.session.isRunning
	}
	}
	}
	}

	private func setRecommendedFrameRateRangeForPressureState(systemPressureState: AVCaptureDevice.SystemPressureState) {
	let pressureLevel = systemPressureState.level
	if pressureLevel == .serious || pressureLevel == .critical {
	if self.movieFileOutput == nil || self.movieFileOutput?.isRecording == false {
	do {
	try self.videoDeviceInput.device.lockForConfiguration()

	self.videoDeviceInput.device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 20)
	self.videoDeviceInput.device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 15)
	self.videoDeviceInput.device.unlockForConfiguration()
	} catch {

	}
	}
	} else if pressureLevel == .shutdown {

	}
	}

	@objc func sessionWasInterrupted(notification: NSNotification) {
	if let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
	let reasonIntegerValue = userInfoValue.integerValue,
	let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue) {
	if reason == .videoDeviceNotAvailableDueToSystemPressure {
	}
	}
	}

	@objc func sessionInterruptionEnded(notification: NSNotification) { }
	*/

}

extension AVCaptureVideoOrientation {
	init?(deviceOrientation: UIDeviceOrientation) {
		switch deviceOrientation {
		case .portrait: self = .portrait
		case .portraitUpsideDown: self = .portraitUpsideDown
		case .landscapeLeft: self = .landscapeRight
		case .landscapeRight: self = .landscapeLeft
		default: return nil
		}
	}

	init?(interfaceOrientation: UIInterfaceOrientation) {
		switch interfaceOrientation {
		case .portrait: self = .portrait
		case .portraitUpsideDown: self = .portraitUpsideDown
		case .landscapeLeft: self = .landscapeLeft
		case .landscapeRight: self = .landscapeRight
		default: return nil
		}
	}
}

extension AVCaptureDevice.DiscoverySession {
	var uniqueDevicePositionsCount: Int {

		var uniqueDevicePositions = [AVCaptureDevice.Position]()

		for device in devices where !uniqueDevicePositions.contains(device.position) {
			uniqueDevicePositions.append(device.position)
		}

		return uniqueDevicePositions.count
	}
}

