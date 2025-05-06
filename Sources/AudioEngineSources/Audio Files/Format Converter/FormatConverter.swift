// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

import AVFoundation

/**
 FormatConverter wraps the more complex AVFoundation and CoreAudio audio conversions in an easy to use format.
 ```swift
 let options = FormatConverter.Options()

 // any options left nil will adopt the value of the input file
 options.format = "wav"
 options.sampleRate = 48000
 options.bitDepth = 24

 let converter = FormatConverter(url: oldURL, outURL: newURL, options: options)

 converter.start { error in
    // the error will be nil on success
 }
 ```
 */
public class FormatConverter {
    // MARK: - properties

    /// The source audio file
    public var url: URL?

    /// The audio file to be created after conversion
    public var outURL: URL?

    /// Options for conversion
    public var options: Options?

    // MARK: - private properties

    // The reader needs to exist outside the start func otherwise the async nature of the
    // AVAssetWriterInput will lose its reference
    var reader: AVAssetReader?
    var writer: AVAssetWriter?

    // MARK: - initialization

    /// init with input, output and options - then start()
    public init(url: URL,
                outURL: URL,
                options: Options? = nil)
    {
        self.url = url
        self.outURL = outURL
        self.options = options ?? Options()
    }

    deinit {
        reader = nil
        writer = nil
        url = nil
        outURL = nil
        options = nil
    }

    // MARK: - functions

    /// The entry point for file conversion
    /// - Parameter completionHandler: the callback that will be triggered when process has completed.
    public func start(completionHandler: FormatConverterCallback? = nil) {
        guard let url = url else {
            completionHandler?(Self.createError(message: "Input file can't be nil."))
            return
        }

        guard let outURL = outURL else {
            completionHandler?(Self.createError(message: "Output file can't be nil."))
            return
        }

        let inputFormat = AudioFileFormat(rawValue: url.pathExtension.lowercased()) ?? .unknown
        // verify inputFormat, only allow files with path extensions for speed?
        guard FormatConverter.inputFormats.contains(inputFormat) else {
            completionHandler?(Self.createError(message: "The input file format is in an incompatible format: \(inputFormat)"))
            return
        }

        if FileManager.default.fileExists(atPath: outURL.path) {
            if options?.eraseFile == true {
                Log("Warning: removing existing file at", outURL.path)
                try? FileManager.default.removeItem(at: outURL)
            } else {
                let message = "The output file exists already. You need to choose a unique URL or delete the file."
                completionHandler?(Self.createError(message: message))
                return
            }
        }

        if options?.format == nil {
            options?.format = AudioFileFormat(rawValue: outURL.pathExtension.lowercased()) ?? .unknown
        }

        // Format checks are necessary as AVAssetReader has opinions about compressed

        // PCM output, any supported input
        if Self.isPCM(url: outURL) == true {
            // PCM output
            convertToPCM(completionHandler: completionHandler)

            // PCM input, compressed output
        } else if Self.isPCM(url: url) == true,
                  Self.isCompressed(url: outURL) == true
        {
            convertPCMToCompressed(completionHandler: completionHandler)

            // Compressed input and output, won't do sample rate
        } else if Self.isCompressed(url: url) == true,
                  Self.isCompressed(url: outURL) == true
        {
            convertCompressed(completionHandler: completionHandler)

        } else {
            completionHandler?(Self.createError(message: "Unable to determine formats for conversion"))
        }
    }
}

// MARK: - Definitions

public enum AudioFileFormat: String {
    case aac
    case aif
    case aifc
    case aiff
    case au
    case caf
    case m4a
    case m4v
    case mov
    case mp3
    case mp4
    case sd2
    case snd
    case ts
    case unknown
    case wav
}

public extension FormatConverter {

    /// FormatConverterCallback is the callback format for start()
    /// - Parameter: error This will contain one parameter of type Error which is nil if the conversion was successful.
    typealias FormatConverterCallback = (_ error: Error?) -> Void

