/* chdkptp.c
 *
 * based on ptpcam.c
 * Copyright (C) 2001-2005 Mariusz Woloszyn <emsi@ipartners.pl>
 * additions
 * Copyright (C) 2010-2019 <reyalp (at) gmail dot com>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */
#if defined(WIN32) && defined(CHDKPTP_PTPIP)
#define WINVER 0x0502
#endif

#include "config.h"
#include "ptp.h"
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <getopt.h>
#include <unistd.h>
#include <signal.h>
#include <sys/types.h>
#include <time.h>
#include <utime.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <fcntl.h>
#ifdef WIN32
#ifdef CHDKPTP_PTPIP
#include <winsock2.h>
#include <ws2tcpip.h>
#endif
#else
#include <sys/mman.h>
#ifdef CHDKPTP_PTPIP
#include <sys/socket.h>
#include <netdb.h>
#endif
#endif
// NOTE libusb-win32 prior to V1.2.4.6 used <usb.h>
#ifdef WIN32
#include <lusb0_usb.h>
#else
#include <usb.h>
#endif
#ifdef CHDKPTP_READLINE
#include <readline/readline.h>
#include <readline/history.h>
#endif

#ifdef WIN32
#define usleep(usec) Sleep((usec)/1000)
#define sleep(sec) Sleep(sec*1000)
#endif

#ifdef ENABLE_NLS
#  include <libintl.h>
#  undef _
#  define _(String) dgettext (GETTEXT_PACKAGE, String)
#  ifdef gettext_noop
#    define N_(String) gettext_noop (String)
#  else
#    define N_(String) (String)
#  endif
#else
#  define textdomain(String) (String)
#  define gettext(String) (String)
#  define dgettext(Domain,Message) (Message)
#  define dcgettext(Domain,Message,Type) (Message)
#  define bindtextdomain(Domain,Directory) (Domain)
#  define _(String) (String)
#  define N_(String) (String)
#endif

#include "sockutil.h"
#include "ptpcam.h"

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#ifdef CHDKPTP_IUP
#include <iup.h>
#include <iuplua.h>
#ifdef CHDKPTP_CD
#include <cd.h>
#include <cdlua.h>
#include <cdiup.h>
#include <cdluaiup.h>
#endif
#endif
#include "lfs/lfs.h"
#include "lbuf.h"
#include "liveimg.h"
#include "rawimg.h"
#include "luautil.h"

// workaround for error building with CD using old mingw
// d:/devel/cd-5.7/lib\libcdcontextplus.a(cdwinp.o):cdwinp.cpp:(.text+0x8dca): undefined reference to `_GdipFontFamilyCachedGenericSansSerif'
// these are defined "extern" in mingw include/gdiplus/gdiplusimpl.h
#if defined(CHDKPTP_CD) && defined(CHDKPTP_GDIP_FONT_HACK)
void *_GdipFontFamilyCachedGenericMonospace;
void *_GdipFontFamilyCachedGenericSansSerif;
void *_GdipFontFamilyCachedGenericSerif;
#endif

/* some defines comes here */

/* CHDK additions */
#define CHDKPTP_VERSION_MAJOR 0
// Minor incremented for incompatible C API changes
// May not be incremented for additions, which can be detected by checking if individual functions exist
#define CHDKPTP_VERSION_MINOR 7 

/* lua registry indexes */
/* meta table for connection objects */
#define CHDK_CONNECTION_META "chkdptp.connection_meta"
/* list of opened connections, indexed weakly as t[path] = connection */
#define CHDK_CONNECTION_LIST "chkdptp.connection_list"
/* meta table for for connection list */
#define CHDK_CONNECTION_LIST_META "chkdptp.connection_list_meta"
/* meta for error object */
#define CHDK_API_ERROR_META "chkdptp.api_error_meta"

/* USB interface class */
#ifndef USB_CLASS_PTP
#define USB_CLASS_PTP		6
#endif

// Test if 'dev' is a valid USB PTP device
#define USB_IS_PTP(dev)	(dev->config && (dev->config->bNumInterfaces > 0) && (dev->config->interface->altsetting->bInterfaceClass == USB_CLASS_PTP))

/* USB control message data phase direction */
#ifndef USB_DP_HTD
#define USB_DP_HTD		(0x00 << 7)	/* host to device */
#endif
#ifndef USB_DP_DTH
#define USB_DP_DTH		(0x01 << 7)	/* device to host */
#endif

/* PTP class specific requests */
#ifndef USB_REQ_DEVICE_RESET
#define USB_REQ_DEVICE_RESET		0x66
#endif
#ifndef USB_REQ_GET_DEVICE_STATUS
#define USB_REQ_GET_DEVICE_STATUS	0x67
#endif

/* USB Feature selector HALT */
#ifndef USB_FEATURE_HALT
#define USB_FEATURE_HALT	0x00
#endif

/* OUR APPLICATION USB URB (2MB) ;) */
#define PTPCAM_USB_URB		2097152

#define USB_TIMEOUT		5000

/* one global variable (yes, I know it sucks) */
short verbose=0;
int usb_reset_on_close;
// TODO this is lame
#define CHDK_CONNECTION_METHOD PTPParams *params; PTP_CON_STATE *ptp_cs; get_connection_data(L,1,&params,&ptp_cs);

// so is this
#define CHDK_ENSURE_CONNECTED if(!ptp_cs->connected) {push_api_error_ptp(L, PTP_ERROR_NOT_CONNECTED); return lua_error(L);}

/* we need it for a proper signal handling :/ */
// reyalp -not using signal handler for now, revisit later
#if 0
PTPParams* globalparams;

void
ptpcam_siginthandler(int signum)
{
    PTP_CON_STATE* ptp_cs=(PTP_CON_STATE *)globalparams->data;
    struct usb_device *dev=usb_device(ptp_cs->usb.handle);

    if (signum==SIGINT)
    {
	/* hey it's not that easy though... but at least we can try! */
	printf("Got SIGINT, trying to clean up and close...\n");
	usleep(5000);
	close_camera (ptp_cs, globalparams, dev);
	exit (-1);
    }
}
#endif

static int
ptp_usb_read_func (unsigned char *bytes, unsigned max_size, void *data)
{
	int result=-1;
	PTP_CON_STATE *ptp_cs=(PTP_CON_STATE *)data;
	int toread=0;
	signed long int rbytes=max_size;
	int read_size = 0;
	do {
		bytes+=toread;
		if (rbytes>PTPCAM_USB_URB) 
			toread = PTPCAM_USB_URB;
		else
			toread = rbytes;
		//printf("read h:0x%p inep:0x%x b:0x%p c:%d to:%d\n",
		//			ptp_cs->usb.handle, ptp_cs->usb.inep,(char *)bytes, toread,ptp_cs->timeout);


		result=USB_BULK_READ(ptp_cs->usb.handle, ptp_cs->usb.inep,(char *)bytes, toread,ptp_cs->timeout);
		/* sometimes retry might help */
		if (result==0) {
			if(verbose) {
				printf("read retry\n");
			}
			result=USB_BULK_READ(ptp_cs->usb.handle, ptp_cs->usb.inep,(char *)bytes, toread,ptp_cs->timeout);
		}
		if (result < 0)
			break;

		read_size += result;
		ptp_cs->read_count += toread;
		rbytes-=PTPCAM_USB_URB;
	} while (rbytes>0);

	//printf("read result=%d size=%d max=%d\n",result,read_size,max_size);

	if (result >= 0) {
		return read_size;
	}
	else 
	{
		if (verbose) perror("usb_bulk_read");
		return -1;
	}
}

static short
ptp_usb_write_func (unsigned char *bytes, unsigned int size, void *data)
{
	int result;
	PTP_CON_STATE *ptp_cs=(PTP_CON_STATE *)data;

	result=USB_BULK_WRITE(ptp_cs->usb.handle,ptp_cs->usb.outep,(char *)bytes,size,ptp_cs->timeout);
	if (result >= 0) {
		ptp_cs->write_count += size;
		return (PTP_RC_OK);
	} else {
		if (verbose) perror("usb_bulk_write");
		return PTP_ERROR_IO;
	}
}

static int
ptp_usb_check_int (unsigned char *bytes, unsigned int size, void *data)
{
	int result;
	PTP_CON_STATE *ptp_cs=(PTP_CON_STATE *)data;

	result=USB_BULK_READ(ptp_cs->usb.handle, ptp_cs->usb.intep,(char *)bytes,size,ptp_cs->timeout);
	if (result==0)
	    result=USB_BULK_READ(ptp_cs->usb.handle, ptp_cs->usb.intep,(char *)bytes,size,ptp_cs->timeout);
	if (verbose>2) fprintf (stderr, "USB_BULK_READ returned %i, size=%i\n", result, size);

	if (result >= 0) {
		return result;
	} else {
		if (verbose) perror("ptp_check_int");
		return result;
	}
}


void
ptpcam_debug (void *data, const char *format, va_list args);
void
ptpcam_debug (void *data, const char *format, va_list args)
{
	if (verbose<2) return;
	vfprintf (stderr, format, args);
	fprintf (stderr,"\n");
	fflush(stderr);
}

#ifdef CHDKPTP_PTPIP
static short
ptp_tcp_write_func (unsigned char *bytes, unsigned int size, void *data)
{
	int result;
	PTP_CON_STATE *ptp_cs=(PTP_CON_STATE *)data;
	result = send( ptp_cs->tcp.cmd_sock, (char *)bytes, size, 0 );
	if (result == SOCKET_ERROR) {
		printf("send failed: %d %s\n", sockutil_errno(),sockutil_strerror(sockutil_errno()));
		return PTP_ERROR_IO;
	} else {
		ptp_cs->write_count += size;
		return (PTP_RC_OK);
	}
}

// TODO this is all wrong, we might not get whole packet, or might get part of next
// need to restructure for a PTP/IP packet oriented read
static int
ptp_tcp_read_func (unsigned char *bytes, unsigned max_size, void *data)
{
	PTP_CON_STATE *ptp_cs=(PTP_CON_STATE *)data;
	int result = recv(ptp_cs->tcp.cmd_sock, (char *)bytes, max_size, 0);
	if ( result > 0 ) {
		//printf("read %d\n",result);
		ptp_cs->read_count += result;
		return result;
	} else if ( result == 0 ) {
		printf("Connection closed\n");
		return -1;
	} else {
		printf("recv failed: %d %s\n", sockutil_errno(),sockutil_strerror(sockutil_errno()));
		return -1;
	}
}

// TODO
static int
ptp_tcp_check_int (unsigned char *bytes, unsigned int size, void *data)
{
	return PTP_RC_OK;
}

// TODO should be specified in connection, in case it actually matters
// guid for connection request, must be 16 bytes, values don't seem to matter
char my_guid[] = {
	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xde,0xad,0xbe,0xef,0x12,0x34,0x56,0x78
};
// friendly name (i.e windows network name), in utf16 value doesn't seem to matter
// according to draft spec, may be null (one 16 bit null)
char my_name[] = {
	'w',0x00,'h',0x00,'e',0x00,'e',0x00,0x00,0x00
};

