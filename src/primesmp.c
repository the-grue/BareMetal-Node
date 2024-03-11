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

unsigned long maxn=100000, primes=1, local=0, lock=0, process_stage=0, processes=0, args=0, start=3, incby=0;
unsigned char tstring[25];

unsigned char eth_dst[6] = {0xff, 0xff, 0xff, 0xff, 0xff, 0xff};
unsigned char eth_src[6] = {0x08, 0x00, 0x27, 0xeb, 0x6b, 0x23}; // server address
unsigned char eth_type[2] = {0xAB, 0xBB};
unsigned char eth_data[10] = {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09};

int main()
{
	unsigned long time_start, time_finish, k, p = 1, q, localcore;
	primes = 1;
	
	// Set default values
	processes = 1;
	start = 3;			// starting offset
	incby = 2;			// Total number of nodes working on the problem

	output("\nBareMetal Node PrimeSMP v0.1");
//	processes = b_string_to_int(b_get_argv(1));
//	start = b_string_to_int(b_get_argv(2));		// starting offset
//	incby = b_string_to_int(b_get_argv(3));		// Total number of nodes working on the problem

	output("\nUsing ");
	itoa(processes, tstring);
	output(tstring);
	output(" CPU core(s), starting at ");
	itoa(start, tstring);
	output(tstring);
	output(", incrementing by ");
	itoa(incby, tstring);
	output(tstring);
	
	process_stage = processes;
	localcore = b_config(SMP_GET_ID, 0);
	time_start = b_config(TIMECOUNTER, 0);		// Grab the starting time

	// Start the other CPU cores
	for (k=1; k<processes; k++)
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
	time_finish = b_config(TIMECOUNTER, 0);
	output("\nFound ");
	itoa(primes, tstring);
	output(tstring);
	output(" primes in ");
	time_finish = (time_finish - time_start) / 8;
	itoa(time_finish, tstring);
	output(tstring);
	output(" seconds\n");

	// Send the result
	imemcpy(&eth_data, &primes, 8);
	b_net_tx((void *)&eth_dst, 64, 0);

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

// EOF
