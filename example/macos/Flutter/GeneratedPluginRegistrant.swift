//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import audio_session
import fvp
import just_audio
import video_player_avfoundation

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  AudioSessionPlugin.register(with: registry.registrar(forPlugin: "AudioSessionPlugin"))
  FvpPlugin.register(with: registry.registrar(forPlugin: "FvpPlugin"))
  JustAudioPlugin.register(with: registry.registrar(forPlugin: "JustAudioPlugin"))
  VideoPlayerPlugin.register(with: registry.registrar(forPlugin: "VideoPlayerPlugin"))
}