// TODO
static int init_event_channel_tcp(PTP_CON_STATE* ptp_cs) {
	printf("initializing event channel\n");
	
	// Create a socket for the command channel
	socket_t sock = socket(ptp_cs->tcp.ai_con->ai_family, ptp_cs->tcp.ai_con->ai_socktype, ptp_cs->tcp.ai_con->ai_protocol);
	if (sock == INVALID_SOCKET) {
		printf("socket failed with error:  %d %s\n", sockutil_errno(),sockutil_strerror(sockutil_errno()));
	}

	// Connect to camera
	int r = connect( sock, ptp_cs->tcp.ai_con->ai_addr, (int)ptp_cs->tcp.ai_con->ai_addrlen);
	if (r == SOCKET_ERROR) {
		printf("connect failed with error:  %d %s\n", sockutil_errno(),sockutil_strerror(sockutil_errno()));
		return 0;
	}
	ptp_cs->tcp.event_sock = sock;
	// TODO need to init channel before open session will work
	PTPIPContainer pkt;
	// todo should use htod*
	pkt.type = PTPIP_TYPE_INIT_EVENT;
	pkt.length = 12; // header + connection number
	
	*(uint32_t *)(pkt.data) = ptp_cs->tcp.connection_id;
	int result = send( ptp_cs->tcp.event_sock, (char *)&pkt, pkt.length, 0 );
	if (result == SOCKET_ERROR) {
		printf("send failed: %d %s\n", sockutil_errno(),sockutil_strerror(sockutil_errno()));
		return 0;
	}

	memset(&pkt,0,sizeof(pkt));
	r = recv(ptp_cs->tcp.event_sock, (char *)&pkt, sizeof(pkt), 0);
	if ( r > 0 ) {
		if( r >= 8) {
			if(pkt.length != r) {
				printf("size %d != %d\n",pkt.length,r);
				return 0;
			}
			if(pkt.type != PTPIP_TYPE_INIT_EVENT_ACK) {
				printf("unexpected type %d\n",pkt.type);
				return 0;
			}
		} else {
			printf("failed to read header %d\n",r);
			return 0;
		}
	} else if ( r == 0 ) {
		printf("connection closed\n");
		return 0;
	} else {
		printf("recv failed with error: %d %s\n", sockutil_errno(),sockutil_strerror(sockutil_errno())); 
		return 0;
	}
	return 1;
}

int init_ptp_tcp(PTPParams* params, PTP_CON_STATE* ptp_cs) {
	params->write_func=ptp_tcp_write_func;
	params->read_func=ptp_tcp_read_func;
	params->check_int_func=ptp_tcp_check_int;
	params->check_int_fast_func=ptp_tcp_check_int;
	params->read_control_func=ptp_tcp_read_control;
	params->read_data_func=ptp_tcp_read_data;
	params->debug_func=ptpcam_debug;
	params->sendreq_func=ptp_tcp_sendreq;
	params->senddata_func=ptp_tcp_senddata;
	params->getresp_func=ptp_tcp_getresp;
	params->getdata_func=ptp_tcp_getdata;
	params->data=ptp_cs;
	params->transaction_id=0;
	params->byteorder = PTP_DL_LE;
	params->pkt_buf.pos = params->pkt_buf.len = 0;

	ptp_cs->write_count = ptp_cs->read_count = 0;

	socket_t sock = INVALID_SOCKET;
	struct addrinfo *result = NULL,
					*ptr = NULL,
					hints;

	sockutil_startup();

	memset( &hints, 0, sizeof(hints) );
	hints.ai_family = AF_UNSPEC;
	hints.ai_socktype = SOCK_STREAM;
	hints.ai_protocol = IPPROTO_TCP;

	// resolve address and port
	int r = getaddrinfo(ptp_cs->tcp.host, ptp_cs->tcp.port, &hints, &result);
	if ( r != 0 ) {
		printf("getaddrinfo failed: %d\n", r);
		return 0;
	}

	// Attempt to connect to an address until one succeeds
	for(ptr=result; ptr != NULL ;ptr=ptr->ai_next) {
		// Create a socket for the command channel
		sock = socket(ptr->ai_family, ptr->ai_socktype, ptr->ai_protocol);
		if (sock == INVALID_SOCKET) {
			printf("socket failed: %d %s\n", sockutil_errno(),sockutil_strerror(sockutil_errno()));
			freeaddrinfo(result);
			return 0;
		}

		// Connect to camera
		r = connect( sock, ptr->ai_addr, (int)ptr->ai_addrlen);
		if (r == SOCKET_ERROR) {
			sockutil_close(sock);
			sock = INVALID_SOCKET;
			continue;
		}
		break;
	}
	ptp_cs->tcp.ai = result;
	ptp_cs->tcp.ai_con = ptr;
	ptp_cs->tcp.cmd_sock = sock;
	printf("initializing command channel\n");

	PTPIPContainer pkt;
	// TODO should use pack functons
	pkt.type = PTPIP_TYPE_INIT_CMD;
	pkt.length = sizeof(my_guid) + sizeof(my_name) + 12; // header + version

	char *p = (char *)pkt.data;
	memcpy(p,my_guid,sizeof(my_guid));
	
	p+=sizeof(my_guid);

	memcpy(p,my_name,sizeof(my_name));
	p+=sizeof(my_name);

	*(int *)p = 0x00010000; // version is after variable length name...

	if(params->write_func((unsigned char *)&pkt,pkt.length,ptp_cs) != PTP_RC_OK) {
		return 0;
	}

	memset(&pkt,0,sizeof(pkt));

	if(params->read_func((unsigned char *)&pkt,sizeof(pkt),ptp_cs) < 0) {
		return 0;
	}
	if(pkt.length < 34) { // header 8 + connection id  4 + guid  16 + version 4 + wchar null name
		printf("response too small\n");
		return 0;
	}
	// TODO should use unpack functons
	if(pkt.type != PTPIP_TYPE_INIT_CMD_ACK) {
		printf("not ack, aborting\n");
		return 0;
	}
	p = (char *)&pkt;
	ptp_cs->tcp.connection_id = *(uint32_t *)(p + 8);
	memcpy(ptp_cs->tcp.cam_guid,p + 12,16);
	// TODO name and version

	if(!init_event_channel_tcp(ptp_cs)) {
		return 0;
	}

	printf("opening session\n");
	short ret = ptp_opensession(params,1);
	if(ret!=PTP_RC_OK) {
		printf("opensession failed 0x%x\n",ret);
		return 0;
	}

	ptp_cs->connected = 1;

	if (ptp_getdeviceinfo(params,&params->deviceinfo)!=PTP_RC_OK) {
		printf("Could not get device info!\n");
		return 0;
	}

	return 1;
}
#endif

int
init_ptp_usb (PTPParams* params, PTP_CON_STATE* ptp_cs, struct usb_device* dev)
{
	usb_dev_handle *device_handle;

	params->write_func=ptp_usb_write_func;
	params->read_func=ptp_usb_read_func;
	params->check_int_func=ptp_usb_check_int;
	params->check_int_fast_func=ptp_usb_check_int;
	params->read_control_func=ptp_usb_read_control;
	params->read_data_func=ptp_usb_read_data;
	params->debug_func=ptpcam_debug;
	params->sendreq_func=ptp_usb_sendreq;
	params->senddata_func=ptp_usb_senddata;
	params->getresp_func=ptp_usb_getresp;
	params->getdata_func=ptp_usb_getdata;
	params->data=ptp_cs;
	params->transaction_id=0;
	params->byteorder = PTP_DL_LE;
	params->pkt_buf.pos = params->pkt_buf.len = 0;

	device_handle = usb_open(dev);
	if (!device_handle) {
		perror("usb_open()");
		return 0;
	}
	ptp_cs->usb.handle=device_handle;
	ptp_cs->write_count = ptp_cs->read_count = 0;
	usb_set_configuration(device_handle, dev->config->bConfigurationValue);
	// TODO should check status, -EBUSY!
	usb_claim_interface(device_handle,
		dev->config->interface->altsetting->bInterfaceNumber);
	// Get max endpoint packet size for bulk transfer fix
	params->max_packet_size = dev->config->interface->altsetting->endpoint->wMaxPacketSize;
//		fprintf(stderr,"max endpoint size = %d\n",params->max_packet_size);
	if (params->max_packet_size == 0) params->max_packet_size = 512;    // safety net ?
	return 1;
}

void
clear_stall(PTP_CON_STATE* ptp_cs)
{
	uint16_t status=0;
	int ret;

	/* check the inep status */
	ret=usb_get_endpoint_status(ptp_cs,ptp_cs->usb.inep,&status);
	if (ret<0) perror ("inep: usb_get_endpoint_status()");
	/* and clear the HALT condition if happend */
	else if (status) {
		printf("Resetting input pipe!\n");
		ret=usb_clear_stall_feature(ptp_cs,ptp_cs->usb.inep);
        	/*usb_clear_halt(ptp_usb->handle,ptp_usb->inep); */
		if (ret<0)perror ("usb_clear_stall_feature()");
	}
	status=0;

	/* check the outep status */
	ret=usb_get_endpoint_status(ptp_cs,ptp_cs->usb.outep,&status);
	if (ret<0) perror ("outep: usb_get_endpoint_status()");
	/* and clear the HALT condition if happend */
	else if (status) {
		printf("Resetting output pipe!\n");
        	ret=usb_clear_stall_feature(ptp_cs,ptp_cs->usb.outep);
		/*usb_clear_halt(ptp_usb->handle,ptp_usb->outep); */
		if (ret<0)perror ("usb_clear_stall_feature()");
	}

        /*usb_clear_halt(ptp_usb->handle,ptp_usb->intep); */
}

void
close_usb(PTP_CON_STATE* ptp_cs, struct usb_device* dev)
{
	//clear_stall(ptp_cs);
	usb_release_interface(ptp_cs->usb.handle, dev->config->interface->altsetting->bInterfaceNumber);
	if(usb_reset_on_close) {
		usb_reset(ptp_cs->usb.handle);
	}
	usb_close(ptp_cs->usb.handle);
}


struct usb_bus*
get_busses()
{
	usb_find_busses();
	usb_find_devices();
	return (usb_get_busses());
}

void
find_endpoints(struct usb_device *dev, int* inep, int* outep, int* intep);
void
find_endpoints(struct usb_device *dev, int* inep, int* outep, int* intep)
{
	int i,n;
	struct usb_endpoint_descriptor *ep;

	ep = dev->config->interface->altsetting->endpoint;
	n=dev->config->interface->altsetting->bNumEndpoints;

	for (i=0;i<n;i++) {
	if (ep[i].bmAttributes==USB_ENDPOINT_TYPE_BULK)	{
		if ((ep[i].bEndpointAddress&USB_ENDPOINT_DIR_MASK)==USB_ENDPOINT_DIR_MASK)
		{
			*inep=ep[i].bEndpointAddress;
			if (verbose>1)
				fprintf(stderr, "Found inep: 0x%02x\n",*inep);
		}
		if ((ep[i].bEndpointAddress&USB_ENDPOINT_DIR_MASK)==0)
		{
			*outep=ep[i].bEndpointAddress;
			if (verbose>1)
				fprintf(stderr, "Found outep: 0x%02x\n",*outep);
		}
		} else if ((ep[i].bmAttributes==USB_ENDPOINT_TYPE_INTERRUPT) &&
			((ep[i].bEndpointAddress&USB_ENDPOINT_DIR_MASK)==
				USB_ENDPOINT_DIR_MASK))
		{
			*intep=ep[i].bEndpointAddress;
			if (verbose>1)
				fprintf(stderr, "Found intep: 0x%02x\n",*intep);
		}
	}
}

void close_camera_usb(PTP_CON_STATE *ptp_cs, PTPParams *params) {
	// usb_device(handle) appears to give bogus results when the device has gone away
	// TODO possible a different device could come back on this bus/dev ?
	struct usb_device *dev=find_device_by_path(ptp_cs->usb.bus,ptp_cs->usb.dev);
	if(!dev) {
		fprintf(stderr,"attempted to close non-present device %s:%s\n",ptp_cs->usb.bus,ptp_cs->usb.dev);
		return;
	}

	if (ptp_closesession(params)!=PTP_RC_OK)
		fprintf(stderr,"ERROR: Could not close session!\n");
	close_usb(ptp_cs, dev);
}

