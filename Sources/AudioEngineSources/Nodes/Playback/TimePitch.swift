// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

import AVFoundation

/// AudioKit version of Apple's Timepitching Audio Unit
///
public class Timepitching: Node {
    fileprivate let timepitchingAU = AVAudioUnitTimePitch()

    let input: Node

    /// Connected nodes
    public var connections: [Node] { [input] }

    /// Underlying AVAudioNode
    public var avAudioNode: AVAudioNode

    /// Rate (rate) ranges from 0.03125 to 32.0 (Default: 1.0)
    public var rate: AUValue = 1.0 {
        didSet {
            rate = rate.clamped(to: 0.031_25 ... 32)
            timepitchingAU.rate = rate
        }
    }

    /// pitching (Cents) ranges from -2400 to 2400 (Default: 0.0)
    public var pitching: AUValue = 0.0 {
        didSet {
            pitching = pitching.clamped(to: -2400 ... 2400)
            timepitchingAU.pitch = pitching
        }
    }

    /// Overlap (generic) ranges from 3.0 to 32.0 (Default: 8.0)
    public var overlap: AUValue = 8.0 {
        didSet {
            overlap = overlap.clamped(to: 3 ... 32)
            timepitchingAU.overlap = overlap
        }
    }

    /// Initialize the time pitching node
    ///
    /// - Parameters:
    ///   - input: Input node to process
    ///   - rate: Rate (rate) ranges from 0.03125 to 32.0 (Default: 1.0)
    ///   - pitching: pitching (Cents) ranges from -2400 to 2400 (Default: 0.0)
    ///   - overlap: Overlap (generic) ranges from 3.0 to 32.0 (Default: 8.0)
    ///
    public init(
        _ input: Node,
        rate: AUValue = 1.0,
        pitching: AUValue = 0.0,
        overlap: AUValue = 8.0
    ) {
        self.input = input
        self.rate = rate
        self.pitching = pitching
        self.overlap = overlap

        avAudioNode = timepitchingAU
    }

    // TODO: This node is untested
}
