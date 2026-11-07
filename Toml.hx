// A poorly written parser for TOML v1.1.0
// Specifications: https://toml.io/en/v1.1.0
// Written solely by me, myself and i
enum TomlTokenType {
    RSqrBracket;
    LSqrBracket;
    Parenthesis;
    Equals;

    Identifier;

    ValueString;
    ValueInteger;
    ValueHexadecimalNumber;
    ValueOctalNumber;
    ValueBinaryNumber;
    ValueFloat; // fractional float
    ValueExponentNumber;
    ValueComplexNumber;
    ValueBoolean;
    ValueOffsetDateTime;
    ValueLocalDateTime;
    ValueLocalDate;
    ValueLocalTime;
    ValueArray;
    ValueInlineTable;
}

@:structInit
class TomlToken {
    public var type:TomlTokenType;
    public var value:String;
    public var locationStart:Int;
    public var locationLength:Int;
}

class Toml {
    public static inline final version = "1.1.0";

    static var fileContent:String;
    static var filePos = 0;
    static var fileEnd = -1;
    static var tokens:Array<TomlToken> = [];

    public static function scan(text:String) {
        fileContent = text;
        fileEnd = fileContent.length-1;

        while(true) {
            var character = getNextCharacter();
            if(character == null) break;

            switch(character) {
                case "\n".code: continue; 
                case ' '.code: continue;
                case '\t'.code: continue;
                case '\r'.code: continue;

                case "#".code: // we ignore all the comments
                    while(true) {
                        var val = getNextCharacter();
                        if(val == null || val == "\n".code) break;
                    }
                case "=".code:
                    tokens.push({value: "=", type: Equals, locationStart: filePos, locationLength: 0});
                    scanValueTypes();
                case "[".code:
                    tokens.push({value: "[", type: LSqrBracket, locationStart: filePos, locationLength: 0});
                case "]".code:
                    tokens.push({value: "]", type: RSqrBracket, locationStart: filePos, locationLength: 0});

                default:
                    // TODO: inf, +inf, -inf
                    // TODO: nan, +nan, -nan
            }
        }

        for(token in tokens) {
            trace('value: ${token.value} type: ${token.type} pos: ${token.locationStart}-${token.locationStart+token.locationLength}');
        }

        filePos = 0;
        fileEnd = -1;
    }

    public static function validate(text:String):Bool {
        var textBytes = haxe.io.Bytes.ofString(text);
        if(!UnicodeString.validate(textBytes, UTF8)) {
            throw 'File is not encoded with UTF-8. Required by TOML v${version} spec';
            return false;
        }

        return false;
    }