void close_camera_tcp(PTP_CON_STATE *ptp_cs, PTPParams *params) {
#ifdef CHDKPTP_PTPIP
	if(ptp_cs->connected) {
		if (ptp_closesession(params)!=PTP_RC_OK) {
			fprintf(stderr,"ERROR: Could not close session!\n");
		}
	}

	if( ptp_cs->tcp.cmd_sock != INVALID_SOCKET) {
		sockutil_close(ptp_cs->tcp.cmd_sock);
		ptp_cs->tcp.cmd_sock = INVALID_SOCKET;
	}
	if( ptp_cs->tcp.event_sock != INVALID_SOCKET) {
		sockutil_close(ptp_cs->tcp.event_sock);
		ptp_cs->tcp.event_sock = INVALID_SOCKET;
	}
	if(ptp_cs->tcp.ai) {
		freeaddrinfo(ptp_cs->tcp.ai);
		ptp_cs->tcp.ai = ptp_cs->tcp.ai_con = NULL;
	}
#endif
	return;
}

void
close_camera(PTP_CON_STATE *ptp_cs, PTPParams *params)
{
	if(ptp_cs->con_type == PTP_CON_USB) {
		close_camera_usb(ptp_cs,params);
	} else {
		close_camera_tcp(ptp_cs,params);
	}
}

int
usb_get_endpoint_status(PTP_CON_STATE* ptp_cs, int ep, uint16_t* status)
{
	 return (usb_control_msg(ptp_cs->usb.handle,
		USB_DP_DTH|USB_RECIP_ENDPOINT, USB_REQ_GET_STATUS,
		USB_FEATURE_HALT, ep, (char *)status, 2, 3000));
}

int
usb_clear_stall_feature(PTP_CON_STATE* ptp_cs, int ep)
{
	return (usb_control_msg(ptp_cs->usb.handle,
		USB_RECIP_ENDPOINT, USB_REQ_CLEAR_FEATURE, USB_FEATURE_HALT,
		ep, NULL, 0, 3000));
}

int
usb_ptp_get_device_status(PTP_CON_STATE* ptp_cs, uint16_t* devstatus);
int
usb_ptp_get_device_status(PTP_CON_STATE* ptp_cs, uint16_t* devstatus)
{
	return (usb_control_msg(ptp_cs->usb.handle,
		USB_DP_DTH|USB_TYPE_CLASS|USB_RECIP_INTERFACE,
		USB_REQ_GET_DEVICE_STATUS, 0, 0,
		(char *)devstatus, 4, 3000));
}

int
usb_ptp_device_reset(PTP_CON_STATE* ptp_cs);
int
usb_ptp_device_reset(PTP_CON_STATE* ptp_cs)
{
	return (usb_control_msg(ptp_cs->usb.handle,
		USB_TYPE_CLASS|USB_RECIP_INTERFACE,
		USB_REQ_DEVICE_RESET, 0, 0, NULL, 0, 3000));
}

void
reset_device (struct usb_device *dev);
void
reset_device (struct usb_device *dev)
{
	PTPParams params;
	PTP_CON_STATE ptp_cs;
	uint16_t status;
	uint16_t devstatus[2] = {0,0};
	int ret;

	printf("reset_device: ");

	if (dev==NULL) {
		printf("null dev\n");
		return;
	}
	printf("dev %s\tbus %s\n",dev->filename,dev->bus->dirname);

	find_endpoints(dev,&ptp_cs.usb.inep,&ptp_cs.usb.outep,&ptp_cs.usb.intep);

	if(!init_ptp_usb(&params, &ptp_cs, dev)) {
		printf("init_ptp_usb failed\n");
		return;
	}
	
	/* get device status (devices likes that regardless of its result)*/
	usb_ptp_get_device_status(&ptp_cs,devstatus);
	
	/* check the in endpoint status*/
	ret = usb_get_endpoint_status(&ptp_cs,ptp_cs.usb.inep,&status);
	if (ret<0) perror ("usb_get_endpoint_status()");
	/* and clear the HALT condition if happend*/
	if (status) {
		printf("Resetting input pipe!\n");
		ret=usb_clear_stall_feature(&ptp_cs,ptp_cs.usb.inep);
		if (ret<0)perror ("usb_clear_stall_feature()");
	}
	status=0;
	/* check the out endpoint status*/
	ret = usb_get_endpoint_status(&ptp_cs,ptp_cs.usb.outep,&status);
	if (ret<0) perror ("usb_get_endpoint_status()");
	/* and clear the HALT condition if happend*/
	if (status) {
		printf("Resetting output pipe!\n");
		ret=usb_clear_stall_feature(&ptp_cs,ptp_cs.usb.outep);
		if (ret<0)perror ("usb_clear_stall_feature()");
	}
	status=0;
	/* check the interrupt endpoint status*/
	ret = usb_get_endpoint_status(&ptp_cs,ptp_cs.usb.intep,&status);
	if (ret<0)perror ("usb_get_endpoint_status()");
	/* and clear the HALT condition if happend*/
	if (status) {
		printf ("Resetting interrupt pipe!\n");
		ret=usb_clear_stall_feature(&ptp_cs,ptp_cs.usb.intep);
		if (ret<0)perror ("usb_clear_stall_feature()");
	}

	/* get device status (now there should be some results)*/
	ret = usb_ptp_get_device_status(&ptp_cs,devstatus);
	if (ret<0) 
		perror ("usb_ptp_get_device_status()");
	else	{
		if (devstatus[1]==PTP_RC_OK) 
			printf ("Device status OK\n");
		else
			printf ("Device status 0x%04x\n",devstatus[1]);
	}
	
	/* finally reset the device (that clears prevoiusly opened sessions)*/
	ret = usb_ptp_device_reset(&ptp_cs);
	if (ret<0)perror ("usb_ptp_device_reset()");
	/* get device status (devices likes that regardless of its result)*/
	usb_ptp_get_device_status(&ptp_cs,devstatus);

	close_usb(&ptp_cs, dev);
}

//----------------------------
/*
get pointers out of user data in given arg
*/
static void get_connection_data(lua_State *L,int narg, PTPParams **params,PTP_CON_STATE **ptp_cs) {
	*params = (PTPParams *)luaL_checkudata(L,narg,CHDK_CONNECTION_META);
	*ptp_cs = (PTP_CON_STATE *)((*params)->data);
}

static void close_connection(PTPParams *params,PTP_CON_STATE *ptp_cs)
{
	if(ptp_cs->connected) {
		close_camera(ptp_cs,params);
	}
	ptp_cs->connected = 0;
}

static int check_connection_status_usb(PTP_CON_STATE *ptp_cs) {
	uint16_t devstatus[2] = {0,0};
	
	// TODO shouldn't ever be true
	if(!ptp_cs->connected) {// never initialized
		return 0;
	}
	if(usb_ptp_get_device_status(ptp_cs,devstatus) < 0) {
		return 0;
	}
	return (devstatus[1] == 0x2001);
}

// TODO
static int check_connection_status_tcp(PTP_CON_STATE *ptp_cs) {
	return 1;
}

/*
get dev and bus from table arg
return 1 on success, 0 on failure leaving rbus and rdev unchanged
*/
static int get_lua_devspec_usb(lua_State *L, int index, const char **rbus, const char **rdev) {
	const char *bus;
	const char *dev;
	if(!lua_istable(L,index)) {
		return 0;
	}
	lua_getfield(L,index,"dev");
	dev = lua_tostring(L,-1);
	lua_pop(L,1);
	lua_getfield(L,index,"bus");
	bus = lua_tostring(L,-1);
	lua_pop(L,1);
	if(!dev || !bus) {
		return 0;
	}
	*rdev = dev;
	*rbus = bus;
	return 1;
}

/*
get the connection user data specified by connection_list key and push it on the stack
if nothing is found, returns 0 and pushes nothing
*/
int get_connection_list_udata(lua_State *L, const char *key) {
	if(!key) {
		return 0;
	}
	lua_getfield(L,LUA_REGISTRYINDEX,CHDK_CONNECTION_LIST);
	lua_getfield(L,-1,key);
	//  TODO could check meta table
	if(lua_isuserdata(L,-1)) {
		lua_replace(L, -2); // move udata up to connection list
		return 1;
	} else {
		lua_pop(L, 2); // nil, connection list
		return 0;
	}
}

struct usb_device *find_device_by_path(const char *find_bus, const char *find_dev) {
	struct usb_bus *bus;
	struct usb_device *dev;

	bus=get_busses();
	for (; bus; bus = bus->next) {
		if(strcmp(find_bus,bus->dirname) != 0) {
			continue;
		}
		for (dev = bus->devices; dev; dev = dev->next) {
			if (USB_IS_PTP(dev)) {
				if(strcmp(find_dev,dev->filename) == 0) {
					return dev;
				}
			}
		}
	}
	return NULL;
}

int open_camera_dev_usb(struct usb_device *dev, PTP_CON_STATE *ptp_cs, PTPParams *params)
{
	uint16_t devstatus[2] = {0,0};
	int ret;
  	if(!dev) {
		printf("open_camera_dev_usb: NULL dev\n");
		return 0;
	}
	find_endpoints(dev,&ptp_cs->usb.inep,&ptp_cs->usb.outep,&ptp_cs->usb.intep);
	if(!init_ptp_usb(params, ptp_cs, dev)) {
		printf("open_camera_dev_usb: init_ptp_usb 1 failed\n");
		return 0;
	}

	ret = ptp_opensession(params,1);
	if(ret!=PTP_RC_OK) {
// TODO temp debug - this appears to be needed on linux if other stuff grabbed the dev
		printf("open_camera_dev_usb: ptp_opensession failed 0x%x\n",ret);
		ret = usb_ptp_device_reset(ptp_cs);
		if (ret<0)perror ("open_camera_dev_usb:usb_ptp_device_reset()");
		/* get device status (devices likes that regardless of its result)*/
		ret = usb_ptp_get_device_status(ptp_cs,devstatus);
		if (ret<0) 
			perror ("usb_ptp_get_device_status()");
		else	{
			if (devstatus[1]==PTP_RC_OK) 
				printf ("Device status OK\n");
			else
				printf ("Device status 0x%04x\n",devstatus[1]);
		}

		close_usb(ptp_cs, dev);
		find_endpoints(dev,&ptp_cs->usb.inep,&ptp_cs->usb.outep,&ptp_cs->usb.intep);
		if(!init_ptp_usb(params, ptp_cs, dev)) {
			printf("open_camera_dev_usb: init_ptp_usb 2 failed\n");
			return 0;
		}
		ret=ptp_opensession(params,1);
		if(ret!=PTP_RC_OK) {
			printf("open_camera_dev_usb: ptp_opensession 2 failed: 0x%x\n",ret);
			return 0;
		}

	}
	if (ptp_getdeviceinfo(params,&params->deviceinfo)!=PTP_RC_OK) {
		// TODO do we want to close here ?
		printf("Could not get device info!\n");
		close_camera(ptp_cs, params);
		return 0;
	}
	// TODO we could check camera CHDK, API version, etc here
	ptp_cs->connected = 1;
	return 1;
}

/*
tostring metamethod for errors
*/
static int api_error_tostring(lua_State *L) {
	if(!lua_istable(L,1)) {
		return luaL_error(L,"expected table");
	}
	lua_getfield(L,1,"msg");
	if(lua_isnil(L,-1)) {
		lua_pop(L,1);
		// if etype is available, use that
		lua_getfield(L,1,"etype");
		if(lua_isnil(L,-1)) {
			lua_pop(L,1);
			lua_pushstring(L,"unknown error");
		}
	}
	return 1;
}

