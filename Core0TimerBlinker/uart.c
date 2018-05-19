#include <stdint.h>
#include <stddef.h>
#include "rpi-SmartStart.h"

 /*--------------------------------------------------------------------------}
 {			  DR REGISTER BCM2835 ARM Peripheral manual page 181			 }
 {--------------------------------------------------------------------------*/
typedef union
{
	struct
	{
		unsigned DATA : 8;											// @0-7  Receive (read) data character. Transmit (write) data character
		unsigned FE : 1;											// @8    Framing error, set to 1 indicates received character did not have a valid stop bit
		unsigned PE : 1;											// @9	 Parity error, set to 1 indicates parity of received character does not match the parity
		unsigned BE : 1;											// @10	 Break error. This bit is set to 1 if a break condition was detected
		unsigned OE : 1;											// @11   Overrun error. This bit is set to 1 if data is received and the receive FIFO is already full
		unsigned unused : 20;										// @12-31 Reserved - Write as 0, read as don't care 
	};
	uint32_t Raw32;													// Union to access all 32 bits as a uint32_t
} dr_reg_t;

 /*--------------------------------------------------------------------------}
 {			  FR REGISTER BCM2835 ARM Peripheral manual page 181			 }
 {--------------------------------------------------------------------------*/
typedef union
{
	struct
	{
		unsigned CTS : 1;											// @0 This bit is 1 when nUARTCTS is LOW. 
		unsigned DSR : 1;											// @1 Unsupported, write zero, read as don't care 
		unsigned DCD : 1;											// @2 Unsupported, write zero, read as don't care 
		unsigned BUSY : 1;											// @3 UART busy. If this bit is set to 1, the UART is transmitting
		unsigned RXFE : 1;											// @4 RXFE bit is set when the receive FIFO is empty and FIFO enabled
		unsigned TXFF : 1;											// @5 TXFF bit is set when the transmit FIFO is full and FIFO enabled
		unsigned RXFF : 1;											// @6 RXFF bit is set when the receive FIFO is full and FIFO enabled
		unsigned TXFE : 1;											// @7 TXFE bit is set when the transmit FIFO is empty and FIFO enabled
		unsigned unused : 24;										// @8-31 Reserved - Write as 0, read as don't care 
	};
	uint32_t Raw32;													// Union to access all 32 bits as a uint32_t
} fr_reg_t;


/*--------------------------------------------------------------------------}
{		     LCRH REGISTER BCM2835 ARM Peripheral manual page 181	        }
{--------------------------------------------------------------------------*/
typedef union
{
	struct
	{
		unsigned BRK : 1;											// @0 If this bit is set to 1, a low-level is continually output on the TXD output
		unsigned PEN : 1;											// @1 Parity enable if set the parity table is implemented 
		unsigned EPS : 1;											// @2 Even parity if bit set, ODD parity if clear. PEN must be set to take effect 
		unsigned STP2 : 1;											// @3 2 Stop bits if set, 1 Stop bit if clear.
		unsigned FEN : 1;											// @4 FIFO enabled if set
		enum {
			BITS5 = 0,
			BITS6 = 1,
			BITS7 = 2,
			BITS8 = 3,
		} WLEN : 2;													// @5-6 Data bits settings
		unsigned SPS : 1;											// @7 Stick parity select. 0 = stick parity is disabled, 1 = stick parity enable. 
		unsigned unused : 24;										// @8-31 Reserved - Write as 0, read as don't care 
	};
	uint32_t Raw32;													// Union to access all 32 bits as a uint32_t
} lcrh_reg_t;

