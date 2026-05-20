import Foundation
import Observation

@Observable
@MainActor
final class PatchOptions {
    var applyBinaryFix = false
    var removeFrameworks = false
    var applyAppUnblocker = false
    var hideFileAfterSigning = false
}
