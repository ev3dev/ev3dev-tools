/* ------------------------------------------------------------------------------
* This sample is based on code from:
*
* http://stackoverflow.com/questions/16367623/using-the-linux-sysfs-notify-call
*/

#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h> 
#include <sys/stat.h> 
#include <poll.h>

#include <sysexits.h>
#include <argp.h>

/* ------------------------------------------------------------------------------
*/
const char *argp_program_version = "1.1";

const char *argp_program_bug_address = "<rhempel@hempeldesigngroup.com>";

/* Program documentation. */
static char doc[] = "sysfs_notify_monitor -- monitor sysfs attribute files for sysfs_notify calls";

/* A description of the arguments we accept. */
static char args_doc[] = "filename";

/* The options we understand. */
static struct argp_option options[] = {
	{"timeout",  't', "msec", 0, 	"Wait at most n milliseconds\n"
					"Negative n means no timeout\n"
					"If not specified, default timeout is 10 seconds" },
	{"debug",    'd', NULL,   0,	"Turn on debug tracing"                           },
	{ 0 }
};
	
/* Used by main to communicate with parse_opt. */
struct arguments {
	int timeout;
	int debug;
	char *sysfs_file;
};

/* Parse a single option. */
static error_t
parse_opt (int key, char *arg, struct argp_state *state)
{
	/* Get the input argument from argp_parse, which we
	know is a pointer to our arguments structure. */
	struct arguments *arguments = state->input;
	
	switch (key)
	{
	case 't':
		arguments->timeout = arg ? atoi (arg) : 10000;
		break;

	case 'd':
		arguments->debug = 1;
		break;
	
	case ARGP_KEY_ARG:
		if (state->arg_num >= 1)
			/* Too many arguments. */
			argp_usage (state);
		else if (state->arg_num == 0)
			arguments->sysfs_file = arg;

		state->next = state->argc;

		break;

	case ARGP_KEY_END:
		if (state->arg_num < 1)
		/* Not enough arguments. */
		argp_usage (state);
		break;
	
	default:
		return ARGP_ERR_UNKNOWN;
	}
	return 0;
}
	
/* Our argp parser. */
static struct argp argp = { options, parse_opt, args_doc, doc };
	
int main(int argc, char **argv)
{
	int cnt, notifyFd, rv;
	int retcode = 0;
	char attrData[32];
	struct pollfd ufds[1];
	
	struct arguments arguments;
	
	/* Default values. */
	arguments.timeout    = 10000;
	arguments.debug      = 0;
	arguments.sysfs_file = "";
	
	/* Parse our arguments; every option seen by parse_opt will
	be reflected in arguments. */
	argp_parse (&argp, argc, argv, 0, 0, &arguments);
	
	// Open a connection to the attribute file.
	if ((notifyFd = open(arguments.sysfs_file, O_RDONLY)) < 0) {
		if (0 != arguments.debug) {
			perror("Unable to open");
		}
		exit(ENOENT);
	}
	
	ufds[0].fd = notifyFd;
	ufds[0].events = POLLPRI|POLLERR;
	
	// Someone suggested dummy reads before the poll() call
	cnt = read( notifyFd, attrData, 32 );

	ufds[0].revents = 0;

	if (( rv = poll( ufds, 1, arguments.timeout)) < 0 ) {
		if (0 != arguments.debug) {
			perror("Poll error");
		}
		retcode = ENOTSUP;
	}
	else if (rv == 0) {
		if (0 != arguments.debug) {
			printf("Poll timeout on %s\n", arguments.sysfs_file);
		}
		retcode = ETIME;
	}
	else if (ufds[0].revents & POLLPRI|POLLERR) {
		cnt = read( notifyFd, attrData, 32 );
		if (0 != arguments.debug) {
			printf("sysfs_notify on %s\n", arguments.sysfs_file);
			printf( "%s\n", attrData );
		}
	}
	
	if (0 != arguments.debug) {
		printf( "revents[0]: %08X\n", ufds[0].revents );
	}	

	close( notifyFd );
	
	exit (retcode);
}
