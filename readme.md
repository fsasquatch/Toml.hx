# Toml.hx
A TOML parser for Haxe. Returns a `Map<String, Dynamic>`. Check the `test` folder for an example. The parser does not parse any identifier written in the format `foo-bar` properly. This should probably be fixed. It parses Zed's cargo file using the `eval` target in `0.0187s`. 

### To-Do
In order of importance,
- [ ] Date & Time
- [ ] Inline tables
- [ ] Array of tables
- [ ] Validator
