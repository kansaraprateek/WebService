//
//  WebService.swift
//  WebService
//
//  Created by Prateek Kansara on 26/05/16.
//  Copyright © 2016 Prateek. All rights reserved.
//

import Foundation
import UIKit

public enum HTTPMethod: Int {
    case GET
    case POST
    case PUT
    case DELETE
};


private let kAFCharactersToBeEscapedInQueryString : NSCharacterSet = NSCharacterSet(charactersInString : ":/?&=;+!@#$()',*")

private func PercentEscapedQueryKeyFromStringWithEncoding(lString : NSString) -> NSString {
    
    return lString.stringByAddingPercentEncodingWithAllowedCharacters(kAFCharactersToBeEscapedInQueryString)!
}

class HTTPHeaders: NSObject {
    
    private var defaultHTTPHeaders : NSMutableDictionary!
    
    private var defaultDocumentHTTPHeaders : NSMutableDictionary!
    
    class var sharedInstance: HTTPHeaders {
        struct Singleton {
            
            static let instance = HTTPHeaders.init()
        }
        return Singleton.instance
    }
    
    func setDefaultHttpHeadears (headers : NSMutableDictionary){
        defaultHTTPHeaders = headers
    }
    
    func getHTTPHeaders() -> NSDictionary?{
        return defaultHTTPHeaders
    }
    
    func setDefaultDocumentHeaders(headers : NSMutableDictionary)  {
        defaultDocumentHTTPHeaders = headers
    }
    
    func getDocumentHeaders() -> NSDictionary? {
        return defaultDocumentHTTPHeaders
    }
}

public class WebService: NSObject {
    
    private var gURLString : NSString!

    public
    
    func setDefaultHeaders(headers : NSMutableDictionary) {
        let headersClass = HTTPHeaders.sharedInstance
        headersClass.setDefaultHttpHeadears(headers)
    }
    
    public
    var httpHeaders : NSDictionary?
    
    /**
     Sending request to url provided with type and block methods to handle response or error
     
     - parameter lUrl:        service url of String type
     - parameter parameters:  dictionary object with required params for service
     - parameter requestType: RequestType parameter with enum value
     - parameter success:     success block on successful service call
     - parameter failed:      failed block when service fails
     - parameter encoded:     bool value to determine parameter to be encoded within the url or not
     */

    public
    func sendRequest(lUrl : String, parameters : AnyObject?, requestType : HTTPMethod, success : (NSHTTPURLResponse?, AnyObject) -> Void, failed : (NSHTTPURLResponse?, AnyObject?) -> Void, encoded : Bool) {
        let webSessionObject : WebServiceSession = WebServiceSession()
        webSessionObject.headerValues = httpHeaders
        webSessionObject.sendHTTPRequestWithURL(lUrl, requestType: requestType, parameters: parameters, success: success, failed: failed, lEncoded: encoded)
    }
}

/// Web service handlers

class WebServiceSession: NSObject {
    
    private var onSuccess :  ((NSHTTPURLResponse?, AnyObject) -> Void)?
    private var onError :  ((NSHTTPURLResponse?, AnyObject?) -> Void)?
    
    private var gURLString : NSString = ""
    private var gRequestType : HTTPMethod = .GET
    
    private var recievedData : NSMutableData!
    
    private var gResponse : NSURLResponse!
    private var gParameters : AnyObject?
    
    private var encoded : Bool!
    
    private var dataTask : NSURLSessionDataTask!
    
    
    /// Mutable Request
    
    private var headerValues : NSDictionary?
    
    private var mutableRequest : NSMutableURLRequest! {
        set{
            self.mutableRequest = newValue
        }
        get {
            
            let lMutableRequest : NSMutableURLRequest = NSMutableURLRequest(URL: NSURL(string: self.gURLString as String)!)
            lMutableRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            lMutableRequest.HTTPMethod = self.getRequestType()
            let httpHeaderClass = HTTPHeaders.sharedInstance
            if headerValues == nil {
                headerValues = httpHeaderClass.getHTTPHeaders()
            }
            
            headerValues?.enumerateKeysAndObjectsUsingBlock({
                (key : AnyObject, val : AnyObject, stop :UnsafeMutablePointer<ObjCBool>) in
                lMutableRequest.setValue(val as? String, forHTTPHeaderField: key as! String)
            })
            
            if gParameters?.count > 0 && !encoded{
                do{
                    lMutableRequest.HTTPBody = try NSJSONSerialization.dataWithJSONObject(gParameters!, options: .PrettyPrinted)
                }
                catch{
                    print("error in parameters")
                }
            }
            
            return lMutableRequest
        }
    }
    
