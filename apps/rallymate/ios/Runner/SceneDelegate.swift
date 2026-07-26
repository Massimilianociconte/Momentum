import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    let remaining = URLContexts.filter {
      !GarminConnectIqBridge.receiveSelectionURL(
        $0.url,
        sourceApplication: $0.options.sourceApplication
      )
    }
    if !remaining.isEmpty {
      super.scene(scene, openURLContexts: remaining)
    }
  }
}
