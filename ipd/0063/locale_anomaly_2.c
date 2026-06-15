#include <locale.h>
#include <stdio.h>
#include <stdlib.h>

/*
 * On illumos, fails to build:
 * locale_anomaly_2.c:9:33: error: initializer element is not constant
 */
static locale_t global_locale = LC_GLOBAL_LOCALE;

int
main(int argc, char **argv)
{
	int fails = 0;

	locale_t l1, l2, l3;

	setlocale(LC_ALL, "");

	l2 = uselocale(NULL);

	if (global_locale != l2) {
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

	return (fails == 0 ? EXIT_SUCCESS : EXIT_FAILURE);
}
