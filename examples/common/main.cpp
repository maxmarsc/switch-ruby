#include <cstdio>
#include <string>
#include <array>

// Include the main libnx system header, for Switch development
#include <switch.h>

#include "ruby.h"
// NOLINTNEXTLINE(cppcoreguidelines-avoid-non-const-global-variables)
extern bool rb_free_at_exit;

namespace {
int rubyWork() {
  // Add pure-ruby load paths
  printf("Setting up load path...\n");
  consoleUpdate(nullptr);
  {
    int load_path_state = 0;
    rb_eval_string_protect("$LOAD_PATH.unshift('" RUBY_STDLIB_DIR
                           "', '" RUBY_STDLIB_DIR "/aarch64-elf')",
                           &load_path_state);
    if (load_path_state != 0) {
      VALUE err           = rb_errinfo();
      VALUE inspected_err = rb_inspect(err);
      printf("%s[ERROR]%s Failed to set up load path: %s\n", CONSOLE_RED,
        
             CONSOLE_RESET, StringValueCStr(inspected_err));
      consoleUpdate(nullptr);
      rb_set_errinfo(Qnil);
      return 1;
    }
  }

  // Initialize temp dir
  printf("Setting up temp dir...\n");
  consoleUpdate(nullptr);
  {
    int tmpdir_state = 0;
    rb_eval_string_protect(
        "require 'tmpdir'; ENV['TMPDIR'] = '" RUBY_TMP_DIR "';", &tmpdir_state);
    if (tmpdir_state != 0) {
      VALUE err           = rb_errinfo();
      VALUE inspected_err = rb_inspect(err);
      printf("%s[ERROR]%s Failed to set up temp dir: %s\n", CONSOLE_RED,
             CONSOLE_RESET, StringValueCStr(inspected_err));
      consoleUpdate(nullptr);
      rb_set_errinfo(Qnil);
      return 1;
    }
  }

  // Run the ruby code
  printf("Running ruby app...\n");
  consoleUpdate(nullptr);
  int state = 0;
  rb_load_protect(rb_str_new_cstr(RUBY_MAIN_APP), 0, &state);
  if (state != 0) {
    VALUE err           = rb_errinfo();
    VALUE inspected_err = rb_inspect(err);
    printf("%s[ERROR]%s Failed to load main ruby app: %s\n", CONSOLE_RED,
           CONSOLE_RESET, StringValueCStr(inspected_err));
    consoleUpdate(nullptr);
    rb_set_errinfo(Qnil);
    return 1;
  }

  return 0;
}
}  // namespace

int main(int argc, char** argv) {
  // initialize console and socket for nxlink
  consoleInit(nullptr);
  socketInitializeDefault();
  nxlinkStdio();
  padConfigureInput(1, HidNpadStyleSet_NpadStandard);
  PadState pad;
  padInitializeDefault(&pad);

  auto rc = romfsInit();
  if (R_FAILED(rc)) {
    printf("romfsInit: %08X\n", rc);
    consoleUpdate(nullptr);
    socketExit();
    consoleExit(nullptr);
    return 1;
  }
  printf("romfs Init Successful!\n");
  consoleUpdate(nullptr);

  // Setup ruby
  printf("Initializing Ruby...\n");
  // NOLINTBEGIN(cppcoreguidelines-pro-type-const-cast)
  std::array<char*, 3> ruby_opts{*argv, const_cast<char*>("-e"),
                                 const_cast<char*>("")};
  // NOLINTEND(cppcoreguidelines-pro-type-const-cast)
  ruby_sysinit(&argc, &argv);
  RUBY_INIT_STACK;
  ruby_init();
  // Load the built-in features & extensions
  ruby_options(3, ruby_opts.data());

  // don't forget to set this flag to make sure ruby_cleanup() clean everything up
  rb_free_at_exit = true;

  // Setup load paths and temp dir, then run the ruby app
  int result = rubyWork();
  ruby_cleanup(0);

  printf("Waiting for [+] button to exit\n");
  consoleUpdate(nullptr);

  while (appletMainLoop()) {
    svcSleepThread(100000000);  // 100ms
    consoleUpdate(nullptr);
    padUpdate(&pad);
    if (padGetButtonsDown(&pad) & HidNpadButton_Plus) {
      break;
    }
  }

  romfsExit();
  socketExit();
  consoleExit(nullptr);
  return result;
}