    /// Formats that this class can write
    static let outputFormats: [AudioFileFormat] = [.wav, .aif, .caf, .m4a]

    static let defaultOutputFormat: AudioFileFormat = .wav

    /// Formats that this class can read
    static let inputFormats: [AudioFileFormat] = FormatConverter.outputFormats + [
        .mp3, .snd, .au, .sd2,
        .aif, .aiff, .aifc, .aac,
        .mp4, .m4v, .mov, .ts,
        .unknown, // allow files with no extension. convertToPCM can still read the type
    ]

    /// An option to block upsampling to a higher bit depth than the source.
    /// For example, converting to 24bit from 16 doesn't have much benefit
    enum BitDepthRule {
        /// Don't allow upsampling to 24bit if the src is 16
        case lessThanOrEqual

        /// allow any conversaion
        case any
    }

    /// The conversion options, leave any property nil to adopt the value of the input file
    /// bitRate assumes a stereo bit rate and the converter will half it for mono
    struct Options {
        /// Audio Format
        public var format: AudioFileFormat?
        /// Sample Rate in Hertz
        public var sampleRate: Double?
        /// used only with PCM data
        public var bitDepth: UInt32?
        /// used only when outputting compressed audio
        public var bitRate: UInt32 = 128000 {
            didSet {
                bitRate = bitRate.clamped(to: 64000 ... 320000)
            }
        }

        /// An option to block upsampling to a higher bit depth than the source.
        /// default value is `.lessThanOrEqual`
        public var bitDepthRule: BitDepthRule = .lessThanOrEqual

        /// How many channels to convert to. Typically 1 or 2
        public var channels: UInt32?

        /// Maps to PCM Conversion format option `AVLinearPCMIsNonInterleaved`
        public var isInterleaved: Bool?

        /// Overwrite existing files, set false if you want to handle this before you call start()
        public var eraseFile: Bool = true

        public init() {}

        /// Create options by parsing the contents of the url and using the audio settings
        /// in the file
        /// - Parameter url: The audio file to open and parse
        public init?(url: URL) {
            guard let avFile = try? AVAudioFile(forReading: url) else { return nil }
            self.init(audioFile: avFile)
        }

        /// Create options by parsing the audioFile for its settings
        /// - Parameter audioFile: an AVAudioFile to parse
        public init?(audioFile: AVAudioFile) {
            let streamDescription = audioFile.fileFormat.streamDescription.pointee

            format = AudioFileFormat(rawValue: audioFile.url.pathExtension) ?? .unknown
            // FormatConverter.formatIDToString(streamDescription.mFormatID)
            sampleRate = streamDescription.mSampleRate
            bitDepth = streamDescription.mBitsPerChannel
            channels = streamDescription.mChannelsPerFrame
        }

        /// Create PCM Options
        /// - Parameters:
        ///   - pcmFormat: wav, aif, or caf
        ///   - sampleRate: Sample Rate
        ///   - bitDepth: Bit Depth, or bits per channel
        ///   - channels: How many channels
        public init?(pcmFormat: AudioFileFormat,
                     sampleRate: Double? = nil,
                     bitDepth: UInt32? = nil,
                     channels: UInt32? = nil)
        {
            format = pcmFormat
            self.sampleRate = sampleRate
            self.bitDepth = bitDepth
            self.channels = channels
        }
    }

    internal func completionProxy(error: Error?,
                                  deleteOutputOnError: Bool = true,
                                  completionHandler: FormatConverterCallback? = nil)
    {
        guard error != nil,
              deleteOutputOnError,
              let outURL = outURL,
              FileManager.default.fileExists(atPath: outURL.path)
        else {
            completionHandler?(error)
            return
        }

        do {
            Log("Deleting on error", outURL.path)
            try FileManager.default.removeItem(at: outURL)
        } catch let err as NSError {
            Log("Failed to remove file", outURL, err)
        }

        completionHandler?(error)
    }
}