/*
push a new error object
*/
static int push_api_error(lua_State *L) {
	lua_newtable(L);
	luaL_getmetatable(L, CHDK_API_ERROR_META);
	lua_setmetatable(L, -2);
	return 1;
}

/*
set stacktrace as field in error object
allows catching and re-throwing with correct stack
assumes stack top is error table, leaves it there
*/
static void api_error_traceback(lua_State *L, int level) {
	// borrowed from iuplua.c
	lua_getglobal(L, "debug");
	if (!lua_istable(L, -1)) {
		lua_pop(L, 1);
		return;
	}
	lua_getfield(L, -1, "traceback");
	if (!lua_isfunction(L, -1)) {
		lua_pop(L, 2);
		return;
	}

	lua_remove(L, -2); // remove the debug table
	lua_pushliteral(L, ""); // empty message for traceback
	lua_pushinteger(L, level);
	lua_call(L, 2, 1);  /* call debug.traceback */
	lua_setfield(L, -2,"traceback");
}

static int push_api_error_ptp(lua_State *L,uint16_t code) {
	push_api_error(L);
	api_error_traceback(L,1);
	lua_pushnumber(L,code);
	lua_setfield(L, -2,"ptp_rc");
	lua_pushstring(L,ptp_strerror(code));
	lua_setfield(L, -2,"msg");
	lua_pushstring(L,"ptp");
	lua_setfield(L, -2,"etype");
	return 1;
}

static int push_api_error_misc(lua_State *L,const char* etype,const char *msg,int critical) {
	push_api_error(L);
	api_error_traceback(L,1);
	if(msg) {
		lua_pushstring(L,msg);
		lua_setfield(L, -2,"msg");
	}
	if(critical) {
		lua_pushboolean(L,1);
		lua_setfield(L, -2,"critical");
	}
	lua_pushstring(L,etype);
	lua_setfield(L, -2,"etype");
	return 1;
}

/*
create an error object to throw from lua
sets meta table on passed table, or create new empty table
err=errlib.new({etype="...",msg="...",ptp_rc=...}[,level])
*/
static int errlib_new(lua_State *L) {
	if(lua_istable(L,1)) {
		luaL_getmetatable(L, CHDK_API_ERROR_META);
		lua_setmetatable(L, 1);
	} else {
		push_api_error(L);
	}
	api_error_traceback(L,luaL_optnumber(L,2,2));
	return 1;
}
/*
does errlib.new and throws the result
*/
static int errlib_throw(lua_State *L) {
	errlib_new(L);
	return lua_error(L);
}
/*
if code isn't PTP_RC_OK, push error return 0
otherwise return 1
*/
/*
static int api_check_ptp(lua_State *L,uint16_t code) {
	if(code == PTP_RC_OK) {
		return 1;
	}
	push_api_error_ptp(L,code);
	return 0;
}
*/

/*
check code and throw if not OK
*/
static int api_check_ptp_throw(lua_State *L,uint16_t code) {
	if(code != PTP_RC_OK) {
		push_api_error_ptp(L,code);
		return lua_error(L);
	}
	return 1;
}

/*
static void api_set_error(lua_State *L,const char *etype, const char *msg) {
	push_api_error_misc(L,etype,msg,0);
}
*/

/*
doesn't actually return, type int to match lua_error() pattern
*/
static int api_throw_error(lua_State *L,const char *etype, const char *msg) {
	push_api_error_misc(L,etype,msg,0);
	return lua_error(L);
}

/*
throw "critical" error - for internal errors, bad args etc, triggers stack trace by default
*/
static int api_throw_error_critical(lua_State *L,const char *etype, const char *msg) {
	push_api_error_misc(L,etype,msg,1);
	return lua_error(L);
}

/*
chdk_connection=chdk.connection([devspec])
devspec={
	bus="bus",
	dev="dev",
} 
or
devspec={
	host="host",
	port="port",
} 
retrieve or create the connection object for the specified device
each unique bus/dev combination has only one connection object. 
No attempt is made to verify that the device exists (it might be plugged/unplugged later anyway)
New connections start disconnected.
An existing connection may or may not be connected
if devinfo is absent, the dummy connection is returned
*/
static int chdk_connection(lua_State *L) {
	PTP_CON_STATE *ptp_cs;
	PTPParams *params;
	const char *bus=NULL;
	const char *dev=NULL;
	const char *host=NULL;
	const char *port=NULL;
	char con_key[LIBUSB_PATH_MAX*2+4];
	int con_type;

	if(lua_istable(L,1)) {
		get_lua_devspec_usb(L,1,&bus,&dev);

		lua_getfield(L,1,"host");
		host = lua_tostring(L,-1);
		lua_pop(L,1);

		lua_getfield(L,1,"port");
		port = lua_tostring(L,-1);
		lua_pop(L,1);
	} else {
		bus = "dummy";
		dev = "dummy";
	}

	if(host || port) {
#ifdef CHDKPTP_PTPIP
		if(dev || bus) {
			return luaL_error(L,"cannot specify dev or bus with PTP/IP");
		}
		if(!host) {
			return luaL_error(L,"missing host");
		}
		if(!port) {
			port = PTPIP_PORT_STR;
		}
		if(strlen(host) >= LIBUSB_PATH_MAX || strlen(port) >= LIBUSB_PATH_MAX) {
			return luaL_error(L,"invalid PTP/IP spec");
		}
		sprintf(con_key,"tcp:%s:%s",host,port);
		con_type = PTP_CON_TCP;
#else
		return luaL_error(L,"PTP/IP not supported in this build");
#endif

	} else  {
		if(!bus || !dev || strlen(dev) >= LIBUSB_PATH_MAX || strlen(bus) >= LIBUSB_PATH_MAX) {
			return luaL_error(L,"invalid device spec");
		}
		sprintf(con_key,"usb:%s/%s",bus,dev);
		con_type = PTP_CON_USB;
	}

	// if connection to specified device exists, just return it
	if(get_connection_list_udata(L,con_key)) {
		return 1;
	}
	params = lua_newuserdata(L,sizeof(PTPParams));
	luaL_getmetatable(L, CHDK_CONNECTION_META);
	lua_setmetatable(L, -2);

	memset(params,0,sizeof(PTPParams));
	ptp_cs = malloc(sizeof(PTP_CON_STATE));
	params->data = ptp_cs; // this will be set on connect, but we want set so it can be collected even if we don't connect
	memset(ptp_cs,0,sizeof(PTP_CON_STATE));
	if(con_type == PTP_CON_USB) {
		strcpy(ptp_cs->usb.dev,dev);
		strcpy(ptp_cs->usb.bus,bus);
	} else {
		strcpy(ptp_cs->tcp.host,host);
		strcpy(ptp_cs->tcp.port,port);
		ptp_cs->tcp.cmd_sock = ptp_cs->tcp.event_sock = INVALID_SOCKET;
	}
	ptp_cs->timeout = USB_TIMEOUT;
	ptp_cs->con_type = con_type;

	// save in registry so we can easily identify / enumerate existing connections
	lua_getfield(L,LUA_REGISTRYINDEX,CHDK_CONNECTION_LIST);
	lua_pushvalue(L, -2); // our user data, for use as key
	lua_setfield(L, -2,con_key); //set t[path]=userdata
	lua_pop(L,1); // done with t
	return 1;
}

static int connect_cam_usb(lua_State *L, PTPParams *params, PTP_CON_STATE *ptp_cs) {
	struct usb_device *dev=find_device_by_path(ptp_cs->usb.bus,ptp_cs->usb.dev);
	if(!dev) {
		return api_throw_error(L,"connect_no_dev","no matching device");
	}
	if(open_camera_dev_usb(dev,ptp_cs,params)) {
		return 0;
	} else {
		ptp_cs->connected = 0;
		// TODO should get return code from open_camera_dev_usb
		return api_throw_error(L,"connect_fail","connection failed");
	}
}
static int connect_cam_tcp(lua_State *L, PTPParams *params, PTP_CON_STATE *ptp_cs) {
#ifdef CHDKPTP_PTPIP
	if(!init_ptp_tcp(params,ptp_cs)) {
		close_camera_tcp(ptp_cs,params); // TODO should clean up any partially open stuff
		ptp_cs->connected = 0;
		// TODO return detailed error messages instead of printing
		return api_throw_error(L,"connect_fail","connection failed");
	}
	return 0;
#else
	return luaL_error(L,"PTP/IP not supported");
#endif
}
/*
con:connect()
throws on error or if already connected
*/
static int chdk_connect(lua_State *L) {
	CHDK_CONNECTION_METHOD;
	
	// TODO might want to disconnect/reconnect, or check real connection status ? or options
	if(ptp_cs->connected) {
		return api_throw_error(L,"connect_connected","connection already connected");
	}

	if(ptp_cs->con_type == PTP_CON_USB) {
		return connect_cam_usb(L,params,ptp_cs);
	} else {
		return connect_cam_tcp(L,params,ptp_cs);
	}
}

/*
disconnect the connection
note under windows the device does not appear in in chdk.list_usb_devices() for a short time after disconnecting
*/
static int chdk_disconnect(lua_State *L) {
  	CHDK_CONNECTION_METHOD;

	close_connection(params,ptp_cs);
	return 0;
}

static int chdk_is_connected(lua_State *L) {
  	CHDK_CONNECTION_METHOD;
	// TODO this should probably be more consistent over other PTP calls, #41
	// flag says we are connected, check usb and update flag
	if(ptp_cs->connected) { 
		if(ptp_cs->con_type == PTP_CON_USB) {
			ptp_cs->connected = check_connection_status_usb(ptp_cs);
		} else {
			ptp_cs->connected = check_connection_status_tcp(ptp_cs);
		}
	}
	lua_pushboolean(L,ptp_cs->connected);
	return 1;
}

// major, minor = chdk.camera_api_version()
// TODO double return is annoying
// TODO we could just get this when we connect
static int chdk_camera_api_version(lua_State *L) {
  	CHDK_CONNECTION_METHOD;
	CHDK_ENSURE_CONNECTED;
	int major,minor;

	api_check_ptp_throw(L,ptp_chdk_get_version(params,&major,&minor));

	lua_pushnumber(L,major);
	lua_pushnumber(L,minor);
	return 2;
}

static int chdk_host_api_version(lua_State *L) {
	lua_newtable(L);
	lua_pushnumber(L,PTP_CHDK_VERSION_MAJOR);
	lua_setfield(L, -2, "MAJOR");
	lua_pushnumber(L,PTP_CHDK_VERSION_MINOR);
	lua_setfield(L, -2, "MINOR");
	return 1;
}

static int chdk_program_version(lua_State *L) {
	lua_newtable(L);
	lua_pushnumber(L,CHDKPTP_VERSION_MAJOR);
	lua_setfield(L, -2, "MAJOR");

	lua_pushnumber(L,CHDKPTP_VERSION_MINOR);
	lua_setfield(L, -2, "MINOR");

	lua_pushnumber(L,CHDKPTP_BUILD_NUM);
	lua_setfield(L, -2, "BUILD");

	lua_pushstring(L,CHDKPTP_REL_DESC);
	lua_setfield(L, -2, "DESC");

	lua_pushstring(L,__DATE__);
	lua_setfield(L, -2, "DATE");

	lua_pushstring(L,__TIME__);
	lua_setfield(L, -2, "TIME");

	lua_pushstring(L,__VERSION__);
	lua_setfield(L, -2, "COMPILER_VERSION");

	return 1;
}

