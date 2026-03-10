#include <sys/socket.h>
#include <unistd.h>

#include <switch.h>
#include <ruby.h>
#include <stdio.h>


extern bool rb_free_at_exit;

int run_file(const char* path) {
    int state = 0;
    rb_load_protect(rb_str_new_cstr(path), 0, &state);
    return state; // 0 = success
}

static void check_poisoned_region() {
      // Count ALL poisoned regions
      extern char* fake_heap_start;
      extern char* fake_heap_end;
      MemoryInfo meminfo;
      u32 pageinfo;
      uintptr_t addr = (uintptr_t)fake_heap_start;
      uintptr_t end = (uintptr_t)fake_heap_end;
      int count = 0;

      while (addr < end) {
          svcQueryMemory(&meminfo, &pageinfo, addr);
          if (meminfo.perm != Perm_Rw) {
              printf("poisoned[%d]: %p size=0x%lx perm=0x%x type=0x%x\n",
                    count, (void*)meminfo.addr, meminfo.size, meminfo.perm, meminfo.type);
              count++;
          }
          addr = meminfo.addr + meminfo.size;
      }
      printf("Total poisoned regions: %d\n", count);
      consoleUpdate(NULL);
    }

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

    // check_poisoned_region();

    printf("Initializing Ruby...\n");
    ruby_sysinit(&argc, &argv);
    RUBY_INIT_STACK;
    ruby_init();
    // Load the built-in features
    extern void rb_call_builtin_inits(void);
    rb_call_builtin_inits();
    ruby_init_loadpath();
    // don't forget to set this flag to make sure ruby_cleanup() clean everything up
    rb_free_at_exit = true;

    // Load the assert definitions for the tests.
    printf("Loading test shim...\n");
    int shim_state = 0;
    romfsInit();
    rb_load_protect(rb_str_new_cstr("romfs:/btest_shim.rb"), 0, &shim_state);
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
        ruby_cleanup(0);
        socketExit();
        consoleExit(NULL);
        return 1;
    }

    const char* files[] = {
        // core language
        "romfs:/bootstraptest/test_literal.rb",
        "romfs:/bootstraptest/test_literal_suffix.rb",
        "romfs:/bootstraptest/test_struct.rb",
        "romfs:/bootstraptest/test_string.rb",
        "romfs:/bootstraptest/test_attr.rb",
        "romfs:/bootstraptest/test_class.rb",
        "romfs:/bootstraptest/test_massign.rb",
        "romfs:/bootstraptest/test_flow.rb",
        "romfs:/bootstraptest/test_flip.rb",
        "romfs:/bootstraptest/test_syntax.rb",
        "romfs:/bootstraptest/test_block.rb",
        "romfs:/bootstraptest/test_method.rb",
        "romfs:/bootstraptest/test_proc.rb",
        "romfs:/bootstraptest/test_jump.rb",
        "romfs:/bootstraptest/test_eval.rb",
        "romfs:/bootstraptest/test_exception.rb",
        "romfs:/bootstraptest/test_constant_cache.rb",
        // slightly higher-level features
        "romfs:/bootstraptest/test_fiber.rb",
        "romfs:/bootstraptest/test_gc.rb",
        "romfs:/bootstraptest/test_objectspace.rb",
        "romfs:/bootstraptest/test_marshal.rb",
        "romfs:/bootstraptest/test_insns.rb",
        "romfs:/bootstraptest/test_ractor.rb",
        "romfs:/bootstraptest/test_thread.rb",
        "romfs:/bootstraptest/test_env.rb",
        // NOT SUPPORTED
        // "romfs:/bootstraptest/test_io.rb",
        // "romfs:/bootstraptest/test_fork.rb",
        // "romfs:/bootstraptest/test_load.rb",
        // "romfs:/bootstraptest/test_autoload.rb",
        // "romfs:/bootstraptest/test_rjit.rb",
        // "romfs:/bootstraptest/test_finalizer.rb",
        NULL
    };

    printf("Running tests...\n");
    int passed = 0, failed = 0;
    for (int i = 0; files[i]; i++) {
        int state = run_file(files[i]);
        // Reset GC.stress after each test file — some tests enable it globally
        rb_eval_string_protect("GC.stress = false", &state);
        // Make sure we collect dead objects like threads to avoid leaks between tests
        rb_eval_string_protect("GC.start", &state);
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
        // check_poisoned_region();
        consoleUpdate(NULL);
    }

    printf("\n%d passed, %d failed\n", passed, failed);
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
    return failed > 0 ? 1 : 0;
}