#include <stdint.h>

void uart_init (uint32_t nBaudrate, int (*printhandler) (const char *fmt, ...));
void uart_send (const char c);
char uart_getc();