/*
con:execlua("code"[,flags])
flags: PTP_CHDK_SCRIPT_FL* values.
no return value, throws error on failure
on compile error, thrown etype='execlua_compile'
on script running, thrown etype='execlua_scriptrun'
con:get_script_id() will return the id of the started script
*/
static int chdk_execlua(lua_State *L) {
  	CHDK_CONNECTION_METHOD;
	CHDK_ENSURE_CONNECTED;

	int status;
	api_check_ptp_throw(L, ptp_chdk_exec_lua(params,
						(char *)luaL_optstring(L,2,""),
						luaL_optnumber(L,3,0),
						&ptp_cs->script_id,&status));

	if(status == PTP_CHDK_S_ERRTYPE_NONE) {
		return 0;
	} else {
		if(status == PTP_CHDK_S_ERRTYPE_COMPILE) {
			return api_throw_error(L,"execlua_compile","compile error"); // caller can check messages for details
		} else if(status == PTP_CHDK_S_ERR_SCRIPTRUNNING) {
			return api_throw_error(L,"execlua_scriptrun","a script is already running");
		} else {
			return api_throw_error_critical(L,"unknown","unknown error");
		}
	}
}

/*
push a new table onto the stack
{
	"bus" = "dirname", 
	"dev" = "filename", 
	"vendor_id" = VENDORID,
	"product_id" = PRODUCTID,
}
TODO may want to include interface/config info
*/
static void push_usb_dev_info(lua_State *L,struct usb_device *dev) {
	lua_createtable(L,0,4);
	lua_pushstring(L, dev->bus->dirname);
	lua_setfield(L, -2, "bus");
	lua_pushstring(L, dev->filename);
	lua_setfield(L, -2, "dev");
	lua_pushnumber(L, dev->descriptor.idVendor);
	lua_setfield(L, -2, "vendor_id");
	lua_pushnumber(L, dev->descriptor.idProduct);
	lua_setfield(L, -2, "product_id");
}

static int chdk_list_usb_devices(lua_State *L) {
	struct usb_bus *bus;
	struct usb_device *dev;
	int found=0;
	bus=get_busses();
	lua_newtable(L);
  	for (; bus; bus = bus->next) {
    	for (dev = bus->devices; dev; dev = dev->next) {
			/* if it's a PTP list it */
			if (USB_IS_PTP(dev)) {
				push_usb_dev_info(L,dev);
				found++;
				lua_rawseti(L, -2, found); // add to array
			}
		}
	}
	return 1;
}

/*
con:upload(src,dst)
throws on error
*/
static int chdk_upload(lua_State *L) {
  	CHDK_CONNECTION_METHOD;
	CHDK_ENSURE_CONNECTED;
	char *src = (char *)luaL_checkstring(L,2);
	char *dst = (char *)luaL_checkstring(L,3);

	api_check_ptp_throw(L,ptp_chdk_upload(params,src,dst));

	return 0;
}

/*
con:download(src,dst)
throws on error
*/
static int chdk_download(lua_State *L) {
  	CHDK_CONNECTION_METHOD;
	CHDK_ENSURE_CONNECTED;
	char *src = (char *)luaL_checkstring(L,2);
	char *dst = (char *)luaL_checkstring(L,3);

	api_check_ptp_throw(L,ptp_chdk_download(params,src,dst));

	return 0;
}

/*
isready,imgnum=con:capture_ready()
isready: 
	false: local error in errmsg
	0: not ready
	0x10000000: remotecap not initialized, or timed out
	otherwise, lowest 3 bits: available data types.
imgnum:
	image number if data is available, otherwise 0
*/
static int chdk_capture_ready(lua_State *L) {
	CHDK_CONNECTION_METHOD;
	CHDK_ENSURE_CONNECTED;
	int isready = 0;
	int imgnum = 0;

	api_check_ptp_throw(L,ptp_chdk_rcisready(params,&isready,&imgnum));

	lua_pushinteger(L,isready);
	lua_pushinteger(L,imgnum);
	return 2;
}

/*
chunk=con:capture_get_chunk(fmt)
fmt: data type (1: jpeg, 2: raw, 4:dng header)
must be a single type reported as available by con:capture_ready()
chunk:
{
	size=number,
	offset=number|nil,
	last=bool
	data=lbuf
}
throws error on error
*/
static int chdk_capture_get_chunk(lua_State *L) {
	CHDK_CONNECTION_METHOD;
	CHDK_ENSURE_CONNECTED;
	int fmt = (unsigned)luaL_checknumber(L,2);
	ptp_chdk_rc_chunk chunk;

	api_check_ptp_throw(L,ptp_chdk_rcgetchunk(params,fmt,&chunk));

	lua_createtable(L,0,4);
	lua_pushinteger(L, chunk.size);
	lua_setfield(L, -2, "size");
	if((int32_t)chunk.offset != -1) {
		lua_pushinteger(L, chunk.offset);
		lua_setfield(L, -2, "offset");
	}
	lua_pushboolean(L, chunk.last);
	lua_setfield(L, -2, "last");

	lbuf_create(L,chunk.data,chunk.size,LBUF_FL_FREE); // data is allocated by ptp chunk, will be freed on gc
	lua_setfield(L, -2, "data");

	return 1;
}

/*
r=con:getmem(address,count[,dest[,flags]])
dest is
"string"
"lbuf"
"number" TODO int or unsigned ?
-- not implemented yet ->
"array" array of numbers
"file",<filename>
default is string
*/
static int chdk_getmem(lua_State *L) {
  	CHDK_CONNECTION_METHOD;
	CHDK_ENSURE_CONNECTED;

	unsigned addr, count;
	const char *dest;
	char *buf;
	int flags;
	addr = (unsigned)luaL_checknumber(L,2);
	count = (unsigned)luaL_checknumber(L,3);
	dest = luaL_optstring(L,4,"string");
	flags = luaL_optnumber(L,5,0);

	// TODO check dest values
	api_check_ptp_throw(L,ptp_chdk_get_memory(params,addr,count,flags,&buf));

	if(strcmp(dest,"string") == 0) {
		lua_pushlstring(L,buf,count);
	} else if(strcmp(dest,"number") == 0) {
		lua_pushnumber(L,(lua_Number)(*(unsigned *)buf));
	} else if(strcmp(dest,"lbuf") == 0) {
		lbuf_create(L,buf,count,LBUF_FL_FREE);
		return 1; // buf will be freed when lbuf is garbage collected
	}
	free(buf);
	return 1;
}

/*
TODO
status[,msg]=con:setmem(address,data)
data is a number (to bet set as a 32 bit int) or string
*/
static int chdk_setmem(lua_State *L) {
	return api_throw_error(L,"not_implemented","not implemented yet, use lua poke()");
}

/*
ret=con:call_function(ptr,arg1,arg2...argN)
call a pointer directly from ptp code.
useful if lua is not available
args must be numbers, or pointers set up on the cam by other means
*/
static int chdk_call_function(lua_State *L) {
	CHDK_CONNECTION_METHOD;
	CHDK_ENSURE_CONNECTED;
	int args[11];
	int ret;
	memset(args,0,sizeof(args));
	int size = lua_gettop(L)-1; // args excluding self
	if(size > 10 || size < 1) {
		return api_throw_error_critical(L,"bad_arg","invalid number of arguments");
	}
	int i;
	for(i=2;i<=size+1;i++) {
		args[i-2] = (unsigned)luaL_checknumber(L,i);
	}
	api_check_ptp_throw(L,ptp_chdk_call_function(params,args,size,&ret));

	lua_pushnumber(L,ret);
	return 1;
}

static int chdk_script_support(lua_State *L) {
  	CHDK_CONNECTION_METHOD;
	CHDK_ENSURE_CONNECTED;
	unsigned status = 0;
    api_check_ptp_throw(L,ptp_chdk_get_script_support(params,&status));

	lua_pushnumber(L,status);
	return 1;
}

/*
status=con:script_status()
status={run:bool,msg:bool} or throws error
*/
static int chdk_script_status(lua_State *L) {
  	CHDK_CONNECTION_METHOD;
	CHDK_ENSURE_CONNECTED;
	unsigned status;

	api_check_ptp_throw(L,ptp_chdk_get_script_status(params,&status));

	lua_createtable(L,0,2);
	lua_pushboolean(L, status & PTP_CHDK_SCRIPT_STATUS_RUN);
	lua_setfield(L, -2, "run");
	lua_pushboolean(L, status & PTP_CHDK_SCRIPT_STATUS_MSG);
	lua_setfield(L, -2, "msg");
	return 1;
}
/*
lbuf=con:get_live_data(lbuf,flags)
lbuf - lbuf to re-use, will be created if nil
throws error on failure
*/
static int chdk_get_live_data(lua_State *L) {
  	CHDK_CONNECTION_METHOD;
	CHDK_ENSURE_CONNECTED;
	lBuf_t *buf = lbuf_getlbuf(L,2);
	unsigned flags=lua_tonumber(L,3);
	char *data=NULL;
	unsigned data_size = 0;
	api_check_ptp_throw(L,ptp_chdk_get_live_data(params,flags,&data,&data_size));

	if(!data) {
		return api_throw_error_critical(L,"internal_error","no data");
	}
	if(!data_size) {
		return api_throw_error_critical(L,"internal_error","zero data size");
	}
	if(buf) {
		if(buf->flags & LBUF_FL_FREE) {
			free(buf->bytes);
		}
		buf->bytes = data;
		buf->len = data_size;
		buf->flags = LBUF_FL_FREE;
		lua_pushvalue(L,2); // copy it to stack top for return
	} else {
		lbuf_create(L,data,data_size,LBUF_FL_FREE);
	}
	return 1;
}

// TODO these assume numbers are 0 based and contiguous 
static const char* script_msg_type_to_name(unsigned type_id) {
	const char *names[]={"none","error","return","user"};
	if(type_id >= sizeof(names)/sizeof(names[0])) {
		return "unknown_msg_type";
	}
	return names[type_id];
}

static const char* script_msg_data_type_to_name(unsigned type_id) {
	const char *names[]={"unsupported","nil","boolean","integer","string","table"};
	if(type_id >= sizeof(names)/sizeof(names[0])) {
		return "unknown_msg_subtype";
	}
	return names[type_id];
}

static const char* script_msg_error_type_to_name(unsigned type_id) {
	const char *names[]={"none","compile","runtime"};
	if(type_id >= sizeof(names)/sizeof(names[0])) {
		return "unknown_error_subtype";
	}
	return names[type_id];
}

/*
msg=con:read_msg()
msg:{
	value=<val> -- lua value, tables are serialized strings
	script_id=number
	mtype=string -- one of "none","error","return","user"
	msubtype=string -- for returns and user messages, one of
	                -- "unsupported","nil","boolean","integer","string","table" 
					-- for errors, one of "compile","runtime"
}
no message: type is set to 'none'
throws error on error
use chdku con:wait_status or chdku con:wait_msg to wait for messages
*/

