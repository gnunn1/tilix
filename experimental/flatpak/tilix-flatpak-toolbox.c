#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv) {
    if (argc != 3) {
        fprintf(stderr, "usage: tilix-flatpak-toolbox <command> <arg>\n");
        return 1;
    }

    if (strcmp(argv[1], "get-passwd") == 0) {
        execlp("getent", "getent", "passwd", argv[2], NULL);
        perror("error calling execlp");
        return 1;
    } else if (strcmp(argv[1], "get-child-pid") == 0) {
        // Caller should have saved terminal to fd 3.
        pid_t pid = tcgetpgrp(3);
        if (pid == -1) {
            perror("error calling tcgetpgrp");
            return 1;
        }

        printf("%ld\n", (long)pid);
    } else if (strcmp(argv[1], "get-proc-stat") == 0) {
        long value = strtol(argv[2], NULL, 10);
        char path[32];
        snprintf(path, sizeof(path), "/proc/%lu/stat", value);

        FILE *fp = fopen(path, "r");
        if (fp == NULL) {
            perror("error opening /proc/<pid>/stat");
            return 1;
        }

        for (;;) {
            char buf[1024];
            int sz = fread(buf, 1, sizeof(buf)-1, fp);
            buf[sz] = 0;

            printf("%s", buf);

            if (sz < sizeof(buf)) {
                if (feof(fp)) {
                    break;
                } else if (ferror(fp)) {
                    perror("error reading from /proc/<pid>/stat");
                    fclose(fp);
                    return 1;
                }
            }
        }

        fclose(fp);
        fflush(stdout);
    } else {
        fprintf(stderr, "Invalid command: %s\n", argv[1]);
        return 1;
    }

    return 0;
}
