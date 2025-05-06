// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

import AVFAudio

/// `AUNewpitching` audio unit
/// This is different to `AUNewTimepitching` (`AVAudioUnitTimepitching`).
/// `AUNewTimepitching` does both time stretching and pitching shifting.
/// `AUNewTimepitching` is `AVAudioUnitTimeEffect` and `AUNewpitching` is `AVAudioUnitEffect`
public class Newpitching: Node {
    private let input: Node
    private let pitchingUnit = instantiate(
        componentDescription: AudioComponentDescription(appleEffect: kAudioUnitSubType_NewTimePitch)
    )

    public var connections: [Node] { [input] }
    public var avAudioNode: AVAudioNode { pitchingUnit }

    /// Initialize the time pitching node
    ///
    /// - Parameters:
    ///   - input: Input node to process
    public init(_ input: Node) {
        self.input = input
    }

    /// pitching (Cents) ranges from -2400 to 2400 (Default: 0.0)
    /// NOTE: Base value of pitching is 1.0.
    /// This means that the value of 1 is the state where no pitching shifing is applied.
    public var pitching: AUValue {
        get { AudioUnitGetParameter(pitchingUnit.audioUnit, param: kNewTimePitchParam_Pitch) }
        set { AudioUnitSetParameter(pitchingUnit.audioUnit, param: kNewTimePitchParam_Pitch, to: newValue) }
    }
}
