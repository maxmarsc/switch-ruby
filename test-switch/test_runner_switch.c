#include <sys/socket.h>
#include <unistd.h>

#include <switch.h>
#include <ruby.h>
#include <stdio.h>

extern bool rb_free_at_exit;

#if defined(WAIT_FOR_DEBUGGER)
//NOLINTNEXTLINE(cppcoreguidelines-avoid-non-const-global-variables)
volatile bool gdb_wait = true;

int waitForDebugger(PadState* pad) {
  printf(
      "Waiting for debugger or [-] button to start or [+] button to exit\n");
  consoleUpdate(NULL);
  while (appletMainLoop() && gdb_wait) {
    padUpdate(pad);
    u64 k_down = padGetButtonsDown(pad);

    if (k_down & HidNpadButton_Minus) {
      break;  // break in order to start the application
    }

    if (k_down & HidNpadButton_Plus) {
      printf("Exiting to hbmenu...\n");
      return 1;
    }
    svcSleepThread(100000000);  // 100ms
  }
  return 0;
}
#endif


int main(int argc, char** argv) {
    // initialize console and socket for nxlink
    consoleInit(NULL);
    socketInitializeDefault();
    nxlinkStdio();
    padConfigureInput(1, HidNpadStyleSet_NpadStandard);
    PadState pad;
    padInitializeDefault(&pad);
#if defined(WAIT_FOR_DEBUGGER)
    if (waitForDebugger(&pad)) {
      socketExit();
      consoleExit(NULL);
      return 0;
    }
#endif

    printf("Initializing Ruby...\n");
    ruby_sysinit(&argc, &argv);
    RUBY_INIT_STACK;
    ruby_init();
    // Load the built-in features
    extern void rb_call_builtin_inits(void);
    extern void Init_ext(void);
    Init_ext(); /* load statically linked extensions before rubygems */
    rb_call_builtin_inits();
    ruby_init_loadpath();

    // don't forget to set this flag to make sure ruby_cleanup() clean everything up
    rb_free_at_exit = true;

    // initialize romfs
    romfsInit();

    // Add pure-ruby load paths
    printf("Setting up load path...\n");
    consoleUpdate(NULL);
    {
      int load_path_state;
      rb_eval_string_protect(
          "$LOAD_PATH.unshift('romfs:/lib', 'romfs:/tool/lib', 'romfs:/build')", 
          &load_path_state
      );
      if (load_path_state != 0) {
        VALUE err = rb_errinfo();
        VALUE inspected_err = rb_inspect(err);
        printf("%s[ERROR]%s Failed to set up load path: %s\n", CONSOLE_RED, CONSOLE_RESET, StringValueCStr(inspected_err));
        consoleUpdate(NULL);
        rb_set_errinfo(Qnil);
        ruby_cleanup(0);
        socketExit();
        consoleExit(NULL);
        return 1;
      }
    }

    // Call the test runner
    printf("Running tests...\n");
    consoleUpdate(NULL);
    int state = 0;
    rb_load_protect(rb_str_new_cstr("romfs:/test_ruby_runner_shim.rb"), 0, &state);
    if (state != 0) {
      VALUE err = rb_errinfo();
      VALUE inspected_err = rb_inspect(err);
      printf("%s[ERROR]%s Failed to load test runner: %s\n", CONSOLE_RED, CONSOLE_RESET, StringValueCStr(inspected_err));
      consoleUpdate(NULL);
      rb_set_errinfo(Qnil);
      ruby_cleanup(0);
      socketExit();
      consoleExit(NULL);
      return 1;
    }

    // printf("\n%d passed, %d failed\n", passed, failed);
    printf("Waiting for [+] button to exit\n");
    consoleUpdate(NULL);
    ruby_cleanup(0);

    while (appletMainLoop()) {
        consoleUpdate(NULL);
        padUpdate(&pad);
        if (padGetButtonsDown(&pad) & HidNpadButton_Plus) break;
    }

    socketExit();
    consoleExit(NULL);
    return 0;
  }