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

#include "libBareMetal.h"

void prime_process();
void * imemcpy (void *dest, const void *src, int len);
unsigned int istrlen (const char *str);
void output(const char *str);
char *reverse(char *str);
void itoa(int n, char s[]);
int atoi(char s[]);

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
	unsigned long time_start, time_finish, k, p = 1, q, localcore;
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
	// Default would be 1, 3, 2
	char * params = (void *)0x800E;
	processes = atoi(params);
	params += 2;
	start = atoi(params);
	params += 2;
	incby = atoi(params);
	params += 2;
	maxn = atoi(params);

	if (processes == 0 || start == 0 || incby == 0 || maxn == 0)
	{
		output ("Invalid parameters.\n");
		return 0;
	}

	output("\nBareMetal Node PrimeSMP v0.1");
	output("\nUsing ");
	itoa(processes, tstring);
	output(tstring);
	output(" CPU core(s), starting at ");
	itoa(start, tstring);
	output(tstring);
	output(", incrementing by ");
	itoa(incby, tstring);
	output(tstring);
	output(", going up to ");
	itoa(maxn, tstring);
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
//	while (p == 1)
//	{
		b_system(SMP_BUSY, (void *)p, (void *)q);
//		itoa(p, tstring);
//		output(tstring);
//	}
//	b_smp_wait();				// Wait for all CPU cores to finish

	// Output the results
	output("\nFound ");
	itoa(primes, tstring);
	output(tstring);
	output(" primes\n");

	// Send the result
	imemcpy(&packet.eth_data, &primes, 8);
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
	output("\nRunning on core ");
	core = b_config(SMP_GET_ID, 0);
	itoa(core, tstring);
	output(tstring);
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


void * imemcpy (void *dest, const void *src, int len)
{
	char *d = dest;
	const char *s = src;
	while (len--)
		*d++ = *s++;
	return dest;
}

unsigned int istrlen (const char *str)
{
	const char *char_ptr;
	for (char_ptr = str; (unsigned long int) char_ptr != 0; ++char_ptr)
	if (*char_ptr == '\0')
		return char_ptr - str;
}

void output(const char *str)
{
	int val = istrlen(str);
	b_output(str, val);
}

char *reverse(char *str)
{
	char tmp, *src, *dst;
	int len;
	if (str != 0)
	{
		len = istrlen (str);
		if (len > 1)
		{
			src = str;
			dst = src + len - 1;
			while (src < dst)
			{
				tmp = *src;
				*src++ = *dst;
				*dst-- = tmp;
			}
		}
	}
	return str;
}

void itoa(int n, char s[])
{
	int i, sign;

	if ((sign = n) < 0)		/* record sign */
		n = -n;			/* make n positive */
	i = 0;

	do {				/* generate digits in reverse order */
		s[i++] = n % 10 + '0';	/* get next digit */
	} while ((n /= 10) > 0);	/* delete it */

	if (sign < 0)
		s[i++] = '-';

	reverse(s);
	s[i] = '\0';
	return;
}

int atoi(char s[])
{
 //   register char *string;	/* String of ASCII digits, possibly
//				 * preceded by white space.  For bases
//				 * greater than 10, either lower- or
//				 * upper-case digits may be used.
//				 */
//{
	register int result = 0;
	register unsigned int digit;
	int sign;

	/*
	* Skip any leading blanks.
	*/

	while (*s == ' ') {
		s += 1;
	}

	/*
	* Check for a sign.
	*/

	if (*s == '-') {
		sign = 1;
		s += 1;
	} else {
		sign = 0;
		if (*s == '+') {
		s += 1;
		}
	}

	for ( ; ; s += 1) {
		digit = *s - '0';
		if (digit > 9) {
			break;
		}
		result = (10*result) + digit;
	}

	if (sign) {
		return -result;
	}
	return result;
}

// EOF