static int chdk_read_msg(lua_State *L) {
  	CHDK_CONNECTION_METHOD;
	CHDK_ENSURE_CONNECTED;

	ptp_chdk_script_msg *msg = NULL;

	api_check_ptp_throw(L,ptp_chdk_read_script_msg(params,&msg));

	lua_createtable(L,0,4);
	lua_pushinteger(L, msg->script_id);
	lua_setfield(L, -2, "script_id");
	lua_pushstring(L, script_msg_type_to_name(msg->type));
	lua_setfield(L, -2, "type");

	switch(msg->type) {
		case PTP_CHDK_S_MSGTYPE_RET:
		case PTP_CHDK_S_MSGTYPE_USER:
			lua_pushstring(L, script_msg_data_type_to_name(msg->subtype));
			lua_setfield(L, -2, "subtype");
			switch(msg->subtype) {
				case PTP_CHDK_TYPE_UNSUPPORTED: // type name will be returned in data
				case PTP_CHDK_TYPE_STRING: 
				case PTP_CHDK_TYPE_TABLE: // tables are returned as a serialized string. 
										  // The user is responsible for unserializing, to allow different serialization methods
					lua_pushlstring(L, msg->data,msg->size);
					lua_setfield(L, -2, "value");
				break;
				case PTP_CHDK_TYPE_BOOLEAN:
					lua_pushboolean(L, *(int *)msg->data);
					lua_setfield(L, -2, "value");
				break;
				case PTP_CHDK_TYPE_INTEGER:
					lua_pushinteger(L, *(int *)msg->data);
					lua_setfield(L, -2, "value");
				break;
				// default or PTP_CHDK_TYPE_NIL - value is nil
			}
		break;
		case PTP_CHDK_S_MSGTYPE_ERR:
			lua_pushstring(L, script_msg_error_type_to_name(msg->subtype));
			lua_setfield(L, -2, "subtype");
			lua_pushlstring(L,msg->data,msg->size);
			lua_setfield(L, -2, "value");
		break;
		// default or MSGTYPE_NONE - value is nil
	}
	free(msg);
	return 1;
}

/*
con:write_msg(msgstring,[script_id])
script_id defaults to the most recently started script
throws error on failure, error.etype can be used to identify full queue etc
*/
static int chdk_write_msg(lua_State *L) {
  	CHDK_CONNECTION_METHOD;
	CHDK_ENSURE_CONNECTED;
	const char *str;
	size_t len;
	int status;
	int target_script_id = luaL_optinteger(L,3,ptp_cs->script_id);

	str = lua_tolstring(L,2,&len);
	if(!str || !len) {
		return api_throw_error_critical(L,"bad_arg","invalid data");
	}

	api_check_ptp_throw(L,ptp_chdk_write_script_msg(params,(char *)str,len,target_script_id,&status));

	switch(status) {
		case PTP_CHDK_S_MSGSTATUS_OK:
			return 0;
		case PTP_CHDK_S_MSGSTATUS_NOTRUN:
			return api_throw_error(L,"msg_notrun","no script running");
		case PTP_CHDK_S_MSGSTATUS_QFULL:
			return api_throw_error(L,"msg_full","message queue full");
		case PTP_CHDK_S_MSGSTATUS_BADID:
			return api_throw_error(L,"msg_badid","bad script id");
	}
	return api_throw_error_critical(L,"internal_error","unexpected status code");
}

/*
(script_id|false) = con:get_script_id()
returns the id of the most recently started script
script ids start at 1, and will be reset if the camera reboots
script id will be false if the last script request failed to reach the camera or no script has yet been run
scripts that encounter a syntax error still generate an id
*/
static int chdk_get_script_id(lua_State *L) {
  	CHDK_CONNECTION_METHOD;
	// TODO do we want to check connections status ?
	if(ptp_cs->script_id) {
		lua_pushnumber(L,ptp_cs->script_id);
	} else {
		lua_pushboolean(L,0);
	}
	return 1;
}

/*
TEMP testing
get_status_result,status[0],status[1]=con:dev_status()
*/
static int chdk_dev_status(lua_State *L) {
  	CHDK_CONNECTION_METHOD;
	uint16_t devstatus[2] = {0,0};
	int r = usb_ptp_get_device_status(ptp_cs,devstatus);
	lua_pushnumber(L,r);
	lua_pushnumber(L,devstatus[0]);
	lua_pushnumber(L,devstatus[1]);
	return 3;
}

/*
ptp_dev_info=con:get_ptp_devinfo()
ptp_dev_info = {
	manufacturer = "manufacturer"
	model = "model"
	device_version = "version""
	serial_number = "serialnum"
	max_packet_size = <number>
	... PTP standard fields
}
serial number may be NULL (=unset in table)
version does not match canon firmware version (e.g. d10 100a = "1-6.0.1.0")
*/
static int chdk_get_ptp_devinfo(lua_State *L) {
	CHDK_CONNECTION_METHOD;
	// don't actually need to be connected to get this, but ensures we have valid data
	CHDK_ENSURE_CONNECTED;

	lua_newtable(L);
	lua_pushnumber(L, params->deviceinfo.StandardVersion);
	lua_setfield(L, -2, "StandardVersion");
	lua_pushnumber(L, params->deviceinfo.VendorExtensionID);
	lua_setfield(L, -2, "VendorExtensionID");
	lua_pushnumber(L, params->deviceinfo.VendorExtensionVersion);
	lua_setfield(L, -2, "VendorExtensionVersion");
	lua_pushstring(L, params->deviceinfo.VendorExtensionDesc);
	lua_setfield(L, -2, "VendorExtensionDesc");
	lua_pushnumber(L, params->deviceinfo.FunctionalMode);
	lua_setfield(L, -2, "FunctionalMode");

	lu_pusharray_raw_u16(L,params->deviceinfo.OperationsSupported_len,params->deviceinfo.OperationsSupported);
	lua_setfield(L, -2, "OperationsSupported");
	lu_pusharray_raw_u16(L,params->deviceinfo.EventsSupported_len,params->deviceinfo.EventsSupported);
	lua_setfield(L, -2, "EventsSupported");
	lu_pusharray_raw_u16(L,params->deviceinfo.DevicePropertiesSupported_len,params->deviceinfo.DevicePropertiesSupported);
	lua_setfield(L, -2, "DevicePropertiesSupported");
	lu_pusharray_raw_u16(L,params->deviceinfo.CaptureFormats_len,params->deviceinfo.CaptureFormats);
	lua_setfield(L, -2, "CaptureFormats");
	lu_pusharray_raw_u16(L,params->deviceinfo.ImageFormats_len,params->deviceinfo.ImageFormats);
	lua_setfield(L, -2, "ImageFormats");

	// TODO for historical reasons, the fields below don't match PTP standard names
	lua_pushstring(L, params->deviceinfo.Model);
	lua_setfield(L, -2, "model");
	lua_pushstring(L, params->deviceinfo.Manufacturer);
	lua_setfield(L, -2, "manufacturer");
	lua_pushstring(L, params->deviceinfo.DeviceVersion);
	lua_setfield(L, -2, "device_version");
	lua_pushstring(L, params->deviceinfo.SerialNumber);
	lua_setfield(L, -2, "serial_number");
	// TODO technically this belongs to the endpoint
	// putting it here for informational purposes anyway so we can display in lua
	// TODO not applicable to ptpip
	lua_pushnumber(L, params->max_packet_size);
	lua_setfield(L, -2, "max_packet_size");

	return 1;
}

// TODO lua code expects all to devices to have devinfo
/*
dev_info=con:get_con_devinfo()
dev_info = {
	transport="usb"|"ip"
	-- usb
	bus="bus"
	dev="dev"
	"vendor_id" = VENDORID, -- nil if no matching PTP capable device is connected
	"product_id" = PRODUCTID, -- nil if no matching PTP capable device is connected
	-- ip
	host="host" -- host specified in chdk.connection
	port="port"
	guid="guid" -- binary 16 byte GUID from cam
}
*/
static int chdk_get_con_devinfo(lua_State *L) {
	CHDK_CONNECTION_METHOD;
	// TODO
	if(ptp_cs->con_type == PTP_CON_USB) {
		struct usb_device *dev;
		dev=find_device_by_path(ptp_cs->usb.bus,ptp_cs->usb.dev);
		if(dev) {
			push_usb_dev_info(L,dev);
		} else {
			lua_newtable(L);
			lua_pushstring(L, ptp_cs->usb.bus);
			lua_setfield(L, -2, "bus");
			lua_pushstring(L, ptp_cs->usb.dev);
			lua_setfield(L, -2, "dev");
		}
		lua_pushstring(L, "usb");
		lua_setfield(L, -2, "transport");
	} else {
		lua_newtable(L);
		lua_pushstring(L, ptp_cs->tcp.host);
		lua_setfield(L, -2, "host");
		lua_pushstring(L, ptp_cs->tcp.port);
		lua_setfield(L, -2, "port");
		lua_pushlstring(L, ptp_cs->tcp.cam_guid,16);
		lua_setfield(L, -2, "guid");

		lua_pushstring(L, "ip");
		lua_setfield(L, -2, "transport");
	}
	return 1;
}

// TEMP TESTING
static int chdk_get_conlist(lua_State *L) {
	lua_getfield(L,LUA_REGISTRYINDEX,CHDK_CONNECTION_LIST);
	return 1;
}

static int chdk_reset_device(lua_State *L) {
	const char *busname, *devname;
	if(get_lua_devspec_usb(L,1,&busname,&devname)) {
		struct usb_device *dev = find_device_by_path(busname,devname);
		if(dev) {
			reset_device(dev);
		} else {
			return api_throw_error(L,"nodev","no matching device");
		}
	} else {
		return api_throw_error(L,"baddev","invalid device spec");
	}
	return 0;
}

static int chdk_set_usb_reset_on_close(lua_State *L) {
	usb_reset_on_close = lua_toboolean(L,1);
	return 0;
}
static int chdk_get_usb_reset_on_close(lua_State *L) {
	lua_pushboolean(L,usb_reset_on_close);
	return 1;
}

/*
most functions throw an error on failure
*/
static const luaL_Reg chdklib[] = {
  {"connection", chdk_connection},
  {"host_api_version", chdk_host_api_version},
  {"program_version", chdk_program_version},
  {"list_usb_devices", chdk_list_usb_devices},
  {"get_conlist", chdk_get_conlist}, // TEMP TESTING
  {"reset_device", chdk_reset_device},
  {"set_usb_reset_on_close", chdk_set_usb_reset_on_close},
  {"get_usb_reset_on_close", chdk_get_usb_reset_on_close},
  {NULL, NULL}
};

static int chdk_connection_gc(lua_State *L) {
	CHDK_CONNECTION_METHOD;

	//printf("collecting connection %s:%s\n",ptp_cs->usb.bus,ptp_cs->usb.dev);

	if(ptp_cs->connected) {
		//printf("disconnecting...");
		close_camera(ptp_cs,params);
		//printf("done\n");
	}
	free(ptp_cs);
	return 0;
}

static int chdk_reset_counters(lua_State *L) {
	CHDK_CONNECTION_METHOD;
	ptp_cs->write_count = ptp_cs->read_count = 0;
	return 0;
}

static int chdk_get_counters(lua_State *L) {
	CHDK_CONNECTION_METHOD;
	lua_createtable(L,0,2);
	lua_pushnumber(L,ptp_cs->write_count);
	lua_setfield(L,-2,"write");
	lua_pushnumber(L,ptp_cs->read_count);
	lua_setfield(L,-2,"read");
	return 1;
}