    inline static function scanValueTypes() {
        while(true) {
            var _next = getNextCharacter();
            
            switch(_next) {
                case " ".code: 
                    continue;

                // Array opening bracket
                case "[".code:
                    tokens.push({value: "[", type: LSqrBracket, locationStart: filePos, locationLength: 0});
                    while(true) {
                        switch(StringTools.fastCodeAt(fileContent, filePos)) {
                            case "[".code:
                                tokens.push({value: "[", type: LSqrBracket, locationStart: filePos, locationLength: 0});
                            case "]".code:
                                tokens.push({value: "]", type: RSqrBracket, locationStart: filePos, locationLength: 0});
                                break;
                            default:
                                scanValueTypes();
                                break;
                        }
                    }
                
                case "]".code:
                    tokens.push({value: "]", type: RSqrBracket, locationStart: filePos, locationLength: 0});
                    break;

                // Basic String
                case "\"".code:
                    var _startPos = filePos;
                    var _value = "";
                    var _length = 0;

                    var fp1 = StringTools.fastCodeAt(fileContent, filePos-1);
                    var fp2 = StringTools.fastCodeAt(fileContent, filePos+1);
                    var fp3 = StringTools.fastCodeAt(fileContent, filePos);

                    // TODO: Handle escape sequences
                    if(fp1 == '\"'.code && fp2 == "\"".code && fp3 == "\"".code) {
                        getNextCharacter(); // skip 2 characters
                        getNextCharacter();

                        // Multiline string
                        while(true) {
                            var next = getNextCharacter();
                            _length++;
                            if(StringTools.fastCodeAt(fileContent, filePos-1) == "\"".code && StringTools.fastCodeAt(fileContent, filePos+1) == "\"".code && StringTools.fastCodeAt(fileContent, filePos) == "\"".code) {
                                tokens.push({value: _value, type: ValueString, locationStart: _startPos, locationLength: _length});
                                break;
                            } else {
                                _value += String.fromCharCode(next);
                            }
                        }
                    } else {
                        // Basic string
                        while(true) {
                            var next = getNextCharacter();
                            _length++;

                            // TODO: This is a temporary solution, also fix this for inline strings
                            if((StringTools.fastCodeAt(fileContent, filePos-2) == "\"".code && next == "\n".code) || (StringTools.fastCodeAt(fileContent, filePos-2) == "\"".code && next == "]".code) || (StringTools.fastCodeAt(fileContent, filePos-2) == "\"".code && next == ",".code)) {
                                _value = _value.substr(0, _length-2);
                                tokens.push({value: _value, type: ValueString, locationStart: _startPos, locationLength: _length});
                                break;
                            } else {
                                _value += String.fromCharCode(next);
                            }
                        }
                    }

                // Inline strings (no escape sequences)
                // I don't really like this duplicated code but its the simplest way I can think of rn
                case "'".code:
                    var _startPos = filePos;
                    var _value = "";
                    var _length = 0;

                    var fp1 = StringTools.fastCodeAt(fileContent, filePos-1);
                    var fp2 = StringTools.fastCodeAt(fileContent, filePos+1);
                    var fp3 = StringTools.fastCodeAt(fileContent, filePos);

                    if(fp1 == "'".code && fp2 == "'".code && fp3 == "'".code) {
                        getNextCharacter(); // skip 2 characters
                        getNextCharacter();

                        // Multiline string
                        while(true) {
                            var next = getNextCharacter();
                            _length++;
                            if((StringTools.fastCodeAt(fileContent, filePos-2) == "\"".code && next == "\n".code) || (StringTools.fastCodeAt(fileContent, filePos-2) == "\"".code && next == "]".code) || (StringTools.fastCodeAt(fileContent, filePos-2) == "\"".code && next == ",".code)) {
                                tokens.push({value: _value, type: ValueString, locationStart: _startPos, locationLength: _length});
                                break;
                            } else {
                                _value += String.fromCharCode(next);
                            }
                        }
                    } else {
                        // Basic string
                        while(true) {
                            var next = getNextCharacter();
                            _length++;

                            if(next == "\n".code || next == "]".code || next == ",".code || next == " ".code) {
                                _value = _value.substr(0, _length-2);
                                tokens.push({value: _value, type: ValueString, locationStart: _startPos, locationLength: _length});
                                break;
                            } else {
                                _value += String.fromCharCode(next);
                            }
                        }
                    }


                case "0".code, "1".code, "2".code, "3".code, "4".code, "5".code, "6".code, "7".code, "8".code, "9".code:
                    // TODO: handle "_", "0x", "0o", "0b", ".", "e", "E"
                    // TODO: handle Date-Time

                    var _value = String.fromCharCode(_next);
                    var _length = 0;
                    var _start = filePos; 
                    while(true) {
                        var _next = getNextCharacter();
                        switch(_next) {
                            case "0".code, "1".code, "2".code, "3".code, "4".code, "5".code, "6".code, "7".code, "8".code, "9".code:
                                _value += String.fromCharCode(_next);
                                _length++;
                            default:
                                tokens.push({value: _value, type: ValueInteger, locationStart: _start, locationLength: _length});
                                break;
                        }
                    }

                default:
                    break;
            }
        }
    }

    inline static function getNextCharacter():Int {
        var value = filePos <= fileEnd ? StringTools.fastCodeAt(fileContent, filePos) : null;
        filePos++;
        return value;
    }
}