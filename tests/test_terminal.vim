" Test for claudecode terminal management

" Source the module under test
source autoload/claudecode/terminal.vim

echo "Testing terminal management..."

" Test terminal existence check (should be false initially)
AssertFalse claudecode#terminal#exists(), "Terminal should not exist initially"

" Test terminal buffer name generation
let expected_name = "claudecode_terminal"
AssertEqual expected_name, claudecode#terminal#get_buffer_name(), "Terminal buffer name should be 'claudecode_terminal'"

" Test terminal command generation
let expected_cmd = "claude"
AssertEqual expected_cmd, claudecode#terminal#get_command([]), "Base command should be 'claude'"

let expected_cmd_with_args = "claude --resume"
AssertEqual expected_cmd_with_args, claudecode#terminal#get_command(["--resume"]), "Command with args should include arguments"

" Test split command generation
source autoload/claudecode/config.vim
let split_cmd = claudecode#terminal#get_split_command()
AssertTrue len(split_cmd) > 0, "Split command should not be empty"

echo "Terminal management tests completed"