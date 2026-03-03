#include <sys/socket.h>
#include <unistd.h>

#include <switch.h>
#include <ruby.h>
#include <stdio.h>

int run_file(const char* path) {
    int state = 0;
    rb_load_protect(rb_str_new_cstr(path), 0, &state);
    return state; // 0 = success
}

#if defined(WAIT_FOR_DEBUGGER)
//NOLINTNEXTLINE(cppcoreguidelines-avoid-non-const-global-variables)
volatile bool gdb_wait = true;

int waitForDebugger(PadState* pad) {
  printf(
      "Waiting for debugger or [-] button to start or [+] button to exit\n");
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
    printf("Initializing console and socket for nxlink...\n");
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
    rb_call_builtin_inits();
    ruby_init_loadpath();

    // Load the assert definitions for the tests.
    printf("Loading test shim...\n");
    int shim_state = 0;
    rb_load_protect(rb_str_new_cstr("./.ruby/bootstraptest/btest_shim.rb"), 0, &shim_state);
    if (shim_state != 0) {
        VALUE err = rb_errinfo();
        VALUE inspected = rb_inspect(err);
        printf("Failed to load shim: %s\n", StringValueCStr(inspected));
        rb_set_errinfo(Qnil);
        // don't return yet, keep console alive so we can read the error message
        while (appletMainLoop()) {
            consoleUpdate(NULL);
            padUpdate(&pad);
            if (padGetButtonsDown(&pad) & HidNpadButton_Plus) break;
        }
        socketExit();
        consoleExit(NULL);
        return 1;
    }

    const char* files[] = {
        "./.ruby/bootstraptest/test_struct.rb",
        "./.ruby/bootstraptest/test_string.rb",
        "./.ruby/bootstraptest/test_attr.rb",
        "./.ruby/bootstraptest/test_block.rb",
        "./.ruby/bootstraptest/test_class.rb",
        // ...
        NULL
    };

    printf("Running tests...\n");
    int passed = 0, failed = 0;
    for (int i = 0; files[i]; i++) {
        int state = run_file(files[i]);
        if (state == 0) {
            printf("%s[PASS]%s %s\n", CONSOLE_GREEN, CONSOLE_RESET,files[i]);
            passed++;
        } else {
            VALUE err = rb_errinfo();
            VALUE inspected_err = rb_inspect(err);
            printf("%s[FAIL]%s %s: %s\n", CONSOLE_RED, CONSOLE_RESET, files[i], StringValueCStr(inspected_err));
            rb_set_errinfo(Qnil);
            failed++;
        }
        consoleUpdate(NULL);
    }

    printf("\n%d passed, %d failed\n", passed, failed);
    ruby_cleanup(0);

    while (appletMainLoop()) {
        consoleUpdate(NULL);
        padUpdate(&pad);
        if (padGetButtonsDown(&pad) & HidNpadButton_Plus) break;
    }

    socketExit();
    consoleExit(NULL);
    return failed > 0 ? 1 : 0;
}