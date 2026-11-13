import haxe.Timer;
import sys.io.File;

function main() {
    var fileName = "zed_cargo.toml";
    var fileContent = File.getContent(fileName);

    var start = Timer.stamp();
    var parsed:Map<String, Dynamic> = Toml.parse(fileContent);
    var end = Timer.stamp();
    Sys.println('Took ${end-start}s');

    trace(parsed);
    // trace(parsed.get("clients").get("data"));
}