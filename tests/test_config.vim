" Test for claudecode configuration management

" Source the module under test
source autoload/claudecode/config.vim

echo "Testing configuration management..."

" Test default values
AssertEqual "right", claudecode#config#get('terminal_position'), "Default terminal position should be 'right'"
AssertEqual 40, claudecode#config#get('terminal_width'), "Default terminal width should be 40"
AssertEqual 40, claudecode#config#get('terminal_height'), "Default terminal height should be 40"

" Test custom values
let g:claudecode_terminal_position = "bottom"
let g:claudecode_terminal_width = 80
let g:claudecode_terminal_height = 20

AssertEqual "bottom", claudecode#config#get('terminal_position'), "Custom terminal position should be 'bottom'"
AssertEqual 80, claudecode#config#get('terminal_width'), "Custom terminal width should be 80"
AssertEqual 20, claudecode#config#get('terminal_height'), "Custom terminal height should be 20"

" Test validation
AssertTrue claudecode#config#validate(), "Valid configuration should pass validation"

" Test invalid position
let g:claudecode_terminal_position = "invalid"
AssertFalse claudecode#config#validate(), "Invalid terminal position should fail validation"

" Reset to valid value
let g:claudecode_terminal_position = "right"
AssertTrue claudecode#config#validate(), "Valid configuration should pass validation after reset"

" Test invalid width
let g:claudecode_terminal_width = 0
AssertFalse claudecode#config#validate(), "Zero terminal width should fail validation"

" Test invalid height
let g:claudecode_terminal_width = 40
let g:claudecode_terminal_height = -1
AssertFalse claudecode#config#validate(), "Negative terminal height should fail validation"

" Clean up
unlet g:claudecode_terminal_position
unlet g:claudecode_terminal_width
unlet g:claudecode_terminal_height

echo "Configuration management tests completed"