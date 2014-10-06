extern void mkl_set_num_threads(int);
#if !defined __unix__
extern void _mkl_set_num_threads(int);
#endif
extern int mkl_get_max_threads();
extern void mkl_get_version_string(char *, int);

#include <stdio.h>
#include <ctype.h>
#include <R.h>

void setThreads (int k) {
	mkl_set_num_threads(k);
#if !defined __unix__
	_mkl_set_num_threads(k);
#endif
}

void getThreads (int *k) {
	k[0] = mkl_get_max_threads();
}

void getVersionString ()
{
        int len=198;
        char buf[202];  /* Win32 seems to need a buffer bigger than speced len */
	mkl_get_version_string(buf, len);
	Rprintf("%s", buf);
}
