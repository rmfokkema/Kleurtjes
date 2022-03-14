func setUpWriter() {

	do {
		outputFileLocation = videoFileLocation()
		videoWriter = try AVAssetWriter(outputURL: outputFileLocation!, fileType: AVFileType.mov)

			// add video input
		videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: [
			AVVideoCodecKey : AVVideoCodecType.h264,
			AVVideoWidthKey : 720,
			AVVideoHeightKey : 1280,
			AVVideoCompressionPropertiesKey : [
				AVVideoAverageBitRateKey : 2300000,
			],
		])

		videoWriterInput.expectsMediaDataInRealTime = true

		if videoWriter.canAdd(videoWriterInput) {
			videoWriter.add(videoWriterInput)
			print("video input added")
		} else {
			print("no input added")
		}

			// add audio input
		audioWriterInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: nil)

		audioWriterInput.expectsMediaDataInRealTime = true

		if videoWriter.canAdd(audioWriterInput!) {
			videoWriter.add(audioWriterInput!)
			print("audio input added")
		}


		videoWriter.startWriting()
	} catch let error {
		debugPrint(error.localizedDescription)
	}


}

func canWrite() -> Bool {
	return isRecording && videoWriter != nil && videoWriter?.status == .writing
}


	//video file location method
func videoFileLocation() -> URL {
	let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
	let videoOutputUrl = URL(fileURLWithPath: documentsPath.appendingPathComponent("videoFile")).appendingPathExtension("mov")
	do {
		if FileManager.default.fileExists(atPath: videoOutputUrl.path) {
			try FileManager.default.removeItem(at: videoOutputUrl)
			print("file removed")
		}
	} catch {
		print(error)
	}

	return videoOutputUrl
}

	// MARK: AVCaptureVideoDataOutputSampleBufferDelegate
func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

	let writable = canWrite()

	if writable,
	   sessionAtSourceTime == nil {
			// start writing
		sessionAtSourceTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
		videoWriter.startSession(atSourceTime: sessionAtSourceTime!)
			//print("Writing")
	}

	if output == videoDataOutput {
		connection.videoOrientation = .portrait

		if connection.isVideoMirroringSupported {
			connection.isVideoMirrored = true
		}
	}

	if writable,
	   output == videoDataOutput,
	   (videoWriterInput.isReadyForMoreMediaData) {
			// write video buffer
		videoWriterInput.append(sampleBuffer)
			//print("video buffering")
	} else if writable,
			  output == audioDataOutput,
			  (audioWriterInput.isReadyForMoreMediaData) {
			// write audio buffer
		audioWriterInput?.append(sampleBuffer)
			//print("audio buffering")
	}

}

	// MARK: Start recording
func start() {
	guard !isRecording else { return }
	isRecording = true
	sessionAtSourceTime = nil
	setUpWriter()
	print(isRecording)
	print(videoWriter)
	if videoWriter.status == .writing {
		print("status writing")
	} else if videoWriter.status == .failed {
		print("status failed")
	} else if videoWriter.status == .cancelled {
		print("status cancelled")
	} else if videoWriter.status == .unknown {
		print("status unknown")
	} else {
		print("status completed")
	}

}

	// MARK: Stop recording
func stop() {
	guard isRecording else { return }
	isRecording = false
	videoWriterInput.markAsFinished()
	print("marked as finished")
	videoWriter.finishWriting { [weak self] in
		self?.sessionAtSourceTime = nil
	}
		//print("finished writing \(self.outputFileLocation)")
	captureSession.stopRunning()
	performSegue(withIdentifier: "videoPreview", sender: nil)
}
