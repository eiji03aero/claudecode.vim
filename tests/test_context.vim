" Test for claudecode context processing

" Source the module under test
source autoload/claudecode/context.vim

echo "Testing context processing..."

" Test relative path calculation
let current_dir = getcwd()
let test_file = current_dir . "/test_file.txt"
let expected_rel_path = "test_file.txt"
AssertEqual expected_rel_path, claudecode#context#get_relative_path(test_file), "Relative path should be calculated correctly"

" Test file path in subdirectory
let test_subfile = current_dir . "/subdir/test_file.txt"
let expected_sub_path = "subdir/test_file.txt"
AssertEqual expected_sub_path, claudecode#context#get_relative_path(test_subfile), "Relative path for subdirectory should be correct"

" Test absolute path outside current directory
let external_file = "/tmp/test_file.txt"
AssertEqual external_file, claudecode#context#get_relative_path(external_file), "Absolute path outside cwd should remain absolute"

" Test buffer context formatting
let test_buffer_name = "test_file.vim"
let expected_buffer_context = "@test_file.vim"
AssertEqual expected_buffer_context, claudecode#context#format_buffer(test_buffer_name), "Buffer context should be formatted with @ prefix"

" Test selection context formatting
let test_selection = ["line 1", "line 2", "line 3"]
let expected_selection_context = "@test_file.vim#L10-12\nline 1\nline 2\nline 3"
let actual_selection_context = claudecode#context#format_selection("test_file.vim", test_selection, 10, 12)
AssertEqual expected_selection_context, actual_selection_context, "Selection context should include file, line numbers, and content"

" Test empty selection
let empty_selection = []
let expected_empty_context = "@test_file.vim#L1-1\n"
let actual_empty_context = claudecode#context#format_selection("test_file.vim", empty_selection, 1, 1)
AssertEqual expected_empty_context, actual_empty_context, "Empty selection should still include header"

echo "Context processing tests completed"