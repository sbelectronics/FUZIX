/* Enable to make ^Z dump the inode table for debug */
#undef CONFIG_IDUMP
/* Enable to make ^A drop back into the monitor */
#undef CONFIG_MONITOR
/* Profil syscall support (not yet complete) */
#undef CONFIG_PROFIL
/* Multiple processes in memory at once */
#define CONFIG_MULTI
/* Single tasking - for now while we get it booting */
#undef CONFIG_SINGLETASK
/* 32bit with flat memory */
#define CONFIG_FLAT
#define CONFIG_32BIT
#define CONFIG_BANKS	1		/* FIXME */
#define CONFIG_USERMEM_DIRECT
/* Video terminal, not a serial tty */
#define CONFIG_VT
/* Simple text mode */
#define CONFIG_VT_SIMPLE
/* Vt definitions */
#define VT_BASE		(uint8_t *)0x6000	/* Default video text mode base */
#define VT_WIDTH	32
#define VT_HEIGHT	16
#define VT_RIGHT	31
#define VT_BOTTOM	15
#define VT_INITIAL_LINE	4

#define TICKSPERSEC 100   /* Ticks per second */

#define BOOT_TTY (512 + 1)   /* Set this to default device for stdio, stderr */
                          /* In this case, the default is the first TTY device */
                            /* Temp FIXME set to serial port for debug ease */

/* We need a tidier way to do this from the loader */
#define CMDLINE	NULL	  /* Location of root dev name */

/* Device parameters */
#define NUM_DEV_TTY 2
#define NDEVS    2        /* Devices 0..NDEVS-1 are capable of being mounted */
                          /*  (add new mountable devices to beginning area.) */
#define TTYDEV   BOOT_TTY /* Device used by kernel for messages, panics */
#define NBUFS    10       /* Number of block buffers */
#define NMOUNTS	 4	  /* Number of mounts at a time */