/*--------------------------------------------------------------------------}
{		      CR REGISTER BCM2835 ARM Peripheral manual page 185	        }
{--------------------------------------------------------------------------*/
typedef union
{
	struct
	{
		unsigned UARTEN : 1;										// @0 Set to 1 = the UART is enabled
		unsigned SIREN : 1;											// @1 Unsupported, write zero, read as don't care  
		unsigned SIRLP : 1;											// @2 Unsupported, write zero, read as don't care  
		unsigned reserved : 4;										// @3-6 Reserved - Write as 0, read as don't care
		unsigned LBE : 1;											// @7 Loopback enable. If set to 1, the UARTTXD is fed to the UARTRXD
		unsigned TXE : 1;											// @8 Transmit enable. If this bit is set to 1, the transmit UART is enabled
		unsigned RXE : 1;											// @9 Receive enable. If this bit is set to 1, the Receive UART is enabled
		unsigned DTR : 1;											// @10 Unsupported, write zero, read as don't care 
		unsigned RTS : 1;											// @11 Request to send. This bit is the complement of the UART request to send, nUARTRTS, modem status output.
		unsigned OUT1 : 1;											// @12 Unsupported, write zero, read as don't care 
		unsigned OUT2 : 1;											// @13 Unsupported, write zero, read as don't care 
		unsigned RTSEN : 1;											// @14 RTS hardware flow control enable. If this bit is set to 1, RTS hardware flow control is enabled. 
		unsigned CTSEN : 1;											// @15 CTS hardware flow control enable. If this bit is set to 1, CTS hardware flow control is enabled
		unsigned unused : 16;										// @16-31 Reserved - Write as 0, read as don't care 
	};
	uint32_t Raw32;													// Union to access all 32 bits as a uint32_t
} cr_reg_t;


/*--------------------------------------------------------------------------}
{		 UART0 STRUCTURE LAYOUT BCM2835 ARM Peripheral manual page 177	    }
{--------------------------------------------------------------------------*/
struct __attribute__((__packed__, aligned(4))) uart0_regs_t {
	dr_reg_t DR;													// +0x0
	uint32_t RSRECR;												// +0x4
	uint32_t unused1[4];											// +0x8
	fr_reg_t FR;													// +0x18
	uint32_t unused2[2];											// +0x1c
	uint32_t IBRD;													// +0x24
	uint32_t FBRD;													// +0x28
	lcrh_reg_t LCRH;												// +0x2c
	cr_reg_t CR;													// +0x30
	uint32_t IFLS;													// +0x34
	uint32_t IMSC;													// +0x38
	uint32_t RIS;													// +0x3c
	uint32_t MIS;													// +0x40
	uint32_t ICR;													// +0x44
	uint32_t DMACR;													// +0x48
};


/*--------------------------------------------------------------------------}
{		      AUXENB Register BCM2835 ARM Peripheral manual page 9	        }
{--------------------------------------------------------------------------*/
typedef union
{
	struct
	{
		unsigned MiniUART_Enable : 1;								// @0 If set the mini UART is enabled, If clear the mini UART is disable
		unsigned SPI1_Enable : 1;									// @1 If set the SPI 1 module is enabled, If clear the SPI 1 module is disabled  
		unsigned SPI2_Enable : 1;									// @2 If set the SPI 2 module is enabled, If clear the SPI 2 module is disabled  
		unsigned reserved : 29;										// @3-31 Reserved - Write as 0, read as don't care 
	};
	uint32_t Raw32;													// Union to access all 32 bits as a uint32_t
} auxenb_reg_t;


/*--------------------------------------------------------------------------}
{		 MINI UART IOREG Register BCM2835 ARM Peripheral manual page 11	    }
{--------------------------------------------------------------------------*/
typedef union
{
	struct
	{
		unsigned DATA : 8;											// @0-7 Transmit Read/write data if DLAB=0, DLAB = 1 Lower 8 bits of 16 bit baud rate generator 
 		unsigned reserved : 24;										// @8-31 Reserved - Write as 0, read as don't care 
	};
	uint32_t Raw32;													// Union to access all 32 bits as a uint32_t
} mu_io_reg_t;

/*--------------------------------------------------------------------------}
{	MINI UART LINE CONTROL Register BCM2835 ARM Peripheral manual page 14	}
{--------------------------------------------------------------------------*/
typedef union
{
	struct
	{
		unsigned DATA_SIZE : 1;										// @0	 If clear the UART works in 7-bit mode, If set the UART works in 8-bit mode 
		unsigned reserved : 5;										// @1-5	 Reserved, write zero, read as don’t care Some of these bits have functions in a 16550 compatible UART but are ignored here
		unsigned BREAK : 1;											// @6	 If set high the UART1_TX line is pulled low continuously
		unsigned DLAB : 1;											// @7	 DLAB access control bit.
		unsigned reserved1 : 24;									// @8-31 Reserved - Write as 0, read as don't care 
	};
	uint32_t Raw32;													// Union to access all 32 bits as a uint32_t
} mu_lcr_reg_t;

