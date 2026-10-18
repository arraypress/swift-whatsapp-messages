//
//  Protobuf.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Just enough of the protobuf wire format to read two of WhatsApp's blobs.
///
/// No schema and no generated code: fields are read by number, and anything
/// malformed reads as nothing rather than a crash — these bytes come from
/// another app's database, and every length is checked before it is used.
enum Protobuf {

    /// One field.
    enum Value: Equatable {
        case varint(UInt64)
        case bytes(Data)
        case fixed64(UInt64)
        case fixed32(UInt32)
    }

    /// The top-level fields of a message, in order. `nil` if malformed.
    static func fields(_ data: Data) -> [(number: Int, value: Value)]? {
        let bytes = [UInt8](data)
        var index = 0
        var out: [(Int, Value)] = []
        while index < bytes.count {
            guard let key = varint(bytes, &index) else { return nil }
            let number = Int(key >> 3)
            guard number > 0 else { return nil }
            switch key & 7 {
            case 0:
                guard let value = varint(bytes, &index) else { return nil }
                out.append((number, .varint(value)))
            case 1:
                guard index + 8 <= bytes.count else { return nil }
                let value = bytes[index..<index + 8].reversed().reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
                index += 8
                out.append((number, .fixed64(value)))
            case 2:
                guard let length = varint(bytes, &index), length <= UInt64(bytes.count - index) else { return nil }
                let end = index + Int(length)
                out.append((number, .bytes(Data(bytes[index..<end]))))
                index = end
            case 5:
                guard index + 4 <= bytes.count else { return nil }
                let value = bytes[index..<index + 4].reversed().reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
                index += 4
                out.append((number, .fixed32(value)))
            default:
                return nil
            }
        }
        return out
    }

    /// The first length-delimited field with this number, as UTF-8 text.
    static func string(_ fields: [(number: Int, value: Value)], _ number: Int) -> String? {
        for field in fields where field.number == number {
            if case .bytes(let data) = field.value { return String(data: data, encoding: .utf8) }
        }
        return nil
    }

    /// Every length-delimited field with this number.
    static func messages(_ fields: [(number: Int, value: Value)], _ number: Int) -> [Data] {
        fields.compactMap { field in
            guard field.number == number, case .bytes(let data) = field.value else { return nil }
            return data
        }
    }

    /// The first varint field with this number.
    static func integer(_ fields: [(number: Int, value: Value)], _ number: Int) -> UInt64? {
        for field in fields where field.number == number {
            if case .varint(let value) = field.value { return value }
        }
        return nil
    }

    /// A base-128 varint, advancing `index`; `nil` if it runs off the end or
    /// past ten bytes.
    static func varint(_ bytes: [UInt8], _ index: inout Int) -> UInt64? {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while index < bytes.count, shift < 64 {
            let byte = bytes[index]
            index += 1
            result |= UInt64(byte & 0x7f) << shift
            if byte & 0x80 == 0 { return result }
            shift += 7
        }
        return nil
    }

    // MARK: - Writing, for fixtures

    /// A varint's bytes.
    static func encodeVarint(_ value: UInt64) -> [UInt8] {
        var value = value
        var out: [UInt8] = []
        repeat {
            var byte = UInt8(value & 0x7f)
            value >>= 7
            if value != 0 { byte |= 0x80 }
            out.append(byte)
        } while value != 0
        return out
    }

    /// A field's bytes: tests build WhatsApp-shaped blobs with these.
    static func encode(_ number: Int, _ value: Value) -> Data {
        var out: [UInt8]
        switch value {
        case .varint(let v):
            out = encodeVarint(UInt64(number) << 3) + encodeVarint(v)
        case .bytes(let data):
            out = encodeVarint(UInt64(number) << 3 | 2) + encodeVarint(UInt64(data.count)) + [UInt8](data)
        case .fixed64(let v):
            out = encodeVarint(UInt64(number) << 3 | 1) + (0..<8).map { UInt8(truncatingIfNeeded: v >> ($0 * 8)) }
        case .fixed32(let v):
            out = encodeVarint(UInt64(number) << 3 | 5) + (0..<4).map { UInt8(truncatingIfNeeded: v >> ($0 * 8)) }
        }
        return Data(out)
    }
}
