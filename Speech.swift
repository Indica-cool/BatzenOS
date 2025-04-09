import AVFoundation

func speak(text: String) {
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: "de-DE")
    AVSpeechSynthesizer().speak(utterance)
}
