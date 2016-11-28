//
//  DocumentHandler.swift
//  WebService
//
//  Created by Prateek Kansara on 30/05/16.
//  Copyright © 2016 Prateek. All rights reserved.
//

import Foundation
import MobileCoreServices
import UIKit

extension URL {
    
//    var typeIdentifier: String {
//        guard isFileURL else { return "unknown" }
//        var uniformTypeIdentifier: AnyObject?
//        do {
//            try getResourceValue(&uniformTypeIdentifier, forKey:  URLResourceKey.typeIdentifierKey)
//            return uniformTypeIdentifier as? String ?? "unknown"
//        } catch let error as NSError {
//            print(error.debugDescription)
//            return "unknown"
//        }
//    }
}

private var globalFileManager : FileManager! {
    
    if FileManager.default.fileExists(atPath: globalDestinationDocPath as String) {
        do{
            try FileManager.default.createDirectory(atPath: globalDestinationDocPath as String, withIntermediateDirectories: false, attributes: nil)
        }
        catch{
            print("failed to create common doc folder")
        }
    }
    
    return FileManager.default
}

private var globalPaths : NSArray! {
    return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true) as NSArray!
}

private var globalDocumentDirectoryPath : NSString! {
    return globalPaths.object(at: 0) as! NSString
}

private var globalDestinationDocPath : NSString! {
    
    return globalDocumentDirectoryPath.appendingPathComponent("/Docs") as NSString!
}

@objc protocol DocumentHandlerDelegate : NSObjectProtocol{
    
    func DocumentUplaodedSuccessfully(_ data : Data)
    func DocumentUploadFailed(_ error : NSError)
}

private let FILEBOUNDARY = "--ARCFormBoundarym9l3512x3aexw29"

open class DocumentHandler : NSObject {
    
    var delegate : DocumentHandlerDelegate{
        set {
            self.delegate = newValue
        }
        get{
            return self.delegate
        }
    }
    
    open var  fileName : NSString!
    
    
    open class var sharedInstance: DocumentHandler {
        struct Singleton {
            
            static let instance = DocumentHandler()
        }
        return Singleton.instance
    }
    
    open
    func setDefaultHeaders(_ headers : NSMutableDictionary) {
        let headersClass = HTTPHeaders.sharedInstance
        headersClass.setDefaultDocumentHeaders(headers)
    }
    
    open var httpHeaders : NSDictionary?
    
    open func downloadDocument(_ urlString : NSString, documentID : NSString, Progress: @escaping (_ bytesWritten : Int64, _ totalBytesWritten : Int64, _ remaining : Int64) -> Void, Success : @escaping (_ location : URL, _ taskDescription : NSString) -> Void, Error : @escaping (_ respones : HTTPURLResponse, _ error : NSError?) -> Void) {
        
        let documetDownlaodSession : DocumentDownloader = DocumentDownloader.init(lURLString: urlString, lRequestType: "GET")
        documetDownlaodSession.uniqueID = documentID
        documetDownlaodSession.headerValues = httpHeaders
        documetDownlaodSession.downloadDocumentWithProgress(Progress, Success: Success, Error: Error)
    }
    
    open func uploadDocumentWithURl(_ urlString : NSString, parameters : NSDictionary?, documentPath : NSArray, fieldName : String, Progress : @escaping (_ bytesSent: Int64, _ totalBytesSent: Int64, _ totalBytesExpectedToSend: Int64) -> Void, Success : @escaping (_ response : HTTPURLResponse) -> Void, Error : @escaping (_ response : HTTPURLResponse, _ error : NSError?) -> Void) {
        
        let data : Data = createBodyWithBoundary(FILEBOUNDARY, parameters: parameters, paths: documentPath, fieldName: fieldName)
        
        
        let uploadDocument : DocumentUploader = DocumentUploader()
        if httpHeaders != nil {
            uploadDocument.headerValues = NSMutableDictionary.init(dictionary: httpHeaders!)
        }
        uploadDocument.uploadDocumentWithURl(urlString, formData: data, uniqueID: self.fileName, Progress: Progress, Success: Success, Error: Error)
    }
    
