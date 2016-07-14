# WebService

[![CI Status](http://img.shields.io/travis/Prateek Kansara/WebService.svg?style=flat)](https://travis-ci.org/Prateek Kansara/WebService)
[![Version](https://img.shields.io/cocoapods/v/WebService.svg?style=flat)](http://cocoapods.org/pods/WebService)
[![License](https://img.shields.io/cocoapods/l/WebService.svg?style=flat)](http://cocoapods.org/pods/WebService)
[![Platform](https://img.shields.io/cocoapods/p/WebService.svg?style=flat)](http://cocoapods.org/pods/WebService)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

##Usage

```ruby
// Import webService class


import WebService

// Basic Header Dictionary


var httpHeaderRequestDict : NSMutableDictionary!{
    get{
        let mutableDict : NSMutableDictionary = NSMutableDictionary()
        mutableDict.setValue("AUTHKEY", forKey: "Authorization")
        mutableDict.setValue("application/json", forKey: "Content-Type")
        return mutableDict
    }
}

// Create webService object
    var webServiceObject : WebService = WebService()
    
// Set header value for all request
    webServiceObject.setDefaultHeaders(httpHeaderRequestDict)



*  use webServiceObject.httpHeaders to set different headers required for this call.


webServiceObject.sendRequest(URLString, parameters: params, requestType: .GET, success: {
(response : NSHTTPURLResponse?, dictionary : AnyObject) in

// Handle data when request Success

}, failed: {
(response : NSHTTPURLResponse?, ResponseDict : AnyObject?) in

// Handle data when request fails

}, encoded: false)

```

## Requirements

* iOS 8.0+
Xcode 7.3.1+

## Installation

WebService is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "WebService"
```

## Author

Prateek Kansara, prateek@kansara.in

## License

WebService is available under the MIT license. See the LICENSE file for more info.
