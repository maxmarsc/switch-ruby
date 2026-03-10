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

    romfsInit();
    int state = run_file("romfs:/basictest/test.rb");
    if (state == 0) {
        printf("%s[PASS]%s %s\n", CONSOLE_GREEN, CONSOLE_RESET, "romfs:/basictest/test.rb");
    } else {
        VALUE err = rb_errinfo();
        VALUE inspected_err = rb_inspect(err);
        printf("%s[FAIL]%s %s: %s\n", CONSOLE_RED, CONSOLE_RESET, "romfs:/basictest/test.rb", StringValueCStr(inspected_err));
        rb_set_errinfo(Qnil);
    }

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
    return state;
}