    fileprivate func createBodyWithBoundary(_ boundary : String, parameters : NSDictionary?, paths : NSArray, fieldName : String) -> Data {
        
        let httpBody : NSMutableData = NSMutableData()
        
        parameters?.enumerateKeysAndObjects({(parameterKey : AnyObject, parameterValue : AnyObject, stop : UnsafeMutablePointer<ObjCBool>) in
            
            httpBody.append(String(format: "--%@\r\n", boundary).data(using: String.Encoding.utf8)!)
            httpBody.append(String(format: "Content-Disposition: form-data; name=\"%@\"\r\n\r\n", parameterKey as! String).data(using: String.Encoding.utf8)!)
            httpBody.append(String(format: "%@\r\n", parameterValue as! String).data(using: String.Encoding.utf8)!)
        } as! (Any, Any, UnsafeMutablePointer<ObjCBool>) -> Void)
        
        for path in paths {
            
            let fileName = (path as! NSString).lastPathComponent
            let data : Data = try! Data(contentsOf: URL(fileURLWithPath: path as! String))
            let mimeType : NSString = (URL(string: path as! String)?.lastPathComponent)! as NSString
            httpBody.append(String(format: "--%@\r\n", boundary).data(using: String.Encoding.utf8)!)
            httpBody.append(String(format: "Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", fieldName, fileName).data(using: String.Encoding.utf8)!)
            httpBody.append(String(format: "Content-Type: %@\r\n\r\n", mimeType).data(using: String.Encoding.utf8)!)
            httpBody.append(data)
            httpBody.append(String(format: "\r\n").data(using: String.Encoding.utf8)!)
        }
        
        httpBody.append(String(format: "--%@--\r\n", boundary).data(using: String.Encoding.utf8)!)
        return httpBody as Data
    }
    
    fileprivate func mimeTypeForPath(_ path : NSString) -> NSString {
        
        let docExtension : CFString = path.pathExtension as CFString
        let UTI  : CFString = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, docExtension, nil) as! CFString
        //        assert(UTI != nil)

        let mimeType = UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType)!
        let mimeString = convertCfTypeToString(cfValue: mimeType)
        return mimeString!
    }
    
    private func convertCfTypeToString(cfValue: Unmanaged<CFString>!) -> NSString?{
        
        /* Coded by Vandad Nahavandipoor */
        
        let value = Unmanaged.fromOpaque(
            cfValue.toOpaque()).takeUnretainedValue() as CFString
        if CFGetTypeID(value) == CFStringGetTypeID(){
            return value as NSString
        } else {
            return nil
        }
    }
}

extension DocumentHandler: UINavigationControllerDelegate {
    
}

// MARK: - Document session class

private class DocumentDownloader: NSObject {
    
    fileprivate var uniqueID : NSString!
    fileprivate var urlString : NSString!
    fileprivate var requestType : NSString!
    fileprivate var backgroundSession : Foundation.URLSession!
    
    fileprivate var inProgress : ((_ bytesWritten : Int64, _ totalBytesWritten : Int64, _ remaining : Int64) -> Void)?
    fileprivate var onSuccess : ((_ location : URL, _ taskDescription : NSString) -> Void)?
    fileprivate var onError : ((_ response : HTTPURLResponse, _ error : NSError?) -> Void)?
    
    fileprivate var headerValues : NSDictionary?
    
    fileprivate var gResponse : HTTPURLResponse!
    
    fileprivate var mutableRequest : URLRequest! {
        set{
            self.mutableRequest = newValue
        }
        get {
            
            var lMutableRequest : URLRequest = URLRequest(url: URL(string: self.urlString as String)!)
            lMutableRequest.httpMethod = "GET"
            lMutableRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let httpHeaderClass = HTTPHeaders.sharedInstance
            if headerValues == nil {
                if httpHeaderClass.getDocumentHeaders() == nil {
                    headerValues = httpHeaderClass.getHTTPHeaders()
                }
                else{
                    headerValues = httpHeaderClass.getDocumentHeaders()
                }
            }
            
            headerValues?.enumerateKeysAndObjects({
                (key : AnyObject, val : AnyObject, stop :UnsafeMutablePointer<ObjCBool>) in
                lMutableRequest.setValue(val as? String, forHTTPHeaderField: key as! String)
            } as! (Any, Any, UnsafeMutablePointer<ObjCBool>) -> Void)
            
            return lMutableRequest
        }
    }
    
    fileprivate var sessionConfiguration : URLSessionConfiguration! {
        set {
            self.sessionConfiguration = newValue
        }
        get{
            
            let sessionConfig = URLSessionConfiguration.background(withIdentifier: self.uniqueID as String)
//            let additionalHeaderDictionary : NSMutableDictionary = NSMutableDictionary ()
//            additionalHeaderDictionary.setValue("application/json", forKey: "Content-Type")
//            sessionConfig.HTTPAdditionalHeaders = additionalHeaderDictionary
            
            return sessionConfig
        }
    }
    
    override init() {
        super.init()
    }
    
    convenience init(lURLString : NSString, lRequestType : NSString) {
        self.init()
        
        requestType = lRequestType
        urlString = lURLString
    }
    
    fileprivate func downloadDocumentWithProgress(_ Progress : @escaping (_ bytesWritten : Int64, _ totalBytesWritten : Int64, _ remaining : Int64) -> Void, Success: @escaping (_ location : URL, _ taskDescription : NSString) -> Void, Error : @escaping (_ response : HTTPURLResponse, _ error : NSError?) -> Void) {
        
        onError = Error
        onSuccess = Success
        inProgress = Progress
        
        
        backgroundSession = Foundation.URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue:OperationQueue.main)
        
        let downloadTask = backgroundSession.downloadTask(with: mutableRequest)
        
        downloadTask.resume()
    }
    
}

extension DocumentDownloader: URLSessionDataDelegate{
    
