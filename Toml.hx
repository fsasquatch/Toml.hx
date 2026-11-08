// A poorly written parser for TOML v1.1.0
// Specifications: https://toml.io/en/v1.1.0
// Written solely by me, myself and i

enum TomlTokenType {
    RSqrBracket;
    LSqrBracket;
    RCurlyBracket;
    LCurlyBracket;
    Equals;
    SignPlus;
    SignMinus;
    Colon;
    Comma;

    Chars; // Just a bunch of letters

    BasicString;
    LiteralString;
    Number;
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

    public static function parse(text:String) {
        var tokens = scan(text);
        // tables
        // array of tables
        // key-value pairs

        var data:Map<String, Dynamic> = [];

        var index = 0;
        var length = tokens.length;
        var currentTable:Map<String, Dynamic> = null;
        while (true) {
            index++;
            if (index >= length)
                break;
            var token = tokens[index];

            switch (token.type) {
                case LSqrBracket:
                    var tok1 = tokens[index + 1];

                    // Table
                    if (tok1.type == Chars) {
                        var tok2 = tokens[index + 2];
                        if (tok2.type == RSqrBracket) {
                            data.set(tok1.value, new Map<String, Dynamic>());
                            currentTable = data.get(tok1.value);
                        } else {
                            // tables inside tables
                            var parent = tok1.value;
                            currentTable = parseNestedTables(data, data.get(parent), tokens, index+2, currentTable);
                        }

                        index++;
                        continue;
                    }
                
                // key value pairs
                case Equals:
                    var prevTok = tokens[index-1];
                    var nextTok = tokens[index+1];
                    if(currentTable != null) {
                        currentTable.set(prevTok.value, null);
                        // trace('${prevTok.value} = ${nextTok.value}');
                    } else {
                        // trace('${prevTok.value} = ${nextTok.value}');
                    }

                default:
            }
        }

        trace(data);
    }

    // index is first nested table
    static function parseNestedTables(data:Map<String, Dynamic>, parent:Map<String, Dynamic>, tokens:Array<TomlToken>, index:Int, currentTable:Map<String, Dynamic>):Map<String, Dynamic> {
        var child = tokens[index];
        var next = tokens[index+1];
        if(next.type == RSqrBracket) {
            parent.set(child.value, new Map<String, Dynamic>());
            currentTable = parent.get(child.value);
            return currentTable;
        } else if(next.type == Chars) {
            currentTable = parseNestedTables(data, parent.get(child.value), tokens, index+1, currentTable);
            return currentTable;
        }

        return null;
    }

    // TODO
    public static function validate(text:String):Bool {
        var textBytes = haxe.io.Bytes.ofString(text);
        if (!UnicodeString.validate(textBytes, UTF8)) {
            throw 'File is not encoded with UTF-8. Required by TOML v${version} spec';
            return false;
        }

        return false;
    }

