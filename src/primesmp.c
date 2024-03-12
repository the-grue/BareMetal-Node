// BareMetal Node PrimeSMP v0.1 (March 11, 2024)
// Written by Ian Seyler
//
// This program checks all odd numbers between 3 and 'maxn' and determines if they are prime.
// On exit the program will display the execution time and how many prime numbers were found.
//
// BareMetal compile using GCC (Tested with 4.5.0)
// gcc -c -m64 -nostdlib -nostartfiles -nodefaultlibs -mno-red-zone -falign-functions=16 -o primesmp.o primesmp.c
// gcc -c -m64 -nostdlib -nostartfiles -nodefaultlibs -mno-red-zone -falign-functions=16 -o libBareMetal.o libBareMetal.c
// objcopy --remove-section .eh_frame --remove-section .rel.eh_frame --remove-section .rela.eh_frame primesmp.o
// objcopy --remove-section .eh_frame --remove-section .rel.eh_frame --remove-section .rela.eh_frame libBareMetal.o
// ld -T c.ld -o primesmp.app primesmp.o libBareMetal.o
//
// maxn = 1000		primes = 168
// maxn = 100000	primes = 9592
// maxn = 500000	primes = 41538
// maxn = 1000000	primes = 78498
// maxn = 5000000	primes = 348513
// maxn = 10000000	primes = 664579
// maxn = 100000000	primes = 5761455
//
// Parameters values
// Cores to use, Starting number, Increment by, Maximum
// For a single core on one machine
// Node 1: 1 3 2 100000
// For 4 cores on one machine
// Node 1: 4 3 2 100000
// For 4 cores on two systems
// Node 1: 4 3 4 100000
// Node 2: 4 5 4 100000
//

#include "libBareMetal.h"

void prime_process();
void * i_memcpy (void *dest, const void *src, int len);
unsigned int i_strlen (const char *str);
void output(const char *str);
int i_atoi(const char *str);
void i_itoa(int value, char *str);

unsigned long maxn=0, primes=0, local=0, lock=0, process_stage=0, processes=0, args=0, start=0, incby=0;
unsigned char tstring[25];

struct EthPacket {
	unsigned char eth_dst[6];
	unsigned char eth_src[6];
	unsigned char eth_type[2];
	unsigned char eth_data[10];
};

int main()
{
	unsigned long time_start, time_finish, k, p, q, localcore;
	struct EthPacket packet;
	
	char * mac = (void *)0x110048;

	packet.eth_dst[0] = 0xff;
	packet.eth_dst[1] = 0xff;
	packet.eth_dst[2] = 0xff;
	packet.eth_dst[3] = 0xff;
	packet.eth_dst[4] = 0xff;
	packet.eth_dst[5] = 0xff;
	packet.eth_src[0] = mac[0];
	packet.eth_src[1] = mac[1];
	packet.eth_src[2] = mac[2];
	packet.eth_src[3] = mac[3];
	packet.eth_src[4] = mac[4];
	packet.eth_src[5] = mac[5];
	packet.eth_type[0] = 0xAB;
	packet.eth_type[1] = 0xBB;

	// Get parameter values
	// Default would be 1, 3, 2, 100000
	char * params = (void *)0x800E;
	processes = i_atoi(params);
	params += 2;
	start = i_atoi(params);
	params += 2;
	incby = i_atoi(params);
	params += 2;
	maxn = i_atoi(params);

	output("\nBareMetal Node PrimeSMP v0.1\n");
	if (processes == 0 || start == 0 || incby == 0 || maxn == 0)
	{
		output ("Invalid parameters.\n");
		return 0;
	}

	output("Using ");
	i_itoa(processes, tstring);
	output(tstring);
	output(" CPU core(s), starting at ");
	i_itoa(start, tstring);
	output(tstring);
	output(", incrementing by ");
	i_itoa(incby, tstring);
	output(tstring);
	output(", going up to ");
	i_itoa(maxn, tstring);
	output(tstring);
	
	process_stage = processes;
	localcore = b_config(SMP_GET_ID, 0);

	// Start the other CPU cores
	for (k=0; k<processes; k++)
	{
		if (localcore != k)
		{
			b_system(SMP_SET, (void *)&prime_process, (void *)k);
		}
	}

	// Run on this CPU core
	prime_process();

	// Wait for all other CPU cores to be finished
	do {
		b_system(SMP_BUSY, (void *)&p, (void *)&q);
		output(".");
	} while (p == 1);

	// Output the results to console
	output("\nDone!\n");
//	output("\nFound ");
//	i_itoa(primes, tstring);
//	output(tstring);
//	output(" primes\n");

	// Send the result
	i_memcpy(&packet.eth_data, &primes, 8);
	b_net_tx((void *)&packet, 64, 0);

	return 0;
}