    func urlSession(_ session: Foundation.URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (Foundation.URLSession.ResponseDisposition) -> Void) {
        gResponse = response as? HTTPURLResponse
        completionHandler(.allow);
    }
}

extension DocumentDownloader : URLSessionDownloadDelegate{
    
    @objc func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
//        if gResponse.statusCode == 200{
            self.onSuccess!(location, "Downloaded")
//        }
//        else{
//            self.onError!(response: gResponse, error: nil)
//        }
    }
    @objc func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        self.inProgress!(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
    }
    
    fileprivate func URLSession(_ session: Foundation.URLSession, task: URLSessionTask, didCompleteWithError error: NSError?) {
        self.onError!(gResponse, error)
    }
}

private class DocumentUploader : NSObject {
    
    fileprivate var gURl : NSString!
    fileprivate var gRequestType : NSString!
    fileprivate var uniqueID : NSString!
    
    fileprivate var onSuccess : ((_ response : HTTPURLResponse) -> Void)?
    fileprivate var onError : ((_ response : HTTPURLResponse, _ error : NSError?) -> Void)?
    fileprivate var inProgress : ((_ bytesSent: Int64, _ totalBytesSent: Int64, _ totalBytesExpectedToSend: Int64) -> Void)?
    
    fileprivate var headerValues : NSMutableDictionary?
    
    fileprivate var gResponse : HTTPURLResponse!
    
    fileprivate var backgroundUploadSession : Foundation.URLSession!
    
    fileprivate var mutableRequest : NSMutableURLRequest! {
        set{
            self.mutableRequest = newValue
        }
        get {
            
            let lMutableRequest : NSMutableURLRequest = NSMutableURLRequest(url: URL(string: self.gURl as String)!)
            lMutableRequest.httpMethod = gRequestType as String
            let httpHeaderClass = HTTPHeaders.sharedInstance
            if headerValues == nil {
                if httpHeaderClass.getDocumentHeaders() == nil {
                    if httpHeaderClass.getHTTPHeaders() == nil {
                        print("Set header values")
                    }
                    else
                    {
                        headerValues = NSMutableDictionary.init(dictionary: httpHeaderClass.getHTTPHeaders()!)
                    }
                }
                else{
                    headerValues = NSMutableDictionary.init(dictionary: httpHeaderClass.getDocumentHeaders()!)
                }
            }
            
            headerValues?.enumerateKeysAndObjects({
                (key : AnyObject, val : AnyObject, stop :UnsafeMutablePointer<ObjCBool>) in
                lMutableRequest.setValue(val as? String, forHTTPHeaderField: key as! String)
            } as! (Any, Any, UnsafeMutablePointer<ObjCBool>) -> Void)
            
            if gRequestType.isEqual("POST")  || gRequestType.isEqual("PUT"){
                let mutipartContentType = NSString(format: "multipart/form-data; boundary=%@", FILEBOUNDARY)
                lMutableRequest.setValue(mutipartContentType as String, forHTTPHeaderField: "Content-Type")
            }
            
            return lMutableRequest
        }
    }

    
    fileprivate func uploadDocumentWithURl(_ urlString : NSString, formData : Data, uniqueID : NSString, Progress : @escaping (_ bytesSent: Int64, _ totalBytesSent: Int64, _ totalBytesExpectedToSend: Int64) -> Void, Success : @escaping (_ response : HTTPURLResponse) -> Void, Error : @escaping (_ response : HTTPURLResponse, _ error : NSError?) -> Void) {
        
        self.gRequestType = "POST"
        self.gURl = urlString
        self.uniqueID = uniqueID
        
        inProgress = Progress
        onSuccess = Success
        onError = Error
    
        let sessionConfig : URLSessionConfiguration = URLSessionConfiguration.default
        
        backgroundUploadSession = Foundation.URLSession(configuration: sessionConfig, delegate: self, delegateQueue:OperationQueue.main)
        
        let uploadTask : URLSessionUploadTask = backgroundUploadSession.uploadTask(with: mutableRequest as URLRequest, from: formData)
        uploadTask.resume()
    
    }
}

extension DocumentUploader: URLSessionDataDelegate{
    
    func urlSession(_ session: Foundation.URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (Foundation.URLSession.ResponseDisposition) -> Void) {
        gResponse = response as? HTTPURLResponse
        
//        print("\(gResponse)")
        completionHandler(.allow);
    }
}

extension DocumentUploader : URLSessionTaskDelegate{
    
    
    @objc func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
//        print("session \(session) task : \(task) error : \(error)")
        if error == nil || gResponse?.statusCode == 200 {
            self.onSuccess!(gResponse)
        }
        else{
            self.onError!(gResponse, error as NSError?)
        }
        
    }
    
    @objc func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        
//        print("byte send \(bytesSent) expected : \(totalBytesExpectedToSend) ")
        self.inProgress!(bytesSent, totalBytesSent, totalBytesExpectedToSend)
        
    }
}
