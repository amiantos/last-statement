//
//  TokeniserState.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 12/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

protocol TokeniserStateProtocol {
    func read(_ t: Tokeniser, _ r: CharacterReader) throws
}

public class TokeniserStateVars {
    public static let nullScalr: UnicodeScalar = "\u{0000}"

    static let attributeSingleValueCharsSorted = ["'", UnicodeScalar.Ampersand, nullScalr].sorted()
    static let attributeDoubleValueCharsSorted = ["\"", UnicodeScalar.Ampersand, nullScalr].sorted()
    static let attributeNameCharsSorted = [UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ", "/", "=", ">", nullScalr, "\"", "'", UnicodeScalar.LessThan].sorted()
    static let attributeValueUnquoted = [UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ", UnicodeScalar.Ampersand, ">", nullScalr, "\"", "'", UnicodeScalar.LessThan, "=", "`"].sorted()

    static let replacementChar: UnicodeScalar = Tokeniser.replacementChar
    static let replacementStr: String = String(Tokeniser.replacementChar)
    static let eof: UnicodeScalar = CharacterReader.EOF
}

enum TokeniserState: TokeniserStateProtocol {
    case Data
    case CharacterReferenceInData
    case Rcdata
    case CharacterReferenceInRcdata
    case Rawtext
    case ScriptData
    case PLAINTEXT
    case TagOpen
    case EndTagOpen
    case TagName
    case RcdataLessthanSign
    case RCDATAEndTagOpen
    case RCDATAEndTagName
    case RawtextLessthanSign
    case RawtextEndTagOpen
    case RawtextEndTagName
    case ScriptDataLessthanSign
    case ScriptDataEndTagOpen
    case ScriptDataEndTagName
    case ScriptDataEscapeStart
    case ScriptDataEscapeStartDash
    case ScriptDataEscaped
    case ScriptDataEscapedDash
    case ScriptDataEscapedDashDash
    case ScriptDataEscapedLessthanSign
    case ScriptDataEscapedEndTagOpen
    case ScriptDataEscapedEndTagName
    case ScriptDataDoubleEscapeStart
    case ScriptDataDoubleEscaped
    case ScriptDataDoubleEscapedDash
    case ScriptDataDoubleEscapedDashDash
    case ScriptDataDoubleEscapedLessthanSign
    case ScriptDataDoubleEscapeEnd
    case BeforeAttributeName
    case AttributeName
    case AfterAttributeName
    case BeforeAttributeValue
    case AttributeValue_doubleQuoted
    case AttributeValue_singleQuoted
    case AttributeValue_unquoted
    case AfterAttributeValue_quoted
    case SelfClosingStartTag
    case BogusComment
    case MarkupDeclarationOpen
    case CommentStart
    case CommentStartDash
    case Comment
    case CommentEndDash
    case CommentEnd
    case CommentEndBang
    case Doctype
    case BeforeDoctypeName
    case DoctypeName
    case AfterDoctypeName
    case AfterDoctypePublicKeyword
    case BeforeDoctypePublicIdentifier
    case DoctypePublicIdentifier_doubleQuoted
    case DoctypePublicIdentifier_singleQuoted
    case AfterDoctypePublicIdentifier
    case BetweenDoctypePublicAndSystemIdentifiers
    case AfterDoctypeSystemKeyword
    case BeforeDoctypeSystemIdentifier
    case DoctypeSystemIdentifier_doubleQuoted
    case DoctypeSystemIdentifier_singleQuoted
    case AfterDoctypeSystemIdentifier
    case BogusDoctype
    case CdataSection

