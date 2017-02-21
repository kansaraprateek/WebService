//
//  ViewController.swift
//  WebService
//
//  Created by Prateek Kansara on 07/14/2016.
//  Copyright (c) 2016 Prateek Kansara. All rights reserved.
//

import UIKit
import WebService

class ViewController: UIViewController {
    
    var httpHeaderRequestDict : NSMutableDictionary!{
        
        get{
            let mutableDict : NSMutableDictionary = NSMutableDictionary()
            mutableDict.setValue("AUTHKEY", forKey: "Authorization")
            mutableDict.setValue("application/json", forKey: "Content-Type")
            return mutableDict
        }
    }
    
    var webServiceObject : WebService = WebService()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        
        /**
            Set default HTTP headers for all the request
         */
        
        webServiceObject.setDefaultHeaders(httpHeaderRequestDict)
    sendRequets()
    }
    
    /**
     Send request
     you can use the HTTP methods like .GET .POST .DELETE .PUT
     Encoded variable is to ecode parameters to the URL. true/false
     */
    func sendRequets() {
        
        let URLString = "https://randomuser.me/api/?results=10"
        let params = "" // Dictionary type
        
        /**
         *  use webServiceObject.httpHeaders to set different headers required for this call.
         */
        
        webServiceObject.sendRequest(URLString, parameters: params as AnyObject?, requestType: .get, success: {
            (response : HTTPURLResponse?, dictionary : Any) in
            
            // Handle data when request Success
            print(dictionary)
            
            }, failed: {
                (response : HTTPURLResponse?, ResponseDict : Any?) in
            
                // Handle data when request fails
                
            }, encoded: false)
        
    }
    
    
    func uploadDocument() {
        _ = DocumentHandler()
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
}


