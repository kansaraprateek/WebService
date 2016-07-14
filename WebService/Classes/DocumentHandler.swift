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

extension NSURL {
    
    var typeIdentifier: String {
        guard fileURL else { return "unknown" }
        var uniformTypeIdentifier: AnyObject?
        do {
            try getResourceValue(&uniformTypeIdentifier, forKey:  NSURLTypeIdentifierKey)
            return uniformTypeIdentifier as? String ?? "unknown"
        } catch let error as NSError {
            print(error.debugDescription)
            return "unknown"
        }
    }
}

private var globalFileManager : NSFileManager! {
    
    if NSFileManager.defaultManager().fileExistsAtPath(globalDestinationDocPath as String) {
        do{
            try NSFileManager.defaultManager().createDirectoryAtPath(globalDestinationDocPath as String, withIntermediateDirectories: false, attributes: nil)
        }
        catch{
            print("failed to create common doc folder")
        }
    }
    
    return NSFileManager.defaultManager()
}

private var globalPaths : NSArray! {
    return NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
}

private var globalDocumentDirectoryPath : NSString! {
    return globalPaths.objectAtIndex(0) as! NSString
}

private var globalDestinationDocPath : NSString! {
    
    return globalDocumentDirectoryPath.stringByAppendingPathComponent("/Docs")
}

@objc protocol DocumentHandlerDelegate : NSObjectProtocol{
    
    func DocumentUplaodedSuccessfully(data : NSData)
    func DocumentUploadFailed(error : NSError)
}

private let FILEBOUNDARY = "--ARCFormBoundarym9l3512x3aexw29"

class DocumentHandler : NSObject {
    
    var delegate : DocumentHandlerDelegate{
        set {
            self.delegate = newValue
        }
        get{
            return self.delegate
        }
    }
    
    var  fileName : NSString!
    
    
    class var sharedInstance: DocumentHandler {
        struct Singleton {
            
            static let instance = DocumentHandler()
        }
        return Singleton.instance
    }

    func setDefaultHeaders(headers : NSMutableDictionary) {
        let headersClass = HTTPHeaders.sharedInstance
        headersClass.setDefaultDocumentHeaders(headers)
    }
    
    var httpHeaders : NSDictionary?
    
    func downloadDocument(urlString : NSString, documentID : NSString, Progress: (bytesWritten : Int64, totalBytesWritten : Int64, remaining : Int64) -> Void, Success : (location : NSURL, taskDescription : NSString) -> Void, Error : (error : NSError) -> Void) {
        
        let documetDownlaodSession : DocumentDownloader = DocumentDownloader.init(lURLString: urlString, lRequestType: "GET")
        documetDownlaodSession.uniqueID = documentID
        documetDownlaodSession.headerValues = httpHeaders
        documetDownlaodSession.downloadDocumentWithProgress(Progress, Success: Success, Error: Error)
    }
    
    func uploadDocumentWithURl(urlString : NSString, parameters : NSDictionary, documentPath : NSArray, fieldName : String, Progress : (bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) -> Void, Success : (response : NSHTTPURLResponse) -> Void, Error : (response : NSHTTPURLResponse, error : NSError) -> Void) {
        
        let data : NSData = createBodyWithBoundary(FILEBOUNDARY, parameters: parameters, paths: documentPath, fieldName: fieldName)
        
        
        let uploadDocument : DocumentUploader = DocumentUploader()
        if httpHeaders != nil {
            uploadDocument.headerValues = NSMutableDictionary.init(dictionary: httpHeaders!)
        }
        uploadDocument.uploadDocumentWithURl(urlString, formData: data, uniqueID: self.fileName, Progress: Progress, Success: Success, Error: Error)
    }
    
