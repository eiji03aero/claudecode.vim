" Test for claudecode dependency validation

" Source the module under test
source autoload/claudecode/deps.vim

echo "Testing dependency validation..."

" Test Claude CLI detection
AssertTrue claudecode#deps#check_claude_cli() || !executable('claude'), "Claude CLI check should return true if claude is available, false otherwise"

" Test vim-fugitive detection
let fugitive_available = exists(':Git') && exists('*fugitive#head')
AssertEqual fugitive_available, claudecode#deps#check_fugitive(), "vim-fugitive check should match actual availability"

" Test overall dependency validation
let expected_valid = claudecode#deps#check_claude_cli() && claudecode#deps#check_fugitive()
AssertEqual expected_valid, claudecode#deps#validate_all(), "validate_all should return true only if both dependencies are available"

echo "Dependency validation tests completed"