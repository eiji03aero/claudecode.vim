" Test runner for claudecode.vim
" Usage: vim -c "source tests/test_runner.vim"

let s:test_results = {'passed': 0, 'failed': 0, 'errors': []}

function! s:assert_equal(expected, actual, message)
  if a:expected == a:actual
    let s:test_results.passed += 1
    echo "PASS: " . a:message
  else
    let s:test_results.failed += 1
    let error_msg = "FAIL: " . a:message . " - Expected: " . string(a:expected) . ", Got: " . string(a:actual)
    call add(s:test_results.errors, error_msg)
    echo error_msg
  endif
endfunction

function! s:assert_true(condition, message)
  call s:assert_equal(1, a:condition ? 1 : 0, a:message)
endfunction

function! s:assert_false(condition, message)
  call s:assert_equal(0, a:condition ? 1 : 0, a:message)
endfunction

function! s:run_tests()
  echo "Running claudecode.vim tests..."
  echo "================================"
  
  " Source all test files
  for test_file in glob('tests/test_*.vim', 0, 1)
    if test_file != 'tests/test_runner.vim'
      echo "Running: " . test_file
      execute 'source ' . test_file
    endif
  endfor
  
  echo "================================"
  echo "Test Results:"
  echo "Passed: " . s:test_results.passed
  echo "Failed: " . s:test_results.failed
  
  if s:test_results.failed > 0
    echo "\nFailures:"
    for error in s:test_results.errors
      echo error
    endfor
    cquit 1
  else
    echo "All tests passed!"
    quit
  endif
endfunction

" Make assertion functions available globally for test files
command! -nargs=* AssertEqual call s:assert_equal(<args>)
command! -nargs=* AssertTrue call s:assert_true(<args>)
command! -nargs=* AssertFalse call s:assert_false(<args>)

" Auto-run tests when this file is sourced
call s:run_tests()