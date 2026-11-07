import haxe.Timer;
import sys.io.File;

function main() {
    var fileName = "test/simple.toml";
    var fileContent = File.getContent(fileName);

    Timer.measure(() -> {
        Toml.scan(fileContent);
    });
}