    private func createBodyWithBoundary(boundary : String, parameters : NSDictionary, paths : NSArray, fieldName : String) -> NSData {
        
        let httpBody : NSMutableData = NSMutableData()
        
        parameters.enumerateKeysAndObjectsUsingBlock({(parameterKey : AnyObject, parameterValue : AnyObject, stop : UnsafeMutablePointer<ObjCBool>) in
            
            httpBody.appendData(String(format: "--%@\r\n", boundary).dataUsingEncoding(NSUTF8StringEncoding)!)
            httpBody.appendData(String(format: "Content-Disposition: form-data; name=\"%@\"\r\n\r\n", parameterKey as! String).dataUsingEncoding(NSUTF8StringEncoding)!)
            httpBody.appendData(String(format: "%@\r\n", parameterValue as! String).dataUsingEncoding(NSUTF8StringEncoding)!)
        })
        
        for path in paths {
            
            let fileName = (path as! NSString).lastPathComponent
            let data : NSData = NSData(contentsOfFile: path as! String)!
            let mimeType : NSString = (NSURL(string: path as! String)?.typeIdentifier)!
            httpBody.appendData(String(format: "--%@\r\n", boundary).dataUsingEncoding(NSUTF8StringEncoding)!)
            httpBody.appendData(String(format: "Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", fieldName, fileName).dataUsingEncoding(NSUTF8StringEncoding)!)
            httpBody.appendData(String(format: "Content-Type: %@\r\n\r\n", mimeType).dataUsingEncoding(NSUTF8StringEncoding)!)
            httpBody.appendData(data)
            httpBody.appendData(String(format: "\r\n").dataUsingEncoding(NSUTF8StringEncoding)!)
        }
        
        httpBody.appendData(String(format: "--%@--\r\n", boundary).dataUsingEncoding(NSUTF8StringEncoding)!)
        return httpBody
    }
    
    private func mimeTypeForPath(path : NSString) -> NSString {
        
        let docExtension : CFStringRef = path.pathExtension
        let UTI  : CFStringRef = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, docExtension, nil) as! CFStringRef
        //        assert(UTI != nil)
        let mimeType : AnyObject = (UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType) as? AnyObject)!
        
        return mimeType as! NSString
    }
}

extension DocumentHandler: UINavigationControllerDelegate {
    
}

// MARK: - Document session class

private class DocumentDownloader: NSObject {
    
    private var uniqueID : NSString!
    private var urlString : NSString!
    private var requestType : NSString!
    private var backgroundSession : NSURLSession!
    
    private var inProgress : ((bytesWritten : Int64, totalBytesWritten : Int64, remaining : Int64) -> Void)?
    private var onSuccess : ((location : NSURL, taskDescription : NSString) -> Void)?
    private var onError : ((error : NSError) -> Void)?
    
    private var headerValues : NSDictionary?
    
    private var mutableRequest : NSMutableURLRequest! {
        set{
            self.mutableRequest = newValue
        }
        get {
            
            let lMutableRequest : NSMutableURLRequest = NSMutableURLRequest(URL: NSURL(string: self.urlString as String)!)
            lMutableRequest.HTTPMethod = "GET"
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
            
            headerValues?.enumerateKeysAndObjectsUsingBlock({
                (key : AnyObject, val : AnyObject, stop :UnsafeMutablePointer<ObjCBool>) in
                lMutableRequest.setValue(val as? String, forHTTPHeaderField: key as! String)
            })
            
            return lMutableRequest
        }
    }
    
    private var sessionConfiguration : NSURLSessionConfiguration! {
        set {
            self.sessionConfiguration = newValue
        }
        get{
            
            let sessionConfig : NSURLSessionConfiguration = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier(self.uniqueID as String)
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
    
    private func downloadDocumentWithProgress(Progress : (bytesWritten : Int64, totalBytesWritten : Int64, remaining : Int64) -> Void, Success: (location : NSURL, taskDescription : NSString) -> Void, Error : (error : NSError) -> Void) {
        
        onError = Error
        onSuccess = Success
        inProgress = Progress
        
        
        backgroundSession = NSURLSession(configuration: sessionConfiguration, delegate: self, delegateQueue:NSOperationQueue.mainQueue())
        
        let downloadTask = backgroundSession.downloadTaskWithRequest(mutableRequest)
        
        downloadTask.resume()
    }
    
}

extension DocumentDownloader: NSURLSessionDataDelegate{
    
    @objc func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveResponse response: NSURLResponse, completionHandler: (NSURLSessionResponseDisposition) -> Void) {
        completionHandler(.Allow);
    }
}

extension DocumentDownloader : NSURLSessionDownloadDelegate{
    
