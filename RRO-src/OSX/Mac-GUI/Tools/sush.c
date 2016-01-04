#include <sys/types.h>
#include <unistd.h>

int main(int argc, char **argv) {
	setuid(0);
	return execv("/bin/sh",argv);
}
