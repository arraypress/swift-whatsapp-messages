//
//  FileClones.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//

import Darwin
import Foundation

/// Whether a file is an APFS clone, and what deleting it would free.
///
/// Measured with `cp -c` in a scratch folder: a 3 MB file and its clone each
/// reported a private size of 0 and the "shares all blocks" flag; an
/// ordinary copy reported its whole size and neither flag. So a folder of
/// clones can be deleted file by file and free nothing until the last copy
/// of each goes — which is why the audit reports both numbers.
enum FileClones {

    /// Private size and clone flag, or `nil` where the volume does not say.
    static func info(_ path: String) -> (privateBytes: Int64, sharesAllBlocks: Bool)? {
        var list = attrlist()
        list.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
        list.forkattr = attrgroup_t(ATTR_CMNEXT_PRIVATESIZE | ATTR_CMNEXT_EXT_FLAGS)
        var buffer = [UInt8](repeating: 0, count: 64)
        let options = UInt32(FSOPT_ATTR_CMN_EXTENDED | FSOPT_NOFOLLOW)
        guard getattrlist(path, &list, &buffer, buffer.count, options) == 0 else { return nil }
        // u_int32 length, then the attributes in bit order: PRIVATESIZE
        // (off_t), EXT_FLAGS (u_int64).
        return buffer.withUnsafeBytes { raw in
            let privateSize = raw.loadUnaligned(fromByteOffset: 4, as: Int64.self)
            let flags = raw.loadUnaligned(fromByteOffset: 12, as: UInt64.self)
            return (privateSize, flags & UInt64(EF_SHARES_ALL_BLOCKS) != 0)
        }
    }
}