/*
standard PTP GetStorageIDs
storageids=con:ptp_get_storage_ids()
storageids: lua array of numbers
*/
static int chdk_ptp_get_storage_ids(lua_State *L) {
	CHDK_CONNECTION_METHOD;
	CHDK_ENSURE_CONNECTED;

	PTPStorageIDs storageids;

	api_check_ptp_throw(L,ptp_getstorageids(params,&storageids));
	lu_pusharray_raw_u32(L,storageids.n,storageids.Storage);
	free(storageids.Storage);
	return 1;
}
/*
standard PTP GetStorageInfo
info=con:ptp_get_storage_info(id)
info = table
*/
static int chdk_ptp_get_storage_info(lua_State *L) {
	CHDK_CONNECTION_METHOD;
	CHDK_ENSURE_CONNECTED;

	uint32_t sid=luaL_checknumber(L,2);
	PTPStorageInfo storageinfo;
	api_check_ptp_throw(L,ptp_getstorageinfo(params,sid,&storageinfo));
	lua_createtable(L,0,8);
	lua_pushnumber(L,storageinfo.StorageType);
	lua_setfield(L,-2,"StorageType");
	lua_pushnumber(L,storageinfo.FilesystemType);
	lua_setfield(L,-2,"FilesystemType");
	lua_pushnumber(L,storageinfo.AccessCapability);
	lua_setfield(L,-2,"AccessCapability");
	lua_pushnumber(L,0); // TODO ptp_unpack_SI doesn't set
	lua_setfield(L,-2,"MaxCapability");
	lua_pushnumber(L,0); // TODO ptp_unpack_SI doesn't set
	lua_setfield(L,-2,"FreeSpaceInBytes");
	// TODO returns -1 (not implemented)
	lua_pushnumber(L,storageinfo.FreeSpaceInImages);
	lua_setfield(L,-2,"FreeSpaceInImages");
	if(storageinfo.StorageDescription) {
		lua_pushstring(L,storageinfo.StorageDescription);
	} else {
		// TODO may just want to leave nil or empty string
		lua_pushstring(L,"(null)");
	}
	lua_setfield(L,-2,"StorageDescription");
	if(storageinfo.VolumeLabel) {
		lua_pushstring(L,storageinfo.VolumeLabel);
	} else {
		lua_pushstring(L,"(null)");
	}
	lua_setfield(L,-2,"VolumeLabel");
	free(storageinfo.StorageDescription);
	free(storageinfo.VolumeLabel);
	return 1;
}

/*
standard PTP GetObjectHandles
handles=con:ptp_get_object_handles([storageid[,formatcode[,association]]])
handles: Lua array of numbers
*/
static int chdk_ptp_get_object_handles(lua_State *L) {
	CHDK_CONNECTION_METHOD;
	CHDK_ENSURE_CONNECTED;

	uint32_t sid=luaL_optnumber(L,2,0xFFFFFFFF); // all storage
	uint32_t ofc=luaL_optnumber(L,3,0); // 0 = any format
	uint32_t assoc=luaL_optnumber(L,4,0); // 0 = any association

	PTPObjectHandles handles;
	api_check_ptp_throw(L,ptp_getobjecthandles(params,sid,ofc,assoc,&handles));
	lu_pusharray_raw_u32(L,handles.n,handles.Handler);
	free(handles.Handler);
	return 1;
}

/*
standard PTP GetObjectInfo
info=con:ptp_get_object_info(handle)
info = table
*/
static int chdk_ptp_get_object_info(lua_State *L) {
	CHDK_CONNECTION_METHOD;
	CHDK_ENSURE_CONNECTED;

	uint32_t handle=luaL_checknumber(L,2);
	PTPObjectInfo oi;
	api_check_ptp_throw(L,ptp_getobjectinfo(params,handle,&oi));

	lua_createtable(L,0,19);
	lua_pushnumber(L,oi.StorageID);
	lua_setfield(L,-2,"StorageID");
	lua_pushnumber(L,oi.ObjectFormat);
	lua_setfield(L,-2,"ObjectFormat");
	lua_pushnumber(L,oi.ProtectionStatus);
	lua_setfield(L,-2,"ProtectionStatus");
	lua_pushnumber(L,oi.ObjectCompressedSize);
	lua_setfield(L,-2,"ObjectCompressedSize");
	lua_pushnumber(L,oi.ThumbFormat);
	lua_setfield(L,-2,"ThumbFormat");
	lua_pushnumber(L,oi.ThumbCompressedSize);
	lua_setfield(L,-2,"ThumbCompressedSize");
	lua_pushnumber(L,oi.ThumbPixWidth);
	lua_setfield(L,-2,"ThumbPixWidth");
	lua_pushnumber(L,oi.ThumbPixHeight);
	lua_setfield(L,-2,"ThumbPixHeight");
	lua_pushnumber(L,oi.ImagePixWidth);
	lua_setfield(L,-2,"ImagePixWidth");
	lua_pushnumber(L,oi.ImagePixHeight);
	lua_setfield(L,-2,"ImagePixHeight");
	lua_pushnumber(L,oi.ImageBitDepth);
	lua_setfield(L,-2,"ImageBitDepth");
	lua_pushnumber(L,oi.ParentObject);
	lua_setfield(L,-2,"ParentObject");
	lua_pushnumber(L,oi.AssociationType);
	lua_setfield(L,-2,"AssociationType");
	lua_pushnumber(L,oi.AssociationDesc);
	lua_setfield(L,-2,"AssociationDesc");
	lua_pushnumber(L,oi.SequenceNumber);
	lua_setfield(L,-2,"SequenceNumber");

	if(oi.Filename) {
		lua_pushstring(L,oi.Filename);
	} else {
		// TODO may just want to leave nil or empty string
		lua_pushstring(L,"(null)");
	}
	lua_setfield(L,-2,"Filename");

	lua_pushnumber(L,oi.CaptureDate);
	lua_setfield(L,-2,"CaptureDate");
	lua_pushnumber(L,oi.ModificationDate);
	lua_setfield(L,-2,"ModificationDate");
	// not implemented in ptp_unpack_OI
	/*
	if(oi.Keywords) {
		lua_pushstring(L,oi.Keywords);
	} else {
		// TODO may just want to leave nil or empty string
		lua_pushstring(L,"(null)");
	}
	lua_setfield(L,-2,"Keywords");
	*/

	free(oi.Filename);
	//free(oi.Keywords);
	return 1;
}

/*
standard PTP GetObject
lbuf=con:ptp_get_object(handle,size)
handle: previously returned by get_object_handles
size: from get_object_info CompressedSize, becuase we don't get transferred size
*/
static int chdk_ptp_get_object(lua_State *L) {
	CHDK_CONNECTION_METHOD;
	CHDK_ENSURE_CONNECTED;
	uint32_t handle=luaL_checknumber(L,2);
	uint32_t size=luaL_checknumber(L,3);
	char *obj=NULL;
	api_check_ptp_throw(L,ptp_getobject(params,handle,&obj));
	lbuf_create(L,obj,size,LBUF_FL_FREE);
	return 1;
}

/*
standard PTP SendObjectInfo
storageid,parent,handle = con:ptp_send_object_info(info[,storageid[,parenthandle]])
info: table like returned by GetObjectInfo
	-- required
	ObjectFormat
	ObjectCompressedSize
	Filename
*/
static int chdk_ptp_send_object_info(lua_State *L) {
	CHDK_CONNECTION_METHOD;
	CHDK_ENSURE_CONNECTED;

	if(!lua_istable(L,2)) {
		return luaL_error(L,"expected table");
	}

	uint32_t sid=luaL_optnumber(L,3,0); // receiver choose storage
	uint32_t parenthandle=luaL_optnumber(L,4,0); // receiver choose folder (0xffffffff for root)

	PTPObjectInfo oi;
	memset(&oi,0,sizeof(oi));

	// per spec, storage, parent etc IDs in object info are from Initiator POV,
	// i.e. meaningless to receiver. But unclear if they need to be set to something valid looking
	oi.StorageID = lu_table_optnumber(L,2,"StorageID",0);
	oi.ObjectFormat = lu_table_checknumber(L,2,"ObjectFormat"); // required
	oi.ProtectionStatus = lu_table_optnumber(L,2,"ProtectionStatus",0); // no protection
	oi.ObjectCompressedSize = lu_table_checknumber(L,2,"ObjectCompressedSize"); // required
	oi.ThumbFormat = lu_table_optnumber(L,2,"ThumbFormat",0); // canon returns 0 for files without (i.e fi2)
	oi.ThumbCompressedSize = lu_table_optnumber(L,2,"ThumbCompressedSize",0);
	oi.ThumbPixWidth = lu_table_optnumber(L,2,"ThumbPixWidth",0);
	oi.ThumbPixHeight = lu_table_optnumber(L,2,"ThumbPixHeight",0);
	oi.ImagePixWidth = lu_table_optnumber(L,2,"ImagePixWidth",0);
	oi.ImagePixHeight = lu_table_optnumber(L,2,"ImagePixHeight",0);
	oi.ImageBitDepth = lu_table_optnumber(L,2,"ImageBitDepth",0);
	oi.ParentObject = lu_table_optnumber(L,2,"ParentObject",0); // theoretically Initiator
	oi.AssociationType = lu_table_optnumber(L,2,"AssociationType",0); // not association
	oi.AssociationDesc = lu_table_optnumber(L,2,"AssociationDesc",0); // not association
	oi.SequenceNumber = lu_table_optnumber(L,2,"SequenceNumber",0);
	oi.Filename = (char *)lu_table_checkstring(L,2,"Filename"); // required
	// CaptureDate not, ModificationDate not set in ptp_pack_OI

	

	uint32_t handle;
	api_check_ptp_throw(L,ptp_sendobjectinfo(params,&sid,&parenthandle,&handle,&oi));
	lua_pushnumber(L,sid);
	lua_pushnumber(L,parenthandle);
	lua_pushnumber(L,handle);
	return 3;
}
/*
standard PTP SendObject
con:ptp_get_object(object)
object: string or lbuf
*/
static int chdk_ptp_send_object(lua_State *L) {
	CHDK_CONNECTION_METHOD;
	CHDK_ENSURE_CONNECTED;
	const char *obj;
	size_t objlen;
	if(lua_isuserdata(L,2)) {
		lBuf_t *lb=lbuf_getlbuf(L,2);
		obj=lb->bytes;
		objlen=lb->len;
	} else {
		obj=lua_tolstring(L,2,&objlen);
	}
	api_check_ptp_throw(L,ptp_sendobject(params,(char *)obj,objlen));
	return 0;
}


/*
methods for connections
*/
static const luaL_Reg chdkconnection[] = {
  {"connect", chdk_connect},
  {"disconnect", chdk_disconnect},
  {"is_connected", chdk_is_connected},
  {"camera_api_version", chdk_camera_api_version},
  {"execlua", chdk_execlua},
  {"upload", chdk_upload},
  {"download", chdk_download},
  {"getmem", chdk_getmem},
  {"setmem", chdk_setmem},
  {"call_function", chdk_call_function},
  {"script_support", chdk_script_support},
  {"script_status", chdk_script_status},
  {"read_msg", chdk_read_msg},
  {"write_msg", chdk_write_msg},
  {"get_script_id", chdk_get_script_id},
  {"dev_status", chdk_dev_status},
  {"get_ptp_devinfo", chdk_get_ptp_devinfo},
  {"get_con_devinfo", chdk_get_con_devinfo}, // does not need to be connected, returns connection spec at minimum
  {"get_live_data",chdk_get_live_data},
  {"capture_ready", chdk_capture_ready},
  {"capture_get_chunk", chdk_capture_get_chunk},
  {"reset_counters",chdk_reset_counters},
  {"get_counters",chdk_get_counters},
  // standard PTP operations
  // NOTE get_object_handles switches camera to PTP mode (black screen, rec switch no longer possible)
  {"ptp_get_storage_ids",chdk_ptp_get_storage_ids},
  {"ptp_get_storage_info",chdk_ptp_get_storage_info},
  {"ptp_get_object_handles",chdk_ptp_get_object_handles},
  {"ptp_get_object_info",chdk_ptp_get_object_info},
  {"ptp_get_object",chdk_ptp_get_object},
  {"ptp_send_object_info",chdk_ptp_send_object_info},
  {"ptp_send_object",chdk_ptp_send_object},
  {NULL, NULL}
};
#ifdef WIN32
static int win_time_period;
static void init_timing()
{
	TIMECAPS tc;
	if((timeGetDevCaps(&tc,sizeof(tc)) == MMSYSERR_NOERROR) && tc.wPeriodMin) {
		win_time_period = tc.wPeriodMin;
		timeBeginPeriod(win_time_period);
	}
}
static void uninit_timing()
{
	if(win_time_period) {
		timeEndPeriod(win_time_period);
	}
}
#else
#define init_timing() ((void)0)
#define uninit_timing() ((void)0)
#endif

