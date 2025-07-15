" Integration test for claudecode.vim

echo "Running claudecode.vim integration tests..."

" Source the main plugin
source plugin/claudecode.vim

" Test plugin loading
AssertTrue exists('g:loaded_claudecode'), "Plugin should be loaded"
AssertEqual '1.0.0', g:claudecode_version, "Plugin version should be set"

" Test commands are defined
AssertTrue exists(':ClaudeCode'), "ClaudeCode command should be defined"
AssertTrue exists(':ClaudeCodeQuit'), "ClaudeCodeQuit command should be defined"

" Test functions are defined
AssertTrue exists('*ClaudeCodeSendSelection'), "ClaudeCodeSendSelection function should be defined"
AssertTrue exists('*ClaudeCodeSendBuffer'), "ClaudeCodeSendBuffer function should be defined"

" Test default configuration
AssertEqual 'right', g:claudecode_terminal_position, "Default terminal position should be 'right'"
AssertEqual 40, g:claudecode_terminal_width, "Default terminal width should be 40"
AssertEqual 40, g:claudecode_terminal_height, "Default terminal height should be 40"

echo "Integration tests completed"