    public static function scan(text:String):Array<TomlToken> {
        var tokens:Array<TomlToken> = [];

        var pos = 0;
        while (true) {
            var character = StringTools.fastCodeAt(text, pos);
            if (StringTools.isEof(character) || character == null)
                break;
            pos++;

            switch (character) {
                case "\n".code, "\t".code, "\r".code, " ".code:
                    continue;

                case "#".code:
                    while (true) {
                        pos++;
                        character = StringTools.fastCodeAt(text, pos);
                        if (character == "\n".code)
                            break;
                    }
                case "[".code:
                    tokens.push({
                        value: "[",
                        type: LSqrBracket,
                        locationStart: pos,
                        locationLength: 0
                    });
                case "]".code:
                    tokens.push({
                        value: "]",
                        type: RSqrBracket,
                        locationStart: pos,
                        locationLength: 0
                    });
                case "=".code:
                    tokens.push({
                        value: "=",
                        type: Equals,
                        locationStart: pos,
                        locationLength: 0
                    });
                case "}".code:
                    tokens.push({
                        value: "}",
                        type: RCurlyBracket,
                        locationStart: pos,
                        locationLength: 0
                    });
                case "{".code:
                    tokens.push({
                        value: "{",
                        type: LCurlyBracket,
                        locationStart: pos,
                        locationLength: 0
                    });
                case "+".code:
                    tokens.push({
                        value: "+",
                        type: SignPlus,
                        locationStart: pos,
                        locationLength: 0
                    });
                case "-".code:
                    tokens.push({
                        value: "-",
                        type: SignMinus,
                        locationStart: pos,
                        locationLength: 0
                    });
                case ":".code:
                    tokens.push({
                        value: ":",
                        type: Colon,
                        locationStart: pos,
                        locationLength: 0
                    });
                case ",".code:
                    tokens.push({
                        value: ",",
                        type: Comma,
                        locationStart: pos,
                        locationLength: 0
                    });

                case '0'.code, '1'.code, '2'.code, '3'.code, '4'.code, '5'.code, '6'.code, '7'.code, '8'.code, '9'.code:
                    var value = String.fromCharCode(character);
                    var start = pos;
                    var length = 0;
                    while (true) {
                        var character = StringTools.fastCodeAt(text, pos);
                        if (!isDigit(character) && character != ".".code && character != "E".code && character != "e".code && character != "_".code
                            && character != "x".code && character != "o".code && character != "b".code)
                            break;
                        else {
                            value += String.fromCharCode(character);
                            pos++;
                            length++;
                        }
                    }
                    tokens.push({
                        value: value,
                        type: Number,
                        locationStart: start,
                        locationLength: length
                    });

                default:
                    // BUG: Escape sequences for multiline strings break when they are near the start/end quotes
                    if (character == "\"".code) {
                        var c1 = StringTools.fastCodeAt(text, pos - 1);
                        var c2 = StringTools.fastCodeAt(text, pos + 1);
                        var c3 = StringTools.fastCodeAt(text, pos);

                        if (c1 == "\"".code && c2 == "\"".code && c3 == "\"".code) {
                            pos += 2;
                            var start = pos;
                            var length = 0;
                            var value = "";

                            while (true) {
                                var c1 = StringTools.fastCodeAt(text, pos - 1);
                                var c2 = StringTools.fastCodeAt(text, pos + 1);
                                var c3 = StringTools.fastCodeAt(text, pos);
                                pos++;
                                length++;

                                // trace(String.fromCharCode(c1)+String.fromCharCode(c3)+String.fromCharCode(c2));

                                if (c1 == "\"".code && c2 == "\"".code && c3 == "\"".code) {
                                    var _value = value.substr(0, length - 2);
                                    pos += 2;
                                    tokens.push({
                                        value: _value,
                                        type: BasicString,
                                        locationStart: start,
                                        locationLength: length
                                    });
                                    break;
                                } else {
                                    value += String.fromCharCode(c3);
                                }
                            }
                        } else {
                            pos++;
                            var start = pos;
                            var length = 0;
                            var value = "";

                            while (true) {
                                var c1 = StringTools.fastCodeAt(text, pos - 1);
                                var c2 = StringTools.fastCodeAt(text, pos + 1);
                                var c3 = StringTools.fastCodeAt(text, pos);
                                if (c1 == null && c2 == null && c3 == null)
                                    break;
                                pos++;
                                length++;
                                value += String.fromCharCode(c1);

                                if (c3 == "\"".code && c1 != "\\".code) {
                                    tokens.push({
                                        value: value,
                                        type: BasicString,
                                        locationStart: start,
                                        locationLength: length
                                    });
                                    break;
                                }
                            }
                        }
                    } else if (character == "'".code) {
                        var c1 = StringTools.fastCodeAt(text, pos - 1);
                        var c2 = StringTools.fastCodeAt(text, pos + 1);
                        var c3 = StringTools.fastCodeAt(text, pos);

                        if (c1 == "\'".code && c2 == "\'".code && c3 == "\'".code) {
                            pos += 2;
                            var start = pos;
                            var length = 0;
                            var value = "";

                            while (true) {
                                var c1 = StringTools.fastCodeAt(text, pos - 1);
                                var c2 = StringTools.fastCodeAt(text, pos + 1);
                                var c3 = StringTools.fastCodeAt(text, pos);
                                pos++;
                                length++;

                                if (c1 == "\'".code && c2 == "\'".code && c3 == "\'".code) {
                                    var _value = value.substr(0, length - 2);
                                    pos += 2;
                                    tokens.push({
                                        value: _value,
                                        type: LiteralString,
                                        locationStart: start,
                                        locationLength: length
                                    });
                                    break;
                                } else {
                                    value += String.fromCharCode(c3);
                                }
                            }
                        } else {
                            pos++;
                            var start = pos;
                            var length = 0;
                            var value = "";

                            while (true) {
                                var c1 = StringTools.fastCodeAt(text, pos - 1);
                                var c2 = StringTools.fastCodeAt(text, pos + 1);
                                var c3 = StringTools.fastCodeAt(text, pos);
                                if (c1 == null && c2 == null && c3 == null)
                                    break;
                                pos++;
                                length++;
                                value += String.fromCharCode(c1);

                                if (c3 == "\'".code && c1 != "\\".code) {
                                    tokens.push({
                                        value: value,
                                        type: LiteralString,
                                        locationStart: start,
                                        locationLength: length
                                    });
                                    break;
                                }
                            }
                        }
                    } else if (isAlphabet(character)) {
                        var value = String.fromCharCode(character);
                        var start = pos;
                        var length = 0;
                        while (true) {
                            var character = StringTools.fastCodeAt(text, pos);
                            if (!isAlphabet(character))
                                break;
                            else {
                                value += String.fromCharCode(character);
                                pos++;
                                length++;
                            }
                        }
                        tokens.push({
                            value: value,
                            type: Chars,
                            locationStart: start,
                            locationLength: length
                        });
                    }
            }
        }

        return tokens;
    }

    static inline function isDigit(character:Int):Bool {
        return switch (character) {
            default:
                false;
            case "0".code:
                true;
            case "1".code:
                true;
            case "2".code:
                true;
            case "3".code:
                true;
            case "4".code:
                true;
            case "5".code:
                true;
            case "6".code:
                true;
            case "7".code:
                true;
            case "8".code:
                true;
            case "9".code:
                true;
        }
    }

    static inline function isAlphabet(character:Int):Bool {
        return (character >= "a".code && character <= "z".code) || (character >= "A".code && character <= "Z".code);
    }
}
