// Pure key model and byte parser (test X3).

enum Key: Equatable {
    case up, down, home, end, pageUp, pageDown
    case enter, esc, ctrlC, ctrlD, backspace
    case char(Character)          // a printable character (UTF-8 decoded)
    case other                    // any other control key: ignored by the selector
}

private func csiKey(_ params: [UInt8], _ final: UInt8) -> Key {
    switch final {
    case 0x41: return .up                          // ESC [ A   (also ESC [ 1 ; 5 A)
    case 0x42: return .down
    case 0x48: return .home
    case 0x46: return .end
    case 0x7E:                                     // ESC [ n ~
        switch String(decoding: params, as: UTF8.self) {
        case "1", "7": return .home
        case "4", "8": return .end
        case "5": return .pageUp
        case "6": return .pageDown
        default: return .other
        }
    default: return .other
    }
}

/// Raw terminal bytes -> keys. Handles CSI (ESC [ …), SS3 (ESC O …), a lone Esc,
/// control keys and UTF-8 characters.
func parseKeys(_ bytes: [UInt8]) -> [Key] {
    var keys: [Key] = []
    var i = 0
    while i < bytes.count {
        let b = bytes[i]
        switch b {
        case 0x1B:
            if i + 1 < bytes.count, bytes[i + 1] == 0x5B || bytes[i + 1] == 0x4F {
                var j = i + 2
                var params: [UInt8] = []
                while j < bytes.count, !(bytes[j] >= 0x40 && bytes[j] <= 0x7E) {
                    params.append(bytes[j]); j += 1
                }
                if j < bytes.count {
                    keys.append(csiKey(params, bytes[j]))
                    i = j + 1
                } else {                           // incomplete sequence
                    keys.append(.other)
                    i = bytes.count
                }
            } else {
                keys.append(.esc); i += 1
            }
        case 0x03: keys.append(.ctrlC); i += 1
        case 0x04: keys.append(.ctrlD); i += 1
        case 0x0D, 0x0A: keys.append(.enter); i += 1
        case 0x7F, 0x08: keys.append(.backspace); i += 1
        case 0x20..<0x7F:
            keys.append(.char(Character(Unicode.Scalar(b)))); i += 1
        case 0x00..<0x20:
            keys.append(.other); i += 1
        default:                                   // >= 0x80: UTF-8 lead byte
            let len = b >= 0xF0 ? 4 : (b >= 0xE0 ? 3 : (b >= 0xC0 ? 2 : 1))
            if len == 1 { keys.append(.other); i += 1 }
            else if i + len > bytes.count { keys.append(.other); i = bytes.count }
            else {
                let s = String(decoding: bytes[i..<(i + len)], as: UTF8.self)
                if let c = s.first { keys.append(.char(c)) } else { keys.append(.other) }
                i += len
            }
        }
    }
    return keys
}