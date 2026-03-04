# btest_shim.rb
def target_platform
  "switch"
end
$bt_passed = 0
$bt_failed = 0
$bt_errors = []

def assert_equal(expected, code_src, msg = '')
  actual = eval(code_src).to_s
  if actual == expected.to_s
    $bt_passed += 1
  else
    $bt_failed += 1
    loc = caller(1).first
    $bt_errors << "FAIL #{loc} #{msg}\n  expected: #{expected.inspect}\n  got:      #{actual.inspect}"
  end
rescue Exception => e
  $bt_failed += 1
  $bt_errors << "ERROR #{caller(1).first} #{msg}: #{e.class}: #{e.message}"
end

def assert_match(pattern, code_src, msg = '')
  actual = eval(code_src).to_s
  re = pattern.is_a?(Regexp) ? pattern : Regexp.new(pattern)
  if re =~ actual
    $bt_passed += 1
  else
    $bt_failed += 1
    $bt_errors << "FAIL #{caller(1).first} #{msg}\n  #{actual.inspect} !~ #{re.inspect}"
  end
rescue Exception => e
  $bt_failed += 1
  $bt_errors << "ERROR #{caller(1).first} #{msg}: #{e.class}: #{e.message}"
end

def assert_normal_exit(code_src, msg = '', **opts)
  eval(code_src)
  $bt_passed += 1
rescue SignalException, SystemExit => e
  $bt_failed += 1
  $bt_errors << "FAIL #{caller(1).first} #{msg}: unexpected exit: #{e}"
rescue Exception
  # Regular Ruby exceptions are NOT a failure for assert_normal_exit
  $bt_passed += 1
end

def assert_finish(timeout_sec, code_src, msg = '')
  # No timeout enforcement on Switch — just run it
  eval(code_src)
  $bt_passed += 1
rescue Exception => e
  $bt_failed += 1
  $bt_errors << "ERROR #{caller(1).first} #{msg}: #{e.class}: #{e.message}"
end