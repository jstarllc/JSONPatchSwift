//===----------------------------------------------------------------------===//
//
// This source file is part of the JSONPatchSwift open source project.
//
// Copyright (c) 2015 EXXETA AG
// Licensed under Apache License v2.0
//
//
//===----------------------------------------------------------------------===//

import SwiftyJSON

func == (lhs: JPSJsonPatch, rhs: JPSJsonPatch) -> Bool {
    
    guard lhs.operations.count == rhs.operations.count else { return false }
    
    for i in 0..<lhs.operations.count {
        if !(lhs.operations[i] == rhs.operations[i]) {
            return false
        }
    }
    
    return true
}

/// Representation of a JSON Patch
public struct JPSJsonPatch {

    let operations: [JPSOperation]

    /**
     Initializes a new `JPSJsonPatch` based on a given SwiftyJSON representation.

     - Parameter _: A String representing one or many JSON Patch operations.
        e.g. (1) JSON({ "op": "add", "path": "/", "value": "foo" })
        or (> 1)
        JSON([ { "op": "add", "path": "/", "value": "foo" },
        { "op": "test", "path": "/", "value": "foo } ])

     - Throws: can throw any error from `JPSJsonPatch.JPSJsonPatchInitialisationError` to
        notify failed initialization.

     - Returns: a `JPSJsonPatch` representation of the given SwiftJSON object
    */
    public init(_ patch: JSON) throws {
        // Check if there is an array of a dictionary as root element. Both are valid JSON patch documents.
        if patch.type == .Dictionary {
            self.operations = [try JPSJsonPatch.extractOperationFromJson(patch)]
            
        } else if patch.type == .Array {
            guard 0 < patch.count else {
                throw JPSJsonPatchInitialisationError.InvalidPatchFormat(message: JPSConstants.JsonPatch.InitialisationErrorMessages.PatchWithEmptyError)
            }
            var operationArray = [JPSOperation]()
            for i in 0..<patch.count {
                let operation = patch[i]
                operationArray.append(try JPSJsonPatch.extractOperationFromJson(operation))
            }
            self.operations = operationArray
            
        } else {
            // All other types are not a valid JSON Patch Operation.
            throw JPSJsonPatchInitialisationError.InvalidPatchFormat(message: JPSConstants.JsonPatch.InitialisationErrorMessages.InvalidRootElement)
        }
    }

    /**
     Initializes a new `JPSJsonPatch` based on a given String representation.

     - Parameter _: A String representing one or many JSON Patch operations.
        e.g. (1) { "op": "add", "path": "/", "value": "foo" }
        or (> 1)
        [ { "op": "add", "path": "/", "value": "foo" },
        { "op": "test", "path": "/", "value": "foo } ]

     - Throws: can throw any error from `JPSJsonPatch.JPSJsonPatchInitialisationError` to
        notify failed initialization.

     - Returns: a `JPSJsonPatch` representation of the given JSON Patch String
     */
    public init(_ patch: String) throws {
        // Convert the String to NSData
        guard let data = patch.dataUsingEncoding(NSUTF8StringEncoding) else {
            throw JPSJsonPatchInitialisationError.InvalidJsonFormat(message: JPSConstants.JsonPatch.InitialisationErrorMessages.PatchEncoding)
        }
        
        // Parse the JSON
        var jsonError: NSError?
        let json = JSON(data: data, options: .AllowFragments, error: &jsonError)
        if let actualError = jsonError {
            throw JPSJsonPatchInitialisationError.InvalidJsonFormat(message: actualError.description)
        }

        try self.init(json)
    }

    /**
     Possible errors thrown by the init function.

     - InvalidJsonFormat: The given String is not a valid JSON.
     - InvalidPatchFormat: The given Patch is invalid (e.g. missing mandatory parameters).
        See error message for details.
     - UnexpectedError: Something unexpected happened.
     */
    public enum JPSJsonPatchInitialisationError: ErrorType {
        case InvalidJsonFormat(message: String?)
        case InvalidPatchFormat(message: String?)
        case UnexpectedError
    }
}


// MARK: - Private functions

extension JPSJsonPatch {
    
    private static func extractOperationFromJson(json: JSON) throws -> JPSOperation {
        
        // The elements 'op' and 'path' are mandatory.
        guard let operation = json[JPSConstants.JsonPatch.Parameter.Op].string else {
            throw JPSJsonPatchInitialisationError.InvalidPatchFormat(message: JPSConstants.JsonPatch.InitialisationErrorMessages.OpElementNotFound)
        }
        guard let path = json[JPSConstants.JsonPatch.Parameter.Path].string else {
            throw JPSJsonPatchInitialisationError.InvalidPatchFormat(message: JPSConstants.JsonPatch.InitialisationErrorMessages.PathElementNotFound)
        }
        guard let operationType = JPSOperation.JPSOperationType(rawValue: operation) else {
            throw JPSJsonPatchInitialisationError.InvalidPatchFormat(message: JPSConstants.JsonPatch.InitialisationErrorMessages.InvalidOperation)
        }

        // 'from' element mandatory for .Move, .Copy operations
        var from: JPSJsonPointer?
        if operationType == .Move || operationType == .Copy {
            guard let fromValue = json[JPSConstants.JsonPatch.Parameter.From].string else {
                throw JPSJsonPatchInitialisationError.InvalidPatchFormat(message: JPSConstants.JsonPatch.InitialisationErrorMessages.FromElementNotFound)
            }
            from = try JPSJsonPointer(rawValue: fromValue)
        }

        // 'value' element mandatory for .Add, .Replace operations
        let value = json[JPSConstants.JsonPatch.Parameter.Value]
        // counterintuitive null check: https://github.com/SwiftyJSON/SwiftyJSON/issues/205
        if (operationType == .Add || operationType == .Replace) && value.null != nil {
            throw JPSJsonPatchInitialisationError.InvalidPatchFormat(message: JPSConstants.JsonPatch.InitialisationErrorMessages.ValueElementNotFound)
        }

        let pointer = try JPSJsonPointer(rawValue: path)
        return JPSOperation(type: operationType, pointer: pointer, value: value, from: from)
    }
    
}
