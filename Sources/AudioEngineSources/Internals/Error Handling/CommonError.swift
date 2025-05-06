// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

import Foundation

// CommonError is an enum with descriptions so we can throw generic errors
// and hopefully provide more detail to developers when code fails
// Please feel free to add any errors you need especially if they come up frequently

enum CommonError: Error, LocalizedError {
    case audioKitNotRunning
    case couldNotOpenFile
    case deviceNotFound
    case invalidDSPObject
    case unexplained
    case undefined
    case custom(String)

    /// Pretty printout
    public var errorDescription: String? {
        switch self {
        case .audioKitNotRunning:
            return "AudioKit is not currently running"
        case .couldNotOpenFile:
            return "Can't open file"
        case .deviceNotFound:
            return "Could not find the requested device"
        case .undefined:
            return "An undefined error occurred."
        case .custom(let message):
            return message
        default:
            return "I'm sorry Dave, I'm afraid I can't do that"
        }
    }
}