    internal func read(_ t: Tokeniser, _ r: CharacterReader) throws {
        switch self {
        case .Data:
            switch r.current() {
            case UnicodeScalar.Ampersand:
                t.advanceTransition(.CharacterReferenceInData)
            case UnicodeScalar.LessThan:
                t.advanceTransition(.TagOpen)
            case TokeniserStateVars.nullScalr:
                t.error(self) // NOT replacement character (oddly?)
                t.emit(r.consume())
            case TokeniserStateVars.eof:
                try t.emit(Token.EOF())
            default:
                let data: String = r.consumeData()
                t.emit(data)
            }
        case .CharacterReferenceInData:
            try TokeniserState.readCharRef(t, .Data)
        case .Rcdata:
            switch r.current() {
            case UnicodeScalar.Ampersand:
                t.advanceTransition(.CharacterReferenceInRcdata)
            case UnicodeScalar.LessThan:
                t.advanceTransition(.RcdataLessthanSign)
            case TokeniserStateVars.nullScalr:
                t.error(self)
                r.advance()
                t.emit(TokeniserStateVars.replacementChar)
            case TokeniserStateVars.eof:
                try t.emit(Token.EOF())
            default:
                let data = r.consumeToAny(UnicodeScalar.Ampersand, UnicodeScalar.LessThan, TokeniserStateVars.nullScalr)
                t.emit(data)
            }
        case .CharacterReferenceInRcdata:
            try TokeniserState.readCharRef(t, .Rcdata)
        case .Rawtext:
            try TokeniserState.readData(t, r, self, .RawtextLessthanSign)
        case .ScriptData:
            try TokeniserState.readData(t, r, self, .ScriptDataLessthanSign)
        case .PLAINTEXT:
            switch r.current() {
            case TokeniserStateVars.nullScalr:
                t.error(self)
                r.advance()
                t.emit(TokeniserStateVars.replacementChar)
            case TokeniserStateVars.eof:
                try t.emit(Token.EOF())
            default:
                let data = r.consumeTo(TokeniserStateVars.nullScalr)
                t.emit(data)
            }
        case .TagOpen:
            // from < in data
            switch r.current() {
            case "!":
                t.advanceTransition(.MarkupDeclarationOpen)
            case "/":
                t.advanceTransition(.EndTagOpen)
            case "?":
                t.advanceTransition(.BogusComment)
            default:
                if r.matchesLetter() {
                    t.createTagPending(true)
                    t.transition(.TagName)
                } else {
                    t.error(self)
                    t.emit(UnicodeScalar.LessThan) // char that got us here
                    t.transition(.Data)
                }
            }
        case .EndTagOpen:
            if r.isEmpty() {
                t.eofError(self)
                t.emit("</")
                t.transition(.Data)
            } else if r.matchesLetter() {
                t.createTagPending(false)
                t.transition(.TagName)
            } else if r.matches(">") {
                t.error(self)
                t.advanceTransition(.Data)
            } else {
                t.error(self)
                t.advanceTransition(.BogusComment)
            }
        case .TagName:
            // from < or </ in data, will have start or end tag pending
            // previous TagOpen state did NOT consume, will have a letter char in current
            // String tagName = r.consumeToAnySorted(tagCharsSorted).toLowerCase()
            let tagName = r.consumeTagName()
            t.tagPending.appendTagName(tagName)

            switch r.consume() {
            case UnicodeScalar.BackslashT:
                t.transition(.BeforeAttributeName)
            case "\n":
                t.transition(.BeforeAttributeName)
            case "\r":
                t.transition(.BeforeAttributeName)
            case UnicodeScalar.BackslashF:
                t.transition(.BeforeAttributeName)
            case " ":
                t.transition(.BeforeAttributeName)
            case "/":
                t.transition(.SelfClosingStartTag)
            case ">":
                try t.emitTagPending()
                t.transition(.Data)
            case TokeniserStateVars.nullScalr: // replacement
                t.tagPending.appendTagName(TokeniserStateVars.replacementStr)
            case TokeniserStateVars.eof: // should emit pending tag?
                t.eofError(self)
                t.transition(.Data)
            // no default, as covered with above consumeToAny
            default:
                break
            }
        case .RcdataLessthanSign:
            if r.matches("/") {
                t.createTempBuffer()
                t.advanceTransition(.RCDATAEndTagOpen)
            } else if r.matchesLetter(), t.appropriateEndTagName() != nil, !r.containsIgnoreCase("</" + t.appropriateEndTagName()!) {
                // diverge from spec: got a start tag, but there's no appropriate end tag (</title>), so rather than
                // consuming to EOF break out here
                t.tagPending = t.createTagPending(false).name(t.appropriateEndTagName()!)
                try t.emitTagPending()
                r.unconsume() // undo UnicodeScalar.LessThan
                t.transition(.Data)
            } else {
                t.emit(UnicodeScalar.LessThan)
                t.transition(.Rcdata)
            }
        case .RCDATAEndTagOpen:
            if r.matchesLetter() {
                t.createTagPending(false)
                t.tagPending.appendTagName(r.current())
                t.dataBuffer.append(r.current())
                t.advanceTransition(.RCDATAEndTagName)
            } else {
                t.emit("</")
                t.transition(.Rcdata)
            }
        case .RCDATAEndTagName:
            if r.matchesLetter() {
                let name = r.consumeLetterSequence()
                t.tagPending.appendTagName(name)
                t.dataBuffer.append(name)
                return
            }

            func anythingElse(_ t: Tokeniser, _ r: CharacterReader) {
                t.emit("</" + t.dataBuffer.toString())
                r.unconsume()
                t.transition(.Rcdata)
            }

            let c = r.consume()
            switch c {
            case UnicodeScalar.BackslashT:
                if try t.isAppropriateEndTagToken() {
                    t.transition(.BeforeAttributeName)
                } else {
                    anythingElse(t, r)
                }
            case "\n":
                if try t.isAppropriateEndTagToken() {
                    t.transition(.BeforeAttributeName)
                } else {
                    anythingElse(t, r)
                }
            case "\r":
                if try t.isAppropriateEndTagToken() {
                    t.transition(.BeforeAttributeName)
                } else {
                    anythingElse(t, r)
                }
            case UnicodeScalar.BackslashF:
                if try t.isAppropriateEndTagToken() {
                    t.transition(.BeforeAttributeName)
                } else {
                    anythingElse(t, r)
                }
            case " ":
                if try t.isAppropriateEndTagToken() {
                    t.transition(.BeforeAttributeName)
                } else {
                    anythingElse(t, r)
                }
            case "/":
                if try t.isAppropriateEndTagToken() {
                    t.transition(.SelfClosingStartTag)
                } else {
                    anythingElse(t, r)
                }
            case ">":
                if try t.isAppropriateEndTagToken() {
                    try t.emitTagPending()
                    t.transition(.Data)
                } else { anythingElse(t, r) }
            default:
                anythingElse(t, r)
            }
        case .RawtextLessthanSign:
            if r.matches("/") {
                t.createTempBuffer()
                t.advanceTransition(.RawtextEndTagOpen)
            } else {
                t.emit(UnicodeScalar.LessThan)
                t.transition(.Rawtext)
            }
        case .RawtextEndTagOpen:
            TokeniserState.readEndTag(t, r, .RawtextEndTagName, .Rawtext)
        case .RawtextEndTagName:
            try TokeniserState.handleDataEndTag(t, r, .Rawtext)
        case .ScriptDataLessthanSign:
            switch r.consume() {
            case "/":
                t.createTempBuffer()
                t.transition(.ScriptDataEndTagOpen)
            case "!":
                t.emit("<!")
                t.transition(.ScriptDataEscapeStart)
            default:
                t.emit(UnicodeScalar.LessThan)
                r.unconsume()
                t.transition(.ScriptData)
            }
        case .ScriptDataEndTagOpen:
            TokeniserState.readEndTag(t, r, .ScriptDataEndTagName, .ScriptData)
        case .ScriptDataEndTagName:
            try TokeniserState.handleDataEndTag(t, r, .ScriptData)
        case .ScriptDataEscapeStart:
            if r.matches("-") {
                t.emit("-")
                t.advanceTransition(.ScriptDataEscapeStartDash)
            } else {
                t.transition(.ScriptData)
            }
        case .ScriptDataEscapeStartDash:
            if r.matches("-") {
                t.emit("-")
                t.advanceTransition(.ScriptDataEscapedDashDash)
            } else {
                t.transition(.ScriptData)
            }
        case .ScriptDataEscaped:
            if r.isEmpty() {
                t.eofError(self)
                t.transition(.Data)
                return
            }

            switch r.current() {
            case "-":
                t.emit("-")
                t.advanceTransition(.ScriptDataEscapedDash)
            case UnicodeScalar.LessThan:
                t.advanceTransition(.ScriptDataEscapedLessthanSign)
            case TokeniserStateVars.nullScalr:
                t.error(self)
                r.advance()
                t.emit(TokeniserStateVars.replacementChar)
            default:
                let data = r.consumeToAny("-", UnicodeScalar.LessThan, TokeniserStateVars.nullScalr)
                t.emit(data)
            }
        case .ScriptDataEscapedDash:
            if r.isEmpty() {
                t.eofError(self)
                t.transition(.Data)
                return
            }

            let c = r.consume()
            switch c {
            case "-":
                t.emit(c)
                t.transition(.ScriptDataEscapedDashDash)
            case UnicodeScalar.LessThan:
                t.transition(.ScriptDataEscapedLessthanSign)
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.emit(TokeniserStateVars.replacementChar)
                t.transition(.ScriptDataEscaped)
            default:
                t.emit(c)
                t.transition(.ScriptDataEscaped)
            }
        case .ScriptDataEscapedDashDash:
            if r.isEmpty() {
                t.eofError(self)
                t.transition(.Data)
                return
            }

            let c = r.consume()
            switch c {
            case "-":
                t.emit(c)
            case UnicodeScalar.LessThan:
                t.transition(.ScriptDataEscapedLessthanSign)
            case ">":
                t.emit(c)
                t.transition(.ScriptData)
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.emit(TokeniserStateVars.replacementChar)
                t.transition(.ScriptDataEscaped)
            default:
                t.emit(c)
                t.transition(.ScriptDataEscaped)
            }
        case .ScriptDataEscapedLessthanSign:
            if r.matchesLetter() {
                t.createTempBuffer()
                t.dataBuffer.append(r.current())
                t.emit("<" + String(r.current()))
                t.advanceTransition(.ScriptDataDoubleEscapeStart)
            } else if r.matches("/") {
                t.createTempBuffer()
                t.advanceTransition(.ScriptDataEscapedEndTagOpen)
            } else {
                t.emit(UnicodeScalar.LessThan)
                t.transition(.ScriptDataEscaped)
            }
        case .ScriptDataEscapedEndTagOpen:
            if r.matchesLetter() {
                t.createTagPending(false)
                t.tagPending.appendTagName(r.current())
                t.dataBuffer.append(r.current())
                t.advanceTransition(.ScriptDataEscapedEndTagName)
            } else {
                t.emit("</")
                t.transition(.ScriptDataEscaped)
            }
        case .ScriptDataEscapedEndTagName:
            try TokeniserState.handleDataEndTag(t, r, .ScriptDataEscaped)
        case .ScriptDataDoubleEscapeStart:
            TokeniserState.handleDataDoubleEscapeTag(t, r, .ScriptDataDoubleEscaped, .ScriptDataEscaped)
        case .ScriptDataDoubleEscaped:
            let c = r.current()
            switch c {
            case "-":
                t.emit(c)
                t.advanceTransition(.ScriptDataDoubleEscapedDash)
            case UnicodeScalar.LessThan:
                t.emit(c)
                t.advanceTransition(.ScriptDataDoubleEscapedLessthanSign)
            case TokeniserStateVars.nullScalr:
                t.error(self)
                r.advance()
                t.emit(TokeniserStateVars.replacementChar)
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
            default:
                let data = r.consumeToAny("-", UnicodeScalar.LessThan, TokeniserStateVars.nullScalr)
                t.emit(data)
            }
        case .ScriptDataDoubleEscapedDash:
            let c = r.consume()
            switch c {
            case "-":
                t.emit(c)
                t.transition(.ScriptDataDoubleEscapedDashDash)
            case UnicodeScalar.LessThan:
                t.emit(c)
                t.transition(.ScriptDataDoubleEscapedLessthanSign)
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.emit(TokeniserStateVars.replacementChar)
                t.transition(.ScriptDataDoubleEscaped)
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
            default:
                t.emit(c)
                t.transition(.ScriptDataDoubleEscaped)
            }
        case .ScriptDataDoubleEscapedDashDash:
            let c = r.consume()
            switch c {
            case "-":
                t.emit(c)
            case UnicodeScalar.LessThan:
                t.emit(c)
                t.transition(.ScriptDataDoubleEscapedLessthanSign)
            case ">":
                t.emit(c)
                t.transition(.ScriptData)
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.emit(TokeniserStateVars.replacementChar)
                t.transition(.ScriptDataDoubleEscaped)
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
            default:
                t.emit(c)
                t.transition(.ScriptDataDoubleEscaped)
            }
        case .ScriptDataDoubleEscapedLessthanSign:
            if r.matches("/") {
                t.emit("/")
                t.createTempBuffer()
                t.advanceTransition(.ScriptDataDoubleEscapeEnd)
            } else {
                t.transition(.ScriptDataDoubleEscaped)
            }
        case .ScriptDataDoubleEscapeEnd:
            TokeniserState.handleDataDoubleEscapeTag(t, r, .ScriptDataEscaped, .ScriptDataDoubleEscaped)
        case .BeforeAttributeName:
            // from tagname <xxx
            let c = r.consume()
            switch c {
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                break // ignore whitespace
            case "/":
                t.transition(.SelfClosingStartTag)
            case ">":
                try t.emitTagPending()
                t.transition(.Data)
            case TokeniserStateVars.nullScalr:
                t.error(self)
                try t.tagPending.newAttribute()
                r.unconsume()
                t.transition(.AttributeName)
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
            case "\"", "'", UnicodeScalar.LessThan, "=":
                t.error(self)
                try t.tagPending.newAttribute()
                t.tagPending.appendAttributeName(c)
                t.transition(.AttributeName)
            default: // A-Z, anything else
                try t.tagPending.newAttribute()
                r.unconsume()
                t.transition(.AttributeName)
            }
        case .AttributeName:
            let name = r.consumeToAnySorted(TokeniserStateVars.attributeNameCharsSorted)
            t.tagPending.appendAttributeName(name)

            let c = r.consume()
            switch c {
            case UnicodeScalar.BackslashT:
                t.transition(.AfterAttributeName)
            case "\n":
                t.transition(.AfterAttributeName)
            case "\r":
                t.transition(.AfterAttributeName)
            case UnicodeScalar.BackslashF:
                t.transition(.AfterAttributeName)
            case " ":
                t.transition(.AfterAttributeName)
            case "/":
                t.transition(.SelfClosingStartTag)
            case "=":
                t.transition(.BeforeAttributeValue)
            case ">":
                try t.emitTagPending()
                t.transition(.Data)
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.tagPending.appendAttributeName(TokeniserStateVars.replacementChar)
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
            case "\"":
                t.error(self)
                t.tagPending.appendAttributeName(c)
            case "'":
                t.error(self)
                t.tagPending.appendAttributeName(c)
            case UnicodeScalar.LessThan:
                t.error(self)
                t.tagPending.appendAttributeName(c)
            // no default, as covered in consumeToAny
            default:
                break
            }
        case .AfterAttributeName:
            let c = r.consume()
            switch c {
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                // ignore
                break
            case "/":
                t.transition(.SelfClosingStartTag)
            case "=":
                t.transition(.BeforeAttributeValue)
            case ">":
                try t.emitTagPending()
                t.transition(.Data)
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.tagPending.appendAttributeName(TokeniserStateVars.replacementChar)
                t.transition(.AttributeName)
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
            case "\"", "'", UnicodeScalar.LessThan:
                t.error(self)
                try t.tagPending.newAttribute()
                t.tagPending.appendAttributeName(c)
                t.transition(.AttributeName)
            default: // A-Z, anything else
                try t.tagPending.newAttribute()
                r.unconsume()
                t.transition(.AttributeName)
            }
        case .BeforeAttributeValue:
            let c = r.consume()
            switch c {
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                // ignore
                break
            case "\"":
                t.transition(.AttributeValue_doubleQuoted)
            case UnicodeScalar.Ampersand:
                r.unconsume()
                t.transition(.AttributeValue_unquoted)
            case "'":
                t.transition(.AttributeValue_singleQuoted)
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.tagPending.appendAttributeValue(TokeniserStateVars.replacementChar)
                t.transition(.AttributeValue_unquoted)
            case TokeniserStateVars.eof:
                t.eofError(self)
                try t.emitTagPending()
                t.transition(.Data)
            case ">":
                t.error(self)
                try t.emitTagPending()
                t.transition(.Data)
            case UnicodeScalar.LessThan, "=", "`":
                t.error(self)
                t.tagPending.appendAttributeValue(c)
                t.transition(.AttributeValue_unquoted)
            default:
                r.unconsume()
                t.transition(.AttributeValue_unquoted)
            }
        case .AttributeValue_doubleQuoted:
            let value = r.consumeToAny(TokeniserStateVars.attributeDoubleValueCharsSorted)
            if value.count > 0 {
                t.tagPending.appendAttributeValue(value)
            } else {
                t.tagPending.setEmptyAttributeValue()
            }

            let c = r.consume()
            switch c {
            case "\"":
                t.transition(.AfterAttributeValue_quoted)
            case UnicodeScalar.Ampersand:

                if let ref = try t.consumeCharacterReference("\"", true) {
                    t.tagPending.appendAttributeValue(ref)
                } else {
                    t.tagPending.appendAttributeValue(UnicodeScalar.Ampersand)
                }
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.tagPending.appendAttributeValue(TokeniserStateVars.replacementChar)
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
            // no default, handled in consume to any above
            default:
                break
            }
        case .AttributeValue_singleQuoted:
            let value = r.consumeToAny(TokeniserStateVars.attributeSingleValueCharsSorted)
            if value.count > 0 {
                t.tagPending.appendAttributeValue(value)
            } else {
                t.tagPending.setEmptyAttributeValue()
            }

            let c = r.consume()
            switch c {
            case "'":
                t.transition(.AfterAttributeValue_quoted)
            case UnicodeScalar.Ampersand:

                if let ref = try t.consumeCharacterReference("'", true) {
                    t.tagPending.appendAttributeValue(ref)
                } else {
                    t.tagPending.appendAttributeValue(UnicodeScalar.Ampersand)
                }
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.tagPending.appendAttributeValue(TokeniserStateVars.replacementChar)
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
            // no default, handled in consume to any above
            default:
                break
            }
        case .AttributeValue_unquoted:
            let value = r.consumeToAnySorted(TokeniserStateVars.attributeValueUnquoted)
            if value.count > 0 {
                t.tagPending.appendAttributeValue(value)
            }

            let c = r.consume()
            switch c {
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                t.transition(.BeforeAttributeName)
            case UnicodeScalar.Ampersand:
                if let ref = try t.consumeCharacterReference(">", true) {
                    t.tagPending.appendAttributeValue(ref)
                } else {
                    t.tagPending.appendAttributeValue(UnicodeScalar.Ampersand)
                }
            case ">":
                try t.emitTagPending()
                t.transition(.Data)
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.tagPending.appendAttributeValue(TokeniserStateVars.replacementChar)
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
            case "\"", "'", UnicodeScalar.LessThan, "=", "`":
                t.error(self)
                t.tagPending.appendAttributeValue(c)
            // no default, handled in consume to any above
            default:
                break
            }
        case .AfterAttributeValue_quoted:
            // CharacterReferenceInAttributeValue state handled inline
            let c = r.consume()
            switch c {
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                t.transition(.BeforeAttributeName)
            case "/":
                t.transition(.SelfClosingStartTag)
            case ">":
                try t.emitTagPending()
                t.transition(.Data)
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
            default:
                t.error(self)
                r.unconsume()
                t.transition(.BeforeAttributeName)
            }
        case .SelfClosingStartTag:
            let c = r.consume()
            switch c {
            case ">":
                t.tagPending._selfClosing = true
                try t.emitTagPending()
                t.transition(.Data)
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
            default:
                t.error(self)
                r.unconsume()
                t.transition(.BeforeAttributeName)
            }
        case .BogusComment:
            // TODO: handle bogus comment starting from eof. when does that trigger?
            // rewind to capture character that lead us here
            r.unconsume()
            let comment: Token.Comment = Token.Comment()
            comment.bogus = true
            comment.data.append(r.consumeTo(">"))
            // TODO: replace nullChar with replaceChar
            try t.emit(comment)
            t.advanceTransition(.Data)
        case .MarkupDeclarationOpen:
            if r.matchConsume("--") {
                t.createCommentPending()
                t.transition(.CommentStart)
            } else if r.matchConsumeIgnoreCase("DOCTYPE") {
                t.transition(.Doctype)
            } else if r.matchConsume("[CDATA[") {
                // TODO: should actually check current namepspace, and only non-html allows cdata. until namespace
                // is implemented properly, keep handling as cdata
                // } else if (!t.currentNodeInHtmlNS() && r.matchConsume("[CDATA[")) {
                t.transition(.CdataSection)
            } else {
                t.error(self)
                t.advanceTransition(.BogusComment) // advance so self character gets in bogus comment data's rewind
            }
        case .CommentStart:
            let c = r.consume()
            switch c {
            case "-":
                t.transition(.CommentStartDash)
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.commentPending.data.append(TokeniserStateVars.replacementChar)
                t.transition(.Comment)
            case ">":
                t.error(self)
                try t.emitCommentPending()
                t.transition(.Data)
            case TokeniserStateVars.eof:
                t.eofError(self)
                try t.emitCommentPending()
                t.transition(.Data)
            default:
                t.commentPending.data.append(c)
                t.transition(.Comment)
            }
        case .CommentStartDash:
            let c = r.consume()
            switch c {
            case "-":
                t.transition(.CommentStartDash)
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.commentPending.data.append(TokeniserStateVars.replacementChar)
                t.transition(.Comment)
            case ">":
                t.error(self)
                try t.emitCommentPending()
                t.transition(.Data)
            case TokeniserStateVars.eof:
                t.eofError(self)
                try t.emitCommentPending()
                t.transition(.Data)
            default:
                t.commentPending.data.append(c)
                t.transition(.Comment)
            }
        case .Comment:
            let c = r.current()
            switch c {
            case "-":
                t.advanceTransition(.CommentEndDash)
            case TokeniserStateVars.nullScalr:
                t.error(self)
                r.advance()
                t.commentPending.data.append(TokeniserStateVars.replacementChar)
            case TokeniserStateVars.eof:
                t.eofError(self)
                try t.emitCommentPending()
                t.transition(.Data)
            default:
                t.commentPending.data.append(r.consumeToAny("-", TokeniserStateVars.nullScalr))
            }
        case .CommentEndDash:
            let c = r.consume()
            switch c {
            case "-":
                t.transition(.CommentEnd)
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.commentPending.data.append("-").append(TokeniserStateVars.replacementChar)
                t.transition(.Comment)
            case TokeniserStateVars.eof:
                t.eofError(self)
                try t.emitCommentPending()
                t.transition(.Data)
            default:
                t.commentPending.data.append("-").append(c)
                t.transition(.Comment)
            }
        case .CommentEnd:
            let c = r.consume()
            switch c {
            case ">":
                try t.emitCommentPending()
                t.transition(.Data)
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.commentPending.data.append("--").append(TokeniserStateVars.replacementChar)
                t.transition(.Comment)
            case "!":
                t.error(self)
                t.transition(.CommentEndBang)
            case "-":
                t.error(self)
                t.commentPending.data.append("-")
            case TokeniserStateVars.eof:
                t.eofError(self)
                try t.emitCommentPending()
                t.transition(.Data)
            default:
                t.error(self)
                t.commentPending.data.append("--").append(c)
                t.transition(.Comment)
            }
        case .CommentEndBang:
            let c = r.consume()
            switch c {
            case "-":
                t.commentPending.data.append("--!")
                t.transition(.CommentEndDash)
            case ">":
                try t.emitCommentPending()
                t.transition(.Data)
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.commentPending.data.append("--!").append(TokeniserStateVars.replacementChar)
                t.transition(.Comment)
            case TokeniserStateVars.eof:
                t.eofError(self)
                try t.emitCommentPending()
                t.transition(.Data)
            default:
                t.commentPending.data.append("--!").append(c)
                t.transition(.Comment)
            }
        case .Doctype:
            let c = r.consume()
            switch c {
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                t.transition(.BeforeDoctypeName)
            case TokeniserStateVars.eof:
                t.eofError(self)
            // note: fall through to > case
            case ">": // catch invalid <!DOCTYPE>
                t.error(self)
                t.createDoctypePending()
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
            default:
                t.error(self)
                t.transition(.BeforeDoctypeName)
            }
        case .BeforeDoctypeName:
            if r.matchesLetter() {
                t.createDoctypePending()
                t.transition(.DoctypeName)
                return
            }
            let c = r.consume()
            switch c {
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                break // ignore whitespace
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.createDoctypePending()
                t.doctypePending.name.append(TokeniserStateVars.replacementChar)
                t.transition(.DoctypeName)
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.createDoctypePending()
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
            default:
                t.createDoctypePending()
                t.doctypePending.name.append(c)
                t.transition(.DoctypeName)
            }
        case .DoctypeName:
            if r.matchesLetter() {
                let name = r.consumeLetterSequence()
                t.doctypePending.name.append(name)
                return
            }
            let c = r.consume()
            switch c {
            case ">":
                try t.emitDoctypePending()
                t.transition(.Data)
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                t.transition(.AfterDoctypeName)
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.doctypePending.name.append(TokeniserStateVars.replacementChar)
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
            default:
                t.doctypePending.name.append(c)
            }
        case .AfterDoctypeName:
            if r.isEmpty() {
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                return
            }
            if r.matchesAny(UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ") {
                r.advance() // ignore whitespace
            } else if r.matches(">") {
                try t.emitDoctypePending()
                t.advanceTransition(.Data)
            } else if r.matchConsumeIgnoreCase(DocumentType.PUBLIC_KEY) {
                t.doctypePending.pubSysKey = DocumentType.PUBLIC_KEY
                t.transition(.AfterDoctypePublicKeyword)
            } else if r.matchConsumeIgnoreCase(DocumentType.SYSTEM_KEY) {
                t.doctypePending.pubSysKey = DocumentType.SYSTEM_KEY
                t.transition(.AfterDoctypeSystemKeyword)
            } else {
                t.error(self)
                t.doctypePending.forceQuirks = true
                t.advanceTransition(.BogusDoctype)
            }
        case .AfterDoctypePublicKeyword:
            let c = r.consume()
            switch c {
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                t.transition(.BeforeDoctypePublicIdentifier)
            case "\"":
                t.error(self)
                // set public id to empty string
                t.transition(.DoctypePublicIdentifier_doubleQuoted)
            case "'":
                t.error(self)
                // set public id to empty string
                t.transition(.DoctypePublicIdentifier_singleQuoted)
            case ">":
                t.error(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
            default:
                t.error(self)
                t.doctypePending.forceQuirks = true
                t.transition(.BogusDoctype)
            }
        case .BeforeDoctypePublicIdentifier:
            let c = r.consume()
            switch c {
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                break
            case "\"":
                // set public id to empty string
                t.transition(.DoctypePublicIdentifier_doubleQuoted)
            case "'":
                // set public id to empty string
                t.transition(.DoctypePublicIdentifier_singleQuoted)
            case ">":
                t.error(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
            default:
                t.error(self)
                t.doctypePending.forceQuirks = true
                t.transition(.BogusDoctype)
            }
        case .DoctypePublicIdentifier_doubleQuoted:
            let c = r.consume()
            switch c {
            case "\"":
                t.transition(.AfterDoctypePublicIdentifier)
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.doctypePending.publicIdentifier.append(TokeniserStateVars.replacementChar)
            case ">":
                t.error(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
            default:
                t.doctypePending.publicIdentifier.append(c)
            }
        case .DoctypePublicIdentifier_singleQuoted:
            let c = r.consume()
            switch c {
            case "'":
                t.transition(.AfterDoctypePublicIdentifier)
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.doctypePending.publicIdentifier.append(TokeniserStateVars.replacementChar)
            case ">":
                t.error(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
            default:
                t.doctypePending.publicIdentifier.append(c)
            }
        case .AfterDoctypePublicIdentifier:
            let c = r.consume()
            switch c {
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                t.transition(.BetweenDoctypePublicAndSystemIdentifiers)
            case ">":
                try t.emitDoctypePending()
                t.transition(.Data)
            case "\"":
                t.error(self)
                // system id empty
                t.transition(.DoctypeSystemIdentifier_doubleQuoted)
            case "'":
                t.error(self)
                // system id empty
                t.transition(.DoctypeSystemIdentifier_singleQuoted)
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
            default:
                t.error(self)
                t.doctypePending.forceQuirks = true
                t.transition(.BogusDoctype)
            }
        case .BetweenDoctypePublicAndSystemIdentifiers:
            let c = r.consume()
            switch c {
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                break
            case ">":
                try t.emitDoctypePending()
                t.transition(.Data)
            case "\"":
                t.error(self)
                // system id empty
                t.transition(.DoctypeSystemIdentifier_doubleQuoted)
            case "'":
                t.error(self)
                // system id empty
                t.transition(.DoctypeSystemIdentifier_singleQuoted)
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
            default:
                t.error(self)
                t.doctypePending.forceQuirks = true
                t.transition(.BogusDoctype)
            }
        case .AfterDoctypeSystemKeyword:
            let c = r.consume()
            switch c {
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                t.transition(.BeforeDoctypeSystemIdentifier)
            case ">":
                t.error(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
            case "\"":
                t.error(self)
                // system id empty
                t.transition(.DoctypeSystemIdentifier_doubleQuoted)
            case "'":
                t.error(self)
                // system id empty
                t.transition(.DoctypeSystemIdentifier_singleQuoted)
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
            default:
                t.error(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
            }
        case .BeforeDoctypeSystemIdentifier:
            let c = r.consume()
            switch c {
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                break
            case "\"":
                // set system id to empty string
                t.transition(.DoctypeSystemIdentifier_doubleQuoted)
            case "'":
                // set public id to empty string
                t.transition(.DoctypeSystemIdentifier_singleQuoted)
            case ">":
                t.error(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
            default:
                t.error(self)
                t.doctypePending.forceQuirks = true
                t.transition(.BogusDoctype)
            }
        case .DoctypeSystemIdentifier_doubleQuoted:
            let c = r.consume()
            switch c {
            case "\"":
                t.transition(.AfterDoctypeSystemIdentifier)
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.doctypePending.systemIdentifier.append(TokeniserStateVars.replacementChar)
            case ">":
                t.error(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
            default:
                t.doctypePending.systemIdentifier.append(c)
            }
        case .DoctypeSystemIdentifier_singleQuoted:
            let c = r.consume()
            switch c {
            case "'":
                t.transition(.AfterDoctypeSystemIdentifier)
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.doctypePending.systemIdentifier.append(TokeniserStateVars.replacementChar)
            case ">":
                t.error(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
            default:
                t.doctypePending.systemIdentifier.append(c)
            }
        case .AfterDoctypeSystemIdentifier:
            let c = r.consume()
            switch c {
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                break
            case ">":
                try t.emitDoctypePending()
                t.transition(.Data)
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
            default:
                t.error(self)
                t.transition(.BogusDoctype)
                // NOT force quirks
            }
        case .BogusDoctype:
            let c = r.consume()
            switch c {
            case ">":
                try t.emitDoctypePending()
                t.transition(.Data)
            case TokeniserStateVars.eof:
                try t.emitDoctypePending()
                t.transition(.Data)
            default:
                // ignore char
                break
            }
        case .CdataSection:
            let data = r.consumeTo("]]>")
            t.emit(data)
            r.matchConsume("]]>")
            t.transition(.Data)
        }
    }

    var description: String { return String(describing: type(of: self)) }
    /**
     * Handles RawtextEndTagName, ScriptDataEndTagName, and ScriptDataEscapedEndTagName. Same body impl, just
     * different else exit transitions.
     */
    private static func handleDataEndTag(_ t: Tokeniser, _ r: CharacterReader, _ elseTransition: TokeniserState) throws {
        if r.matchesLetter() {
            let name = r.consumeLetterSequence()
            t.tagPending.appendTagName(name)
            t.dataBuffer.append(name)
            return
        }

        var needsExitTransition = false
        if try t.isAppropriateEndTagToken() && !r.isEmpty() {
            let c = r.consume()
            switch c {
            case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                t.transition(BeforeAttributeName)
            case "/":
                t.transition(SelfClosingStartTag)
            case ">":
                try t.emitTagPending()
                t.transition(Data)
            default:
                t.dataBuffer.append(c)
                needsExitTransition = true
            }
        } else {
            needsExitTransition = true
        }

        if needsExitTransition {
            t.emit("</" + t.dataBuffer.toString())
            t.transition(elseTransition)
        }
    }

    private static func readData(_ t: Tokeniser, _ r: CharacterReader, _ current: TokeniserState, _ advance: TokeniserState) throws {
        switch r.current() {
        case UnicodeScalar.LessThan:
            t.advanceTransition(advance)
        case TokeniserStateVars.nullScalr:
            t.error(current)
            r.advance()
            t.emit(TokeniserStateVars.replacementChar)
        case TokeniserStateVars.eof:
            try t.emit(Token.EOF())
        default:
            let data = r.consumeToAny(UnicodeScalar.LessThan, TokeniserStateVars.nullScalr)
            t.emit(data)
        }
    }

    private static func readCharRef(_ t: Tokeniser, _ advance: TokeniserState) throws {
        let c = try t.consumeCharacterReference(nil, false)
        if c == nil {
            t.emit(UnicodeScalar.Ampersand)
        } else {
            t.emit(c!)
        }
        t.transition(advance)
    }

    private static func readEndTag(_ t: Tokeniser, _ r: CharacterReader, _ a: TokeniserState, _ b: TokeniserState) {
        if r.matchesLetter() {
            t.createTagPending(false)
            t.transition(a)
        } else {
            t.emit("</")
            t.transition(b)
        }
    }

    private static func handleDataDoubleEscapeTag(_ t: Tokeniser, _ r: CharacterReader, _ primary: TokeniserState, _ fallback: TokeniserState) {
        if r.matchesLetter() {
            let name = r.consumeLetterSequence()
            t.dataBuffer.append(name)
            t.emit(name)
            return
        }

        let c = r.consume()
        switch c {
        case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ", "/", ">":
            if t.dataBuffer.toString() == "script" {
                t.transition(primary)
            } else {
                t.transition(fallback)
            }
            t.emit(c)
        default:
            r.unconsume()
            t.transition(fallback)
        }
    }
}