/*--------------------------------------------------------------------------}
{	MINI UART MODEM CONTROL Register BCM2835 ARM Peripheral manual page 14	}
{--------------------------------------------------------------------------*/
typedef union
{
	struct
	{
		unsigned reserved : 1;										// @0	 Reserved, write zero, read as don’t care 
		unsigned RTS : 1;											// @1	 If clear the UART1_RTS line is high, If set the UART1_RTS line is low 
		unsigned reserved1 : 30;									// @2-31 Reserved - Write as 0, read as don't care 
	};
	uint32_t Raw32;													// Union to access all 32 bits as a uint32_t
} mu_mcr_reg_t;

/*--------------------------------------------------------------------------}
{	MINI UART LINE STATUS Register BCM2835 ARM Peripheral manual page 15	}
{--------------------------------------------------------------------------*/
typedef union
{
	struct
	{
		unsigned RXFDA : 1;											// @0	 This bit is set if the receive FIFO holds at least 1 
		unsigned RXOE : 1;											// @1	 This bit is set if there was a receiver overrun
		unsigned reserved : 3;										// @2-4	 Reserved, write zero, read as don’t care 
		unsigned TXFE : 1;											// @5	 This bit is set if the transmit FIFO can accept at least one byte
		unsigned TXIdle : 1;										// @6	 This bit is set if the transmit FIFO is empty and the transmitter is idle. (Finished shifting out the last bit). 
		unsigned reserved1 : 25;									// @7-31 Reserved - Write as 0, read as don't care 
	};
	uint32_t Raw32;													// Union to access all 32 bits as a uint32_t
} mu_lsr_reg_t;

/*--------------------------------------------------------------------------}
{     MINI UART CONTROL Register BCM2835 ARM Peripheral manual page 16	    }
{--------------------------------------------------------------------------*/
typedef union
{
	struct
	{
		unsigned RXE : 1;											// @0	 If this bit is set the mini UART receiver is enabled, If this bit is clear the mini UART receiver is disabled  
		unsigned TXE : 1;											// @1	 If this bit is set the mini UART transmitter is enabled, If this bit is clear the mini UART transmitter is disabled
		unsigned EnableRTS : 1;										// @2	 If this bit is set the RTS line will de-assert if the rc FIFO reaches it 'auto flow' level. If this bit is clear RTS is controlled by the AUX_MU_MCR_REG register bit 1. 
		unsigned EnableCTS : 1;										// @3	 If this bit is set the transmitter will stop if the CTS line is de-asserted. If this bit is clear the transmitter will ignore the status of the CTS line
		enum {
			FIFOhas3spaces = 0,
			FIFOhas2spaces = 1,
			FIFOhas1spaces = 2,
			FIFOhas4spaces = 3,
		} RTSflowLevel : 2;											// @4-5	 These two bits specify at what receiver FIFO level the RTS line is de-asserted in auto-flow mode
		unsigned RTSassertLevel : 1;								// @6	 If set the RTS auto flow assert level is low, If clear the RTS auto flow assert level is high
		unsigned CTSassertLevel : 1;								// @7	 If set the CTS auto flow assert level is low, If clear the CTS auto flow assert level is high
		unsigned reserved : 24;										// @8-31 Reserved - Write as 0, read as don't care 
	};
	uint32_t Raw32;													// Union to access all 32 bits as a uint32_t
} mu_cntl_reg_t;

/*--------------------------------------------------------------------------}
{	  MINI UART BAUDRATE Register BCM2835 ARM Peripheral manual page 19  	}
{--------------------------------------------------------------------------*/
typedef union
{
	struct
	{
		unsigned BaudRate : 16;										// @0-15	 mini UART baudrate counter  
		unsigned reserved : 16;										// @16-31	 Reserved - Write as 0, read as don't care 
	};
	uint32_t Raw32;													// Union to access all 32 bits as a uint32_t
} mu_baudrate_reg_t;