// prime_process() only works on odd numbers.
// The only even prime number is 2. All other even numbers can be divided by 2.
// 1 process	1: 3 5 7 ...
// 2 processes	1: 3 7 11 ...	2: 5 9 13 ...
// 3 processes	1: 3 9 15 ...	2: 5 11 17 ...	3: 7 13 19 ...
// 4 processes	1: 3 11 19 ...	2: 5 13 21 ...	3: 7 15 23 ...	4: 9 17 25...
// And so on.

void prime_process()
{
	register unsigned long h, i, j, tprimes=0, core;

	// Lock process_stage, copy it to local var, subtract 1 from process_stage, unlock it.
	b_system(SMP_LOCK, (void *)lock, 0);
	process_stage--;
//	output("\nRunning on core ");
//	core = b_config(SMP_GET_ID, 0);
//	i_itoa(core, tstring);
//	output(tstring);
	b_system(SMP_UNLOCK, (void *)lock, 0);
	i = start + (process_stage * incby);
	h = processes * incby;

	// Process
	for(; i<=maxn; i+=h)
	{
		for(j=2; j<=i-1; j++)
		{
			if(i%j==0) break; // Number is divisible by some other number. So break out
		}
		if(i==j)
		{
			tprimes = tprimes + 1;
		}
	} // Continue loop up to max number

	// Add tprimes to primes.
	b_system(SMP_LOCK, (void *)lock, 0);
	primes = primes + tprimes;
	b_system(SMP_UNLOCK, (void *)lock, 0);
}

void * i_memcpy (void *dest, const void *src, int len)
{
	char *d = dest;
	const char *s = src;
	while (len--)
	{
		*d++ = *s++;
	}
	return dest;
}

unsigned int i_strlen (const char *str)
{
	const char *char_ptr;
	for (char_ptr = str; (unsigned long int) char_ptr != 0; ++char_ptr)
	if (*char_ptr == '\0')
	{
		return char_ptr - str;
	}
}

void output(const char *str)
{
	int val = i_strlen(str);
	b_output(str, val);
}

int i_atoi(const char *str) {
	int result = 0; // Initialize result
	int sign = 1;  // Initialize sign as positive
	int i = 0; // Initialize index of first digit

	// If number is negative, then update sign
	if (str[0] == '-')
	{
		sign = -1;
		i++; // Also update index of first digit
	}

	// Iterate through all digits of input string and update result
	for (; str[i] != '\0'; ++i)
	{
		// Check for non-numeric char. Assuming ASCII, numeric chars are from '0'(48) to '9'(57).
		if (str[i] < '0' || str[i] > '9')
		{
			break; // If non-numeric char is found, break the loop.
		}

		// Shift result 10 times to left and add current digit.
		// '0' is subtracted to convert char to int.
		result = result * 10 + str[i] - '0';
	}
  
	// Return result with sign
	return result * sign;
}

void i_itoa(int value, char *str) {
	char temp[12]; // Temporary array to hold characters. 11 chars for INT_MIN, 1 for '\0'
	int i = 0;
	int isNegative = 0;

	// Check if number is negative
	if (value < 0)
	{
		isNegative = 1;
		value = -value; // Make the number positive for processing
	}

	// Process individual digits
	do {
		temp[i++] = (value % 10) + '0'; // Convert int digit to char
		value /= 10;
	} while (value);

	// If the number was negative, add '-'
	if (isNegative)
	{
		temp[i++] = '-';
	}

	temp[i] = '\0'; // Null-terminate the temporary string

	// Reverse the temporary string into the output string
	int start = 0;
	int end = i - 1; // Exclude the null terminator for reversing
	while (start < end)
	{
		// Swap characters
		char t = temp[start];
		temp[start] = temp[end];
		temp[end] = t;
		start++;
		end--;
	}

	// Copy the reversed string into the output buffer
	for (int j = 0; temp[j] != '\0'; ++j)
	{
		str[j] = temp[j];
	}

	str[i] = '\0'; // Ensure the output string is null-terminated
}

// EOF
