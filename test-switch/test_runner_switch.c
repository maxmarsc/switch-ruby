#include <sys/socket.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>

#include <switch.h>
#include <ruby.h>

extern bool rb_free_at_exit;

#define RUBY_TMP_DIR "sdmc:/switch/.tmp_ruby_test"

/**
 * Recursively deletes a directory and all its contents, with root-path safety.
 *
 * @param path The absolute or relative path to the directory.
 * @return 0 on success, -1 on failure or safety abort.
 */
int remove_directory(const char *path) {
    // SAFETY CHECK: Prevent wiping the entire SD card
    if (!path || 
        strcmp(path, "/") == 0 || strcmp(path, "/atmosphere") == 0 || strcmp(path, "/switch") == 0 ||
        strcmp(path, "sdmc:/") == 0 || strcmp(path, "sdmc:/atmosphere") == 0 || strcmp(path, "sdmc:/switch") == 0 ||
        strcmp(path, "sdmc:") == 0) {
        printf("CRITICAL: Safety abort! Refusing to delete root directory: %s\n", path ? path : "NULL");
        return -1;
    }

    // 2. Format the path (strip trailing slash if present for better stat() compatibility)
    char clean_path[512];
    strncpy(clean_path, path, sizeof(clean_path) - 1);
    clean_path[sizeof(clean_path) - 1] = '\0';
    
    size_t len = strlen(clean_path);
    if (len > 0 && clean_path[len - 1] == '/') {
        clean_path[len - 1] = '\0';
        len--;
    }

    // Open and traverse
    DIR *dir = opendir(clean_path);
    int res = -1;

    if (dir) {
        struct dirent *entry;
        res = 0;
        
        while (!res && (entry = readdir(dir))) {
            int res2 = -1;
            char *filepath;
            size_t file_len;

            if (!strcmp(entry->d_name, ".") || !strcmp(entry->d_name, "..")) {
                continue;
            }

            file_len = len + strlen(entry->d_name) + 2; 
            filepath = malloc(file_len);

            if (filepath) {
                struct stat statbuf;
                snprintf(filepath, file_len, "%s/%s", clean_path, entry->d_name);
                
                if (!stat(filepath, &statbuf)) {
                    if (S_ISDIR(statbuf.st_mode)) {
                        // Recursively call the safe function
                        res2 = remove_directory(filepath); 
                    } else {
                        res2 = unlink(filepath); 
                    }
                }
                free(filepath);
            }
            res = res2; 
        }
        closedir(dir);
    }

    // Remove the empty directory
    if (!res) {
        res = rmdir(clean_path);
    }

    return res;
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

int rubyWork() {
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
      return 1;
    }
  }

  // Initialize temp dir
  printf("Setting up temp dir...\n");
  consoleUpdate(NULL);
  {
    int tmpdir_state;
    rb_eval_string_protect(
        "require 'tmpdir'; ENV['TMPDIR'] = '" RUBY_TMP_DIR "';", 
        &tmpdir_state
    );
    if (tmpdir_state != 0) {
      VALUE err = rb_errinfo();
      VALUE inspected_err = rb_inspect(err);
      printf("%s[ERROR]%s Failed to set up temp dir: %s\n", CONSOLE_RED, CONSOLE_RESET, StringValueCStr(inspected_err));
      consoleUpdate(NULL);
      rb_set_errinfo(Qnil);
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
    return 1;
  }

  return 0;
}


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

    char * ruby_opts[] = {argv[0], "-e", ""};

    printf("Initializing Ruby...\n");
    ruby_sysinit(&argc, &argv);
    RUBY_INIT_STACK;
    ruby_init();
    // Load the built-in features & extensions
    ruby_options(3, ruby_opts);
    romfsInit();

    // don't forget to set this flag to make sure ruby_cleanup() clean everything up
    rb_free_at_exit = true;

    // Create temp dir for tests that need it. 
    remove_directory(RUBY_TMP_DIR); // in case it was left over from a previous run
    mkdir(RUBY_TMP_DIR, 0755);
    chmod(RUBY_TMP_DIR, 0755);

    // Starting ruby work
    consoleUpdate(NULL);
    if (rubyWork()) {
      ruby_cleanup(0);
      socketExit();
      consoleExit(NULL);
      return 1;
    }

    // Actually running the tests, test/unit seems to register test to run at exit ?
    int status = ruby_cleanup(0);
    printf("\n%s%s%s\n", 
        status == 0 ? CONSOLE_GREEN : CONSOLE_RED,
        status == 0 ? "[PASS] ALL TESTS PASSED" : "[FAIL] SOME TESTS FAILED",
        CONSOLE_RESET);

    if (remove_directory(RUBY_TMP_DIR) != 0) {
      printf("%s[WARNING]%s Failed to clean up temp directory: %s\n", CONSOLE_YELLOW, CONSOLE_RESET, RUBY_TMP_DIR);
    }

    printf("Waiting for [+] button to exit\n");
    consoleUpdate(NULL);

    // while (appletMainLoop()) {
    //     svcSleepThread(100000000);  // 100ms
    //     consoleUpdate(NULL);
    //     padUpdate(&pad);
    //     if (padGetButtonsDown(&pad) & HidNpadButton_Plus) break;
    // }

    socketExit();
    consoleExit(NULL);
    return 0;
  }