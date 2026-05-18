/************************************************************************/
/*																		*/
/*	main.c	--	Zybo Tone Generator (AXI DDS)		 				*/
/*																		*/
/************************************************************************/
/*	Author: Kendall Farnham												*/
/*  ENGS 128 - Lab 1 SDK	with AXI DDS							*/
/************************************************************************/
/*  Modified from Digilent audio DMA demo (demo.c)								*/
/*  Original Author: Sam Lowe	(9/6/2016)								*/
/*	Copyright 2015, Digilent Inc.										*/
/************************************************************************/

#include <stdio.h>
#include "xil_printf.h"
#include "intc/intc.h"
#include "iic/iic.h"
#include "audio/audio.h"
#include "xuartps.h"		// contains UART driver for reading from terminal


// BSP/platform include files
#include "xparameters.h"
#include "xil_exception.h"
#include "xdebug.h"
#include "xiic.h"
#include "xtime_l.h"
#include "xscugic.h"
#include "sleep.h"
#include "xil_cache.h"

// Get hardware device IDs and memory addresses from xparameters.h
#define UART_DEVICE_ID XPAR_PS7_UART_1_DEVICE_ID
#define UART_BASEADDR XPAR_PS7_UART_1_BASEADDR
#define AXI_LITE_BASEADDR XPAR_ENGS128_AXI_DDS_0_BASEADDR

// Set Global variables
// Get IP base address for the AXI Lite interface
s32 *baseaddr_p = (s32 *)AXI_LITE_BASEADDR;
XUartPs UartPs;
XUartPs_Config *Config;

// Device instances
static XIic sIic;
static XScuGic sIntc;

 // Interrupt vector table
 const ivt_t ivt[] = {
 	//IIC
 	{XPAR_FABRIC_AXI_IIC_0_IIC2INTC_IRPT_INTR, (Xil_ExceptionHandler)XIic_InterruptHandler, &sIic}
 };

 /*
  * 	Function to convert input string to 32-bit integer
  * 	Use to convert serial terminal characters to AXI data
  */
 s32 string_to_int32(const char *str) {
     int result = 0;
     s32 result_32b;
     while (*str) {
         if (*str >= '0' && *str <= '9') {
             result = result * 10 + (*str - '0');
         }
         str++;
     }
     result_32b = (s32)result;
     return result_32b;
 }


 /*
  * 	Function to read in user input data from serial terminal
  */
 void getUserInput()
 {
 	char userInput[10]; 		// Buffer to store user input
 	char char_received = '0';	// Variable to store read character
 	s32 input_value = 0;		// Data to write
 	s32 input_register_value = 0;	// Register offset
 	int i = 0;
 	int step = 0;				// Step 0: get register, Step 1: get value

 	// Flush UART FIFO
 	while (XUartPs_IsReceiveData(UART_BASEADDR))
 	{
 		XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
 	}

 	xil_printf("Write the LEFT audio DDS phase increment value to REGISTER 0.\n\r");
 	xil_printf("Write the RIGHT audio DDS phase increment value to REGISTER 1.\n\r");

 	// Initialize DDS phase increments
 	// C2, C3, C4, C5, C6,  C7
 	//  6, 11, 22, 45, 89, 179
 	*(baseaddr_p) = 11;	// left audio set to 129 Hz (C3)
 	*(baseaddr_p + 1) = 89;	//right audio set to 1043 Hz (C6)

 	// Prompt for register offset
 	xil_printf("Enter the register offset (0 = LEFT audio, 1 = RIGHT audio): \n\r");

 	// Wait for data on UART
 	while (!XUartPs_IsReceiveData(UART_BASEADDR)) {}

 	while (char_received != 'q')
 	{
 		if (XUartPs_IsReceiveData(UART_BASEADDR))
 		{
 			char_received = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);

 			if (char_received == '\r') {
 				userInput[i] = '\0'; // Null-terminate the string
 				xil_printf("\n\r");

 				if (step == 0) {
 					input_register_value = string_to_int32(userInput);
 					xil_printf("Register offset entered: %d\n\r", input_register_value);
 					step = 1;

 					// Prompt for data value
 					xil_printf("Enter the data to write (DDS phase increment value): \n\r");
 				}
 				else if (step == 1) {
 					input_value = string_to_int32(userInput);
 					xil_printf("Value entered: %d\n\r", input_value);

 					// Perform the register write
 					*(baseaddr_p + input_register_value) = input_value;
 					xil_printf("Wrote %d to register offset %d\n\r", input_value, input_register_value);

 					step = 0;
 					xil_printf("Enter the register offset (0 = LEFT audio, 1 = RIGHT audio): \n\r");
 				}

 				// Reset buffer and indices
 				for (int k = 0; k < 10; k++) userInput[k] = '0';
 				char_received = '0';
 				i = 0;
 			}
 			else {
 				xil_printf("%c", char_received);
 				userInput[i++] = char_received;
 			}
 		}
 	}
 	return;
 }


 /*
  * 	Initialize the UART
  */
 int configureUart()
 {

     // Initialize the UART
     Config = XUartPs_LookupConfig(UART_DEVICE_ID);
     if (Config == NULL) {
         return XST_FAILURE;
     }
     XUartPs_CfgInitialize(&UartPs, Config, Config->BaseAddress);
     XUartPs_SetBaudRate(&UartPs, 115200); // Set the baud rate as needed

     xil_printf("UART Configured for User Input\n\r");

     return 0;
 }


int main()
{
	int Status;

	//Initialize the interrupt controller
	Status = fnInitInterruptController(&sIntc);
	if(Status != XST_SUCCESS) {
		xil_printf("Error initializing interrupts");
		return XST_FAILURE;
	}


	// Initialize IIC controller
	Status = fnInitIic(&sIic);
	if(Status != XST_SUCCESS) {
		xil_printf("Error initializing I2C controller");
		return XST_FAILURE;
	}


	// Initialize Audio Codec I2S
	Status = fnInitAudio();
	if(Status != XST_SUCCESS) {
		xil_printf("Audio initializing ERROR");
		return XST_FAILURE;
	}

	{
		XTime  tStart, tEnd;

		XTime_GetTime(&tStart);
		do {
			XTime_GetTime(&tEnd);
		}
		while((tEnd-tStart)/(COUNTS_PER_SECOND/10) < 20);
	}
	//Initialize Audio I2S
	Status = fnInitAudio();
	if(Status != XST_SUCCESS) {
		xil_printf("Audio initializing ERROR");
		return XST_FAILURE;
	}

	fnSetLineInput();
	//fnSetHpOutput();	// NOTE: do not set HP output

	// Enable all interrupts in our interrupt vector table
	// Make sure all driver instances using interrupts are initialized first
	fnEnableInterrupts(&sIntc, &ivt[0], sizeof(ivt)/sizeof(ivt[0]));


    print("Audio codec initialized.\n\r");

	// Initialize the UART serial terminal
    configureUart();

    print("Successfully ran configuration sequence.");

	// Start the program
	xil_printf("---------------------------------------------\n\r");
	xil_printf("Starting AXI DDS demo... To exit, press q. \n\r");
	xil_printf("---------------------------------------------\n\r");

	getUserInput();

    xil_printf("End of test\n\n\r");

    return 0;

    return 0;
}
