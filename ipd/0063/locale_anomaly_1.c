/*
 * Demonstrates anomalous behavior on illumos due to the value of
 * LC_GLOBAL_LOCALE being variable.
 */
#include <locale.h>
#include <stdio.h>
#include <stdlib.h>

int
main(int argc, char **argv)
{
	int fails = 0;

	locale_t l1, l2, l3;

	setlocale(LC_ALL, "C");

	l1 = LC_GLOBAL_LOCALE;

	setlocale(LC_ALL, "");

	l2 = uselocale(NULL);

	if (l1 != l2) {
		printf("FAIL: initial uselocale(NULL) != LC_GLOBAL_LOCALE\n");
		fails++;
	} else {
		/*
		 * "On success, uselocale() returns the locale handle that
		 * was set by the previous call to uselocale() in this thread,
		 * or LC_GLOBAL_LOCALE if there was no such previous call."
		 */
		printf("PASS: initial uselocale(NULL) == LC_GLOBAL_LOCALE\n");
	}

	(void) uselocale(l1);

	l3 = uselocale(NULL);

	if (l3 != l2) {
		printf("FAIL: uselocale(NULL) != LC_GLOBAL_LOCALE"
		    " after uselocale(LC_GLOBAL_LOCALE)\n");
		fails++;
	}

	return (fails == 0 ? EXIT_SUCCESS : EXIT_FAILURE);
}