    private var session : NSURLSession!
    
    /**
     Request method enum to String
     
     - returns: returns string as request type
     */
    
    private func getRequestType() -> String {
        
        switch self.gRequestType {
        case .POST:
            return "POST"
        case .GET:
            return "GET"
        case .PUT:
            return "PUT"
        case .DELETE:
            return "DELETE"
        }
    }
    
    /**
     Sending request to url provided with type and block methods to handle response or error
     
     - parameter url:         service url of String type
     - parameter requestType: dictionary object with required params for service
     - parameter parameters:  RequestType parameter with enum value
     - parameter success:     success block on successful service call
     - parameter failed:      failed block when service fails
     - parameter lEncoded:    bool value to determine parameter to be encoded within the url or not
     */
    func sendHTTPRequestWithURL(url : NSString, requestType: HTTPMethod, parameters: AnyObject?,success : (NSHTTPURLResponse?, AnyObject) -> Void, failed : (NSHTTPURLResponse?, AnyObject?) -> Void, lEncoded : Bool)  {
        gURLString = url
        gRequestType = requestType
        encoded = lEncoded
        

        onSuccess = success
        onError = failed
        
        if lEncoded {
            encodedRequestWithParameters(parameters)
        }
        else{
            gParameters = parameters
            sendRequest()
        }
    }
    
    /**
     Encoded request with parameters
     
     - parameter params: Anyobject with dictionary of params
     */
    private func encodedRequestWithParameters(params : AnyObject?) {
        
        let encodedParamArray : NSMutableArray = NSMutableArray()
        if ((params?.count) != nil) {
            params!.enumerateKeysAndObjectsUsingBlock({(parameterKey : AnyObject, parameterValue : AnyObject, stop : UnsafeMutablePointer<ObjCBool>) in
                
                encodedParamArray.addObject(NSString(format: "%@=%@", PercentEscapedQueryKeyFromStringWithEncoding(parameterKey as! NSString), PercentEscapedQueryKeyFromStringWithEncoding(parameterValue as! NSString)))
            })
            
            let encodedURL : NSString = NSString(format: "%@%@", gURLString, encodedParamArray.componentsJoinedByString("&"))
            gURLString = encodedURL
        }
        
        session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration(), delegate: self, delegateQueue: NSOperationQueue.mainQueue())
        dataTask = session.dataTaskWithRequest(mutableRequest)
        dataTask.resume()
        
    }
    
    /**
     Request without encoding
     */
    private func sendRequest(){
        
        session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration(), delegate: self, delegateQueue: NSOperationQueue.mainQueue())
        dataTask = session.dataTaskWithRequest(mutableRequest)
        
        dataTask.resume()
    }
}

extension WebServiceSession: NSURLSessionDataDelegate{
    
    func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveResponse response: NSURLResponse, completionHandler: (NSURLSessionResponseDisposition) -> Void) {
        
        gResponse = response
        recievedData = nil
        recievedData = NSMutableData()
        
        completionHandler(.Allow);

    }
    
    func WebServiceSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) {
        recievedData.appendData(data)
    }
    
}

extension WebServiceSession : NSURLSessionTaskDelegate {

    func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        let httpResponse = gResponse as? NSHTTPURLResponse
        if (error == nil) {
            
            
                let responseDict : AnyObject!
                do{
                    
                    responseDict = try NSJSONSerialization.JSONObjectWithData(recievedData, options: .AllowFragments)
                    //                print(responseDict)
                }
                catch{
                    print("serialization failed")
                    let error : NSError = NSError.init(domain: "SerializationFailed", code: 0, userInfo: nil)
                    onError!(httpResponse, error)
                    return
                }
                
                if httpResponse!.statusCode == 200 {
                
                    onSuccess!(httpResponse, responseDict)
            
                }
                else
                {
                    onError!(httpResponse, responseDict)
                }
        }
        else{
            onError!(httpResponse, error!)
        }
    }
}