/*--------------------------------------------------------------------------}
{		 UART0 STRUCTURE LAYOUT BCM2835 ARM Peripheral manual page 8	    }
{--------------------------------------------------------------------------*/
struct __attribute__((__packed__, aligned(4))) aux_regs_t {
	uint32_t IRQ;													// +0x0
	auxenb_reg_t ENABLES;											// +0x4
	uint32_t unused[14];											// +0x8
	mu_io_reg_t MU_IO_REG;											// +0x40
	uint32_t MU_IER_REG;											// +0x44
	uint32_t MU_IIR_REG;											// +0x48
	mu_lcr_reg_t MU_LCR_REG;										// +0x4C
	mu_mcr_reg_t MU_MCR_REG;										// +0x50
	const mu_lsr_reg_t MU_LSR_REG;									// +0x54   ** READ ONLY HENCE CONST ***
	uint32_t MU_MSR_REG;											// +0x58
	uint32_t MU_SCRATCH;											// +0x5C
	mu_cntl_reg_t MU_CNTL_REG;										// +0x60
	uint32_t MU_STAT_REG;											// +0x64
	mu_baudrate_reg_t MU_BAUD_REG;									// +0x68;
};


/*-------------------------------------------------------------------------*/
/* If you have never seen compile time assertions it's worth google search */
/* on "Compile Time Assertions". It is part of the C11++ specification and */
/* all compilers that support the standard will have them (GCC, MSC inc)   */
/*-------------------------------------------------------------------------*/
#include <assert.h>								// Need for compile time static_assert
static_assert(offsetof(struct uart0_regs_t, FR) == 0x18, "In uart0_reg_t FR should be at offset 0x18");
static_assert(offsetof(struct uart0_regs_t, LCRH) == 0x2C, "In uart0_reg_t FR should be at offset 0x2C");
static_assert(sizeof(struct uart0_regs_t) == 0x4C, "Structure uart0_reg_t should be 0x4C bytes in size");

static_assert(sizeof(struct aux_regs_t) == 0x6C, "Structure aux_reg_t should be 0x6C bytes in size");


#define UART0 ((volatile struct uart0_regs_t*)(uintptr_t)(RPi_IO_Base_Addr + 0x00201000))
#define AUX ((volatile struct aux_regs_t*)(uintptr_t)(RPi_IO_Base_Addr + 0x00215000))


static int(*prnhandler) (const char *fmt, ...) = 0;


/**
 * Set baud rate and characteristics (115200 8N1) and map to GPIO
 */
#define TagClockRate 4000000

void uart_init (uint32_t nBaudrate, int (*printhandler) (const char *fmt, ...))
{

	uint32_t Buffer[5] = { 0 };
	mailbox_tag_message(&Buffer[0], 5, MAILBOX_TAG_GET_CLOCK_RATE, 8, 8, CLK_UART_ID, Buffer[4]);
	if (printhandler) printhandler("UART clock speed set to %u\n", Buffer[4]);

	prnhandler = printhandler;

	AUX->ENABLES.MiniUART_Enable = 1;
	
	AUX->MU_CNTL_REG.Raw32 = 0; // Zero whole register

	AUX->MU_LCR_REG.DATA_SIZE = 1;
	AUX->MU_MCR_REG.RTS  = 0;
	
	AUX->MU_BAUD_REG.BaudRate = 0xCB6;   // should be 9600 baud

	gpio_setup(14, GPIO_ALTFUNC5);
	gpio_setup(15, GPIO_ALTFUNC5);

	AUX->MU_CNTL_REG.TXE = 1;
	AUX->MU_CNTL_REG.RXE = 1;
}

/**
 * Send a character
 */
void uart_send (const char c) {
	while (1)
	{
		if (AUX->MU_LSR_REG.TXFE == 1) break;  // TX FIFO EMPTY
	}
	AUX->MU_IO_REG.DATA =  c;
	if (prnhandler) prnhandler("%c", c);
}

/**
 * Receive a character
 */
char uart_getc() {
	while (1)
	{
		if (AUX->MU_LSR_REG.RXFDA) break;   // RX FIFIO DATA AVAILABLE
	}
	return(AUX->MU_IO_REG.DATA);

}



