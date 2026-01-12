import Flutter
import UIKit
import SSZipArchive
import VisionKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let ZIP_CHANNEL = "com.scandocpro.zip/native"
  private let VISION_SCAN_CHANNEL = "vision_scan"
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // ZIP Channel
    let zipChannel = FlutterMethodChannel(name: ZIP_CHANNEL, binaryMessenger: controller.binaryMessenger)
    zipChannel.setMethodCallHandler { [weak self] (call, result) in
      self?.handleZipMethod(call: call, result: result)
    }
    
    // VisionKit Scan Channel
    let visionChannel = FlutterMethodChannel(name: VISION_SCAN_CHANNEL, binaryMessenger: controller.binaryMessenger)
    visionChannel.setMethodCallHandler { [weak self] (call, result) in
      self?.handleVisionScanMethod(call: call, result: result, controller: controller)
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // MARK: - VisionKit Scanner
  
  private func handleVisionScanMethod(call: FlutterMethodCall, result: @escaping FlutterResult, controller: FlutterViewController) {
    switch call.method {
    case "startScan":
      presentDocumentScanner(result: result, controller: controller)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func presentDocumentScanner(result: @escaping FlutterResult, controller: FlutterViewController) {
    // Check if VNDocumentCameraViewController available (iOS 13+)
    guard VNDocumentCameraViewController.isSupported else {
      result(FlutterError(code: "NOT_SUPPORTED", message: "VisionKit not available", details: nil))
      return
    }
    
    DispatchQueue.main.async {
      let documentViewController = VNDocumentCameraViewController()
      documentViewController.delegate = self
      
      // Store result for later callback
      self.scanResultCallback = result
      
      controller.present(documentViewController, animated: true)
    }
  }
  
  private var scanResultCallback: FlutterResult?
  
  /// Lưu nhiều ảnh từ VisionKit scan (multi-page)
  /// Trả về List<String> đường dẫn temp file
  private func saveMultiPageScanResult(_ scan: VNDocumentCameraScan) {
    guard let callback = scanResultCallback else { return }
    
    DispatchQueue.global(qos: .userInitiated).async {
      var tempPaths: [String] = []
      let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      
      // Extract tất cả các trang
      for pageIndex in 0..<scan.pageCount {
        let image = scan.imageOfPage(at: pageIndex)
        let fileName = "scan_temp_\(Int(Date().timeIntervalSince1970 * 1000))_p\(pageIndex + 1).jpg"
        let filePath = documentsDir.appendingPathComponent(fileName).path
        
        // Convert to JPEG (quality 0.8)
        if let jpegData = image.jpegData(compressionQuality: 0.8),
           FileManager.default.createFile(atPath: filePath, contents: jpegData) {
          tempPaths.append(filePath)
        } else {
          DispatchQueue.main.async {
            callback(FlutterError(code: "SAVE_ERROR", message: "Failed to save page \(pageIndex + 1)", details: nil))
          }
          return
        }
      }
      
      DispatchQueue.main.async {
        callback(tempPaths) // Trả về List<String>
      }
    }
  }
  
  // MARK: - ZIP methods (native iOS)
  
  private func handleZipMethod(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "zip_folder":
      guard let args = call.arguments as? [String: Any],
            let bienSo = args["bienSo"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing bienSo", details: nil))
        return
      }
      zipFolder(bienSo: bienSo, result: result)
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  /// Nén toàn bộ thư mục HoSoXe/<bienSo>/ thành HoSoXe/<bienSo>.zip
  private func zipFolder(bienSo: String, result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async {
      let fileManager = FileManager.default
      let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
      let folderURL = documentsDir.appendingPathComponent("HoSoXe/\(bienSo)")
      let zipURL = documentsDir.appendingPathComponent("HoSoXe/\(bienSo).zip")
      
      // Validate folder exists
      var isDir: ObjCBool = false
      guard fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDir), isDir.boolValue else {
        DispatchQueue.main.async {
          result(FlutterError(code: "FOLDER_NOT_FOUND", message: "Hồ sơ không tồn tại", details: nil))
        }
        return
      }
      
      // Ensure folder is not empty
      if let contents = try? fileManager.contentsOfDirectory(atPath: folderURL.path), contents.isEmpty {
        DispatchQueue.main.async {
          result(FlutterError(code: "EMPTY_FOLDER", message: "Hồ sơ trống", details: nil))
        }
        return
      }
      
      // Remove old zip if any
      if fileManager.fileExists(atPath: zipURL.path) {
        try? fileManager.removeItem(at: zipURL)
      }
      
      // Native zip via SSZipArchive (iOS)
      let success = SSZipArchive.createZipFile(atPath: zipURL.path, withContentsOfDirectory: folderURL.path, keepParentDirectory: true)
      DispatchQueue.main.async {
        if success {
          result(zipURL.path)
        } else {
          result(FlutterError(code: "ZIP_FAILED", message: "Failed to zip folder", details: nil))
        }
      }
    }
  }
}

// MARK: - VNDocumentCameraViewControllerDelegate
extension AppDelegate: VNDocumentCameraViewControllerDelegate {
  func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
    controller.dismiss(animated: true)
    
    // Multi-page support
    guard scan.pageCount > 0 else {
      scanResultCallback?(FlutterError(code: "NO_PAGES", message: "No pages scanned", details: nil))
      scanResultCallback = nil
      return
    }
    
    print("📄 Scanned \(scan.pageCount) page(s)")
    saveMultiPageScanResult(scan)
    scanResultCallback = nil
  }
  
  func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
    controller.dismiss(animated: true)
    scanResultCallback?(nil)
    scanResultCallback = nil
  }
  
  func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
    controller.dismiss(animated: true)
    scanResultCallback?(FlutterError(code: "SCAN_ERROR", message: error.localizedDescription, details: nil))
    scanResultCallback = nil
  }
}