    @objc func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        self.onSuccess!(location: location, taskDescription: "Downloaded")
    }
    @objc func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        self.inProgress!(bytesWritten: bytesWritten, totalBytesWritten: totalBytesWritten, remaining: totalBytesExpectedToWrite)
    }
}

private class DocumentUploader : NSObject {
    
    private var gURl : NSString!
    private var gRequestType : NSString!
    private var uniqueID : NSString!
    
    private var onSuccess : ((response : NSHTTPURLResponse) -> Void)?
    private var onError : ((response : NSHTTPURLResponse, error : NSError) -> Void)?
    private var inProgress : ((bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) -> Void)?
    
    private var headerValues : NSMutableDictionary?
    
    private var gResponse : NSHTTPURLResponse!
    
    private var backgroundUploadSession : NSURLSession!
    
    private var mutableRequest : NSMutableURLRequest! {
        set{
            self.mutableRequest = newValue
        }
        get {
            
            let lMutableRequest : NSMutableURLRequest = NSMutableURLRequest(URL: NSURL(string: self.gURl as String)!)
            lMutableRequest.HTTPMethod = gRequestType as String
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
            
            headerValues?.enumerateKeysAndObjectsUsingBlock({
                (key : AnyObject, val : AnyObject, stop :UnsafeMutablePointer<ObjCBool>) in
                lMutableRequest.setValue(val as? String, forHTTPHeaderField: key as! String)
            })
            
            if gRequestType.isEqual("POST") {
                let mutipartContentType = NSString(format: "multipart/form-data; boundary=%@", FILEBOUNDARY)
                lMutableRequest.setValue(mutipartContentType as String, forHTTPHeaderField: "Content-Type")
            }
            
            return lMutableRequest
        }
    }

    
    private func uploadDocumentWithURl(urlString : NSString, formData : NSData, uniqueID : NSString, Progress : (bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) -> Void, Success : (response : NSHTTPURLResponse) -> Void, Error : (response : NSHTTPURLResponse, error : NSError) -> Void) {
        
        self.gRequestType = "POST"
        self.gURl = urlString
        self.uniqueID = uniqueID
        
        inProgress = Progress
        onSuccess = Success
        onError = Error
    
        let sessionConfig : NSURLSessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration()
        
        backgroundUploadSession = NSURLSession(configuration: sessionConfig, delegate: self, delegateQueue:NSOperationQueue.mainQueue())
        
        let uploadTask : NSURLSessionUploadTask = backgroundUploadSession.uploadTaskWithRequest(mutableRequest, fromData: formData)
        uploadTask.resume()
    
    }
}

extension DocumentUploader: NSURLSessionDataDelegate{
    
    @objc func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveResponse response: NSURLResponse, completionHandler: (NSURLSessionResponseDisposition) -> Void) {
        gResponse = response as? NSHTTPURLResponse
        
        print("\(gResponse)")
        completionHandler(.Allow);
    }
}

extension DocumentUploader : NSURLSessionTaskDelegate{
    
    
    @objc func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        
        print("session \(session) task : \(task) error : \(error)")
        if error == nil {
            self.onSuccess!(response: gResponse)
        }
        else{
            self.onError!(response: gResponse, error: error!)
        }
        
    }
    
    @objc func URLSession(session: NSURLSession, task: NSURLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        
        print("byte send \(bytesSent) expected : \(totalBytesExpectedToSend) ")
        self.inProgress!(bytesSent: bytesSent, totalBytesSent: totalBytesSent, totalBytesExpectedToSend: totalBytesExpectedToSend)
        
    }
}
