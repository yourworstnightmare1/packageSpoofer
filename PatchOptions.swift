import Foundation
import Observation

@Observable
@MainActor
final class PatchOptions {
    var cloneBeforeSpoofing = false
    var applyBinaryFix = false
    var removeFrameworks = false
    var applyAppUnblocker = false
    var hideFileAfterSigning = false
    var bypassGatekeeper = false
    var applyCategorySpoofer = false
    var openAppOnCompletion = false
    var forceMetalHUD = false
}
