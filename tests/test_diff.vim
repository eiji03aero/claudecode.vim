" Test for claudecode diff integration

" Source the module under test
source autoload/claudecode/diff.vim

echo "Testing diff integration..."

" Test diff detection patterns
let diff_line1 = "diff --git a/file.txt b/file.txt"
let diff_line2 = "--- a/file.txt"
let diff_line3 = "+++ b/file.txt"
let normal_line = "This is just normal text"

AssertTrue claudecode#diff#is_diff_line(diff_line1), "Git diff header should be detected"
AssertTrue claudecode#diff#is_diff_line(diff_line2), "Diff old file marker should be detected"
AssertTrue claudecode#diff#is_diff_line(diff_line3), "Diff new file marker should be detected"
AssertFalse claudecode#diff#is_diff_line(normal_line), "Normal text should not be detected as diff"

" Test diff block detection
let diff_lines = [
  \ "Some output before",
  \ "diff --git a/test.txt b/test.txt",
  \ "index 1234567..abcdefg 100644",
  \ "--- a/test.txt",
  \ "+++ b/test.txt",
  \ "@@ -1,3 +1,4 @@",
  \ " existing line",
  \ "-removed line",
  \ "+added line",
  \ " another existing line",
  \ "Some output after"
  \ ]

let detected_blocks = claudecode#diff#extract_diff_blocks(diff_lines)
AssertEqual 1, len(detected_blocks), "Should detect one diff block"

if len(detected_blocks) > 0
  let block = detected_blocks[0]
  AssertEqual 2, block.start, "Diff block should start at line 2 (0-indexed)"
  AssertEqual 9, block.end, "Diff block should end at line 9 (0-indexed)"
  AssertEqual "test.txt", block.filename, "Should extract filename correctly"
endif

echo "Diff integration tests completed"