/*
sys.sleep(ms)
NOTE this should not be used from gui code, since it blocks the whole gui
*/
static int syslib_sleep(lua_State *L) {
	unsigned ms=luaL_checknumber(L,1);
	// deal with the differences in sleep, usleep and windows Sleep
	if(ms > 1000) {
		sleep(ms/1000);
		ms=ms%1000;
	}
	usleep(ms*1000);
	return 0;
}

static int syslib_getsleepres(lua_State *L) {
#ifdef WIN32
	if(win_time_period) {
		lua_pushnumber(L,win_time_period);
	} else {
		lua_pushnumber(L,15);
	}
#else
	lua_pushnumber(L,1);
#endif
	return 1;
}

static int syslib_ostype(lua_State *L) {
	lua_pushstring(L,CHDKPTP_OSTYPE);
	return 1;
}

static int syslib_gettimeofday(lua_State *L) {
	struct timeval tv;
	gettimeofday(&tv,NULL);
	lua_pushnumber(L,tv.tv_sec);
	lua_pushnumber(L,tv.tv_usec);
	return 2;
}

/*
 * get tick value suitable for measuring time intervals, as double
 */
static int syslib_gettick(lua_State *L) {
#ifdef CLOCK_MONOTONIC
	struct timespec tp;
	clock_gettime(CLOCK_MONOTONIC,&tp);
	lua_Number r = tp.tv_sec + (lua_Number)tp.tv_nsec/1000000000;
#else
	// fall back to gettimeofday 
	// bad because precision unspecified, may change due to NTP, leap sec, 
	struct timeval tv;
	gettimeofday(&tv,NULL);
	lua_Number r = tv.tv_sec + (lua_Number)tv.tv_usec/1000000;
#endif
	lua_pushnumber(L,r);
	return 1;
}

/*
 * get tick resolution, in nanosec as double, or false if unavilable
 */
static int syslib_gettickres(lua_State *L) {
#ifdef CLOCK_MONOTONIC
	struct timespec res;
	clock_getres(CLOCK_MONOTONIC,&res);
	lua_Number r = res.tv_sec + (lua_Number)res.tv_nsec/1000000000;
	lua_pushnumber(L,r);
#else
	lua_pushboolean(L,0);
#endif
	return 1;
}

#ifdef CHDKPTP_READLINE
static int readlinelib_line(lua_State *L) {
	const char *prompt=luaL_optstring(L,1,NULL);
	char *line=readline(prompt);
	if(line) {
		lua_pushstring(L,line);
		free(line);
	} else {
		lua_pushboolean(L,0);
	}
	return 1;
}
static int readlinelib_add_history(lua_State *L) {
	const char *str=luaL_checkstring(L,1);
	char *buf=malloc(strlen(str)+1);
	strcpy(buf,str);
	add_history(buf);
	return 0;
}
#endif

/*
global copies of argc, argv for lua
*/
static int g_argc;
static char **g_argv;

// default exit value
static int sys_exit_value;
/*
get argv[0]
*/
static int syslib_getcmd(lua_State *L) {
	lua_pushstring(L,g_argv[0]);
	return 1;
}
/*
get command line arguments as an array
args=sys.getargs()
*/
static int syslib_getargs(lua_State *L) {
	int i;
	lua_createtable(L,g_argc-1,0);
// make the command line args available in lua
	for(i = 1; i < g_argc; i++) {
		lua_pushstring(L,g_argv[i]);
		lua_rawseti(L, -2, i); // add to array
	}
	return 1;
}

/*
val=sys.getenv("name")
*/
static int syslib_getenv(lua_State *L) {
	const char *e = getenv(luaL_checkstring(L,1));
	if(e) {
		lua_pushstring(L,e);
		return 1;
	}
	return 0;
}

/*
sys.set_exit_value(number)
*/
static int syslib_set_exit_value(lua_State *L) {
	sys_exit_value = luaL_checknumber(L,1);
	return 0;
}

/*
n=sys.get_exit_value()
*/
static int syslib_get_exit_value(lua_State *L) {
	lua_pushnumber(L,sys_exit_value);
	return 1;
}



static int corevar_set_verbose(lua_State *L) {
	verbose = luaL_checknumber(L,1);
	return 0;
}
static int corevar_get_verbose(lua_State *L) {
	lua_pushnumber(L,verbose);
	return 1;
}

#if LUA_VERSION_NUM >= 503
int maxn (lua_State *L) {
  lua_Number max = 0;
  luaL_checktype(L, 1, LUA_TTABLE);
  lua_pushnil(L);  /* first key */
  while (lua_next(L, 1)) {
    lua_pop(L, 1);  /* remove value */
    if (lua_type(L, -1) == LUA_TNUMBER) {
      lua_Number v = lua_tonumber(L, -1);
      if (v > max) max = v;
    }
  }
  lua_pushnumber(L, max);
  return 1;
}
#endif

static const luaL_Reg lua_syslib[] = {
  {"sleep", syslib_sleep},
  {"getsleepres", syslib_getsleepres},
  {"ostype", syslib_ostype},
  {"gettimeofday", syslib_gettimeofday},
  {"gettick", syslib_gettick},
  {"gettickres", syslib_gettickres},
  {"getcmd",syslib_getcmd},
  {"getargs",syslib_getargs},
  {"getenv",syslib_getenv},
  {"set_exit_value",syslib_set_exit_value},
  {"get_exit_value",syslib_get_exit_value},
#if LUA_VERSION_NUM >= 503
  {"maxn",maxn},
#endif
  {NULL, NULL}
};
#ifdef CHDKPTP_READLINE
static const luaL_Reg lua_readlinelib[] = {
  {"line",readlinelib_line},
  {"add_history",readlinelib_add_history},
  {NULL, NULL}
};
#endif

// getters/setters for variables exposed to lua
static const luaL_Reg lua_corevar[] = {
  {"set_verbose", corevar_set_verbose},
  {"get_verbose", corevar_get_verbose},
  {NULL, NULL}
};

#ifdef CHDKPTP_IUP
static int gui_inited;
#endif

// TODO we should allow loading IUP and CD with require
static int guisys_init(lua_State *L) {
#ifdef CHDKPTP_IUP
	if(!gui_inited) {
		gui_inited = 1;
		iuplua_open(L); 
#ifdef CHDKPTP_CD
		cdlua_open(L); 
		cdluaiup_open(L); 
#ifdef CHDKPTP_CD_PLUS
		cdInitContextPlus();
#endif // CD_PLUS
#endif // CD
	}
	lua_pushboolean(L,1);
	return 1;
#else // IUP
	lua_pushboolean(L,0);
	return 1;
#endif
}

static int uninit_gui_libs(lua_State *L) {
#ifdef CHDKPTP_IUP
	if(gui_inited) {
#ifdef CHDKPTP_CD
		cdlua_close(L);
#endif
		iuplua_close(L); 
//		IupClose(); // ???
		return 1;
	}
#endif
	return 0;
}

static int guisys_caps(lua_State *L) {
	lua_newtable(L);
#ifdef CHDKPTP_IUP
	lua_pushboolean(L,1);
	lua_setfield(L,-2,"IUP");
#endif
#ifdef CHDKPTP_CD
	lua_pushboolean(L,1);
	lua_setfield(L,-2,"CD");
#endif
	lua_pushboolean(L,1);
	lua_setfield(L,-2,"LIVEVIEW");
#ifdef CHDKPTP_CD_PLUS
	lua_pushboolean(L,1);
	lua_setfield(L,-2,"CDPLUS");
#endif
	return 1;
}

static void init_ptp_codes(lua_State *L) {
	lua_newtable(L);
	const PTPErrorDef *p;
	int i;
	for(i=0;(p=ptp_get_error_by_index(i)) != NULL;i++) {
		lua_pushnumber(L,p->error);
		lua_setfield(L,-2,p->id);
	}
	lua_setglobal(L,"ptp");
}

static const luaL_Reg lua_guisyslib[] = {
  {"init", guisys_init},
  {"caps", guisys_caps},
  {NULL, NULL}
};

static const luaL_Reg lua_errlib[] = {
  {"new", errlib_new},
  {"throw", errlib_throw},
  {NULL, NULL}
};


static int chdkptp_registerlibs(lua_State *L) {
	/* set up meta table for error object */
	luaL_newmetatable(L,CHDK_API_ERROR_META);
	lua_pushcfunction(L,api_error_tostring);
	lua_setfield(L,-2,"__tostring");

	luaL_register(L, "errlib", lua_errlib);

	// register error codes
	init_ptp_codes(L);

	/* set up meta table for connection object */
	luaL_newmetatable(L,CHDK_CONNECTION_META);
	lua_pushcfunction(L,chdk_connection_gc);
	lua_setfield(L,-2,"__gc");

	/* register functions that operate on a connection
	 * lua code can use them to implement OO connection interface
	*/
	luaL_register(L, "chdk_connection", chdkconnection);  

	/* register functions that don't require a connection */
	luaL_register(L, "chdk", chdklib);

	luaL_register(L, "sys", lua_syslib);
#ifdef CHDKPTP_READLINE
	luaL_register(L, "readline", lua_readlinelib);
#endif
	luaL_register(L, "corevar", lua_corevar);
	luaL_register(L, "guisys", lua_guisyslib);

	luaopen_liveimg(L);	
	
	// create a table to keep track of connections
	lua_newtable(L);
	// metatable for above
	luaL_newmetatable(L, CHDK_CONNECTION_LIST_META);
	lua_pushstring(L, "kv");  /* mode values: weak keys, weak values */
	lua_setfield(L, -2, "__mode");  /* metatable.__mode */
	lua_setmetatable(L,-2);
	lua_setfield(L,LUA_REGISTRYINDEX,CHDK_CONNECTION_LIST);
	return 1;
}

static int exec_lua_string(lua_State *L, const char *luacode) {
	int r;
	r=luaL_loadstring(L,luacode);
	if(r) {
		fprintf(stderr,"loadstring failed %d\n",r);
		fprintf(stderr,"error %s\n",lua_tostring(L, -1));
	} else {
		r=lua_pcall(L,0,LUA_MULTRET, 0);
		if(r) {
			fprintf(stderr,"pcall failed %d\n",r);
			fprintf(stderr,"error %s\n",lua_tostring(L, -1));
			// TODO should get stack trace
		}
	}
	return r==0;
}


/* main program  */
int main(int argc, char ** argv)
{
	g_argc = argc;
	g_argv = argv;
	/* register signal handlers */
//	signal(SIGINT, ptpcam_siginthandler);
	init_timing();
	usb_init();
	lua_State *L = luaL_newstate();
	luaL_openlibs(L);
	luaopen_lfs(L);
	luaopen_lbuf(L);
	luaopen_rawimg(L);	
	chdkptp_registerlibs(L);
	int r=exec_lua_string(L,"require('main')");
	uninit_gui_libs(L);
	lua_close(L);
	// gc takes care of any open connections

#ifdef CHDKPTP_PTPIP
	sockutil_cleanup();
#endif
	uninit_timing();
	// running main failed, return 1 if sys_exit_value would be success
	if(!r && !sys_exit_value) {
		return 1;
	}
	return sys_exit_value;
}
