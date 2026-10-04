#include <stdlib.h>
#include <string.h>
#include <stdint.h>

size_t DBRuntimeChain(const char* source) {
    if(!source) return 0;
    size_t len = strlen(source);
    char* copy = (char*)malloc(len + 1);
    if(!copy) return 0;
    memcpy(copy, source, len + 1);
    size_t result = strlen(copy);
    free(copy);
    return result;
}

void* DBRuntimeChainAddress(void) {
    return (void*)&DBRuntimeChain;
}
