/*
 * Copyright (C) 2022 <reyalp (at) gmail dot com>
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
 *  with chdkptp. If not, see <http://www.gnu.org/licenses/>.
 */
/*
* this file defines lists mapping PTP constants to strings and related functions
*/
#include "config.h"
#include "ptp.h"

/* c&p from ptp.c */
#ifdef ENABLE_NLS
#  include <libintl.h>
#  undef _
#  define _(String) dgettext (PACKAGE, String)
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

/* PTP standard return codes */
#define PTP_RC_DEF(name,desc) {PTP_RC_##name,#name,desc}
// internal error codes
#define PTP_ERROR_DEF(name,desc) {PTP_##name,#name,desc}
// extension error codes, text description is just name
#define PTP_RC_EXT_DEF(ext_id,name) {PTP_RC_##ext_id##_##name,#name,#name}

static PTPRcDef ptp_rcodes_STD[] = {
	PTP_RC_DEF(Undefined, 		N_("Undefined Error")),
	PTP_RC_DEF(OK, 			N_("OK!")),
	PTP_RC_DEF(GeneralError, 		N_("General Error")),
	PTP_RC_DEF(SessionNotOpen, 	N_("Session Not Open")),
	PTP_RC_DEF(InvalidTransactionID, 	N_("Invalid Transaction ID")),
	PTP_RC_DEF(OperationNotSupported, 	N_("Operation Not Supported")),
	PTP_RC_DEF(ParameterNotSupported, 	N_("Parameter Not Supported")),
	PTP_RC_DEF(IncompleteTransfer, 	N_("Incomplete Transfer")),
	PTP_RC_DEF(InvalidStorageId, 	N_("Invalid Storage ID")),
	PTP_RC_DEF(InvalidObjectHandle, 	N_("Invalid Object Handle")),
	PTP_RC_DEF(DevicePropNotSupported, N_("Device Prop Not Supported")),
	PTP_RC_DEF(InvalidObjectFormatCode, N_("Invalid Object Format Code")),
	PTP_RC_DEF(StoreFull, 		N_("Store Full")),
	PTP_RC_DEF(ObjectWriteProtected, 	N_("Object Write Protected")),
	PTP_RC_DEF(StoreReadOnly, 		N_("Store Read Only")),
	PTP_RC_DEF(AccessDenied,		N_("Access Denied")),
	PTP_RC_DEF(NoThumbnailPresent, 	N_("No Thumbnail Present")),
	PTP_RC_DEF(SelfTestFailed, 	N_("Self Test Failed")),
	PTP_RC_DEF(PartialDeletion, 	N_("Partial Deletion")),
	PTP_RC_DEF(StoreNotAvailable, 	N_("Store Not Available")),
	PTP_RC_DEF(SpecificationByFormatUnsupported, N_("Specification By Format Unsupported")),
	PTP_RC_DEF(NoValidObjectInfo, 	N_("No Valid Object Info")),
	PTP_RC_DEF(InvalidCodeFormat, 	N_("Invalid Code Format")),
	PTP_RC_DEF(UnknownVendorCode, 	N_("Unknown Vendor Code")),
	PTP_RC_DEF(CaptureAlreadyTerminated, N_("Capture Already Terminated")),
	PTP_RC_DEF(DeviceBusy, 		N_("Device Busy")),
	PTP_RC_DEF(InvalidParentObject, 	N_("Invalid Parent Object")),
	PTP_RC_DEF(InvalidDevicePropFormat, N_("Invalid Device Prop Format")),
	PTP_RC_DEF(InvalidDevicePropValue, N_("Invalid Device Prop Value")),
	PTP_RC_DEF(InvalidParameter, 	N_("Invalid Parameter")),
	PTP_RC_DEF(SessionAlreadyOpened, 	N_("Session Already Opened")),
	PTP_RC_DEF(TransactionCanceled, 	N_("Transaction Canceled")),
	PTP_RC_DEF(SpecificationOfDestinationUnsupported, N_("Specification Of Destination Unsupported")),
	/* PTP v1.1 */
	PTP_RC_DEF(InvalidEnumHandle,N_("Invalid Enum Handle")),
	PTP_RC_DEF(NoStreamEnabled,N_("No Stream Enabled")),
	PTP_RC_DEF(InvalidDataSet,N_("InvalidDataSet")),
	/* internal codes */
	PTP_ERROR_DEF(ERROR_IO,		  N_("I/O error")),
	PTP_ERROR_DEF(ERROR_BADPARAM,	  N_("bad parameter")),
	PTP_ERROR_DEF(ERROR_DATA_EXPECTED, N_("Protocol error: data expected")),
	PTP_ERROR_DEF(ERROR_RESP_EXPECTED, N_("Protocol error: response expected")),
	PTP_ERROR_DEF(ERROR_NOT_CONNECTED, N_("not connected")),
	{0,NULL,NULL},
};

static PTPRcDef ptp_rcodes_EK[] = {
/* Eastman Kodak extension Response Codes */
	PTP_RC_EXT_DEF(EK,FilenameRequired),
	PTP_RC_EXT_DEF(EK,FilenameConflicts),
	PTP_RC_EXT_DEF(EK,FilenameInvalid),
	{0,NULL,NULL},
};

static PTPRcDef ptp_rcodes_CANON[] = {
/* Canon specific response codes */
	PTP_RC_EXT_DEF(CANON,UNKNOWN_COMMAND),
	PTP_RC_EXT_DEF(CANON,OPERATION_REFUSED),
	PTP_RC_EXT_DEF(CANON,LENS_COVER),
	PTP_RC_EXT_DEF(CANON,BATTERY_LOW),
	PTP_RC_EXT_DEF(CANON,NOT_READY),
	// PTP_RC_EXT_DEF(CANON_A009),
	PTP_RC_EXT_DEF(CANON,EOS_UnknownCommand),
	PTP_RC_EXT_DEF(CANON,EOS_OperationRefused),
	PTP_RC_EXT_DEF(CANON,EOS_LensCoverClosed),
	PTP_RC_EXT_DEF(CANON,EOS_LowBattery),
	PTP_RC_EXT_DEF(CANON,EOS_ObjectNotReady),
	PTP_RC_EXT_DEF(CANON,EOS_CannotMakeObject),
	PTP_RC_EXT_DEF(CANON,EOS_MemoryStatusNotReady),

	{0,NULL,NULL},
};

static PTPRcDef ptp_rcodes_NIKON[] = {
/* Nikon specific response codes */
	PTP_RC_EXT_DEF(NIKON,HardwareError),
	PTP_RC_EXT_DEF(NIKON,OutOfFocus),
	PTP_RC_EXT_DEF(NIKON,ChangeCameraModeFailed),
	PTP_RC_EXT_DEF(NIKON,InvalidStatus),
	PTP_RC_EXT_DEF(NIKON,SetPropertyNotSupported),
	PTP_RC_EXT_DEF(NIKON,WbResetError),
	PTP_RC_EXT_DEF(NIKON,DustReferenceError),
	PTP_RC_EXT_DEF(NIKON,ShutterSpeedBulb),
	PTP_RC_EXT_DEF(NIKON,MirrorUpSequence),
	PTP_RC_EXT_DEF(NIKON,CameraModeNotAdjustFNumber),
	PTP_RC_EXT_DEF(NIKON,NotLiveView),
	PTP_RC_EXT_DEF(NIKON,MfDriveStepEnd),
	PTP_RC_EXT_DEF(NIKON,MfDriveStepInsufficiency),
	PTP_RC_EXT_DEF(NIKON,NoFullHDPresent),
	PTP_RC_EXT_DEF(NIKON,StoreError),
	PTP_RC_EXT_DEF(NIKON,StoreUnformatted),
	PTP_RC_EXT_DEF(NIKON,AdvancedTransferCancel),
	PTP_RC_EXT_DEF(NIKON,Bulb_Release_Busy),
	PTP_RC_EXT_DEF(NIKON,Silent_Release_Busy),
	PTP_RC_EXT_DEF(NIKON,MovieFrame_Release_Busy),
	PTP_RC_EXT_DEF(NIKON,Shutter_Speed_Time),
	PTP_RC_EXT_DEF(NIKON,Waiting_2ndRelease),
	PTP_RC_EXT_DEF(NIKON,MirrorUpCapture_Already_Start),
	PTP_RC_EXT_DEF(NIKON,Invalid_SBAttribute_Value),

	{0,NULL,NULL},
};

// none known
/*
static PTPRcDef ptp_rcodes_CASIO[] = {
	{0,NULL,NULL},
};
*/

// none known
/*
static PTPRcDef ptp_rcodes_SONY[] = {
	{0,NULL,NULL},
};
*/
static PTPRcDef ptp_rcodes_MTP[] = {
/* Microsoft/MTP specific codes */
	PTP_RC_EXT_DEF(MTP,Undefined),
	PTP_RC_EXT_DEF(MTP,Invalid_ObjectPropCode),
	PTP_RC_EXT_DEF(MTP,Invalid_ObjectProp_Format),
	PTP_RC_EXT_DEF(MTP,Invalid_ObjectProp_Value),
	PTP_RC_EXT_DEF(MTP,Invalid_ObjectReference),
	PTP_RC_EXT_DEF(MTP,Invalid_Dataset),
	PTP_RC_EXT_DEF(MTP,Specification_By_Group_Unsupported),
	PTP_RC_EXT_DEF(MTP,Specification_By_Depth_Unsupported),
	PTP_RC_EXT_DEF(MTP,Object_Too_Large),
	PTP_RC_EXT_DEF(MTP,ObjectProp_Not_Supported),

	{0,NULL,NULL},
};

static PTPRcDef ptp_rcodes_MTP_EXT[] = {
/* Microsoft Advanced Audio/Video Transfer response codes
(microsoft.com/AAVT 1.0) */
	PTP_RC_EXT_DEF(MTP,Invalid_Media_Session_ID),
	PTP_RC_EXT_DEF(MTP,Media_Session_Limit_Reached),
	PTP_RC_EXT_DEF(MTP,No_More_Data),
/* WiFi Provisioning MTP Extension Error Codes (microsoft.com/WPDWCN: 1.0) */
	PTP_RC_EXT_DEF(MTP,Invalid_WFC_Syntax),
	PTP_RC_EXT_DEF(MTP,WFC_Version_Not_Supported),

	{0,NULL,NULL},
};

// none known
/*
static PTPRcDef ptp_rcodes_OLYMPUS[] = {
	{0,NULL,NULL},
};
*/

// none known
/*
static PTPRcDef ptp_rcodes_ANDROID[] = {
	{0,NULL,NULL},
}
*/


// none known
/*
static PTPRcDef ptp_rcodes_LEICA[] = {
	{0,NULL,NULL},
};
*/

// none known
/*
static PTPRcDef ptp_rcodes_PARROT[] = {
	{0,NULL,NULL},
};
*/

// none known
/*
static PTPRcDef ptp_rcodes_PANASONIC[] = {
	{0,NULL,NULL},
};
*/

// none known
/*
static PTPRcDef ptp_rcodes_FUJI[] = {
	{0,NULL,NULL},
};
*/

// none known
/*
static PTPRcDef ptp_rcodes_SIGMA[] = {
	{0,NULL,NULL},
};
*/

const PTPRcDef *ptp_get_error_by_code(uint16_t error) {
	int i;
	for (i=0; ptp_rcodes_STD[i].error; i++) {
		if (ptp_rcodes_STD[i].error == error){
			return &ptp_rcodes_STD[i];
		}
	}
	return &ptp_rcodes_STD[0];
}

/* report PTP errors - TODO only handles standard codes */
const char *ptp_strerror(uint16_t error) {
	return ptp_get_error_by_code(error)->txt;
}

/* tables of event code, name, 0 terminated */
#define PTP_EC_DEF(name) {PTP_EC_##name,#name}
#define PTP_EC_EXT_DEF(ext_id,name) {PTP_EC_##ext_id##_##name,#name}
static PTPCodeDef ptp_evcodes_STD[] = {
/* PTP Event Codes */
	PTP_EC_DEF(Undefined),
	PTP_EC_DEF(CancelTransaction),
	PTP_EC_DEF(ObjectAdded),
	PTP_EC_DEF(ObjectRemoved),
	PTP_EC_DEF(StoreAdded),
	PTP_EC_DEF(StoreRemoved),
	PTP_EC_DEF(DevicePropChanged),
	PTP_EC_DEF(ObjectInfoChanged),
	PTP_EC_DEF(DeviceInfoChanged),
	PTP_EC_DEF(RequestObjectTransfer),
	PTP_EC_DEF(StoreFull),
	PTP_EC_DEF(DeviceReset),
	PTP_EC_DEF(StorageInfoChanged),
	PTP_EC_DEF(CaptureComplete),
	PTP_EC_DEF(UnreportedStatus),

	{0,NULL},
};
// none known
/*
static PTPCodeDef ptp_evcodes_EK[] = {
	{0,NULL},
};
*/

static PTPCodeDef ptp_evcodes_CANON[] = {
/* Canon extension Event Codes */
	PTP_EC_EXT_DEF(CANON,ExtendedErrorcode),
	PTP_EC_EXT_DEF(CANON,ObjectInfoChanged),
	PTP_EC_EXT_DEF(CANON,RequestObjectTransfer),
	PTP_EC_EXT_DEF(CANON,ShutterButtonPressed0),
	PTP_EC_EXT_DEF(CANON,CameraModeChanged),
	PTP_EC_EXT_DEF(CANON,ShutterButtonPressed1),

	PTP_EC_EXT_DEF(CANON,StartDirectTransfer),
	PTP_EC_EXT_DEF(CANON,StopDirectTransfer),

	PTP_EC_EXT_DEF(CANON,TranscodeProgress),

/* Canon EOS events */
	PTP_EC_EXT_DEF(CANON,EOS_RequestGetEvent),
	PTP_EC_EXT_DEF(CANON,EOS_RequestCancelTransferMA),
	PTP_EC_EXT_DEF(CANON,EOS_ObjectAddedEx),
	PTP_EC_EXT_DEF(CANON,EOS_ObjectRemoved),
	PTP_EC_EXT_DEF(CANON,EOS_RequestGetObjectInfoEx),
	PTP_EC_EXT_DEF(CANON,EOS_StorageStatusChanged),
	PTP_EC_EXT_DEF(CANON,EOS_StorageInfoChanged),
	PTP_EC_EXT_DEF(CANON,EOS_RequestObjectTransfer),
	PTP_EC_EXT_DEF(CANON,EOS_ObjectInfoChangedEx),
	PTP_EC_EXT_DEF(CANON,EOS_ObjectContentChanged),
	PTP_EC_EXT_DEF(CANON,EOS_PropValueChanged),
	PTP_EC_EXT_DEF(CANON,EOS_AvailListChanged),
	PTP_EC_EXT_DEF(CANON,EOS_CameraStatusChanged),
	PTP_EC_EXT_DEF(CANON,EOS_WillSoonShutdown),
	PTP_EC_EXT_DEF(CANON,EOS_ShutdownTimerUpdated),
	PTP_EC_EXT_DEF(CANON,EOS_RequestCancelTransfer),
	PTP_EC_EXT_DEF(CANON,EOS_RequestObjectTransferDT),
	PTP_EC_EXT_DEF(CANON,EOS_RequestCancelTransferDT),
	PTP_EC_EXT_DEF(CANON,EOS_StoreAdded),
	PTP_EC_EXT_DEF(CANON,EOS_StoreRemoved),
	PTP_EC_EXT_DEF(CANON,EOS_BulbExposureTime),
	PTP_EC_EXT_DEF(CANON,EOS_RecordingTime),
	PTP_EC_EXT_DEF(CANON,EOS_InnerDevelopParam),
	PTP_EC_EXT_DEF(CANON,EOS_RequestObjectTransferDevelop),
	PTP_EC_EXT_DEF(CANON,EOS_GPSLogOutputProgress),
	PTP_EC_EXT_DEF(CANON,EOS_GPSLogOutputComplete),
	PTP_EC_EXT_DEF(CANON,EOS_TouchTrans),
	PTP_EC_EXT_DEF(CANON,EOS_RequestObjectTransferExInfo),
	PTP_EC_EXT_DEF(CANON,EOS_PowerZoomInfoChanged),
	PTP_EC_EXT_DEF(CANON,EOS_RequestPushMode),
	PTP_EC_EXT_DEF(CANON,EOS_RequestObjectTransferTS),
	PTP_EC_EXT_DEF(CANON,EOS_AfResult),
	PTP_EC_EXT_DEF(CANON,EOS_CTGInfoCheckComplete),
	PTP_EC_EXT_DEF(CANON,EOS_OLCInfoChanged),
	PTP_EC_EXT_DEF(CANON,EOS_ObjectAddedEx64),
	PTP_EC_EXT_DEF(CANON,EOS_ObjectInfoChangedEx64),
	PTP_EC_EXT_DEF(CANON,EOS_RequestObjectTransfer64),
	PTP_EC_EXT_DEF(CANON,EOS_RequestObjectTransferDT64),
	PTP_EC_EXT_DEF(CANON,EOS_RequestObjectTransferFTP64),
	PTP_EC_EXT_DEF(CANON,EOS_RequestObjectTransferInfoEx64),
	PTP_EC_EXT_DEF(CANON,EOS_RequestObjectTransferMA64),
	PTP_EC_EXT_DEF(CANON,EOS_ImportError),
	PTP_EC_EXT_DEF(CANON,EOS_BlePairing),
	PTP_EC_EXT_DEF(CANON,EOS_RequestAutoSendImages),
	PTP_EC_EXT_DEF(CANON,EOS_RequestTranscodedBlockTransfer),
	PTP_EC_EXT_DEF(CANON,EOS_RequestCAssistImage),
	PTP_EC_EXT_DEF(CANON,EOS_RequestObjectTransferFTP),

	{0,NULL},
};

static PTPCodeDef ptp_evcodes_NIKON[] = {
/* Nikon extension Event Codes */
	PTP_EC_EXT_DEF(NIKON,ObjectAddedInSDRAM),
	PTP_EC_EXT_DEF(NIKON,CaptureCompleteRecInSdram),
/* Gets 1 parameter, objectid pointing to DPOF object */
	PTP_EC_EXT_DEF(NIKON,AdvancedTransfer),
	PTP_EC_EXT_DEF(NIKON,PreviewImageAdded),
	PTP_EC_EXT_DEF(NIKON,MovieRecordInterrupted),
	PTP_EC_EXT_DEF(NIKON,1stCaptureComplete),
	PTP_EC_EXT_DEF(NIKON,MirrorUpCancelComplete),
	PTP_EC_EXT_DEF(NIKON,MovieRecordComplete),
	PTP_EC_EXT_DEF(NIKON,MovieRecordStarted),
	PTP_EC_EXT_DEF(NIKON,PictureControlAdjustChanged),
	PTP_EC_EXT_DEF(NIKON,LiveViewStateChanged),
	PTP_EC_EXT_DEF(NIKON,ManualSettingsLensDataChanged),
	PTP_EC_EXT_DEF(NIKON,ActiveSelectionInterrupted),
	PTP_EC_EXT_DEF(NIKON,SBAdded),
	PTP_EC_EXT_DEF(NIKON,SBRemoved),
	PTP_EC_EXT_DEF(NIKON,SBAttrChanged),
	PTP_EC_EXT_DEF(NIKON,SBGroupAttrChanged),

	{0,NULL},
};

// none known
/*
static PTPCodeDef ptp_evcodes_CASIO[] = {
	{0,NULL},
};
*/

static PTPCodeDef ptp_evcodes_SONY[] = {
/* Sony */
	PTP_EC_EXT_DEF(SONY,ObjectAdded),
	PTP_EC_EXT_DEF(SONY,ObjectRemoved),
	PTP_EC_EXT_DEF(SONY,PropertyChanged),

	{0,NULL},
};

static PTPCodeDef ptp_evcodes_MTP[] = {
/* MTP Event codes */
	PTP_EC_EXT_DEF(MTP,ObjectPropChanged),
	PTP_EC_EXT_DEF(MTP,ObjectPropDescChanged),
	PTP_EC_EXT_DEF(MTP,ObjectReferencesChanged),

	{0,NULL},
};

// none known
/*
static PTPCodeDef ptp_evcodes_MTP_EXT[] = {
	{0,NULL},
};
*/

static PTPCodeDef ptp_evcodes_OLYMPUS[] = {
/* Olympus E series, PTP style in the 2018+ range (e1mark2 etc.) */
/* From olympus capture tool */
	PTP_EC_EXT_DEF(OLYMPUS,CreateRecView),
	PTP_EC_EXT_DEF(OLYMPUS,CreateRecView_New),
	PTP_EC_EXT_DEF(OLYMPUS,ObjectAdded),
	PTP_EC_EXT_DEF(OLYMPUS,ObjectAdded_New),
	PTP_EC_EXT_DEF(OLYMPUS,AF_Frame),
	PTP_EC_EXT_DEF(OLYMPUS,AF_Frame_New),
	PTP_EC_EXT_DEF(OLYMPUS,DirectStoreImage),
	PTP_EC_EXT_DEF(OLYMPUS,DirectStoreImage_New),
	PTP_EC_EXT_DEF(OLYMPUS,ComplateCameraControlOff),
	PTP_EC_EXT_DEF(OLYMPUS,ComplateCameraControlOff_New),
	PTP_EC_EXT_DEF(OLYMPUS,AF_Frame_Over_Info),
	PTP_EC_EXT_DEF(OLYMPUS,AF_Frame_Over_Info_New),
	PTP_EC_EXT_DEF(OLYMPUS,DevicePropChanged),
	PTP_EC_EXT_DEF(OLYMPUS,DevicePropChanged_New),
	PTP_EC_EXT_DEF(OLYMPUS,ImageTransferModeFinish),
	PTP_EC_EXT_DEF(OLYMPUS,ImageTransferModeFinish_New),
	PTP_EC_EXT_DEF(OLYMPUS,ImageRecordFinish),
	PTP_EC_EXT_DEF(OLYMPUS,ImageRecordFinish_New),
	PTP_EC_EXT_DEF(OLYMPUS,SlotStatusChange),
	PTP_EC_EXT_DEF(OLYMPUS,SlotStatusChange_New),
	PTP_EC_EXT_DEF(OLYMPUS,PrioritizeRecord),
	PTP_EC_EXT_DEF(OLYMPUS,PrioritizeRecord_New),
	PTP_EC_EXT_DEF(OLYMPUS,FailCombiningAfterShooting),
	PTP_EC_EXT_DEF(OLYMPUS,FailCombiningAfterShooting_New),
	PTP_EC_EXT_DEF(OLYMPUS,NotifyAFTargetFrame),
	PTP_EC_EXT_DEF(OLYMPUS,NotifyAFTargetFrame_New),
	PTP_EC_EXT_DEF(OLYMPUS,RawEditParamChanged),
	PTP_EC_EXT_DEF(OLYMPUS,OlyNotifyCreateDrawEdit),

/* Used by the XML based E series driver */
	// non-unique, not handled here
	/*
	PTP_EC_EXT_DEF(OLYMPUS,PropertyChanged),
	PTP_EC_EXT_DEF(OLYMPUS,CaptureComplete),
	*/

	{0,NULL},
};

// none known
/*
static PTPCodeDef ptp_evcodes_ANDROID[] = {
	{0,NULL},
};
*/

// none known
/*
static PTPCodeDef ptp_evcodes_LEICA[] = {
	{0,NULL},
};
*/

static PTPCodeDef ptp_evcodes_PARROT[] = {
	PTP_EC_EXT_DEF(PARROT,Status),
	PTP_EC_EXT_DEF(PARROT,MagnetoCalibrationStatus),

	{0,NULL},
};

static PTPCodeDef ptp_evcodes_PANASONIC[] = {
	PTP_EC_EXT_DEF(PANASONIC,ObjectAdded),
	PTP_EC_EXT_DEF(PANASONIC,ObjectAddedSDRAM),

	{0,NULL},
};

static PTPCodeDef ptp_evcodes_FUJI[] = {
	PTP_EC_EXT_DEF(FUJI,PreviewAvailable),
	PTP_EC_EXT_DEF(FUJI,ObjectAdded),

	{0,NULL},
};

// none known
/*
static PTPCodeDef ptp_evcodes_SIGMA[] = {
	{0,NULL},
};
*/

/* tables of object format code, name, 0 terminated */
#define PTP_OFC_DEF(name) {PTP_OFC_##name,#name}
#define PTP_OFC_EXT_DEF(ext_id,name) {PTP_OFC_##ext_id##_##name,#name}

static PTPCodeDef ptp_ofcodes_STD[] = {
/* ancillary formats */
	PTP_OFC_DEF(Undefined),
	PTP_OFC_DEF(Association),
	PTP_OFC_DEF(Script),
	PTP_OFC_DEF(Executable),
	PTP_OFC_DEF(Text),
	PTP_OFC_DEF(HTML),
	PTP_OFC_DEF(DPOF),
	PTP_OFC_DEF(AIFF),
	PTP_OFC_DEF(WAV),
	PTP_OFC_DEF(MP3),
	PTP_OFC_DEF(AVI),
	PTP_OFC_DEF(MPEG),
	PTP_OFC_DEF(ASF),
	PTP_OFC_DEF(QT),
/* image formats */
	PTP_OFC_DEF(EXIF_JPEG),
	PTP_OFC_DEF(TIFF_EP),
	PTP_OFC_DEF(FlashPix),
	PTP_OFC_DEF(BMP),
	PTP_OFC_DEF(CIFF),
	PTP_OFC_DEF(Undefined_0x3806),
	PTP_OFC_DEF(GIF),
	PTP_OFC_DEF(JFIF),
	PTP_OFC_DEF(PCD),
	PTP_OFC_DEF(PICT),
	PTP_OFC_DEF(PNG),
	PTP_OFC_DEF(Undefined_0x380C),
	PTP_OFC_DEF(TIFF),
	PTP_OFC_DEF(TIFF_IT),
	PTP_OFC_DEF(JP2),
	PTP_OFC_DEF(JPX),
/* ptp v1.1 has only DNG new */
	PTP_OFC_DEF(DNG),

	{0,NULL},
};

static PTPCodeDef ptp_ofcodes_EK[] = {
/* Eastman Kodak extension ancillary format */
	PTP_OFC_EXT_DEF(EK,M3U),
	{0,NULL},
};

static PTPCodeDef ptp_ofcodes_CANON[] = {
/* Canon extension */
	PTP_OFC_EXT_DEF(CANON,CRW),
	PTP_OFC_EXT_DEF(CANON,CRW3),
	PTP_OFC_EXT_DEF(CANON,MOV),
	PTP_OFC_EXT_DEF(CANON,MOV2),
	PTP_OFC_EXT_DEF(CANON,CR3),
/* CHDK specific raw mode */
	PTP_OFC_EXT_DEF(CANON,CHDK_CRW),
	PTP_OFC_EXT_DEF(CANON,FI2),

	{0,NULL},
};

// none known
/*
static PTPCodeDef ptp_ofcodes_NIKON[] = {
	{0,NULL},
};
*/

// none known
/*
static PTPCodeDef ptp_ofcodes_CASIO[] = {
	{0,NULL},
};
*/

static PTPCodeDef ptp_ofcodes_SONY[] = {
/* Sony */
	PTP_OFC_EXT_DEF(SONY,RAW),
	{0,NULL},
};

static PTPCodeDef ptp_ofcodes_MTP[] = {
/* MTP extensions */
	PTP_OFC_EXT_DEF(MTP,MediaCard),
	PTP_OFC_EXT_DEF(MTP,MediaCardGroup),
	PTP_OFC_EXT_DEF(MTP,Encounter),
	PTP_OFC_EXT_DEF(MTP,EncounterBox),
	PTP_OFC_EXT_DEF(MTP,M4A),
	PTP_OFC_EXT_DEF(MTP,ZUNEUNDEFINED),
	PTP_OFC_EXT_DEF(MTP,Firmware),
	PTP_OFC_EXT_DEF(MTP,WindowsImageFormat),
	PTP_OFC_EXT_DEF(MTP,UndefinedAudio),
	PTP_OFC_EXT_DEF(MTP,WMA),
	PTP_OFC_EXT_DEF(MTP,OGG),
	PTP_OFC_EXT_DEF(MTP,AAC),
	PTP_OFC_EXT_DEF(MTP,AudibleCodec),
	PTP_OFC_EXT_DEF(MTP,FLAC),
	PTP_OFC_EXT_DEF(MTP,SamsungPlaylist),
	PTP_OFC_EXT_DEF(MTP,UndefinedVideo),
	PTP_OFC_EXT_DEF(MTP,WMV),
	PTP_OFC_EXT_DEF(MTP,MP4),
	PTP_OFC_EXT_DEF(MTP,MP2),
	PTP_OFC_EXT_DEF(MTP,3GP),
	PTP_OFC_EXT_DEF(MTP,UndefinedCollection),
	PTP_OFC_EXT_DEF(MTP,AbstractMultimediaAlbum),
	PTP_OFC_EXT_DEF(MTP,AbstractImageAlbum),
	PTP_OFC_EXT_DEF(MTP,AbstractAudioAlbum),
	PTP_OFC_EXT_DEF(MTP,AbstractVideoAlbum),
	PTP_OFC_EXT_DEF(MTP,AbstractAudioVideoPlaylist),
	PTP_OFC_EXT_DEF(MTP,AbstractContactGroup),
	PTP_OFC_EXT_DEF(MTP,AbstractMessageFolder),
	PTP_OFC_EXT_DEF(MTP,AbstractChapteredProduction),
	PTP_OFC_EXT_DEF(MTP,AbstractAudioPlaylist),
	PTP_OFC_EXT_DEF(MTP,AbstractVideoPlaylist),
	PTP_OFC_EXT_DEF(MTP,AbstractMediacast),
	PTP_OFC_EXT_DEF(MTP,WPLPlaylist),
	PTP_OFC_EXT_DEF(MTP,M3UPlaylist),
	PTP_OFC_EXT_DEF(MTP,MPLPlaylist),
	PTP_OFC_EXT_DEF(MTP,ASXPlaylist),
	PTP_OFC_EXT_DEF(MTP,PLSPlaylist),
	PTP_OFC_EXT_DEF(MTP,UndefinedDocument),
	PTP_OFC_EXT_DEF(MTP,AbstractDocument),
	PTP_OFC_EXT_DEF(MTP,XMLDocument),
	PTP_OFC_EXT_DEF(MTP,MSWordDocument),
	PTP_OFC_EXT_DEF(MTP,MHTCompiledHTMLDocument),
	PTP_OFC_EXT_DEF(MTP,MSExcelSpreadsheetXLS),
	PTP_OFC_EXT_DEF(MTP,MSPowerpointPresentationPPT),
	PTP_OFC_EXT_DEF(MTP,UndefinedMessage),
	PTP_OFC_EXT_DEF(MTP,AbstractMessage),
	PTP_OFC_EXT_DEF(MTP,UndefinedContact),
	PTP_OFC_EXT_DEF(MTP,AbstractContact),
	PTP_OFC_EXT_DEF(MTP,vCard2),
	PTP_OFC_EXT_DEF(MTP,vCard3),
	PTP_OFC_EXT_DEF(MTP,UndefinedCalendarItem),
	PTP_OFC_EXT_DEF(MTP,AbstractCalendarItem),
	PTP_OFC_EXT_DEF(MTP,vCalendar1),
	PTP_OFC_EXT_DEF(MTP,vCalendar2),
	PTP_OFC_EXT_DEF(MTP,UndefinedWindowsExecutable),
	PTP_OFC_EXT_DEF(MTP,MediaCast),
	PTP_OFC_EXT_DEF(MTP,Section),
	{0,NULL},
};

// none known (or included in above, unclear)
/*
static PTPCodeDef ptp_ofcodes_MTP_EXT[] = {
	{0,NULL},
};
*/

// none known
/*
static PTPCodeDef ptp_ofcodes_OLYMPUS[] = {
	{0,NULL},
};
*/

// none known
/*
static PTPCodeDef ptp_ofcodes_ANDROID[] = {
	{0,NULL},
};
*/

// none known
/*
static PTPCodeDef ptp_ofcodes_LEICA[] = {
	{0,NULL},
};
*/

// none known
/*
static PTPCodeDef ptp_ofcodes_PARROT[] = {
	{0,NULL},
};
*/

// none known
/*
static PTPCodeDef ptp_ofcodes_PANASONIC[] = {
	{0,NULL},
};
*/

// none known
/*
static PTPCodeDef ptp_ofcodes_FUJI[] = {
	{0,NULL},
};
*/

// none known
/*
static PTPCodeDef ptp_ofcodes_SIGMA[] = {
	{0,NULL},
};
*/

/* tables of prop code, name, 0 terminated */
#define PTP_DPC_DEF(name) {PTP_DPC_##name,#name}
#define PTP_DPC_EXT_DEF(ext_id,name) {PTP_DPC_##ext_id##_##name,#name}
static PTPCodeDef ptp_dpcodes_STD[] = {
/* PTP v1.0 property codes */
	PTP_DPC_DEF(Undefined),
	PTP_DPC_DEF(BatteryLevel),
	PTP_DPC_DEF(FunctionalMode),
	PTP_DPC_DEF(ImageSize),
	PTP_DPC_DEF(CompressionSetting),
	PTP_DPC_DEF(WhiteBalance),
	PTP_DPC_DEF(RGBGain),
	PTP_DPC_DEF(FNumber),
	PTP_DPC_DEF(FocalLength),
	PTP_DPC_DEF(FocusDistance),
	PTP_DPC_DEF(FocusMode),
	PTP_DPC_DEF(ExposureMeteringMode),
	PTP_DPC_DEF(FlashMode),
	PTP_DPC_DEF(ExposureTime),
	PTP_DPC_DEF(ExposureProgramMode),
	PTP_DPC_DEF(ExposureIndex),
	PTP_DPC_DEF(ExposureBiasCompensation),
	PTP_DPC_DEF(DateTime),
	PTP_DPC_DEF(CaptureDelay),
	PTP_DPC_DEF(StillCaptureMode),
	PTP_DPC_DEF(Contrast),
	PTP_DPC_DEF(Sharpness),
	PTP_DPC_DEF(DigitalZoom),
	PTP_DPC_DEF(EffectMode),
	PTP_DPC_DEF(BurstNumber),
	PTP_DPC_DEF(BurstInterval),
	PTP_DPC_DEF(TimelapseNumber),
	PTP_DPC_DEF(TimelapseInterval),
	PTP_DPC_DEF(FocusMeteringMode),
	PTP_DPC_DEF(UploadURL),
	PTP_DPC_DEF(Artist),
	PTP_DPC_DEF(CopyrightInfo),
/* PTP v1.1 property codes */
	PTP_DPC_DEF(SupportedStreams),
	PTP_DPC_DEF(EnabledStreams),
	PTP_DPC_DEF(VideoFormat),
	PTP_DPC_DEF(VideoResolution),
	PTP_DPC_DEF(VideoQuality),
	PTP_DPC_DEF(VideoFrameRate),
	PTP_DPC_DEF(VideoContrast),
	PTP_DPC_DEF(VideoBrightness),
	PTP_DPC_DEF(AudioFormat),
	PTP_DPC_DEF(AudioBitrate),
	PTP_DPC_DEF(AudioSamplingRate),
	PTP_DPC_DEF(AudioBitPerSample),
	PTP_DPC_DEF(AudioVolume),

	{0,NULL},
};

static PTPCodeDef ptp_dpcodes_EK[] = {
/* Eastman Kodak extension device property codes */
	PTP_DPC_EXT_DEF(EK,ColorTemperature),
	PTP_DPC_EXT_DEF(EK,DateTimeStampFormat),
	PTP_DPC_EXT_DEF(EK,BeepMode),
	PTP_DPC_EXT_DEF(EK,VideoOut),
	PTP_DPC_EXT_DEF(EK,PowerSaving),
	PTP_DPC_EXT_DEF(EK,UI_Language),

	{0,NULL},
};

static PTPCodeDef ptp_dpcodes_CANON[] = {
/* Canon extension device property codes */
	PTP_DPC_EXT_DEF(CANON,BeepMode),
	PTP_DPC_EXT_DEF(CANON,BatteryKind),
	PTP_DPC_EXT_DEF(CANON,BatteryStatus),
	PTP_DPC_EXT_DEF(CANON,UILockType),
	PTP_DPC_EXT_DEF(CANON,CameraMode),
	PTP_DPC_EXT_DEF(CANON,ImageQuality),
	PTP_DPC_EXT_DEF(CANON,FullViewFileFormat),
	PTP_DPC_EXT_DEF(CANON,ImageSize),
	PTP_DPC_EXT_DEF(CANON,SelfTime),
	PTP_DPC_EXT_DEF(CANON,FlashMode),
	PTP_DPC_EXT_DEF(CANON,Beep),
	PTP_DPC_EXT_DEF(CANON,ShootingMode),
	PTP_DPC_EXT_DEF(CANON,ImageMode),
	PTP_DPC_EXT_DEF(CANON,DriveMode),
	PTP_DPC_EXT_DEF(CANON,EZoom),
	PTP_DPC_EXT_DEF(CANON,MeteringMode),
	PTP_DPC_EXT_DEF(CANON,AFDistance),
	PTP_DPC_EXT_DEF(CANON,FocusingPoint),
	PTP_DPC_EXT_DEF(CANON,WhiteBalance),
	PTP_DPC_EXT_DEF(CANON,SlowShutterSetting),
	PTP_DPC_EXT_DEF(CANON,AFMode),
	PTP_DPC_EXT_DEF(CANON,ImageStabilization),
	PTP_DPC_EXT_DEF(CANON,Contrast),
	PTP_DPC_EXT_DEF(CANON,ColorGain),
	PTP_DPC_EXT_DEF(CANON,Sharpness),
	PTP_DPC_EXT_DEF(CANON,Sensitivity),
	PTP_DPC_EXT_DEF(CANON,ParameterSet),
	PTP_DPC_EXT_DEF(CANON,ISOSpeed),
	PTP_DPC_EXT_DEF(CANON,Aperture),
	PTP_DPC_EXT_DEF(CANON,ShutterSpeed),
	PTP_DPC_EXT_DEF(CANON,ExpCompensation),
	PTP_DPC_EXT_DEF(CANON,FlashCompensation),
	PTP_DPC_EXT_DEF(CANON,AEBExposureCompensation),
	PTP_DPC_EXT_DEF(CANON,AvOpen),
	PTP_DPC_EXT_DEF(CANON,AvMax),
	PTP_DPC_EXT_DEF(CANON,FocalLength),
	PTP_DPC_EXT_DEF(CANON,FocalLengthTele),
	PTP_DPC_EXT_DEF(CANON,FocalLengthWide),
	PTP_DPC_EXT_DEF(CANON,FocalLengthDenominator),
	PTP_DPC_EXT_DEF(CANON,CaptureTransferMode),
	PTP_DPC_EXT_DEF(CANON,Zoom),
	PTP_DPC_EXT_DEF(CANON,NamePrefix),
	PTP_DPC_EXT_DEF(CANON,SizeQualityMode),
	PTP_DPC_EXT_DEF(CANON,SupportedThumbSize),
	PTP_DPC_EXT_DEF(CANON,SizeOfOutputDataFromCamera),
	PTP_DPC_EXT_DEF(CANON,SizeOfInputDataToCamera),
	PTP_DPC_EXT_DEF(CANON,RemoteAPIVersion),
	PTP_DPC_EXT_DEF(CANON,FirmwareVersion),
	PTP_DPC_EXT_DEF(CANON,CameraModel),
	PTP_DPC_EXT_DEF(CANON,CameraOwner),
	PTP_DPC_EXT_DEF(CANON,UnixTime),
	PTP_DPC_EXT_DEF(CANON,CameraBodyID),
	PTP_DPC_EXT_DEF(CANON,CameraOutput),
	PTP_DPC_EXT_DEF(CANON,DispAv),
	PTP_DPC_EXT_DEF(CANON,AvOpenApex),
	PTP_DPC_EXT_DEF(CANON,DZoomMagnification),
	PTP_DPC_EXT_DEF(CANON,MlSpotPos),
	PTP_DPC_EXT_DEF(CANON,DispAvMax),
	PTP_DPC_EXT_DEF(CANON,AvMaxApex),
	PTP_DPC_EXT_DEF(CANON,EZoomStartPosition),
	PTP_DPC_EXT_DEF(CANON,FocalLengthOfTele),
	PTP_DPC_EXT_DEF(CANON,EZoomSizeOfTele),
	PTP_DPC_EXT_DEF(CANON,PhotoEffect),
	PTP_DPC_EXT_DEF(CANON,AssistLight),
	PTP_DPC_EXT_DEF(CANON,FlashQuantityCount),
	PTP_DPC_EXT_DEF(CANON,RotationAngle),
	PTP_DPC_EXT_DEF(CANON,RotationScene),
	PTP_DPC_EXT_DEF(CANON,EventEmulateMode),
	PTP_DPC_EXT_DEF(CANON,DPOFVersion),
	PTP_DPC_EXT_DEF(CANON,TypeOfSupportedSlideShow),
	PTP_DPC_EXT_DEF(CANON,AverageFilesizes),
	PTP_DPC_EXT_DEF(CANON,ModelID),

	PTP_DPC_EXT_DEF(CANON,EOS_PowerZoomPosition),
	PTP_DPC_EXT_DEF(CANON,EOS_StrobeSettingSimple),
	PTP_DPC_EXT_DEF(CANON,EOS_ConnectTrigger),
	PTP_DPC_EXT_DEF(CANON,EOS_ChangeCameraMode),

/* From EOS 400D trace. */
	PTP_DPC_EXT_DEF(CANON,EOS_Aperture),
	PTP_DPC_EXT_DEF(CANON,EOS_ShutterSpeed),
	PTP_DPC_EXT_DEF(CANON,EOS_ISOSpeed),
	PTP_DPC_EXT_DEF(CANON,EOS_ExpCompensation),
	PTP_DPC_EXT_DEF(CANON,EOS_AutoExposureMode),
	PTP_DPC_EXT_DEF(CANON,EOS_DriveMode),
	PTP_DPC_EXT_DEF(CANON,EOS_MeteringMode),
	PTP_DPC_EXT_DEF(CANON,EOS_FocusMode),
	PTP_DPC_EXT_DEF(CANON,EOS_WhiteBalance),
	PTP_DPC_EXT_DEF(CANON,EOS_ColorTemperature),
	PTP_DPC_EXT_DEF(CANON,EOS_WhiteBalanceAdjustA),
	PTP_DPC_EXT_DEF(CANON,EOS_WhiteBalanceAdjustB),
	PTP_DPC_EXT_DEF(CANON,EOS_WhiteBalanceXA),
	PTP_DPC_EXT_DEF(CANON,EOS_WhiteBalanceXB),
	PTP_DPC_EXT_DEF(CANON,EOS_ColorSpace),
	PTP_DPC_EXT_DEF(CANON,EOS_PictureStyle),
	PTP_DPC_EXT_DEF(CANON,EOS_BatteryPower),
	PTP_DPC_EXT_DEF(CANON,EOS_BatterySelect),
	PTP_DPC_EXT_DEF(CANON,EOS_CameraTime),
	PTP_DPC_EXT_DEF(CANON,EOS_AutoPowerOff),
	PTP_DPC_EXT_DEF(CANON,EOS_Owner),
	PTP_DPC_EXT_DEF(CANON,EOS_ModelID),
	PTP_DPC_EXT_DEF(CANON,EOS_PTPExtensionVersion),
	PTP_DPC_EXT_DEF(CANON,EOS_DPOFVersion),
	PTP_DPC_EXT_DEF(CANON,EOS_AvailableShots),
	PTP_DPC_EXT_DEF(CANON,EOS_CaptureDestination),
	PTP_DPC_EXT_DEF(CANON,EOS_BracketMode),
	PTP_DPC_EXT_DEF(CANON,EOS_CurrentStorage),
	PTP_DPC_EXT_DEF(CANON,EOS_CurrentFolder),
	PTP_DPC_EXT_DEF(CANON,EOS_ImageFormat),
	PTP_DPC_EXT_DEF(CANON,EOS_ImageFormatCF),
	PTP_DPC_EXT_DEF(CANON,EOS_ImageFormatSD),
	PTP_DPC_EXT_DEF(CANON,EOS_ImageFormatExtHD),
	PTP_DPC_EXT_DEF(CANON,EOS_RefocusState),
	PTP_DPC_EXT_DEF(CANON,EOS_CameraNickname),
	PTP_DPC_EXT_DEF(CANON,EOS_StroboSettingExpCompositionControl),
	PTP_DPC_EXT_DEF(CANON,EOS_ConnectStatus),
	PTP_DPC_EXT_DEF(CANON,EOS_LensBarrelStatus),
	PTP_DPC_EXT_DEF(CANON,EOS_SilentShutterSetting),
	PTP_DPC_EXT_DEF(CANON,EOS_LV_AF_EyeDetect),
	PTP_DPC_EXT_DEF(CANON,EOS_AutoTransMobile),
	PTP_DPC_EXT_DEF(CANON,EOS_URLSupportFormat),
	PTP_DPC_EXT_DEF(CANON,EOS_SpecialAcc),
	PTP_DPC_EXT_DEF(CANON,EOS_CompressionS),
	PTP_DPC_EXT_DEF(CANON,EOS_CompressionM1),
	PTP_DPC_EXT_DEF(CANON,EOS_CompressionM2),
	PTP_DPC_EXT_DEF(CANON,EOS_CompressionL),
	PTP_DPC_EXT_DEF(CANON,EOS_IntervalShootSetting),
	PTP_DPC_EXT_DEF(CANON,EOS_IntervalShootState),
	PTP_DPC_EXT_DEF(CANON,EOS_PushMode),
	PTP_DPC_EXT_DEF(CANON,EOS_LvCFilterKind),
	PTP_DPC_EXT_DEF(CANON,EOS_AEModeDial),
	PTP_DPC_EXT_DEF(CANON,EOS_AEModeCustom),
	PTP_DPC_EXT_DEF(CANON,EOS_MirrorUpSetting),
	PTP_DPC_EXT_DEF(CANON,EOS_HighlightTonePriority),
	PTP_DPC_EXT_DEF(CANON,EOS_AFSelectFocusArea),
	PTP_DPC_EXT_DEF(CANON,EOS_HDRSetting),
	PTP_DPC_EXT_DEF(CANON,EOS_TimeShootSetting),
	PTP_DPC_EXT_DEF(CANON,EOS_NFCApplicationInfo),
	PTP_DPC_EXT_DEF(CANON,EOS_PCWhiteBalance1),
	PTP_DPC_EXT_DEF(CANON,EOS_PCWhiteBalance2),
	PTP_DPC_EXT_DEF(CANON,EOS_PCWhiteBalance3),
	PTP_DPC_EXT_DEF(CANON,EOS_PCWhiteBalance4),
	PTP_DPC_EXT_DEF(CANON,EOS_PCWhiteBalance5),
	PTP_DPC_EXT_DEF(CANON,EOS_MWhiteBalance),
	PTP_DPC_EXT_DEF(CANON,EOS_MWhiteBalanceEx),
	PTP_DPC_EXT_DEF(CANON,EOS_PowerZoomSpeed),
	PTP_DPC_EXT_DEF(CANON,EOS_NetworkServerRegion),
	PTP_DPC_EXT_DEF(CANON,EOS_GPSLogCtrl),
	PTP_DPC_EXT_DEF(CANON,EOS_GPSLogListNum),
	PTP_DPC_EXT_DEF(CANON,EOS_UnknownPropD14D),
	PTP_DPC_EXT_DEF(CANON,EOS_PictureStyleStandard),
	PTP_DPC_EXT_DEF(CANON,EOS_PictureStylePortrait),
	PTP_DPC_EXT_DEF(CANON,EOS_PictureStyleLandscape),
	PTP_DPC_EXT_DEF(CANON,EOS_PictureStyleNeutral),
	PTP_DPC_EXT_DEF(CANON,EOS_PictureStyleFaithful),
	PTP_DPC_EXT_DEF(CANON,EOS_PictureStyleBlackWhite),
	PTP_DPC_EXT_DEF(CANON,EOS_PictureStyleAuto),
	PTP_DPC_EXT_DEF(CANON,EOS_PictureStyleExStandard),
	PTP_DPC_EXT_DEF(CANON,EOS_PictureStyleExPortrait),
	PTP_DPC_EXT_DEF(CANON,EOS_PictureStyleExLandscape),
	PTP_DPC_EXT_DEF(CANON,EOS_PictureStyleExNeutral),
	PTP_DPC_EXT_DEF(CANON,EOS_PictureStyleExFaithful),
	PTP_DPC_EXT_DEF(CANON,EOS_PictureStyleExBlackWhite),
	PTP_DPC_EXT_DEF(CANON,EOS_PictureStyleExAuto),
	PTP_DPC_EXT_DEF(CANON,EOS_PictureStyleExFineDetail),
	PTP_DPC_EXT_DEF(CANON,EOS_PictureStyleUserSet1),
	PTP_DPC_EXT_DEF(CANON,EOS_PictureStyleUserSet2),
	PTP_DPC_EXT_DEF(CANON,EOS_PictureStyleUserSet3),
	PTP_DPC_EXT_DEF(CANON,EOS_PictureStyleExUserSet1),
	PTP_DPC_EXT_DEF(CANON,EOS_PictureStyleExUserSet2),
	PTP_DPC_EXT_DEF(CANON,EOS_PictureStyleExUserSet3),
	PTP_DPC_EXT_DEF(CANON,EOS_MovieAVModeFine),
	PTP_DPC_EXT_DEF(CANON,EOS_ShutterReleaseCounter),
	PTP_DPC_EXT_DEF(CANON,EOS_AvailableImageSize),
	PTP_DPC_EXT_DEF(CANON,EOS_ErrorHistory),
	PTP_DPC_EXT_DEF(CANON,EOS_LensExchangeHistory),
	PTP_DPC_EXT_DEF(CANON,EOS_StroboExchangeHistory),
	PTP_DPC_EXT_DEF(CANON,EOS_PictureStyleParam1),
	PTP_DPC_EXT_DEF(CANON,EOS_PictureStyleParam2),
	PTP_DPC_EXT_DEF(CANON,EOS_PictureStyleParam3),
	PTP_DPC_EXT_DEF(CANON,EOS_MovieRecordVolumeLine),
	PTP_DPC_EXT_DEF(CANON,EOS_NetworkCommunicationMode),
	PTP_DPC_EXT_DEF(CANON,EOS_CanonLogGamma),
	PTP_DPC_EXT_DEF(CANON,EOS_SmartphoneShowImageConfig),
	PTP_DPC_EXT_DEF(CANON,EOS_HighISOSettingNoiseReduction),
	PTP_DPC_EXT_DEF(CANON,EOS_MovieServoAF),
	PTP_DPC_EXT_DEF(CANON,EOS_ContinuousAFValid),
	PTP_DPC_EXT_DEF(CANON,EOS_Attenuator),
	PTP_DPC_EXT_DEF(CANON,EOS_UTCTime),
	PTP_DPC_EXT_DEF(CANON,EOS_Timezone),
	PTP_DPC_EXT_DEF(CANON,EOS_Summertime),
	PTP_DPC_EXT_DEF(CANON,EOS_FlavorLUTParams),
	PTP_DPC_EXT_DEF(CANON,EOS_CustomFunc1),
	PTP_DPC_EXT_DEF(CANON,EOS_CustomFunc2),
	PTP_DPC_EXT_DEF(CANON,EOS_CustomFunc3),
	PTP_DPC_EXT_DEF(CANON,EOS_CustomFunc4),
	PTP_DPC_EXT_DEF(CANON,EOS_CustomFunc5),
	PTP_DPC_EXT_DEF(CANON,EOS_CustomFunc6),
	PTP_DPC_EXT_DEF(CANON,EOS_CustomFunc7),
	PTP_DPC_EXT_DEF(CANON,EOS_CustomFunc8),
	PTP_DPC_EXT_DEF(CANON,EOS_CustomFunc9),
	PTP_DPC_EXT_DEF(CANON,EOS_CustomFunc10),
	PTP_DPC_EXT_DEF(CANON,EOS_CustomFunc11),
	PTP_DPC_EXT_DEF(CANON,EOS_CustomFunc12),
	PTP_DPC_EXT_DEF(CANON,EOS_CustomFunc13),
	PTP_DPC_EXT_DEF(CANON,EOS_CustomFunc14),
	PTP_DPC_EXT_DEF(CANON,EOS_CustomFunc15),
	PTP_DPC_EXT_DEF(CANON,EOS_CustomFunc16),
	PTP_DPC_EXT_DEF(CANON,EOS_CustomFunc17),
	PTP_DPC_EXT_DEF(CANON,EOS_CustomFunc18),
	PTP_DPC_EXT_DEF(CANON,EOS_CustomFunc19),
	PTP_DPC_EXT_DEF(CANON,EOS_CustomFunc19),
	PTP_DPC_EXT_DEF(CANON,EOS_InnerDevelop),
	PTP_DPC_EXT_DEF(CANON,EOS_MultiAspect),
	PTP_DPC_EXT_DEF(CANON,EOS_MovieSoundRecord),
	PTP_DPC_EXT_DEF(CANON,EOS_MovieRecordVolume),
	PTP_DPC_EXT_DEF(CANON,EOS_WindCut),
	PTP_DPC_EXT_DEF(CANON,EOS_ExtenderType),
	PTP_DPC_EXT_DEF(CANON,EOS_OLCInfoVersion),
	PTP_DPC_EXT_DEF(CANON,EOS_UnknownPropD19A),
	PTP_DPC_EXT_DEF(CANON,EOS_UnknownPropD19C),
	PTP_DPC_EXT_DEF(CANON,EOS_UnknownPropD19D),
	PTP_DPC_EXT_DEF(CANON,EOS_GPSDeviceActive),
	PTP_DPC_EXT_DEF(CANON,EOS_CustomFuncEx),
	PTP_DPC_EXT_DEF(CANON,EOS_MyMenu),
	PTP_DPC_EXT_DEF(CANON,EOS_MyMenuList),
	PTP_DPC_EXT_DEF(CANON,EOS_WftStatus),
	PTP_DPC_EXT_DEF(CANON,EOS_WftInputTransmission),
	PTP_DPC_EXT_DEF(CANON,EOS_HDDirectoryStructure),
	PTP_DPC_EXT_DEF(CANON,EOS_BatteryInfo),
	PTP_DPC_EXT_DEF(CANON,EOS_AdapterInfo),
	PTP_DPC_EXT_DEF(CANON,EOS_LensStatus),
	PTP_DPC_EXT_DEF(CANON,EOS_QuickReviewTime),
	PTP_DPC_EXT_DEF(CANON,EOS_CardExtension),
	PTP_DPC_EXT_DEF(CANON,EOS_TempStatus),
	PTP_DPC_EXT_DEF(CANON,EOS_ShutterCounter),
	PTP_DPC_EXT_DEF(CANON,EOS_SpecialOption),
	PTP_DPC_EXT_DEF(CANON,EOS_PhotoStudioMode),
	PTP_DPC_EXT_DEF(CANON,EOS_SerialNumber),
	PTP_DPC_EXT_DEF(CANON,EOS_EVFOutputDevice),
	PTP_DPC_EXT_DEF(CANON,EOS_EVFMode),
	PTP_DPC_EXT_DEF(CANON,EOS_DepthOfFieldPreview),
	PTP_DPC_EXT_DEF(CANON,EOS_EVFSharpness),
	PTP_DPC_EXT_DEF(CANON,EOS_EVFWBMode),
	PTP_DPC_EXT_DEF(CANON,EOS_EVFClickWBCoeffs),
	PTP_DPC_EXT_DEF(CANON,EOS_EVFColorTemp),
	PTP_DPC_EXT_DEF(CANON,EOS_ExposureSimMode),
	PTP_DPC_EXT_DEF(CANON,EOS_EVFRecordStatus),
	PTP_DPC_EXT_DEF(CANON,EOS_LvAfSystem),
	PTP_DPC_EXT_DEF(CANON,EOS_MovSize),
	PTP_DPC_EXT_DEF(CANON,EOS_LvViewTypeSelect),
	PTP_DPC_EXT_DEF(CANON,EOS_MirrorDownStatus),
	PTP_DPC_EXT_DEF(CANON,EOS_MovieParam),
	PTP_DPC_EXT_DEF(CANON,EOS_MirrorLockupState),
	PTP_DPC_EXT_DEF(CANON,EOS_FlashChargingState),
	PTP_DPC_EXT_DEF(CANON,EOS_AloMode),
	PTP_DPC_EXT_DEF(CANON,EOS_FixedMovie),
	PTP_DPC_EXT_DEF(CANON,EOS_OneShotRawOn),
	PTP_DPC_EXT_DEF(CANON,EOS_ErrorForDisplay),
	PTP_DPC_EXT_DEF(CANON,EOS_AEModeMovie),
	PTP_DPC_EXT_DEF(CANON,EOS_BuiltinStroboMode),
	PTP_DPC_EXT_DEF(CANON,EOS_StroboDispState),
	PTP_DPC_EXT_DEF(CANON,EOS_StroboETTL2Metering),
	PTP_DPC_EXT_DEF(CANON,EOS_ContinousAFMode),
	PTP_DPC_EXT_DEF(CANON,EOS_MovieParam2),
	PTP_DPC_EXT_DEF(CANON,EOS_StroboSettingExpComposition),
	PTP_DPC_EXT_DEF(CANON,EOS_MovieParam3),
	PTP_DPC_EXT_DEF(CANON,EOS_MovieParam4),
	PTP_DPC_EXT_DEF(CANON,EOS_LVMedicalRotate),
	PTP_DPC_EXT_DEF(CANON,EOS_Artist),
	PTP_DPC_EXT_DEF(CANON,EOS_Copyright),
	PTP_DPC_EXT_DEF(CANON,EOS_BracketValue),
	PTP_DPC_EXT_DEF(CANON,EOS_FocusInfoEx),
	PTP_DPC_EXT_DEF(CANON,EOS_DepthOfField),
	PTP_DPC_EXT_DEF(CANON,EOS_Brightness),
	PTP_DPC_EXT_DEF(CANON,EOS_LensAdjustParams),
	PTP_DPC_EXT_DEF(CANON,EOS_EFComp),
	PTP_DPC_EXT_DEF(CANON,EOS_LensName),
	PTP_DPC_EXT_DEF(CANON,EOS_AEB),
	PTP_DPC_EXT_DEF(CANON,EOS_StroboSetting),
	PTP_DPC_EXT_DEF(CANON,EOS_StroboWirelessSetting),
	PTP_DPC_EXT_DEF(CANON,EOS_StroboFiring),
	PTP_DPC_EXT_DEF(CANON,EOS_LensID),
	PTP_DPC_EXT_DEF(CANON,EOS_LCDBrightness),
	PTP_DPC_EXT_DEF(CANON,EOS_CADarkBright),

	PTP_DPC_EXT_DEF(CANON,EOS_CAssistPreset),
	PTP_DPC_EXT_DEF(CANON,EOS_CAssistBrightness),
	PTP_DPC_EXT_DEF(CANON,EOS_CAssistContrast),
	PTP_DPC_EXT_DEF(CANON,EOS_CAssistSaturation),
	PTP_DPC_EXT_DEF(CANON,EOS_CAssistColorBA),
	PTP_DPC_EXT_DEF(CANON,EOS_CAssistColorMG),
	PTP_DPC_EXT_DEF(CANON,EOS_CAssistMonochrome),
	PTP_DPC_EXT_DEF(CANON,EOS_FocusShiftSetting),
	PTP_DPC_EXT_DEF(CANON,EOS_MovieSelfTimer),
	PTP_DPC_EXT_DEF(CANON,EOS_Clarity),
	PTP_DPC_EXT_DEF(CANON,EOS_2GHDRSetting),
	PTP_DPC_EXT_DEF(CANON,EOS_MovieParam5),
	PTP_DPC_EXT_DEF(CANON,EOS_HDRViewAssistModeRec),
	PTP_DPC_EXT_DEF(CANON,EOS_PropFinderAFFrame),
	PTP_DPC_EXT_DEF(CANON,EOS_VariableMovieRecSetting),
	PTP_DPC_EXT_DEF(CANON,EOS_PropAutoRotate),
	PTP_DPC_EXT_DEF(CANON,EOS_MFPeakingSetting),
	PTP_DPC_EXT_DEF(CANON,EOS_MovieSpatialOversampling),
	PTP_DPC_EXT_DEF(CANON,EOS_MovieCropMode),
	PTP_DPC_EXT_DEF(CANON,EOS_ShutterType),
	PTP_DPC_EXT_DEF(CANON,EOS_WFTBatteryPower),
	PTP_DPC_EXT_DEF(CANON,EOS_BatteryInfoEx),

	{0,NULL},
};

static PTPCodeDef ptp_dpcodes_NIKON[] = {
/* Nikon extension device property codes */
	PTP_DPC_EXT_DEF(NIKON,ShootingBank),
	PTP_DPC_EXT_DEF(NIKON,ShootingBankNameA),
	PTP_DPC_EXT_DEF(NIKON,ShootingBankNameB),
	PTP_DPC_EXT_DEF(NIKON,ShootingBankNameC),
	PTP_DPC_EXT_DEF(NIKON,ShootingBankNameD),
	PTP_DPC_EXT_DEF(NIKON,ResetBank0),
	PTP_DPC_EXT_DEF(NIKON,RawCompression),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalanceAutoBias),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalanceTungstenBias),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalanceFluorescentBias),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalanceDaylightBias),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalanceFlashBias),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalanceCloudyBias),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalanceShadeBias),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalanceColorTemperature),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalancePresetNo),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalancePresetName0),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalancePresetName1),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalancePresetName2),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalancePresetName3),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalancePresetName4),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalancePresetVal0),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalancePresetVal1),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalancePresetVal2),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalancePresetVal3),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalancePresetVal4),
	PTP_DPC_EXT_DEF(NIKON,ImageSharpening),
	PTP_DPC_EXT_DEF(NIKON,ToneCompensation),
	PTP_DPC_EXT_DEF(NIKON,ColorModel),
	PTP_DPC_EXT_DEF(NIKON,HueAdjustment),
	PTP_DPC_EXT_DEF(NIKON,NonCPULensDataFocalLength),
	PTP_DPC_EXT_DEF(NIKON,FmmManualSetting),
	PTP_DPC_EXT_DEF(NIKON,NonCPULensDataMaximumAperture),
	PTP_DPC_EXT_DEF(NIKON,F0ManualSetting),
	PTP_DPC_EXT_DEF(NIKON,ShootingMode),
	PTP_DPC_EXT_DEF(NIKON,CaptureAreaCrop),
	PTP_DPC_EXT_DEF(NIKON,JPEG_Compression_Policy),
	PTP_DPC_EXT_DEF(NIKON,ColorSpace),
	PTP_DPC_EXT_DEF(NIKON,AutoDXCrop),
	PTP_DPC_EXT_DEF(NIKON,FlickerReduction),
	PTP_DPC_EXT_DEF(NIKON,RemoteMode),
	PTP_DPC_EXT_DEF(NIKON,VideoMode),
	PTP_DPC_EXT_DEF(NIKON,EffectMode),
	PTP_DPC_EXT_DEF(NIKON,1_Mode),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalancePresetName5),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalancePresetName6),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalanceTunePreset5),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalanceTunePreset6),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalancePresetProtect5),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalancePresetProtect6),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalancePresetValue5),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalancePresetValue6),
	PTP_DPC_EXT_DEF(NIKON,CSMMenuBankSelect),
	PTP_DPC_EXT_DEF(NIKON,MenuBankNameA),
	PTP_DPC_EXT_DEF(NIKON,MenuBankNameB),
	PTP_DPC_EXT_DEF(NIKON,MenuBankNameC),
	PTP_DPC_EXT_DEF(NIKON,MenuBankNameD),
	PTP_DPC_EXT_DEF(NIKON,ResetBank),
	PTP_DPC_EXT_DEF(NIKON,AFStillLockOnAcross),
	PTP_DPC_EXT_DEF(NIKON,AFStillLockOnMove),
	PTP_DPC_EXT_DEF(NIKON,A1AFCModePriority),
	PTP_DPC_EXT_DEF(NIKON,A2AFSModePriority),
	PTP_DPC_EXT_DEF(NIKON,A3GroupDynamicAF),
	PTP_DPC_EXT_DEF(NIKON,A4AFActivation),
	PTP_DPC_EXT_DEF(NIKON,FocusAreaIllumManualFocus),
	PTP_DPC_EXT_DEF(NIKON,FocusAreaIllumContinuous),
	PTP_DPC_EXT_DEF(NIKON,FocusAreaIllumWhenSelected),
	PTP_DPC_EXT_DEF(NIKON,FocusAreaWrap),
	PTP_DPC_EXT_DEF(NIKON,FocusAreaSelect),
	PTP_DPC_EXT_DEF(NIKON,VerticalAFON),
	PTP_DPC_EXT_DEF(NIKON,AFLockOn),
	PTP_DPC_EXT_DEF(NIKON,FocusAreaZone),
	PTP_DPC_EXT_DEF(NIKON,EnableCopyright),
	PTP_DPC_EXT_DEF(NIKON,ISOAuto),
	PTP_DPC_EXT_DEF(NIKON,EVISOStep),
	PTP_DPC_EXT_DEF(NIKON,EVStep),
	PTP_DPC_EXT_DEF(NIKON,EVStepExposureComp),
	PTP_DPC_EXT_DEF(NIKON,ExposureCompensation),
	PTP_DPC_EXT_DEF(NIKON,CenterWeightArea),
	PTP_DPC_EXT_DEF(NIKON,ExposureBaseMatrix),
	PTP_DPC_EXT_DEF(NIKON,ExposureBaseCenter),
	PTP_DPC_EXT_DEF(NIKON,ExposureBaseSpot),
	PTP_DPC_EXT_DEF(NIKON,LiveViewAFArea),
	PTP_DPC_EXT_DEF(NIKON,AELockMode),
	PTP_DPC_EXT_DEF(NIKON,AELAFLMode),
	PTP_DPC_EXT_DEF(NIKON,LiveViewAFFocus),
	PTP_DPC_EXT_DEF(NIKON,MeterOff),
	PTP_DPC_EXT_DEF(NIKON,SelfTimer),
	PTP_DPC_EXT_DEF(NIKON,MonitorOff),
	PTP_DPC_EXT_DEF(NIKON,ImgConfTime),
	PTP_DPC_EXT_DEF(NIKON,AutoOffTimers),
	PTP_DPC_EXT_DEF(NIKON,AngleLevel),
	PTP_DPC_EXT_DEF(NIKON,D1ShootingSpeed),
	PTP_DPC_EXT_DEF(NIKON,D2MaximumShots),
	PTP_DPC_EXT_DEF(NIKON,ExposureDelayMode),
	PTP_DPC_EXT_DEF(NIKON,LongExposureNoiseReduction),
	PTP_DPC_EXT_DEF(NIKON,FileNumberSequence),
	PTP_DPC_EXT_DEF(NIKON,ControlPanelFinderRearControl),
	PTP_DPC_EXT_DEF(NIKON,ControlPanelFinderViewfinder),
	PTP_DPC_EXT_DEF(NIKON,D7Illumination),
	PTP_DPC_EXT_DEF(NIKON,NrHighISO),
	PTP_DPC_EXT_DEF(NIKON,SHSET_CH_GUID_DISP),
	PTP_DPC_EXT_DEF(NIKON,ArtistName),
	PTP_DPC_EXT_DEF(NIKON,CopyrightInfo),
	PTP_DPC_EXT_DEF(NIKON,FlashSyncSpeed),
	PTP_DPC_EXT_DEF(NIKON,FlashShutterSpeed),
	PTP_DPC_EXT_DEF(NIKON,E3AAFlashMode),
	PTP_DPC_EXT_DEF(NIKON,E4ModelingFlash),
	PTP_DPC_EXT_DEF(NIKON,BracketSet),
	PTP_DPC_EXT_DEF(NIKON,E6ManualModeBracketing),
	PTP_DPC_EXT_DEF(NIKON,BracketOrder),
	PTP_DPC_EXT_DEF(NIKON,E8AutoBracketSelection),
	PTP_DPC_EXT_DEF(NIKON,BracketingSet),
	PTP_DPC_EXT_DEF(NIKON,AngleLevelPitching),
	PTP_DPC_EXT_DEF(NIKON,AngleLevelYawing),
	PTP_DPC_EXT_DEF(NIKON,ExtendShootingMenu),
	PTP_DPC_EXT_DEF(NIKON,F1CenterButtonShootingMode),
	PTP_DPC_EXT_DEF(NIKON,CenterButtonPlaybackMode),
	PTP_DPC_EXT_DEF(NIKON,F2Multiselector),
	PTP_DPC_EXT_DEF(NIKON,F3PhotoInfoPlayback),
	PTP_DPC_EXT_DEF(NIKON,F4AssignFuncButton),
	PTP_DPC_EXT_DEF(NIKON,F5CustomizeCommDials),
	PTP_DPC_EXT_DEF(NIKON,ReverseCommandDial),
	PTP_DPC_EXT_DEF(NIKON,ApertureSetting),
	PTP_DPC_EXT_DEF(NIKON,MenusAndPlayback),
	PTP_DPC_EXT_DEF(NIKON,F6ButtonsAndDials),
	PTP_DPC_EXT_DEF(NIKON,NoCFCard),
	PTP_DPC_EXT_DEF(NIKON,CenterButtonZoomRatio),
	PTP_DPC_EXT_DEF(NIKON,FunctionButton2),
	PTP_DPC_EXT_DEF(NIKON,AFAreaPoint),
	PTP_DPC_EXT_DEF(NIKON,NormalAFOn),
	PTP_DPC_EXT_DEF(NIKON,CleanImageSensor),
	PTP_DPC_EXT_DEF(NIKON,ImageCommentString),
	PTP_DPC_EXT_DEF(NIKON,ImageCommentEnable),
	PTP_DPC_EXT_DEF(NIKON,ImageRotation),
	PTP_DPC_EXT_DEF(NIKON,ManualSetLensNo),
	PTP_DPC_EXT_DEF(NIKON,RetractableLensWarning),
	PTP_DPC_EXT_DEF(NIKON,FaceDetection),
	PTP_DPC_EXT_DEF(NIKON,3DTrackingCaptureArea),
	PTP_DPC_EXT_DEF(NIKON,MatrixMetering),
	PTP_DPC_EXT_DEF(NIKON,MovScreenSize),
	PTP_DPC_EXT_DEF(NIKON,MovVoice),
	PTP_DPC_EXT_DEF(NIKON,MovMicrophone),
	PTP_DPC_EXT_DEF(NIKON,MovFileSlot),
	PTP_DPC_EXT_DEF(NIKON,MovRecProhibitCondition),
	PTP_DPC_EXT_DEF(NIKON,ManualMovieSetting),
	PTP_DPC_EXT_DEF(NIKON,MovQuality),
	PTP_DPC_EXT_DEF(NIKON,MovRecordMicrophoneLevelValue),
	PTP_DPC_EXT_DEF(NIKON,MovWindNoiseReduction),
	PTP_DPC_EXT_DEF(NIKON,MovRecordingZone),
	PTP_DPC_EXT_DEF(NIKON,MovISOAutoControl),
	PTP_DPC_EXT_DEF(NIKON,MovISOAutoHighLimit),
	PTP_DPC_EXT_DEF(NIKON,MovFileType),
	PTP_DPC_EXT_DEF(NIKON,LiveViewScreenDisplaySetting),
	PTP_DPC_EXT_DEF(NIKON,MonitorOffDelay),
	PTP_DPC_EXT_DEF(NIKON,ExposureIndexEx),
	PTP_DPC_EXT_DEF(NIKON,ISOControlSensitivity),
	PTP_DPC_EXT_DEF(NIKON,RawImageSize),
	PTP_DPC_EXT_DEF(NIKON,MultiBatteryInfo),
	PTP_DPC_EXT_DEF(NIKON,FlickerReductionSetting),
	PTP_DPC_EXT_DEF(NIKON,DiffractionCompensatipn),
	PTP_DPC_EXT_DEF(NIKON,MovieLogOutput),
	PTP_DPC_EXT_DEF(NIKON,MovieAutoDistortion),
	PTP_DPC_EXT_DEF(NIKON,RemainingExposureTime),
	PTP_DPC_EXT_DEF(NIKON,MovieLogSetting),
	PTP_DPC_EXT_DEF(NIKON,Bracketing),
	PTP_DPC_EXT_DEF(NIKON,AutoExposureBracketStep),
	PTP_DPC_EXT_DEF(NIKON,AutoExposureBracketProgram),
	PTP_DPC_EXT_DEF(NIKON,AutoExposureBracketCount),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalanceBracketStep),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalanceBracketProgram),
	PTP_DPC_EXT_DEF(NIKON,ADLBracketingPattern),
	PTP_DPC_EXT_DEF(NIKON,ADLBracketingStep),
	PTP_DPC_EXT_DEF(NIKON,HDMIOutputDataDepth),
	PTP_DPC_EXT_DEF(NIKON,LensID),
	PTP_DPC_EXT_DEF(NIKON,LensSort),
	PTP_DPC_EXT_DEF(NIKON,LensType),
	PTP_DPC_EXT_DEF(NIKON,FocalLengthMin),
	PTP_DPC_EXT_DEF(NIKON,FocalLengthMax),
	PTP_DPC_EXT_DEF(NIKON,MaxApAtMinFocalLength),
	PTP_DPC_EXT_DEF(NIKON,MaxApAtMaxFocalLength),
	PTP_DPC_EXT_DEF(NIKON,LensTypeML),
	PTP_DPC_EXT_DEF(NIKON,FinderISODisp),
	PTP_DPC_EXT_DEF(NIKON,AutoOffPhoto),
	PTP_DPC_EXT_DEF(NIKON,AutoOffMenu),
	PTP_DPC_EXT_DEF(NIKON,AutoOffInfo),
	PTP_DPC_EXT_DEF(NIKON,SelfTimerShootNum),
	PTP_DPC_EXT_DEF(NIKON,VignetteCtrl),
	PTP_DPC_EXT_DEF(NIKON,AutoDistortionControl),
	PTP_DPC_EXT_DEF(NIKON,SceneMode),
	PTP_DPC_EXT_DEF(NIKON,UserMode),
	PTP_DPC_EXT_DEF(NIKON,SceneMode2),
	PTP_DPC_EXT_DEF(NIKON,SelfTimerInterval),
	PTP_DPC_EXT_DEF(NIKON,ExposureTime),
	PTP_DPC_EXT_DEF(NIKON,ACPower),
	PTP_DPC_EXT_DEF(NIKON,WarningStatus),
	PTP_DPC_EXT_DEF(NIKON,MaximumShots),
	PTP_DPC_EXT_DEF(NIKON,AFLockStatus),
	PTP_DPC_EXT_DEF(NIKON,AELockStatus),
	PTP_DPC_EXT_DEF(NIKON,FVLockStatus),
	PTP_DPC_EXT_DEF(NIKON,AutofocusLCDTopMode2),
	PTP_DPC_EXT_DEF(NIKON,AutofocusArea),
	PTP_DPC_EXT_DEF(NIKON,FlexibleProgram),
	PTP_DPC_EXT_DEF(NIKON,LightMeter),
	PTP_DPC_EXT_DEF(NIKON,RecordingMedia),
	PTP_DPC_EXT_DEF(NIKON,USBSpeed),
	PTP_DPC_EXT_DEF(NIKON,CCDNumber),
	PTP_DPC_EXT_DEF(NIKON,CameraOrientation),
	PTP_DPC_EXT_DEF(NIKON,GroupPtnType),
	PTP_DPC_EXT_DEF(NIKON,FNumberLock),
	PTP_DPC_EXT_DEF(NIKON,ExposureApertureLock),
	PTP_DPC_EXT_DEF(NIKON,TVLockSetting),
	PTP_DPC_EXT_DEF(NIKON,AVLockSetting),
	PTP_DPC_EXT_DEF(NIKON,IllumSetting),
	PTP_DPC_EXT_DEF(NIKON,FocusPointBright),
	PTP_DPC_EXT_DEF(NIKON,ExposureCompFlashUsed),
	PTP_DPC_EXT_DEF(NIKON,ExternalFlashAttached),
	PTP_DPC_EXT_DEF(NIKON,ExternalFlashStatus),
	PTP_DPC_EXT_DEF(NIKON,ExternalFlashSort),
	PTP_DPC_EXT_DEF(NIKON,ExternalFlashMode),
	PTP_DPC_EXT_DEF(NIKON,ExternalFlashCompensation),
	PTP_DPC_EXT_DEF(NIKON,NewExternalFlashMode),
	PTP_DPC_EXT_DEF(NIKON,FlashExposureCompensation),
	PTP_DPC_EXT_DEF(NIKON,ExternalFlashMultiFlashMode),
	PTP_DPC_EXT_DEF(NIKON,ConnectionPath),
	PTP_DPC_EXT_DEF(NIKON,HDRMode),
	PTP_DPC_EXT_DEF(NIKON,HDRHighDynamic),
	PTP_DPC_EXT_DEF(NIKON,HDRSmoothing),
	PTP_DPC_EXT_DEF(NIKON,HDRSaveIndividualImages),
	PTP_DPC_EXT_DEF(NIKON,VibrationReduction),
	PTP_DPC_EXT_DEF(NIKON,OptimizeImage),
	PTP_DPC_EXT_DEF(NIKON,WBAutoType),
	PTP_DPC_EXT_DEF(NIKON,Saturation),
	PTP_DPC_EXT_DEF(NIKON,BW_FillerEffect),
	PTP_DPC_EXT_DEF(NIKON,BW_Sharpness),
	PTP_DPC_EXT_DEF(NIKON,BW_Contrast),
	PTP_DPC_EXT_DEF(NIKON,BW_Setting_Type),
	PTP_DPC_EXT_DEF(NIKON,Slot2SaveMode),
	PTP_DPC_EXT_DEF(NIKON,RawBitMode),
	PTP_DPC_EXT_DEF(NIKON,ActiveDLighting),
	PTP_DPC_EXT_DEF(NIKON,FlourescentType),
	PTP_DPC_EXT_DEF(NIKON,TuneColourTemperature),
	PTP_DPC_EXT_DEF(NIKON,TunePreset0),
	PTP_DPC_EXT_DEF(NIKON,TunePreset1),
	PTP_DPC_EXT_DEF(NIKON,TunePreset2),
	PTP_DPC_EXT_DEF(NIKON,TunePreset3),
	PTP_DPC_EXT_DEF(NIKON,TunePreset4),
	PTP_DPC_EXT_DEF(NIKON,PrimarySlot),
	PTP_DPC_EXT_DEF(NIKON,WBPresetProtect1),
	PTP_DPC_EXT_DEF(NIKON,WBPresetProtect2),
	PTP_DPC_EXT_DEF(NIKON,WBPresetProtect3),
	PTP_DPC_EXT_DEF(NIKON,ActiveFolder),
	PTP_DPC_EXT_DEF(NIKON,WBPresetProtect4),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalanceReset),
	PTP_DPC_EXT_DEF(NIKON,WhiteBalanceNaturalLightAutoBias),
	PTP_DPC_EXT_DEF(NIKON,BeepOff),
	PTP_DPC_EXT_DEF(NIKON,AutofocusMode),
	PTP_DPC_EXT_DEF(NIKON,AFAssist),
	PTP_DPC_EXT_DEF(NIKON,PADVPMode),
	PTP_DPC_EXT_DEF(NIKON,ISOAutoShutterTime),
	PTP_DPC_EXT_DEF(NIKON,ImageReview),
	PTP_DPC_EXT_DEF(NIKON,AFAreaIllumination),
	PTP_DPC_EXT_DEF(NIKON,FlashMode),
	PTP_DPC_EXT_DEF(NIKON,FlashCommanderMode),
	PTP_DPC_EXT_DEF(NIKON,FlashSign),
	PTP_DPC_EXT_DEF(NIKON,ISO_Auto),
	PTP_DPC_EXT_DEF(NIKON,RemoteTimeout),
	PTP_DPC_EXT_DEF(NIKON,GridDisplay),
	PTP_DPC_EXT_DEF(NIKON,FlashModeManualPower),
	PTP_DPC_EXT_DEF(NIKON,FlashModeCommanderPower),
	PTP_DPC_EXT_DEF(NIKON,AutoFP),
	PTP_DPC_EXT_DEF(NIKON,DateImprintSetting),
	PTP_DPC_EXT_DEF(NIKON,DateCounterSelect),
	PTP_DPC_EXT_DEF(NIKON,DateCountData),
	PTP_DPC_EXT_DEF(NIKON,DateCountDisplaySetting),
	PTP_DPC_EXT_DEF(NIKON,RangeFinderSetting),
	PTP_DPC_EXT_DEF(NIKON,LimitedAFAreaMode),
	PTP_DPC_EXT_DEF(NIKON,AFModeRestrictions),
	PTP_DPC_EXT_DEF(NIKON,LowLightAF),
	PTP_DPC_EXT_DEF(NIKON,ApplyLiveViewSetting),
	PTP_DPC_EXT_DEF(NIKON,MovieAfSpeed),
	PTP_DPC_EXT_DEF(NIKON,MovieAfSpeedWhenToApply),
	PTP_DPC_EXT_DEF(NIKON,MovieAfTrackingSensitivity),
	PTP_DPC_EXT_DEF(NIKON,CSMMenu),
	PTP_DPC_EXT_DEF(NIKON,WarningDisplay),
	PTP_DPC_EXT_DEF(NIKON,BatteryCellKind),
	PTP_DPC_EXT_DEF(NIKON,ISOAutoHiLimit),
	PTP_DPC_EXT_DEF(NIKON,DynamicAFArea),
	PTP_DPC_EXT_DEF(NIKON,ContinuousSpeedHigh),
	PTP_DPC_EXT_DEF(NIKON,InfoDispSetting),
	PTP_DPC_EXT_DEF(NIKON,PreviewButton),
	PTP_DPC_EXT_DEF(NIKON,PreviewButton2),
	PTP_DPC_EXT_DEF(NIKON,AEAFLockButton2),
	PTP_DPC_EXT_DEF(NIKON,IndicatorDisp),
	PTP_DPC_EXT_DEF(NIKON,CellKindPriority),
	PTP_DPC_EXT_DEF(NIKON,BracketingFramesAndSteps),
	PTP_DPC_EXT_DEF(NIKON,MovieReleaseButton),
	PTP_DPC_EXT_DEF(NIKON,FlashISOAutoHighLimit),
	PTP_DPC_EXT_DEF(NIKON,LiveViewMode),
	PTP_DPC_EXT_DEF(NIKON,LiveViewDriveMode),
	PTP_DPC_EXT_DEF(NIKON,LiveViewStatus),
	PTP_DPC_EXT_DEF(NIKON,LiveViewImageZoomRatio),
	PTP_DPC_EXT_DEF(NIKON,LiveViewProhibitCondition),
	PTP_DPC_EXT_DEF(NIKON,LiveViewExposurePreview),
	PTP_DPC_EXT_DEF(NIKON,LiveViewSelector),
	PTP_DPC_EXT_DEF(NIKON,LiveViewWhiteBalance),
	PTP_DPC_EXT_DEF(NIKON,MovieShutterSpeed),
	PTP_DPC_EXT_DEF(NIKON,MovieFNumber),
	PTP_DPC_EXT_DEF(NIKON,MovieISO),
	PTP_DPC_EXT_DEF(NIKON,MovieExposureBiasCompensation),
	PTP_DPC_EXT_DEF(NIKON,LiveViewMovieMode),
	PTP_DPC_EXT_DEF(NIKON,LiveViewImageSize),
	PTP_DPC_EXT_DEF(NIKON,LiveViewPhotography),
	PTP_DPC_EXT_DEF(NIKON,MovieExposureMeteringMode),
	PTP_DPC_EXT_DEF(NIKON,ExposureDisplayStatus),
	PTP_DPC_EXT_DEF(NIKON,ExposureIndicateStatus),
	PTP_DPC_EXT_DEF(NIKON,InfoDispErrStatus),
	PTP_DPC_EXT_DEF(NIKON,ExposureIndicateLightup),
	PTP_DPC_EXT_DEF(NIKON,ContinousShootingCount),
	PTP_DPC_EXT_DEF(NIKON,MovieRecFrameCount),
	PTP_DPC_EXT_DEF(NIKON,CameraLiveViewStatus),
	PTP_DPC_EXT_DEF(NIKON,DetectionPeaking),
	PTP_DPC_EXT_DEF(NIKON,LiveViewTFTStatus),
	PTP_DPC_EXT_DEF(NIKON,LiveViewImageStatus),
	PTP_DPC_EXT_DEF(NIKON,LiveViewImageCompression),
	PTP_DPC_EXT_DEF(NIKON,LiveViewZoomArea),
	PTP_DPC_EXT_DEF(NIKON,FlashOpen),
	PTP_DPC_EXT_DEF(NIKON,FlashCharged),
	PTP_DPC_EXT_DEF(NIKON,FlashMRepeatValue),
	PTP_DPC_EXT_DEF(NIKON,FlashMRepeatCount),
	PTP_DPC_EXT_DEF(NIKON,FlashMRepeatInterval),
	PTP_DPC_EXT_DEF(NIKON,FlashCommandChannel),
	PTP_DPC_EXT_DEF(NIKON,FlashCommandSelfMode),
	PTP_DPC_EXT_DEF(NIKON,FlashCommandSelfCompensation),
	PTP_DPC_EXT_DEF(NIKON,FlashCommandSelfValue),
	PTP_DPC_EXT_DEF(NIKON,FlashCommandAMode),
	PTP_DPC_EXT_DEF(NIKON,FlashCommandACompensation),
	PTP_DPC_EXT_DEF(NIKON,FlashCommandAValue),
	PTP_DPC_EXT_DEF(NIKON,FlashCommandBMode),
	PTP_DPC_EXT_DEF(NIKON,FlashCommandBCompensation),
	PTP_DPC_EXT_DEF(NIKON,FlashCommandBValue),
	PTP_DPC_EXT_DEF(NIKON,ExternalRecordingControl),
	PTP_DPC_EXT_DEF(NIKON,HighlightBrightness),
	PTP_DPC_EXT_DEF(NIKON,SBWirelessMode),
	PTP_DPC_EXT_DEF(NIKON,SBWirelessMultipleFlashMode),
	PTP_DPC_EXT_DEF(NIKON,SBUsableGroup),
	PTP_DPC_EXT_DEF(NIKON,WirelessCLSEntryMode),
	PTP_DPC_EXT_DEF(NIKON,SBPINCode),
	PTP_DPC_EXT_DEF(NIKON,RadioMultipleFlashChannel),
	PTP_DPC_EXT_DEF(NIKON,OpticalMultipleFlashChannel),
	PTP_DPC_EXT_DEF(NIKON,FlashRangeDisplay),
	PTP_DPC_EXT_DEF(NIKON,AllTestFiringDisable),
	PTP_DPC_EXT_DEF(NIKON,SBSettingMemberLock),
	PTP_DPC_EXT_DEF(NIKON,SBIntegrationFlashReady),
	PTP_DPC_EXT_DEF(NIKON,ApplicationMode),
	PTP_DPC_EXT_DEF(NIKON,ExposureRemaining),
	PTP_DPC_EXT_DEF(NIKON,ActiveSlot),
	PTP_DPC_EXT_DEF(NIKON,ISOAutoShutterCorrectionTime),
	PTP_DPC_EXT_DEF(NIKON,MirrorUpStatus),
	PTP_DPC_EXT_DEF(NIKON,MirrorUpReleaseShootingCount),
	PTP_DPC_EXT_DEF(NIKON,MovieAfAreaMode),
	PTP_DPC_EXT_DEF(NIKON,MovieVibrationReduction),
	PTP_DPC_EXT_DEF(NIKON,MovieFocusMode),
	PTP_DPC_EXT_DEF(NIKON,RecordTimeCodes),
	PTP_DPC_EXT_DEF(NIKON,CountUpMethod),
	PTP_DPC_EXT_DEF(NIKON,TimeCodeOrigin),
	PTP_DPC_EXT_DEF(NIKON,DropFrame),
	PTP_DPC_EXT_DEF(NIKON,ActivePicCtrlItem),
	PTP_DPC_EXT_DEF(NIKON,ChangePicCtrlItem),
	PTP_DPC_EXT_DEF(NIKON,ElectronicFrontCurtainShutter),
	PTP_DPC_EXT_DEF(NIKON,MovieResetShootingMenu),
	PTP_DPC_EXT_DEF(NIKON,MovieCaptureAreaCrop),
	PTP_DPC_EXT_DEF(NIKON,MovieAutoDxCrop),
	PTP_DPC_EXT_DEF(NIKON,MovieWbAutoType),
	PTP_DPC_EXT_DEF(NIKON,MovieWbTuneAuto),
	PTP_DPC_EXT_DEF(NIKON,MovieWbTuneIncandescent),
	PTP_DPC_EXT_DEF(NIKON,MovieWbFlourescentType),
	PTP_DPC_EXT_DEF(NIKON,MovieWbTuneFlourescent),
	PTP_DPC_EXT_DEF(NIKON,MovieWbTuneSunny),
	PTP_DPC_EXT_DEF(NIKON,MovieWbTuneCloudy),
	PTP_DPC_EXT_DEF(NIKON,MovieWbTuneShade),
	PTP_DPC_EXT_DEF(NIKON,MovieWbColorTemp),
	PTP_DPC_EXT_DEF(NIKON,MovieWbTuneColorTemp),
	PTP_DPC_EXT_DEF(NIKON,MovieWbPresetData0),
	PTP_DPC_EXT_DEF(NIKON,MovieWbPresetDataComment1),
	PTP_DPC_EXT_DEF(NIKON,MovieWbPresetDataComment2),
	PTP_DPC_EXT_DEF(NIKON,MovieWbPresetDataComment3),
	PTP_DPC_EXT_DEF(NIKON,MovieWbPresetDataComment4),
	PTP_DPC_EXT_DEF(NIKON,MovieWbPresetDataComment5),
	PTP_DPC_EXT_DEF(NIKON,MovieWbPresetDataComment6),
	PTP_DPC_EXT_DEF(NIKON,MovieWbPresetDataValue1),
	PTP_DPC_EXT_DEF(NIKON,MovieWbPresetDataValue2),
	PTP_DPC_EXT_DEF(NIKON,MovieWbPresetDataValue3),
	PTP_DPC_EXT_DEF(NIKON,MovieWbPresetDataValue4),
	PTP_DPC_EXT_DEF(NIKON,MovieWbPresetDataValue5),
	PTP_DPC_EXT_DEF(NIKON,MovieWbPresetDataValue6),
	PTP_DPC_EXT_DEF(NIKON,MovieWbTunePreset1),
	PTP_DPC_EXT_DEF(NIKON,MovieWbTunePreset2),
	PTP_DPC_EXT_DEF(NIKON,MovieWbTunePreset3),
	PTP_DPC_EXT_DEF(NIKON,MovieWbTunePreset4),
	PTP_DPC_EXT_DEF(NIKON,MovieWbTunePreset5),
	PTP_DPC_EXT_DEF(NIKON,MovieWbTunePreset6),
	PTP_DPC_EXT_DEF(NIKON,MovieWbPresetProtect1),
	PTP_DPC_EXT_DEF(NIKON,MovieWbPresetProtect2),
	PTP_DPC_EXT_DEF(NIKON,MovieWbPresetProtect3),
	PTP_DPC_EXT_DEF(NIKON,MovieWbPresetProtect4),
	PTP_DPC_EXT_DEF(NIKON,MovieWbPresetProtect5),
	PTP_DPC_EXT_DEF(NIKON,MovieWbPresetProtect6),
	PTP_DPC_EXT_DEF(NIKON,MovieWhiteBalanceReset),
	PTP_DPC_EXT_DEF(NIKON,MovieNrHighISO),
	PTP_DPC_EXT_DEF(NIKON,MovieActivePicCtrlItem),
	PTP_DPC_EXT_DEF(NIKON,MovieChangePicCtrlItem),
	PTP_DPC_EXT_DEF(NIKON,ExposureBaseCompHighlight),
	PTP_DPC_EXT_DEF(NIKON,MovieWhiteBalance),
	PTP_DPC_EXT_DEF(NIKON,MovieActiveDLighting),
	PTP_DPC_EXT_DEF(NIKON,MovieWbTuneNatural),
	PTP_DPC_EXT_DEF(NIKON,MovieAttenuator),
	PTP_DPC_EXT_DEF(NIKON,MovieVignetteControl),
	PTP_DPC_EXT_DEF(NIKON,MovieDiffractionCompensation),
	PTP_DPC_EXT_DEF(NIKON,UseDeviceStageFlag),
	PTP_DPC_EXT_DEF(NIKON,MovieCaptureMode),
	PTP_DPC_EXT_DEF(NIKON,SlowMotionMovieRecordScreenSize),
	PTP_DPC_EXT_DEF(NIKON,HighSpeedStillCaptureRate),
	PTP_DPC_EXT_DEF(NIKON,BestMomentCaptureMode),
	PTP_DPC_EXT_DEF(NIKON,ActiveSelectionFrameSavedDefault),
	PTP_DPC_EXT_DEF(NIKON,ActiveSelectionCapture40frameOver),
	PTP_DPC_EXT_DEF(NIKON,ActiveSelectionOnReleaseRecord),
	PTP_DPC_EXT_DEF(NIKON,ActiveSelectionSelectedPictures),
	PTP_DPC_EXT_DEF(NIKON,ExposureRemainingInMovie),
	PTP_DPC_EXT_DEF(NIKON,OpticalVR),
	PTP_DPC_EXT_DEF(NIKON,ElectronicVR),
	PTP_DPC_EXT_DEF(NIKON,SilentPhotography),
	PTP_DPC_EXT_DEF(NIKON,FacePriority),
	PTP_DPC_EXT_DEF(NIKON,LensTypeNikon1),
	PTP_DPC_EXT_DEF(NIKON,ISONoiseReduction),
	PTP_DPC_EXT_DEF(NIKON,MovieLoopLength),


/* Nikon V1 (or WU adapter?) Trace */
/* d241 - gets string "Nikon_WU2_0090B5123C61" */
	PTP_DPC_EXT_DEF(NIKON,D241),
/* d244 - gets a single byte 0x00 */
	PTP_DPC_EXT_DEF(NIKON,D244),
/* d247 - gets 3 bytes 0x01 0x00 0x00 */
	PTP_DPC_EXT_DEF(NIKON,D247),
/* S9700 */
	PTP_DPC_EXT_DEF(NIKON,GUID),
/* d250 - gets a string "0000123C61" */
	PTP_DPC_EXT_DEF(NIKON,D250),
/* d251 - gets a 0x0100000d */
	PTP_DPC_EXT_DEF(NIKON,D251),

/* this is irregular, as it should be -0x5000 or 0xD000 based */
	PTP_DPC_EXT_DEF(NIKON,1_ISO),
	PTP_DPC_EXT_DEF(NIKON,1_FNumber),
	PTP_DPC_EXT_DEF(NIKON,1_ShutterSpeed),
	PTP_DPC_EXT_DEF(NIKON,1_FNumber2),
	PTP_DPC_EXT_DEF(NIKON,1_ShutterSpeed2),
	PTP_DPC_EXT_DEF(NIKON,1_ImageCompression),
	PTP_DPC_EXT_DEF(NIKON,1_ImageSize),
	PTP_DPC_EXT_DEF(NIKON,1_WhiteBalance),
	PTP_DPC_EXT_DEF(NIKON,1_LongExposureNoiseReduction),
	PTP_DPC_EXT_DEF(NIKON,1_HiISONoiseReduction),
	PTP_DPC_EXT_DEF(NIKON,1_ActiveDLighting),
	PTP_DPC_EXT_DEF(NIKON,1_Language),
	PTP_DPC_EXT_DEF(NIKON,1_ReleaseWithoutCard),
	PTP_DPC_EXT_DEF(NIKON,1_MovQuality),

	{0,NULL},
};

static PTPCodeDef ptp_dpcodes_CASIO[] = {
/* Casio EX-F1 */
	PTP_DPC_EXT_DEF(CASIO,MONITOR),
	PTP_DPC_EXT_DEF(CASIO,STORAGE),
	PTP_DPC_EXT_DEF(CASIO,UNKNOWN_1),
	PTP_DPC_EXT_DEF(CASIO,UNKNOWN_2),
	PTP_DPC_EXT_DEF(CASIO,UNKNOWN_3),
	PTP_DPC_EXT_DEF(CASIO,RECORD_LIGHT),
	PTP_DPC_EXT_DEF(CASIO,UNKNOWN_4),
	PTP_DPC_EXT_DEF(CASIO,UNKNOWN_5),
	PTP_DPC_EXT_DEF(CASIO,MOVIE_MODE),
	PTP_DPC_EXT_DEF(CASIO,HD_SETTING),
	PTP_DPC_EXT_DEF(CASIO,HS_SETTING),
	PTP_DPC_EXT_DEF(CASIO,CS_HIGH_SPEED),
	PTP_DPC_EXT_DEF(CASIO,CS_UPPER_LIMIT),
	PTP_DPC_EXT_DEF(CASIO,CS_SHOT),
	PTP_DPC_EXT_DEF(CASIO,UNKNOWN_6),
	PTP_DPC_EXT_DEF(CASIO,UNKNOWN_7),
	PTP_DPC_EXT_DEF(CASIO,UNKNOWN_8),
	PTP_DPC_EXT_DEF(CASIO,UNKNOWN_9),
	PTP_DPC_EXT_DEF(CASIO,UNKNOWN_10),
	PTP_DPC_EXT_DEF(CASIO,UNKNOWN_11),
	PTP_DPC_EXT_DEF(CASIO,UNKNOWN_12),
	PTP_DPC_EXT_DEF(CASIO,UNKNOWN_13),
	PTP_DPC_EXT_DEF(CASIO,UNKNOWN_14),
	PTP_DPC_EXT_DEF(CASIO,UNKNOWN_15),
	PTP_DPC_EXT_DEF(CASIO,UNKNOWN_16),
	PTP_DPC_EXT_DEF(CASIO,UNKNOWN_17),
	PTP_DPC_EXT_DEF(CASIO,UNKNOWN_18),

	{0,NULL},
};

static PTPCodeDef ptp_dpcodes_SONY[] = {
/* Sony A900 */
	PTP_DPC_EXT_DEF(SONY,DPCCompensation),
	PTP_DPC_EXT_DEF(SONY,DRangeOptimize),
	PTP_DPC_EXT_DEF(SONY,ImageSize),
	PTP_DPC_EXT_DEF(SONY,ShutterSpeed),
	PTP_DPC_EXT_DEF(SONY,ColorTemp),
	PTP_DPC_EXT_DEF(SONY,CCFilter),
	PTP_DPC_EXT_DEF(SONY,AspectRatio),
	PTP_DPC_EXT_DEF(SONY,FocusFound),
	PTP_DPC_EXT_DEF(SONY,Zoom),
	PTP_DPC_EXT_DEF(SONY,ObjectInMemory),
	PTP_DPC_EXT_DEF(SONY,ExposeIndex),
	PTP_DPC_EXT_DEF(SONY,BatteryLevel),
	PTP_DPC_EXT_DEF(SONY,SensorCrop),
	PTP_DPC_EXT_DEF(SONY,PictureEffect),
	PTP_DPC_EXT_DEF(SONY,ABFilter),
	PTP_DPC_EXT_DEF(SONY,ISO),
	PTP_DPC_EXT_DEF(SONY,StillImageStoreDestination),
/* guessed DPC_SONY_DateTimeSettings 0xD223  error on query */
/* guessed DPC_SONY_FocusArea 0xD22C  (type=0x4) Enumeration [1,2,3,257,258,259,260,513,514,515,516,517,518,519,261,520] value: 1 */
/* guessed DPC_SONY_LiveDisplayEffect 0xD231 (type=0x2) Enumeration [1,2] value: 1 */
/* guessed DPC_SONY_FileType 0xD235  (enum: 0,1) */
/* guessed DPC_SONY_JpegQuality 0xD252 */
/* d255 reserved 5 */
/* d254 reserved 4 */
	PTP_DPC_EXT_DEF(SONY,ExposureCompensation),
	PTP_DPC_EXT_DEF(SONY,ISO2),
	PTP_DPC_EXT_DEF(SONY,ShutterSpeed2),
	PTP_DPC_EXT_DEF(SONY,PriorityMode),
	PTP_DPC_EXT_DEF(SONY,AutoFocus),
	PTP_DPC_EXT_DEF(SONY,Capture),
/* D2DB (2) , D2D3 (2) , D2C8 (2) also seen in Camera Remote related to D2C2 */
/* S1 ?
 * AEL - d2c3
 * FEL - d2c9
 * AFL - d2c4
 * AWBL - d2d9
 */
/* semi control opcodes */
	PTP_DPC_EXT_DEF(SONY,Movie),
	PTP_DPC_EXT_DEF(SONY,StillImage),

	PTP_DPC_EXT_DEF(SONY,NearFar),
/*#define PTP_DPC_SONY_AutoFocus				0xD2D2 something related */

	PTP_DPC_EXT_DEF(SONY,AF_Area_Position),

/* Sony QX properties */
/* all for 96f8 Control Device */
	PTP_DPC_EXT_DEF(SONY,QX_Zoom_Absolute),
	PTP_DPC_EXT_DEF(SONY,QX_Movie_Rec),
	PTP_DPC_EXT_DEF(SONY,QX_Request_For_Update),
	PTP_DPC_EXT_DEF(SONY,QX_Zoom_Wide_For_One_Shot),
	PTP_DPC_EXT_DEF(SONY,QX_Zoom_Tele_For_One_Shot),
	PTP_DPC_EXT_DEF(SONY,QX_S2_Button),
	PTP_DPC_EXT_DEF(SONY,QX_Media_Format),
	PTP_DPC_EXT_DEF(SONY,QX_S1_Button),
	PTP_DPC_EXT_DEF(SONY,QX_AE_Lock),
	PTP_DPC_EXT_DEF(SONY,QX_Request_For_Update_For_Lens),
	PTP_DPC_EXT_DEF(SONY,QX_Power_Off),
	PTP_DPC_EXT_DEF(SONY,QX_RequestOneShooting),
	PTP_DPC_EXT_DEF(SONY,QX_AF_Lock),
	PTP_DPC_EXT_DEF(SONY,QX_Zoom_Tele),
	PTP_DPC_EXT_DEF(SONY,QX_Zoom_Wide),
	PTP_DPC_EXT_DEF(SONY,QX_Focus_Magnification),
	PTP_DPC_EXT_DEF(SONY,QX_Focus_Near_For_One_Shot),
	PTP_DPC_EXT_DEF(SONY,QX_Focus_Far_For_One_Shot),
	PTP_DPC_EXT_DEF(SONY,QX_Focus_Near_For_Continuous),
	PTP_DPC_EXT_DEF(SONY,QX_Focus_Far_For_Continuous),
	PTP_DPC_EXT_DEF(SONY,QX_Camera_Setting_Reset),
	PTP_DPC_EXT_DEF(SONY,QX_Camera_Initialize),

/* old */
	PTP_DPC_EXT_DEF(SONY,QX_Capture),
	PTP_DPC_EXT_DEF(SONY,QX_AutoFocus),

/* set via 96fa */
	PTP_DPC_EXT_DEF(SONY,QX_PictureProfileInitialize),
	PTP_DPC_EXT_DEF(SONY,QX_PictureProfile),
	PTP_DPC_EXT_DEF(SONY,QX_AFSPrioritySetting),
	PTP_DPC_EXT_DEF(SONY,QX_AFCPrioritySetting),
	PTP_DPC_EXT_DEF(SONY,QX_LensUpdateState),
	PTP_DPC_EXT_DEF(SONY,QX_SilentShooting),
	PTP_DPC_EXT_DEF(SONY,QX_HDMIInfoDisplay),
	PTP_DPC_EXT_DEF(SONY,QX_TCUBDisp),
	PTP_DPC_EXT_DEF(SONY,QX_TCPreset),
	PTP_DPC_EXT_DEF(SONY,QX_TCMake),
	PTP_DPC_EXT_DEF(SONY,QX_TCRun),
	PTP_DPC_EXT_DEF(SONY,QX_UBPreset),
	PTP_DPC_EXT_DEF(SONY,QX_TCFormat),
	PTP_DPC_EXT_DEF(SONY,QX_LongExposureNR),
	PTP_DPC_EXT_DEF(SONY,QX_UBTimeRec),
	PTP_DPC_EXT_DEF(SONY,QX_FocusMagnificationLevel),
	PTP_DPC_EXT_DEF(SONY,QX_FocusMagnificationPosition),
	PTP_DPC_EXT_DEF(SONY,QX_LensStatus),
	PTP_DPC_EXT_DEF(SONY,QX_LiveviewResolution),
	PTP_DPC_EXT_DEF(SONY,QX_NotifyFocusPosition),
	PTP_DPC_EXT_DEF(SONY,QX_DriveMode),
	PTP_DPC_EXT_DEF(SONY,QX_DateTime),
	PTP_DPC_EXT_DEF(SONY,QX_AspectRatio),
	PTP_DPC_EXT_DEF(SONY,QX_ImageSize),
	PTP_DPC_EXT_DEF(SONY,QX_WhiteBalance),
	PTP_DPC_EXT_DEF(SONY,QX_CompressionSetting),
	PTP_DPC_EXT_DEF(SONY,QX_CautionError),
	PTP_DPC_EXT_DEF(SONY,QX_StorageInformation),
	PTP_DPC_EXT_DEF(SONY,QX_MovieQualitySetting),
	PTP_DPC_EXT_DEF(SONY,QX_MovieFormatSetting),
	PTP_DPC_EXT_DEF(SONY,QX_ZoomSetAbsolute),
	PTP_DPC_EXT_DEF(SONY,QX_ZoomInformation),
	PTP_DPC_EXT_DEF(SONY,QX_FocusSpeedForOneShot),
	PTP_DPC_EXT_DEF(SONY,QX_FlashCompensation),
	PTP_DPC_EXT_DEF(SONY,QX_ExposureCompensation),
	PTP_DPC_EXT_DEF(SONY,QX_Aperture),
	PTP_DPC_EXT_DEF(SONY,QX_ShootingFileInformation),
	PTP_DPC_EXT_DEF(SONY,QX_MediaFormatState),
	PTP_DPC_EXT_DEF(SONY,QX_ZoomMode),
	PTP_DPC_EXT_DEF(SONY,QX_FlashMode),
	PTP_DPC_EXT_DEF(SONY,QX_FocusMode),
	PTP_DPC_EXT_DEF(SONY,QX_ExposureMode),
	PTP_DPC_EXT_DEF(SONY,QX_MovieRecordingState),
	PTP_DPC_EXT_DEF(SONY,QX_SelectSaveMedia),
	PTP_DPC_EXT_DEF(SONY,QX_StillSteady),
	PTP_DPC_EXT_DEF(SONY,QX_MovieSteady),
	PTP_DPC_EXT_DEF(SONY,QX_Housing),
	PTP_DPC_EXT_DEF(SONY,QX_K4OutputSetting),
	PTP_DPC_EXT_DEF(SONY,QX_HDMIRECControl),
	PTP_DPC_EXT_DEF(SONY,QX_TimeCodeOutputToHDMI),
	PTP_DPC_EXT_DEF(SONY,QX_HDMIResolution),
	PTP_DPC_EXT_DEF(SONY,QX_NTSC_PAL_Selector),
	PTP_DPC_EXT_DEF(SONY,QX_HDMIOutput),
	PTP_DPC_EXT_DEF(SONY,QX_ISOAutoMinimum),
	PTP_DPC_EXT_DEF(SONY,QX_ISOAutoMaximum),
	PTP_DPC_EXT_DEF(SONY,QX_APSCSuper35mm),
	PTP_DPC_EXT_DEF(SONY,QX_LiveviewStatus),
	PTP_DPC_EXT_DEF(SONY,QX_WhiteBalanceInitialize),
	PTP_DPC_EXT_DEF(SONY,QX_OperatingMode),
	PTP_DPC_EXT_DEF(SONY,QX_BiaxialFineTuningABDirection),
	PTP_DPC_EXT_DEF(SONY,QX_HighISONr),
	PTP_DPC_EXT_DEF(SONY,QX_AELockIndication),
	PTP_DPC_EXT_DEF(SONY,QX_ElectronicFrontCurtainShutter),
	PTP_DPC_EXT_DEF(SONY,QX_ShutterSpeed),
	PTP_DPC_EXT_DEF(SONY,QX_FocusIndication),
	PTP_DPC_EXT_DEF(SONY,QX_BiaxialFineTuningGMDirection),
	PTP_DPC_EXT_DEF(SONY,QX_ColorTemperature),
	PTP_DPC_EXT_DEF(SONY,QX_BatteryLevelIndication),
	PTP_DPC_EXT_DEF(SONY,QX_ISO),
	PTP_DPC_EXT_DEF(SONY,QX_AutoSlowShutter),
	PTP_DPC_EXT_DEF(SONY,QX_DynamicRangeOptimizer),

	{0,NULL},
};

static PTPCodeDef ptp_dpcodes_MTP[] = {
/* Microsoft/MTP specific */
	PTP_DPC_EXT_DEF(MTP,SecureTime),
	PTP_DPC_EXT_DEF(MTP,DeviceCertificate),
	PTP_DPC_EXT_DEF(MTP,RevocationInfo),
	PTP_DPC_EXT_DEF(MTP,SynchronizationPartner),
	PTP_DPC_EXT_DEF(MTP,DeviceFriendlyName),
	PTP_DPC_EXT_DEF(MTP,VolumeLevel),
	PTP_DPC_EXT_DEF(MTP,DeviceIcon),
	PTP_DPC_EXT_DEF(MTP,SessionInitiatorInfo),
	PTP_DPC_EXT_DEF(MTP,PerceivedDeviceType),
	PTP_DPC_EXT_DEF(MTP,PlaybackRate),
	PTP_DPC_EXT_DEF(MTP,PlaybackObject),
	PTP_DPC_EXT_DEF(MTP,PlaybackContainerIndex),
	PTP_DPC_EXT_DEF(MTP,PlaybackPosition),
	PTP_DPC_EXT_DEF(MTP,PlaysForSureID),

	{0,NULL},
};

static PTPCodeDef ptp_dpcodes_MTP_EXT[] = {
/* Zune extension device property codes */
	PTP_DPC_EXT_DEF(MTP,ZUNE_UNKNOWN1),
	PTP_DPC_EXT_DEF(MTP,ZUNE_UNKNOWN2),
	PTP_DPC_EXT_DEF(MTP,ZUNE_UNKNOWN3),
	PTP_DPC_EXT_DEF(MTP,ZUNE_UNKNOWN4),

/* Zune specific property codes */
	PTP_DPC_EXT_DEF(MTP,Zune_UnknownVersion),

	{0,NULL},
};

static PTPCodeDef ptp_dpcodes_OLYMPUS[] = {
/* Olympus */
/* these are from OMD E-M1 Mark 2 */
	PTP_DPC_EXT_DEF(OLYMPUS,Aperture),
	PTP_DPC_EXT_DEF(OLYMPUS,FocusMode),
	PTP_DPC_EXT_DEF(OLYMPUS,ExposureMeteringMode),
	PTP_DPC_EXT_DEF(OLYMPUS,ISO),
	PTP_DPC_EXT_DEF(OLYMPUS,ExposureCompensation),
	PTP_DPC_EXT_DEF(OLYMPUS,OMD_DriveMode),
	PTP_DPC_EXT_DEF(OLYMPUS,ImageFormat),
	PTP_DPC_EXT_DEF(OLYMPUS,FaceDetection),
	PTP_DPC_EXT_DEF(OLYMPUS,AspectRatio),
	PTP_DPC_EXT_DEF(OLYMPUS,Shutterspeed),
	PTP_DPC_EXT_DEF(OLYMPUS,WhiteBalance),
	PTP_DPC_EXT_DEF(OLYMPUS,LiveViewModeOM),
	PTP_DPC_EXT_DEF(OLYMPUS,CaptureTarget),

/* unsure where these were from */
	PTP_DPC_EXT_DEF(OLYMPUS,ResolutionMode),
	PTP_DPC_EXT_DEF(OLYMPUS,FocusPriority),
	PTP_DPC_EXT_DEF(OLYMPUS,DriveMode),
	PTP_DPC_EXT_DEF(OLYMPUS,DateTimeFormat),
	PTP_DPC_EXT_DEF(OLYMPUS,ExposureBiasStep),
	PTP_DPC_EXT_DEF(OLYMPUS,WBMode),
	PTP_DPC_EXT_DEF(OLYMPUS,OneTouchWB),
	PTP_DPC_EXT_DEF(OLYMPUS,ManualWB),
	PTP_DPC_EXT_DEF(OLYMPUS,ManualWBRBBias),
	PTP_DPC_EXT_DEF(OLYMPUS,CustomWB),
	PTP_DPC_EXT_DEF(OLYMPUS,CustomWBValue),
	PTP_DPC_EXT_DEF(OLYMPUS,ExposureTimeEx),
	PTP_DPC_EXT_DEF(OLYMPUS,BulbMode),
	PTP_DPC_EXT_DEF(OLYMPUS,AntiMirrorMode),
	PTP_DPC_EXT_DEF(OLYMPUS,AEBracketingFrame),
	PTP_DPC_EXT_DEF(OLYMPUS,AEBracketingStep),
	PTP_DPC_EXT_DEF(OLYMPUS,WBBracketingFrame),
	PTP_DPC_EXT_DEF(OLYMPUS,WBBracketingRBFrame),
	PTP_DPC_EXT_DEF(OLYMPUS,WBBracketingRBRange),
	PTP_DPC_EXT_DEF(OLYMPUS,WBBracketingGMFrame),
	PTP_DPC_EXT_DEF(OLYMPUS,WBBracketingGMRange),
	PTP_DPC_EXT_DEF(OLYMPUS,FLBracketingFrame),
	PTP_DPC_EXT_DEF(OLYMPUS,FLBracketingStep),
	PTP_DPC_EXT_DEF(OLYMPUS,FlashBiasCompensation),
	PTP_DPC_EXT_DEF(OLYMPUS,ManualFocusMode),
	PTP_DPC_EXT_DEF(OLYMPUS,RawSaveMode),
	PTP_DPC_EXT_DEF(OLYMPUS,AUXLightMode),
	PTP_DPC_EXT_DEF(OLYMPUS,LensSinkMode),
	PTP_DPC_EXT_DEF(OLYMPUS,BeepStatus),
	PTP_DPC_EXT_DEF(OLYMPUS,ColorSpace),
	PTP_DPC_EXT_DEF(OLYMPUS,ColorMatching),
	PTP_DPC_EXT_DEF(OLYMPUS,Saturation),
	PTP_DPC_EXT_DEF(OLYMPUS,NoiseReductionPattern),
	PTP_DPC_EXT_DEF(OLYMPUS,NoiseReductionRandom),
	PTP_DPC_EXT_DEF(OLYMPUS,ShadingMode),
	PTP_DPC_EXT_DEF(OLYMPUS,ISOBoostMode),
	PTP_DPC_EXT_DEF(OLYMPUS,ExposureIndexBiasStep),
	PTP_DPC_EXT_DEF(OLYMPUS,FilterEffect),
	PTP_DPC_EXT_DEF(OLYMPUS,ColorTune),
	PTP_DPC_EXT_DEF(OLYMPUS,Language),
	PTP_DPC_EXT_DEF(OLYMPUS,LanguageCode),
	PTP_DPC_EXT_DEF(OLYMPUS,RecviewMode),
	PTP_DPC_EXT_DEF(OLYMPUS,SleepTime),
	PTP_DPC_EXT_DEF(OLYMPUS,ManualWBGMBias),
	PTP_DPC_EXT_DEF(OLYMPUS,AELAFLMode),
	PTP_DPC_EXT_DEF(OLYMPUS,AELButtonStatus),
	PTP_DPC_EXT_DEF(OLYMPUS,CompressionSettingEx),
	PTP_DPC_EXT_DEF(OLYMPUS,ToneMode),
	PTP_DPC_EXT_DEF(OLYMPUS,GradationMode),
	PTP_DPC_EXT_DEF(OLYMPUS,DevelopMode),
	PTP_DPC_EXT_DEF(OLYMPUS,ExtendInnerFlashMode),
	PTP_DPC_EXT_DEF(OLYMPUS,OutputDeviceMode),
	PTP_DPC_EXT_DEF(OLYMPUS,LiveViewMode),
	PTP_DPC_EXT_DEF(OLYMPUS,LCDBacklight),
	PTP_DPC_EXT_DEF(OLYMPUS,CustomDevelop),
	PTP_DPC_EXT_DEF(OLYMPUS,GradationAutoBias),
	PTP_DPC_EXT_DEF(OLYMPUS,FlashRCMode),
	PTP_DPC_EXT_DEF(OLYMPUS,FlashRCGroupValue),
	PTP_DPC_EXT_DEF(OLYMPUS,FlashRCChannelValue),
	PTP_DPC_EXT_DEF(OLYMPUS,FlashRCFPMode),
	PTP_DPC_EXT_DEF(OLYMPUS,FlashRCPhotoChromicMode),
	PTP_DPC_EXT_DEF(OLYMPUS,FlashRCPhotoChromicBias),
	PTP_DPC_EXT_DEF(OLYMPUS,FlashRCPhotoChromicManualBias),
	PTP_DPC_EXT_DEF(OLYMPUS,FlashRCQuantityLightLevel),
	PTP_DPC_EXT_DEF(OLYMPUS,FocusMeteringValue),
	PTP_DPC_EXT_DEF(OLYMPUS,ISOBracketingFrame),
	PTP_DPC_EXT_DEF(OLYMPUS,ISOBracketingStep),
	PTP_DPC_EXT_DEF(OLYMPUS,BulbMFMode),
	PTP_DPC_EXT_DEF(OLYMPUS,BurstFPSValue),
	PTP_DPC_EXT_DEF(OLYMPUS,ISOAutoBaseValue),
	PTP_DPC_EXT_DEF(OLYMPUS,ISOAutoMaxValue),
	PTP_DPC_EXT_DEF(OLYMPUS,BulbLimiterValue),
	PTP_DPC_EXT_DEF(OLYMPUS,DPIMode),
	PTP_DPC_EXT_DEF(OLYMPUS,DPICustomValue),
	PTP_DPC_EXT_DEF(OLYMPUS,ResolutionValueSetting),
	PTP_DPC_EXT_DEF(OLYMPUS,AFTargetSize),
	PTP_DPC_EXT_DEF(OLYMPUS,LightSensorMode),
	PTP_DPC_EXT_DEF(OLYMPUS,AEBracket),
	PTP_DPC_EXT_DEF(OLYMPUS,WBRBBracket),
	PTP_DPC_EXT_DEF(OLYMPUS,WBGMBracket),
	PTP_DPC_EXT_DEF(OLYMPUS,FlashBracket),
	PTP_DPC_EXT_DEF(OLYMPUS,ISOBracket),
	PTP_DPC_EXT_DEF(OLYMPUS,MyModeStatus),
	PTP_DPC_EXT_DEF(OLYMPUS,DateTimeUTC),

	{0,NULL},
};

// none known
/*
static PTPCodeDef ptp_dpcodes_ANDROID[] = {

	{0,NULL},
};
*/

static PTPCodeDef ptp_dpcodes_LEICA[] = {
/* Leica */
	PTP_DPC_EXT_DEF(LEICA,ExternalShooting),
/* d040 */
/* d60c */
/* d60e */
/* d610 */

	{0,NULL},
};

static PTPCodeDef ptp_dpcodes_PARROT[] = {
/* https://github.com/Parrot-Developers/sequoia-ptpy */
	PTP_DPC_EXT_DEF(PARROT,PhotoSensorEnableMask),
	PTP_DPC_EXT_DEF(PARROT,PhotoSensorsKeepOn),
	PTP_DPC_EXT_DEF(PARROT,MultispectralImageSize),
	PTP_DPC_EXT_DEF(PARROT,MainBitDepth),
	PTP_DPC_EXT_DEF(PARROT,MultispectralBitDepth),
	PTP_DPC_EXT_DEF(PARROT,HeatingEnable),
	PTP_DPC_EXT_DEF(PARROT,WifiStatus),
	PTP_DPC_EXT_DEF(PARROT,WifiSSID),
	PTP_DPC_EXT_DEF(PARROT,WifiEncryptionType),
	PTP_DPC_EXT_DEF(PARROT,WifiPassphrase),
	PTP_DPC_EXT_DEF(PARROT,WifiChannel),
	PTP_DPC_EXT_DEF(PARROT,Localization),
	PTP_DPC_EXT_DEF(PARROT,WifiMode),
	PTP_DPC_EXT_DEF(PARROT,AntiFlickeringFrequency),
	PTP_DPC_EXT_DEF(PARROT,DisplayOverlayMask),
	PTP_DPC_EXT_DEF(PARROT,GPSInterval),
	PTP_DPC_EXT_DEF(PARROT,MultisensorsExposureMeteringMode),
	PTP_DPC_EXT_DEF(PARROT,MultisensorsExposureTime),
	PTP_DPC_EXT_DEF(PARROT,MultisensorsExposureProgramMode),
	PTP_DPC_EXT_DEF(PARROT,MultisensorsExposureIndex),
	PTP_DPC_EXT_DEF(PARROT,MultisensorsIrradianceGain),
	PTP_DPC_EXT_DEF(PARROT,MultisensorsIrradianceIntegrationTime),
	PTP_DPC_EXT_DEF(PARROT,OverlapRate),

	{0,NULL},
};

// uses weird 32 bit codes according to gphoto
/*
static PTPCodeDef ptp_dpcodes_PANASONIC[] = {

	{0,NULL},
};
*/

static PTPCodeDef ptp_dpcodes_FUJI[] = {
/* Fuji specific */
	PTP_DPC_EXT_DEF(FUJI,FilmSimulation),
	PTP_DPC_EXT_DEF(FUJI,FilmSimulationTune),
	PTP_DPC_EXT_DEF(FUJI,DRangeMode),
	PTP_DPC_EXT_DEF(FUJI,ColorMode),
	PTP_DPC_EXT_DEF(FUJI,ColorSpace),
	PTP_DPC_EXT_DEF(FUJI,WhitebalanceTune1),
	PTP_DPC_EXT_DEF(FUJI,WhitebalanceTune2),
	PTP_DPC_EXT_DEF(FUJI,ColorTemperature),
	PTP_DPC_EXT_DEF(FUJI,Quality),
	PTP_DPC_EXT_DEF(FUJI,RecMode),
	PTP_DPC_EXT_DEF(FUJI,LiveViewBrightness),
	PTP_DPC_EXT_DEF(FUJI,ThroughImageZoom),
	PTP_DPC_EXT_DEF(FUJI,NoiseReduction),
	PTP_DPC_EXT_DEF(FUJI,MacroMode),
	PTP_DPC_EXT_DEF(FUJI,LiveViewStyle),
	PTP_DPC_EXT_DEF(FUJI,FaceDetectionMode),
	PTP_DPC_EXT_DEF(FUJI,RedEyeCorrectionMode),
	PTP_DPC_EXT_DEF(FUJI,RawCompression),
	PTP_DPC_EXT_DEF(FUJI,GrainEffect),
	PTP_DPC_EXT_DEF(FUJI,SetEyeAFMode),
	PTP_DPC_EXT_DEF(FUJI,FocusPoints),
	PTP_DPC_EXT_DEF(FUJI,MFAssistMode),
	PTP_DPC_EXT_DEF(FUJI,InterlockAEAFArea),
	PTP_DPC_EXT_DEF(FUJI,CommandDialMode),
	PTP_DPC_EXT_DEF(FUJI,Shadowing),
/* d02a - d02c also appear in setafmode */
	PTP_DPC_EXT_DEF(FUJI,ExposureIndex),
	PTP_DPC_EXT_DEF(FUJI,MovieISO),
	PTP_DPC_EXT_DEF(FUJI,WideDynamicRange),
	PTP_DPC_EXT_DEF(FUJI,TNumber),
	PTP_DPC_EXT_DEF(FUJI,Comment),
	PTP_DPC_EXT_DEF(FUJI,SerialMode),
	PTP_DPC_EXT_DEF(FUJI,ExposureDelay),
	PTP_DPC_EXT_DEF(FUJI,PreviewTime),
	PTP_DPC_EXT_DEF(FUJI,BlackImageTone),
	PTP_DPC_EXT_DEF(FUJI,Illumination),
	PTP_DPC_EXT_DEF(FUJI,FrameGuideMode),
	PTP_DPC_EXT_DEF(FUJI,ViewfinderWarning),
	PTP_DPC_EXT_DEF(FUJI,AutoImageRotation),
	PTP_DPC_EXT_DEF(FUJI,DetectImageRotation),
	PTP_DPC_EXT_DEF(FUJI,ShutterPriorityMode1),
	PTP_DPC_EXT_DEF(FUJI,ShutterPriorityMode2),
	PTP_DPC_EXT_DEF(FUJI,AFIlluminator),
	PTP_DPC_EXT_DEF(FUJI,Beep),
	PTP_DPC_EXT_DEF(FUJI,AELock),
	PTP_DPC_EXT_DEF(FUJI,ISOAutoSetting1),
	PTP_DPC_EXT_DEF(FUJI,ISOAutoSetting2),
	PTP_DPC_EXT_DEF(FUJI,ISOAutoSetting3),
	PTP_DPC_EXT_DEF(FUJI,ExposureStep),
	PTP_DPC_EXT_DEF(FUJI,CompensationStep),
	PTP_DPC_EXT_DEF(FUJI,ExposureSimpleSet),
	PTP_DPC_EXT_DEF(FUJI,CenterPhotometryRange),
	PTP_DPC_EXT_DEF(FUJI,PhotometryLevel1),
	PTP_DPC_EXT_DEF(FUJI,PhotometryLevel2),
	PTP_DPC_EXT_DEF(FUJI,PhotometryLevel3),
	PTP_DPC_EXT_DEF(FUJI,FlashTuneSpeed),
	PTP_DPC_EXT_DEF(FUJI,FlashShutterLimit),
	PTP_DPC_EXT_DEF(FUJI,BuiltinFlashMode),
	PTP_DPC_EXT_DEF(FUJI,FlashManualMode),
	PTP_DPC_EXT_DEF(FUJI,FlashRepeatingMode1),
	PTP_DPC_EXT_DEF(FUJI,FlashRepeatingMode2),
	PTP_DPC_EXT_DEF(FUJI,FlashRepeatingMode3),
	PTP_DPC_EXT_DEF(FUJI,FlashCommanderMode1),
	PTP_DPC_EXT_DEF(FUJI,FlashCommanderMode2),
	PTP_DPC_EXT_DEF(FUJI,FlashCommanderMode3),
	PTP_DPC_EXT_DEF(FUJI,FlashCommanderMode4),
	PTP_DPC_EXT_DEF(FUJI,FlashCommanderMode5),
	PTP_DPC_EXT_DEF(FUJI,FlashCommanderMode6),
	PTP_DPC_EXT_DEF(FUJI,FlashCommanderMode7),
	PTP_DPC_EXT_DEF(FUJI,ModelingFlash),
	PTP_DPC_EXT_DEF(FUJI,BKT),
	PTP_DPC_EXT_DEF(FUJI,BKTChange),
	PTP_DPC_EXT_DEF(FUJI,BKTOrder),
	PTP_DPC_EXT_DEF(FUJI,BKTSelection),
	PTP_DPC_EXT_DEF(FUJI,AEAFLockButton),
	PTP_DPC_EXT_DEF(FUJI,CenterButton),
	PTP_DPC_EXT_DEF(FUJI,MultiSelectorButton),
	PTP_DPC_EXT_DEF(FUJI,FunctionLock),
	PTP_DPC_EXT_DEF(FUJI,Password),
	PTP_DPC_EXT_DEF(FUJI,ChangePassword),
	PTP_DPC_EXT_DEF(FUJI,CommandDialSetting1),
	PTP_DPC_EXT_DEF(FUJI,CommandDialSetting2),
	PTP_DPC_EXT_DEF(FUJI,CommandDialSetting3),
	PTP_DPC_EXT_DEF(FUJI,CommandDialSetting4),
	PTP_DPC_EXT_DEF(FUJI,ButtonsAndDials),
	PTP_DPC_EXT_DEF(FUJI,NonCPULensData),
	PTP_DPC_EXT_DEF(FUJI,MBD200Batteries),
	PTP_DPC_EXT_DEF(FUJI,AFOnForMBD200Batteries),
	PTP_DPC_EXT_DEF(FUJI,FirmwareVersion),
	PTP_DPC_EXT_DEF(FUJI,ShotCount),
	PTP_DPC_EXT_DEF(FUJI,ShutterExchangeCount),
	PTP_DPC_EXT_DEF(FUJI,WorldClock),
	PTP_DPC_EXT_DEF(FUJI,TimeDifference1),
	PTP_DPC_EXT_DEF(FUJI,TimeDifference2),
	PTP_DPC_EXT_DEF(FUJI,Language),
	PTP_DPC_EXT_DEF(FUJI,FrameNumberSequence),
	PTP_DPC_EXT_DEF(FUJI,VideoMode),
	PTP_DPC_EXT_DEF(FUJI,SetUSBMode),
	PTP_DPC_EXT_DEF(FUJI,CommentWriteSetting),
	PTP_DPC_EXT_DEF(FUJI,BCRAppendDelimiter),
	PTP_DPC_EXT_DEF(FUJI,CommentEx),
	PTP_DPC_EXT_DEF(FUJI,VideoOutOnOff),
	PTP_DPC_EXT_DEF(FUJI,CropMode),
	PTP_DPC_EXT_DEF(FUJI,LensZoomPos),
	PTP_DPC_EXT_DEF(FUJI,FocusPosition),
	PTP_DPC_EXT_DEF(FUJI,LiveViewImageQuality),
	PTP_DPC_EXT_DEF(FUJI,LiveViewImageSize),
	PTP_DPC_EXT_DEF(FUJI,LiveViewCondition),
	PTP_DPC_EXT_DEF(FUJI,StandbyMode),
	PTP_DPC_EXT_DEF(FUJI,LiveViewExposure),
	PTP_DPC_EXT_DEF(FUJI,LiveViewWhiteBalance),
	PTP_DPC_EXT_DEF(FUJI,LiveViewWhiteBalanceGain),
	PTP_DPC_EXT_DEF(FUJI,LiveViewTuning),
	PTP_DPC_EXT_DEF(FUJI,FocusMeteringMode),
	PTP_DPC_EXT_DEF(FUJI,FocusLength),
	PTP_DPC_EXT_DEF(FUJI,CropAreaFrameInfo),
	PTP_DPC_EXT_DEF(FUJI,ResetSetting),
	PTP_DPC_EXT_DEF(FUJI,IOPCode),
	PTP_DPC_EXT_DEF(FUJI,TetherRawConditionCode),
	PTP_DPC_EXT_DEF(FUJI,TetherRawCompatibilityCode),
	PTP_DPC_EXT_DEF(FUJI,LightTune),
	PTP_DPC_EXT_DEF(FUJI,ReleaseMode),
	PTP_DPC_EXT_DEF(FUJI,BKTFrame1),
	PTP_DPC_EXT_DEF(FUJI,BKTFrame2),
	PTP_DPC_EXT_DEF(FUJI,BKTStep),
	PTP_DPC_EXT_DEF(FUJI,ProgramShift),
	PTP_DPC_EXT_DEF(FUJI,FocusAreas),
	PTP_DPC_EXT_DEF(FUJI,PriorityMode),
/* D208 is some kind of control, likely bitmasked. reported like an enum.
 * 0x200 seems to mean focusing?
 * 0x208 capture?
 * camera starts with 0x304
 * xt2:    0x104,0x200,0x4,0x304,0x500,0xc,0xa000,6,0x9000,2,0x9100,1,0x9300,5
 * xt3:    0x104,0x200,0x4,0x304,0x500,0xc,0xa000,6,0x9000,2,0x9100,1,0x9200,0x40,0x9300,5,0x804,0x80
 * xt30:   0x104,0x200,0x4,0x304,0x500,0xc,0xa000,6,0x9000,2,0x9100,1,0x9200,0x40,0x9300,5
 * xt4:    0x104,0x200,0x4,0x304,0x500,0xc,0x8000,0xa000,6,0x9000,2,0x9100,1,0x9300,5,0xe,0x9200,0x40,0x804,0x80
 * xh1:    0x104,0x200,0x4,0x304,0x500,0xc,0xa000,6,0x9000,2,0x9100,1,0x9300,5
 * gfx100: 0x104,0x200,0x4,0x304,0x500,0xc,0x8000,0xa000,6,0x9000,2,0x9100,1,0x9300,5,0xe,0x9200
 * gfx50r: 0x104,0x200,0x4,0x304,0x500,0xc,0xa000,6,0x9000,2,0x9100,1,0x9300,5,0xe
 * xpro2:  0x104,0x200,0x4,0x304,0x500,0xc,0xa000,6,0x9000,2,0x9100,1
 *
 * 0x304 is for regular capture 	SDK_ShootS2toS0	(default) (SDK_Shoot)
 * 0x200 seems for autofocus (s1?)	SDK_ShootS1
 * 0x500 start bulb? 0xc end bulb?	SDK_StartBulb
 * 0x400 might also be start bulb?	SDK_StartBulb
 * 0xc					SDK_EndBulb
 * 0x600 				SDK_1PushAF
 * 0x4 					SDK_CancelS1
 * 0x300 				SDK_ShootS2
 * 0x8000 migh be autowhitebalance
 */
	PTP_DPC_EXT_DEF(FUJI,AFStatus),
	PTP_DPC_EXT_DEF(FUJI,DeviceName),
	PTP_DPC_EXT_DEF(FUJI,MediaRecord),
	PTP_DPC_EXT_DEF(FUJI,MediaCapacity),
	PTP_DPC_EXT_DEF(FUJI,FreeSDRAMImages),
	PTP_DPC_EXT_DEF(FUJI,MediaStatus),
	PTP_DPC_EXT_DEF(FUJI,CurrentState),
	PTP_DPC_EXT_DEF(FUJI,AELock2),
	PTP_DPC_EXT_DEF(FUJI,Copyright),
	PTP_DPC_EXT_DEF(FUJI,Copyright2),
	PTP_DPC_EXT_DEF(FUJI,Aperture),
	PTP_DPC_EXT_DEF(FUJI,ShutterSpeed),
	PTP_DPC_EXT_DEF(FUJI,DeviceError),
	PTP_DPC_EXT_DEF(FUJI,SensitivityFineTune1),
	PTP_DPC_EXT_DEF(FUJI,SensitivityFineTune2),
	PTP_DPC_EXT_DEF(FUJI,CaptureRemaining),
	PTP_DPC_EXT_DEF(FUJI,MovieRemainingTime),
	PTP_DPC_EXT_DEF(FUJI,ForceMode),
	PTP_DPC_EXT_DEF(FUJI,ShutterSpeed2),
	PTP_DPC_EXT_DEF(FUJI,ImageAspectRatio),
	PTP_DPC_EXT_DEF(FUJI,BatteryLevel),
	PTP_DPC_EXT_DEF(FUJI,TotalShotCount),
	PTP_DPC_EXT_DEF(FUJI,HighLightTone),
	PTP_DPC_EXT_DEF(FUJI,ShadowTone),
	PTP_DPC_EXT_DEF(FUJI,LongExposureNR),
	PTP_DPC_EXT_DEF(FUJI,FullTimeManualFocus),
	PTP_DPC_EXT_DEF(FUJI,ISODialHn1),
	PTP_DPC_EXT_DEF(FUJI,ISODialHn2),
	PTP_DPC_EXT_DEF(FUJI,ViewMode1),
	PTP_DPC_EXT_DEF(FUJI,ViewMode2),
	PTP_DPC_EXT_DEF(FUJI,DispInfoMode),
	PTP_DPC_EXT_DEF(FUJI,LensISSwitch),
	PTP_DPC_EXT_DEF(FUJI,FocusPoint),
	PTP_DPC_EXT_DEF(FUJI,InstantAFMode),
	PTP_DPC_EXT_DEF(FUJI,PreAFMode),
	PTP_DPC_EXT_DEF(FUJI,CustomSetting),
	PTP_DPC_EXT_DEF(FUJI,LMOMode),
	PTP_DPC_EXT_DEF(FUJI,LockButtonMode),
	PTP_DPC_EXT_DEF(FUJI,AFLockMode),
	PTP_DPC_EXT_DEF(FUJI,MicJackMode),
	PTP_DPC_EXT_DEF(FUJI,ISMode),
	PTP_DPC_EXT_DEF(FUJI,DateTimeDispFormat),
	PTP_DPC_EXT_DEF(FUJI,AeAfLockKeyAssign),
	PTP_DPC_EXT_DEF(FUJI,CrossKeyAssign),
	PTP_DPC_EXT_DEF(FUJI,SilentMode),
	PTP_DPC_EXT_DEF(FUJI,PBSound),
	PTP_DPC_EXT_DEF(FUJI,EVFDispAutoRotate),
	PTP_DPC_EXT_DEF(FUJI,ExposurePreview),
	PTP_DPC_EXT_DEF(FUJI,DispBrightness1),
	PTP_DPC_EXT_DEF(FUJI,DispBrightness2),
	PTP_DPC_EXT_DEF(FUJI,DispChroma1),
	PTP_DPC_EXT_DEF(FUJI,DispChroma2),
	PTP_DPC_EXT_DEF(FUJI,FocusCheckMode),
	PTP_DPC_EXT_DEF(FUJI,FocusScaleUnit),
	PTP_DPC_EXT_DEF(FUJI,SetFunctionButton),
	PTP_DPC_EXT_DEF(FUJI,SensorCleanTiming),
	PTP_DPC_EXT_DEF(FUJI,CustomAutoPowerOff),
	PTP_DPC_EXT_DEF(FUJI,FileNamePrefix1),
	PTP_DPC_EXT_DEF(FUJI,FileNamePrefix2),
	PTP_DPC_EXT_DEF(FUJI,BatteryInfo1),
	PTP_DPC_EXT_DEF(FUJI,BatteryInfo2),
	PTP_DPC_EXT_DEF(FUJI,LensNameAndSerial),
	PTP_DPC_EXT_DEF(FUJI,CustomDispInfo),
	PTP_DPC_EXT_DEF(FUJI,FunctionLockCategory1),
	PTP_DPC_EXT_DEF(FUJI,FunctionLockCategory2),
	PTP_DPC_EXT_DEF(FUJI,CustomPreviewTime),
	PTP_DPC_EXT_DEF(FUJI,FocusArea1),
	PTP_DPC_EXT_DEF(FUJI,FocusArea2),
	PTP_DPC_EXT_DEF(FUJI,FocusArea3),
	PTP_DPC_EXT_DEF(FUJI,FrameGuideGridInfo1),
	PTP_DPC_EXT_DEF(FUJI,FrameGuideGridInfo2),
	PTP_DPC_EXT_DEF(FUJI,FrameGuideGridInfo3),
	PTP_DPC_EXT_DEF(FUJI,FrameGuideGridInfo4),
	PTP_DPC_EXT_DEF(FUJI,LensUnknownData),
	PTP_DPC_EXT_DEF(FUJI,LensZoomPosCaps),
	PTP_DPC_EXT_DEF(FUJI,LensFNumberList),
	PTP_DPC_EXT_DEF(FUJI,LensFocalLengthList),
	PTP_DPC_EXT_DEF(FUJI,FocusLimiter),
	PTP_DPC_EXT_DEF(FUJI,FocusArea4),
	PTP_DPC_EXT_DEF(FUJI,InitSequence),
	PTP_DPC_EXT_DEF(FUJI,AppVersion),

	{0,NULL},
};

// none known
/*
static PTPCodeDef ptp_dpcodes_SIGMA[] = {

	{0,NULL},
};
*/

/* tables of opcode, operation name, 0 terminated */
#define PTP_OC_DEF(name) {PTP_OC_##name,#name}
#define PTP_OC_EXT_DEF(ext_id,name) {PTP_OC_##ext_id##_##name,#name}
static PTPCodeDef ptp_opcodes_STD[] = {
/* PTP v1.0 operation codes */
	PTP_OC_DEF(Undefined),
	PTP_OC_DEF(GetDeviceInfo),
	PTP_OC_DEF(OpenSession),
	PTP_OC_DEF(CloseSession),
	PTP_OC_DEF(GetStorageIDs),
	PTP_OC_DEF(GetStorageInfo),
	PTP_OC_DEF(GetNumObjects),
	PTP_OC_DEF(GetObjectHandles),
	PTP_OC_DEF(GetObjectInfo),
	PTP_OC_DEF(GetObject),
	PTP_OC_DEF(GetThumb),
	PTP_OC_DEF(DeleteObject),
	PTP_OC_DEF(SendObjectInfo),
	PTP_OC_DEF(SendObject),
	PTP_OC_DEF(InitiateCapture),
	PTP_OC_DEF(FormatStore),
	PTP_OC_DEF(ResetDevice),
	PTP_OC_DEF(SelfTest),
	PTP_OC_DEF(SetObjectProtection),
	PTP_OC_DEF(PowerDown),
	PTP_OC_DEF(GetDevicePropDesc),
	PTP_OC_DEF(GetDevicePropValue),
	PTP_OC_DEF(SetDevicePropValue),
	PTP_OC_DEF(ResetDevicePropValue),
	PTP_OC_DEF(TerminateOpenCapture),
	PTP_OC_DEF(MoveObject),
	PTP_OC_DEF(CopyObject),
	PTP_OC_DEF(GetPartialObject),
	PTP_OC_DEF(InitiateOpenCapture),
/* PTP v1.1 operation codes */
	PTP_OC_DEF(StartEnumHandles),
	PTP_OC_DEF(EnumHandles),
	PTP_OC_DEF(StopEnumHandles),
	PTP_OC_DEF(GetVendorExtensionMaps),
	PTP_OC_DEF(GetVendorDeviceInfo),
	PTP_OC_DEF(GetResizedImageObject),
	PTP_OC_DEF(GetFilesystemManifest),
	PTP_OC_DEF(GetStreamInfo),
	PTP_OC_DEF(GetStream),
	{0,NULL},
};

static PTPCodeDef ptp_opcodes_EK[] = {
/* Eastman Kodak extension Operation Codes */
	PTP_OC_EXT_DEF(EK,GetSerial),
	PTP_OC_EXT_DEF(EK,SetSerial),
	PTP_OC_EXT_DEF(EK,SendFileObjectInfo),
	PTP_OC_EXT_DEF(EK,SendFileObject),
	PTP_OC_EXT_DEF(EK,SetText),
	{0,NULL},
};

// from CHDK source tools/ptp_op_names.c */

static PTPCodeDef ptp_opcodes_CANON[] = {
/* Canon extension Operation Codes */
	PTP_OC_EXT_DEF(CANON,GetPartialObjectInfo),
	PTP_OC_EXT_DEF(CANON,SetObjectArchive),
	PTP_OC_EXT_DEF(CANON,KeepDeviceOn),
	PTP_OC_EXT_DEF(CANON,LockDeviceUI),
	PTP_OC_EXT_DEF(CANON,UnlockDeviceUI),
	PTP_OC_EXT_DEF(CANON,GetObjectHandleByName),
	PTP_OC_EXT_DEF(CANON,InitiateReleaseControl),
	PTP_OC_EXT_DEF(CANON,TerminateReleaseControl),
	PTP_OC_EXT_DEF(CANON,TerminatePlaybackMode),
	PTP_OC_EXT_DEF(CANON,ViewfinderOn),
	PTP_OC_EXT_DEF(CANON,ViewfinderOff),
	PTP_OC_EXT_DEF(CANON,DoAeAfAwb),
	PTP_OC_EXT_DEF(CANON,GetCustomizeSpec),
	PTP_OC_EXT_DEF(CANON,GetCustomizeItemInfo),
	PTP_OC_EXT_DEF(CANON,GetCustomizeData),
	PTP_OC_EXT_DEF(CANON,SetCustomizeData),
	PTP_OC_EXT_DEF(CANON,GetCaptureStatus),
	PTP_OC_EXT_DEF(CANON,CheckEvent),
	PTP_OC_EXT_DEF(CANON,FocusLock),
	PTP_OC_EXT_DEF(CANON,FocusUnlock),
	PTP_OC_EXT_DEF(CANON,GetLocalReleaseParam),
	PTP_OC_EXT_DEF(CANON,SetLocalReleaseParam),
	PTP_OC_EXT_DEF(CANON,AskAboutPcEvf),
	PTP_OC_EXT_DEF(CANON,SendPartialObject),
	PTP_OC_EXT_DEF(CANON,InitiateCaptureInMemory),
	PTP_OC_EXT_DEF(CANON,GetPartialObjectEx),
	PTP_OC_EXT_DEF(CANON,SetObjectTime),
	PTP_OC_EXT_DEF(CANON,GetViewfinderImage),
	PTP_OC_EXT_DEF(CANON,GetObjectAttributes),
	PTP_OC_EXT_DEF(CANON,ChangeUSBProtocol),
	PTP_OC_EXT_DEF(CANON,GetChanges),
	PTP_OC_EXT_DEF(CANON,GetObjectInfoEx),
	PTP_OC_EXT_DEF(CANON,InitiateDirectTransfer),
	PTP_OC_EXT_DEF(CANON,TerminateDirectTransfer),
	PTP_OC_EXT_DEF(CANON,SendObjectInfoByPath),
	PTP_OC_EXT_DEF(CANON,SendObjectByPath),
	PTP_OC_EXT_DEF(CANON,InitiateDirectTansferEx),
	PTP_OC_EXT_DEF(CANON,GetAncillaryObjectHandles),
	PTP_OC_EXT_DEF(CANON,GetTreeInfo),
	PTP_OC_EXT_DEF(CANON,GetTreeSize),
	PTP_OC_EXT_DEF(CANON,NotifyProgress),
	PTP_OC_EXT_DEF(CANON,NotifyCancelAccepted),
//    PTP_OC_EXT_DEF(CANON_902C),
	PTP_OC_EXT_DEF(CANON,GetDirectory),
//    PTP_OC_EXT_DEF(CANON_902E),
//    PTP_OC_EXT_DEF(CANON_902F),
	PTP_OC_EXT_DEF(CANON,SetPairingInfo),
	PTP_OC_EXT_DEF(CANON,GetPairingInfo),
	PTP_OC_EXT_DEF(CANON,DeletePairingInfo),
	PTP_OC_EXT_DEF(CANON,GetMACAddress),
	PTP_OC_EXT_DEF(CANON,SetDisplayMonitor),
	PTP_OC_EXT_DEF(CANON,PairingComplete),
	PTP_OC_EXT_DEF(CANON,GetWirelessMAXChannel),
// ### Magic Lantern
	PTP_OC_EXT_DEF(CANON,InitiateEventProc0),
	PTP_OC_EXT_DEF(CANON,TerminateEventProc_051),
	PTP_OC_EXT_DEF(CANON,ExecuteEventProc),
	PTP_OC_EXT_DEF(CANON,GetEventProcReturnData),
	PTP_OC_EXT_DEF(CANON,IsEventProcRunning),
	PTP_OC_EXT_DEF(CANON,QuerySizeOfTransparentMemory),
	PTP_OC_EXT_DEF(CANON,LoadTransparentMemory),
	PTP_OC_EXT_DEF(CANON,SaveTransparentMemory),
	PTP_OC_EXT_DEF(CANON,QuickLoadTransparentMemory),
	PTP_OC_EXT_DEF(CANON,InitiateEventProc1),
	PTP_OC_EXT_DEF(CANON,TerminateEventProc_05D),
// ### Gphoto
	PTP_OC_EXT_DEF(CANON,GetWebServiceSpec),
	PTP_OC_EXT_DEF(CANON,IsNeoKabotanProcMode),
	PTP_OC_EXT_DEF(CANON,GetWebServiceData),
	PTP_OC_EXT_DEF(CANON,SetWebServiceData),
	PTP_OC_EXT_DEF(CANON,DeleteWebServiceData),
	PTP_OC_EXT_DEF(CANON,GetRootCertificateSpec),
	PTP_OC_EXT_DEF(CANON,GetRootCertificateData),
	PTP_OC_EXT_DEF(CANON,SetRootCertificateData),
	PTP_OC_EXT_DEF(CANON,DeleteRootCertificateData),
	PTP_OC_EXT_DEF(CANON,GetGpsMobilelinkObjectInfo),
	PTP_OC_EXT_DEF(CANON,SendGpsTagInfo),
	PTP_OC_EXT_DEF(CANON,GetTranscodeApproxSize),
	PTP_OC_EXT_DEF(CANON,RequestTranscodeStart),
	PTP_OC_EXT_DEF(CANON,RequestTranscodeCancel),
	PTP_OC_EXT_DEF(CANON,SetRemoteShootingMode),
	PTP_OC_EXT_DEF(CANON,EOS_GetStorageIDs),
	PTP_OC_EXT_DEF(CANON,EOS_GetStorageInfo),
	PTP_OC_EXT_DEF(CANON,EOS_GetObjectInfo),
	PTP_OC_EXT_DEF(CANON,EOS_GetObject),
	PTP_OC_EXT_DEF(CANON,EOS_DeleteObject),
	PTP_OC_EXT_DEF(CANON,EOS_FormatStore),
	PTP_OC_EXT_DEF(CANON,EOS_GetPartialObject),
	PTP_OC_EXT_DEF(CANON,EOS_GetDeviceInfoEx),
	PTP_OC_EXT_DEF(CANON,EOS_GetObjectInfoEx),
	PTP_OC_EXT_DEF(CANON,EOS_GetThumbEx),
	PTP_OC_EXT_DEF(CANON,EOS_SendPartialObject),
	PTP_OC_EXT_DEF(CANON,EOS_SetObjectAttributes),
	PTP_OC_EXT_DEF(CANON,EOS_GetObjectTime),
	PTP_OC_EXT_DEF(CANON,EOS_SetObjectTime),
	PTP_OC_EXT_DEF(CANON,EOS_RemoteRelease),
	PTP_OC_EXT_DEF(CANON,EOS_SetDevicePropValueEx),
// ### Magic Lantern,
	PTP_OC_EXT_DEF(CANON,EOS_SendObjectEx),
	PTP_OC_EXT_DEF(CANON,EOS_CreateObject),
// ### Gphoto
	PTP_OC_EXT_DEF(CANON,EOS_GetRemoteMode),
	PTP_OC_EXT_DEF(CANON,EOS_SetRemoteMode),
	PTP_OC_EXT_DEF(CANON,EOS_SetEventMode),
	PTP_OC_EXT_DEF(CANON,EOS_GetEvent),
	PTP_OC_EXT_DEF(CANON,EOS_TransferComplete),
	PTP_OC_EXT_DEF(CANON,EOS_CancelTransfer),
	PTP_OC_EXT_DEF(CANON,EOS_ResetTransfer),
	PTP_OC_EXT_DEF(CANON,EOS_PCHDDCapacity),
	PTP_OC_EXT_DEF(CANON,EOS_SetUILock),
	PTP_OC_EXT_DEF(CANON,EOS_ResetUILock),
	PTP_OC_EXT_DEF(CANON,EOS_KeepDeviceOn),
	PTP_OC_EXT_DEF(CANON,EOS_SetNullPacketMode),
	PTP_OC_EXT_DEF(CANON,EOS_UpdateFirmware),
	PTP_OC_EXT_DEF(CANON,EOS_TransferCompleteDT),
	PTP_OC_EXT_DEF(CANON,EOS_CancelTransferDT),
	PTP_OC_EXT_DEF(CANON,EOS_SetWftProfile),
	PTP_OC_EXT_DEF(CANON,EOS_GetWftProfile),
	PTP_OC_EXT_DEF(CANON,EOS_SetProfileToWft),
	PTP_OC_EXT_DEF(CANON,EOS_BulbStart),
	PTP_OC_EXT_DEF(CANON,EOS_BulbEnd),
	PTP_OC_EXT_DEF(CANON,EOS_RequestDevicePropValue),
	PTP_OC_EXT_DEF(CANON,EOS_RemoteReleaseOn),
	PTP_OC_EXT_DEF(CANON,EOS_RemoteReleaseOff),
	PTP_OC_EXT_DEF(CANON,EOS_RegistBackgroundImage),
	PTP_OC_EXT_DEF(CANON,EOS_ChangePhotoStudioMode),
	PTP_OC_EXT_DEF(CANON,EOS_GetPartialObjectEx),
// ### Magic Lantern,
	PTP_OC_EXT_DEF(CANON,EOS_ReSizeImageData),
	PTP_OC_EXT_DEF(CANON,EOS_GetReSizeData),
	PTP_OC_EXT_DEF(CANON,EOS_ReleaseReSizeData),
// ### Gphoto
	PTP_OC_EXT_DEF(CANON,EOS_ResetMirrorLockupState),
	PTP_OC_EXT_DEF(CANON,EOS_PopupBuiltinFlash),
	PTP_OC_EXT_DEF(CANON,EOS_EndGetPartialObjectEx),
	PTP_OC_EXT_DEF(CANON,EOS_MovieSelectSWOn),
	PTP_OC_EXT_DEF(CANON,EOS_MovieSelectSWOff),
	PTP_OC_EXT_DEF(CANON,EOS_GetCTGInfo),
	PTP_OC_EXT_DEF(CANON,EOS_GetLensAdjust),
	PTP_OC_EXT_DEF(CANON,EOS_SetLensAdjust),
	PTP_OC_EXT_DEF(CANON,EOS_ReadyToSendMusic),
	PTP_OC_EXT_DEF(CANON,EOS_CreateHandle),
	PTP_OC_EXT_DEF(CANON,EOS_SendPartialObjectEx),
	PTP_OC_EXT_DEF(CANON,EOS_EndSendPartialObjectEx),
	PTP_OC_EXT_DEF(CANON,EOS_SetCTGInfo),
	PTP_OC_EXT_DEF(CANON,EOS_SetRequestOLCInfoGroup),
	PTP_OC_EXT_DEF(CANON,EOS_SetRequestRollingPitchingLevel),
	PTP_OC_EXT_DEF(CANON,EOS_GetCameraSupport),
	PTP_OC_EXT_DEF(CANON,EOS_SetRating),
	PTP_OC_EXT_DEF(CANON,EOS_RequestInnerDevelopStart),
	PTP_OC_EXT_DEF(CANON,EOS_RequestInnerDevelopParamChange),
	PTP_OC_EXT_DEF(CANON,EOS_RequestInnerDevelopEnd),
	PTP_OC_EXT_DEF(CANON,EOS_GpsLoggingDataMode),
	PTP_OC_EXT_DEF(CANON,EOS_GetGpsLogCurrentHandle),
	PTP_OC_EXT_DEF(CANON,EOS_SetImageRecoveryData),
	PTP_OC_EXT_DEF(CANON,EOS_GetImageRecoveryList),
	PTP_OC_EXT_DEF(CANON,EOS_FormatImageRecoveryData),
	PTP_OC_EXT_DEF(CANON,EOS_GetPresetLensAdjustParam),
	PTP_OC_EXT_DEF(CANON,EOS_GetRawDispImage),
	PTP_OC_EXT_DEF(CANON,EOS_SaveImageRecoveryData),
	PTP_OC_EXT_DEF(CANON,EOS_RequestBLE),
	PTP_OC_EXT_DEF(CANON,EOS_DrivePowerZoom),
// ### Magic Lantern,
	PTP_OC_EXT_DEF(CANON,EOS_SendTimeSyncMessage),
// ### Gphoto
	PTP_OC_EXT_DEF(CANON,EOS_GetIptcData),
	PTP_OC_EXT_DEF(CANON,EOS_SetIptcData),
	PTP_OC_EXT_DEF(CANON,EOS_InitiateViewfinder),
	PTP_OC_EXT_DEF(CANON,EOS_TerminateViewfinder),
	PTP_OC_EXT_DEF(CANON,EOS_GetViewFinderData),
	PTP_OC_EXT_DEF(CANON,EOS_DoAf),
	PTP_OC_EXT_DEF(CANON,EOS_DriveLens),
	PTP_OC_EXT_DEF(CANON,EOS_DepthOfFieldPreview),
	PTP_OC_EXT_DEF(CANON,EOS_ClickWB),
	PTP_OC_EXT_DEF(CANON,EOS_Zoom),
	PTP_OC_EXT_DEF(CANON,EOS_ZoomPosition),
	PTP_OC_EXT_DEF(CANON,EOS_SetLiveAfFrame),
	PTP_OC_EXT_DEF(CANON,EOS_TouchAfPosition),
	PTP_OC_EXT_DEF(CANON,EOS_SetLvPcFlavoreditMode),
	PTP_OC_EXT_DEF(CANON,EOS_SetLvPcFlavoreditParam),
	PTP_OC_EXT_DEF(CANON,EOS_RequestSensorCleaning),
	PTP_OC_EXT_DEF(CANON,EOS_AfCancel),
	PTP_OC_EXT_DEF(CANON,EOS_SetImageRecoveryDataEx),
	PTP_OC_EXT_DEF(CANON,EOS_GetImageRecoveryListEx),
	PTP_OC_EXT_DEF(CANON,EOS_CompleteAutoSendImages),
	PTP_OC_EXT_DEF(CANON,EOS_NotifyAutoTransferStatus),
	PTP_OC_EXT_DEF(CANON,EOS_GetReducedObject),
	PTP_OC_EXT_DEF(CANON,EOS_GetObjectInfo64),
	PTP_OC_EXT_DEF(CANON,EOS_GetObject64),
	PTP_OC_EXT_DEF(CANON,EOS_GetPartialObject64),
	PTP_OC_EXT_DEF(CANON,EOS_GetObjectInfoEx64),
	PTP_OC_EXT_DEF(CANON,EOS_GetPartialObjectEX64),
	PTP_OC_EXT_DEF(CANON,EOS_CreateHandle64),
	PTP_OC_EXT_DEF(CANON,EOS_NotifySaveComplete),
	PTP_OC_EXT_DEF(CANON,EOS_GetTranscodedBlock),
	PTP_OC_EXT_DEF(CANON,EOS_TransferCompleteTranscodedBlock),
	PTP_OC_EXT_DEF(CANON,EOS_NotifyEstimateNumberofImport),
	PTP_OC_EXT_DEF(CANON,EOS_NotifyNumberofImported),
	PTP_OC_EXT_DEF(CANON,EOS_NotifySizeOfPartialDataTransfer),
// ### Magic Lantern,
	PTP_OC_EXT_DEF(CANON,EOS_GetObjectUrl),
// ### Gphoto
	PTP_OC_EXT_DEF(CANON,EOS_NotifyFinish),
	PTP_OC_EXT_DEF(CANON,EOS_GetWFTData),
	PTP_OC_EXT_DEF(CANON,EOS_SetWFTData),
	PTP_OC_EXT_DEF(CANON,EOS_ChangeWFTSettingNumber),
	PTP_OC_EXT_DEF(CANON,EOS_GetPictureStylePCFlavorParam),
	PTP_OC_EXT_DEF(CANON,EOS_SetPictureStylePCFlavorParam),
	PTP_OC_EXT_DEF(CANON,EOS_GetObjectURL),
	PTP_OC_EXT_DEF(CANON,EOS_SetCAssistMode),
	PTP_OC_EXT_DEF(CANON,EOS_GetCAssistPresetThumb),
	PTP_OC_EXT_DEF(CANON,EOS_SetFELock),
	PTP_OC_EXT_DEF(CANON,EOS_DeleteWFTSettingNumber),
	PTP_OC_EXT_DEF(CANON,EOS_SetDefaultCameraSetting),
	PTP_OC_EXT_DEF(CANON,EOS_GetAEData),
	PTP_OC_EXT_DEF(CANON,EOS_SendHostInfo),
	PTP_OC_EXT_DEF(CANON,EOS_NotifyNetworkError),
// ### Magic Lantern,
	PTP_OC_EXT_DEF(CANON,EOS_ceresOpenFileValue),
	PTP_OC_EXT_DEF(CANON,EOS_ceresCreateFileValue),
	PTP_OC_EXT_DEF(CANON,EOS_ceresRemoveFileValue),
	PTP_OC_EXT_DEF(CANON,EOS_ceresCloseFileValue),
	PTP_OC_EXT_DEF(CANON,EOS_ceresGetWriteObject),
	PTP_OC_EXT_DEF(CANON,EOS_ceresSEndReadObject),
	PTP_OC_EXT_DEF(CANON,EOS_ceresFileAttributesValue),
	PTP_OC_EXT_DEF(CANON,EOS_ceresFileTimeValue),
	PTP_OC_EXT_DEF(CANON,EOS_ceresSeekFileValue),
	PTP_OC_EXT_DEF(CANON,EOS_ceresCreateDirectoryValue),
	PTP_OC_EXT_DEF(CANON,EOS_ceresRemoveDirectoryValue),
	PTP_OC_EXT_DEF(CANON,EOS_ceresSEndFileInfo),
	PTP_OC_EXT_DEF(CANON,EOS_ceresSEndFileInfoListEx),
	PTP_OC_EXT_DEF(CANON,EOS_ceresSEndDriveInfo),
	PTP_OC_EXT_DEF(CANON,EOS_ceresNotifyDriveStatus),
	PTP_OC_EXT_DEF(CANON,EOS_ceresSplitFileValue),
	PTP_OC_EXT_DEF(CANON,EOS_ceresRenameFileValue),
	PTP_OC_EXT_DEF(CANON,EOS_ceresTruncateFileValue),
	PTP_OC_EXT_DEF(CANON,EOS_SendCertData),
	PTP_OC_EXT_DEF(CANON,EOS_DistinctionRTC),
	PTP_OC_EXT_DEF(CANON,EOS_NotifyGpsTimeSyncStatus),
	PTP_OC_EXT_DEF(CANON,EOS_GetAdapterFirmData),
	PTP_OC_EXT_DEF(CANON,EOS_ceresSEndScanningResult),
	PTP_OC_EXT_DEF(CANON,EOS_ceresSEndHostInfo),
	PTP_OC_EXT_DEF(CANON,EOS_NotifyAdapterStatus),
	PTP_OC_EXT_DEF(CANON,EOS_ceresNotifyNetworkError),
// ### Gphoto
	PTP_OC_EXT_DEF(CANON,EOS_AdapterTransferProgress),
// ### Magic Lantern,
	PTP_OC_EXT_DEF(CANON,EOS_ceresRequestAdapterProperty),
	PTP_OC_EXT_DEF(CANON,EOS_ceresSEndWpsPinCode),
	PTP_OC_EXT_DEF(CANON,EOS_ceresSEndWizardInfo),
// ### Gphoto
	PTP_OC_EXT_DEF(CANON,EOS_TransferCompleteFTP),
	PTP_OC_EXT_DEF(CANON,EOS_CancelTransferFTP),
// ### Magic Lantern,
	PTP_OC_EXT_DEF(CANON,EOS_ceresGetUpdateFileData),
	PTP_OC_EXT_DEF(CANON,EOS_NotifyUpdateProgress),
	PTP_OC_EXT_DEF(CANON,EOS_ceresSEndFactoryProperty),
	PTP_OC_EXT_DEF(CANON,EOS_ceresSEndGpsInfo),
	PTP_OC_EXT_DEF(CANON,EOS_ceresSEndBtPairingResult),
// ### Gphoto
// ML calls this PTP_OC_CANON_EOS_ceresNotifyBtStatus),
	PTP_OC_EXT_DEF(CANON,EOS_NotifyBtStatus),
// ### Magic Lantern
	PTP_OC_EXT_DEF(CANON,EOS_SendTimeSyncInfo),
// ### Gphoto
	PTP_OC_EXT_DEF(CANON,EOS_SetAdapterBatteryReport),
	PTP_OC_EXT_DEF(CANON,EOS_FAPIMessageTX),
	PTP_OC_EXT_DEF(CANON,EOS_FAPIMessageRX),
	PTP_OC_EXT_DEF(CANON,CHDK),
	PTP_OC_EXT_DEF(CANON,MagicLantern),
	{0,NULL},
};

static PTPCodeDef ptp_opcodes_NIKON[] = {
/* Nikon extension Operation Codes */
	PTP_OC_EXT_DEF(NIKON,GetProfileAllData),
	PTP_OC_EXT_DEF(NIKON,SendProfileData),
	PTP_OC_EXT_DEF(NIKON,DeleteProfile),
	PTP_OC_EXT_DEF(NIKON,SetProfileData),
	PTP_OC_EXT_DEF(NIKON,AdvancedTransfer),
	PTP_OC_EXT_DEF(NIKON,GetFileInfoInBlock),
	PTP_OC_EXT_DEF(NIKON,InitiateCaptureRecInSdram),
	PTP_OC_EXT_DEF(NIKON,AfDrive),
	PTP_OC_EXT_DEF(NIKON,ChangeCameraMode),
	PTP_OC_EXT_DEF(NIKON,DelImageSDRAM),
	PTP_OC_EXT_DEF(NIKON,GetLargeThumb),
	PTP_OC_EXT_DEF(NIKON,CurveDownload),
	PTP_OC_EXT_DEF(NIKON,CurveUpload),
	PTP_OC_EXT_DEF(NIKON,GetEvent),
	PTP_OC_EXT_DEF(NIKON,DeviceReady),
	PTP_OC_EXT_DEF(NIKON,SetPreWBData),
	PTP_OC_EXT_DEF(NIKON,GetVendorPropCodes),
	PTP_OC_EXT_DEF(NIKON,AfCaptureSDRAM),
	PTP_OC_EXT_DEF(NIKON,GetPictCtrlData),
	PTP_OC_EXT_DEF(NIKON,SetPictCtrlData),
	PTP_OC_EXT_DEF(NIKON,DelCstPicCtrl),
	PTP_OC_EXT_DEF(NIKON,GetPicCtrlCapability),
	PTP_OC_EXT_DEF(NIKON,GetPreviewImg),
	PTP_OC_EXT_DEF(NIKON,StartLiveView),
	PTP_OC_EXT_DEF(NIKON,EndLiveView),
	PTP_OC_EXT_DEF(NIKON,GetLiveViewImg),
	PTP_OC_EXT_DEF(NIKON,MfDrive),
	PTP_OC_EXT_DEF(NIKON,ChangeAfArea),
	PTP_OC_EXT_DEF(NIKON,AfDriveCancel),
	PTP_OC_EXT_DEF(NIKON,InitiateCaptureRecInMedia),
	PTP_OC_EXT_DEF(NIKON,GetVendorStorageIDs),
	PTP_OC_EXT_DEF(NIKON,StartMovieRecInCard),
	PTP_OC_EXT_DEF(NIKON,EndMovieRec),
	PTP_OC_EXT_DEF(NIKON,TerminateCapture),
	PTP_OC_EXT_DEF(NIKON,GetFhdPicture),
	PTP_OC_EXT_DEF(NIKON,GetDevicePTPIPInfo),
	PTP_OC_EXT_DEF(NIKON,GetPartialObjectHiSpeed),
	PTP_OC_EXT_DEF(NIKON,StartSpotWb),
	PTP_OC_EXT_DEF(NIKON,EndSpotWb),
	PTP_OC_EXT_DEF(NIKON,ChangeSpotWbArea),
	PTP_OC_EXT_DEF(NIKON,MeasureSpotWb),
	PTP_OC_EXT_DEF(NIKON,EndSpotWbResultDisp),
	PTP_OC_EXT_DEF(NIKON,CancelImagesInSDRAM),
	PTP_OC_EXT_DEF(NIKON,GetSBHandles),
	PTP_OC_EXT_DEF(NIKON,GetSBAttrDesc),
	PTP_OC_EXT_DEF(NIKON,GetSBAttrValue),
	PTP_OC_EXT_DEF(NIKON,SetSBAttrValue),
	PTP_OC_EXT_DEF(NIKON,GetSBGroupAttrDesc),
	PTP_OC_EXT_DEF(NIKON,GetSBGroupAttrValue),
	PTP_OC_EXT_DEF(NIKON,SetSBGroupAttrValue),
	PTP_OC_EXT_DEF(NIKON,TestFlash),
	PTP_OC_EXT_DEF(NIKON,GetEventEx),
	PTP_OC_EXT_DEF(NIKON,MirrorUpCancel),
	PTP_OC_EXT_DEF(NIKON,PowerZoomByFocalLength),
	PTP_OC_EXT_DEF(NIKON,ActiveSelectionControl),
	PTP_OC_EXT_DEF(NIKON,SaveCameraSetting),
	PTP_OC_EXT_DEF(NIKON,GetObjectSize),
	PTP_OC_EXT_DEF(NIKON,ChangeMonitorOff),
	PTP_OC_EXT_DEF(NIKON,GetLiveViewCompressedSize),
	PTP_OC_EXT_DEF(NIKON,StartTracking),
	PTP_OC_EXT_DEF(NIKON,EndTracking),
	PTP_OC_EXT_DEF(NIKON,ChangeAELock),
	PTP_OC_EXT_DEF(NIKON,GetLiveViewImageEx),
	PTP_OC_EXT_DEF(NIKON,GetPartialObjectEx),
	PTP_OC_EXT_DEF(NIKON,GetManualSettingLensData),
	PTP_OC_EXT_DEF(NIKON,InitiatePixelMapping),
	PTP_OC_EXT_DEF(NIKON,GetObjectsMetaData),
	PTP_OC_EXT_DEF(NIKON,ChangeApplicationMode),
	PTP_OC_EXT_DEF(NIKON,ResetMenu),
	PTP_OC_EXT_DEF(NIKON,GetDevicePropEx),
	{0,NULL},
};

static PTPCodeDef ptp_opcodes_CASIO[] = {
/* Casio EX-F1 (from http://code.google.com/p/exf1ctrl/ ) */
	PTP_OC_EXT_DEF(CASIO,STILL_START),
	PTP_OC_EXT_DEF(CASIO,STILL_STOP),

	PTP_OC_EXT_DEF(CASIO,FOCUS),
	PTP_OC_EXT_DEF(CASIO,CF_PRESS),
	PTP_OC_EXT_DEF(CASIO,CF_RELEASE),
	PTP_OC_EXT_DEF(CASIO,GET_OBJECT_INFO),

	PTP_OC_EXT_DEF(CASIO,SHUTTER),
	PTP_OC_EXT_DEF(CASIO,GET_STILL_HANDLES),
	PTP_OC_EXT_DEF(CASIO,STILL_RESET),
	PTP_OC_EXT_DEF(CASIO,HALF_PRESS),
	PTP_OC_EXT_DEF(CASIO,HALF_RELEASE),
	PTP_OC_EXT_DEF(CASIO,CS_PRESS),
	PTP_OC_EXT_DEF(CASIO,CS_RELEASE),

	PTP_OC_EXT_DEF(CASIO,ZOOM),
	PTP_OC_EXT_DEF(CASIO,CZ_PRESS),
	PTP_OC_EXT_DEF(CASIO,CZ_RELEASE),

	PTP_OC_EXT_DEF(CASIO,MOVIE_START),
	PTP_OC_EXT_DEF(CASIO,MOVIE_STOP),
	PTP_OC_EXT_DEF(CASIO,MOVIE_PRESS),
	PTP_OC_EXT_DEF(CASIO,MOVIE_RELEASE),
	PTP_OC_EXT_DEF(CASIO,GET_MOVIE_HANDLES),
	PTP_OC_EXT_DEF(CASIO,MOVIE_RESET),

	PTP_OC_EXT_DEF(CASIO,GET_OBJECT),
	PTP_OC_EXT_DEF(CASIO,GET_THUMBNAIL),
	{0,NULL},
};

static PTPCodeDef ptp_opcodes_SONY[] = {
/* Sony stuff */
	PTP_OC_EXT_DEF(SONY,SDIOConnect),
	PTP_OC_EXT_DEF(SONY,GetSDIOGetExtDeviceInfo),
	PTP_OC_EXT_DEF(SONY,GetDevicePropdesc),
	PTP_OC_EXT_DEF(SONY,GetDevicePropertyValue),
	PTP_OC_EXT_DEF(SONY,SetControlDeviceA),
	PTP_OC_EXT_DEF(SONY,GetControlDeviceDesc),
	PTP_OC_EXT_DEF(SONY,SetControlDeviceB),
	PTP_OC_EXT_DEF(SONY,GetAllDevicePropData),
	PTP_OC_EXT_DEF(SONY,QX_SetExtPictureProfile),
	PTP_OC_EXT_DEF(SONY,QX_GetExtPictureProfile),
	PTP_OC_EXT_DEF(SONY,QX_GetExtLensInfo),
	PTP_OC_EXT_DEF(SONY,QX_SendUpdateFile),
	PTP_OC_EXT_DEF(SONY,QX_GetAllDevicePropData),
	PTP_OC_EXT_DEF(SONY,QX_SetControlDeviceB),
	PTP_OC_EXT_DEF(SONY,QX_SetControlDeviceA),
	PTP_OC_EXT_DEF(SONY,QX_GetSDIOGetExtDeviceInfo),
	PTP_OC_EXT_DEF(SONY,QX_Connect),
	{0,NULL},
};

static PTPCodeDef ptp_opcodes_MTP[] = {
/* Microsoft / MTP extension codes */
	PTP_OC_EXT_DEF(MTP,GetObjectPropsSupported),
	PTP_OC_EXT_DEF(MTP,GetObjectPropDesc),
	PTP_OC_EXT_DEF(MTP,GetObjectPropValue),
	PTP_OC_EXT_DEF(MTP,SetObjectPropValue),
	PTP_OC_EXT_DEF(MTP,GetObjPropList),
	PTP_OC_EXT_DEF(MTP,SetObjPropList),
	PTP_OC_EXT_DEF(MTP,GetInterdependendPropdesc),
	PTP_OC_EXT_DEF(MTP,SendObjectPropList),
	PTP_OC_EXT_DEF(MTP,GetObjectReferences),
	PTP_OC_EXT_DEF(MTP,SetObjectReferences),
	PTP_OC_EXT_DEF(MTP,UpdateDeviceFirmware),
	PTP_OC_EXT_DEF(MTP,Skip),
	{0,NULL},
};

/* not included with core MTP because codes overlap with canon and other extensions */
static PTPCodeDef ptp_opcodes_MTP_EXT[] = {
/*
 * Windows Media Digital Rights Management for Portable Devices
 * Extension Codes (microsoft.com/WMDRMPD: 10.1)
 */
	PTP_OC_EXT_DEF(MTP,WMDRMPD_GetSecureTimeChallenge),
	PTP_OC_EXT_DEF(MTP,WMDRMPD_GetSecureTimeResponse),
	PTP_OC_EXT_DEF(MTP,WMDRMPD_SetLicenseResponse),
	PTP_OC_EXT_DEF(MTP,WMDRMPD_GetSyncList),
	PTP_OC_EXT_DEF(MTP,WMDRMPD_SendMeterChallengeQuery),
	PTP_OC_EXT_DEF(MTP,WMDRMPD_GetMeterChallenge),
	PTP_OC_EXT_DEF(MTP,WMDRMPD_SetMeterResponse),
	PTP_OC_EXT_DEF(MTP,WMDRMPD_CleanDataStore),
	PTP_OC_EXT_DEF(MTP,WMDRMPD_GetLicenseState),
	PTP_OC_EXT_DEF(MTP,WMDRMPD_SendWMDRMPDCommand),
	PTP_OC_EXT_DEF(MTP,WMDRMPD_SendWMDRMPDRequest),

/*
 * Windows Media Digital Rights Management for Portable Devices
 * Extension Codes (microsoft.com/WMDRMPD: 10.1)
 * Below are operations that have no public documented identifier
 * associated with them "Vendor-defined Command Code"
 */
	PTP_OC_EXT_DEF(MTP,WMDRMPD_SendWMDRMPDAppRequest),
	PTP_OC_EXT_DEF(MTP,WMDRMPD_GetWMDRMPDAppResponse),
	PTP_OC_EXT_DEF(MTP,WMDRMPD_EnableTrustedFilesOperations),
	PTP_OC_EXT_DEF(MTP,WMDRMPD_DisableTrustedFilesOperations),
	PTP_OC_EXT_DEF(MTP,WMDRMPD_EndTrustedAppSession),
/* ^^^ guess ^^^ */

/*
 * Microsoft Advanced Audio/Video Transfer
 * Extensions (microsoft.com/AAVT: 1.0)
 */
	PTP_OC_EXT_DEF(MTP,AAVT_OpenMediaSession),
	PTP_OC_EXT_DEF(MTP,AAVT_CloseMediaSession),
	PTP_OC_EXT_DEF(MTP,AAVT_GetNextDataBlock),
	PTP_OC_EXT_DEF(MTP,AAVT_SetCurrentTimePosition),

/*
 * Windows Media Digital Rights Management for Network Devices
 * Extensions (microsoft.com/WMDRMND: 1.0) MTP/IP?
 */
	PTP_OC_EXT_DEF(MTP,WMDRMND_SendRegistrationRequest),
	PTP_OC_EXT_DEF(MTP,WMDRMND_GetRegistrationResponse),
	PTP_OC_EXT_DEF(MTP,WMDRMND_GetProximityChallenge),
	PTP_OC_EXT_DEF(MTP,WMDRMND_SendProximityResponse),
	PTP_OC_EXT_DEF(MTP,WMDRMND_SendWMDRMNDLicenseRequest),
	PTP_OC_EXT_DEF(MTP,WMDRMND_GetWMDRMNDLicenseResponse),

/*
 * Windows Media Player Portiable Devices
 * Extension Codes (microsoft.com/WMPPD: 11.1)
 */
	PTP_OC_EXT_DEF(MTP,WMPPD_ReportAddedDeletedItems),
	PTP_OC_EXT_DEF(MTP,WMPPD_ReportAcquiredItems),
	PTP_OC_EXT_DEF(MTP,WMPPD_PlaylistObjectPref),

/*
 * Undocumented Zune Operation Codes
 * maybe related to WMPPD extension set?
 */
	PTP_OC_EXT_DEF(MTP,ZUNE_GETUNDEFINED001),

/* WiFi Provisioning MTP Extension Codes (microsoft.com/WPDWCN: 1.0) */
	PTP_OC_EXT_DEF(MTP,WPDWCN_ProcessWFCObject),

	{0,NULL},
};

static PTPCodeDef ptp_opcodes_OLYMPUS[] = {
/* Olympus OMD series commands */
	PTP_OC_EXT_DEF(OLYMPUS,OMD_Capture),
	PTP_OC_EXT_DEF(OLYMPUS,GetLiveViewImage),
	PTP_OC_EXT_DEF(OLYMPUS,OMD_GetImage),
	PTP_OC_EXT_DEF(OLYMPUS,OMD_ChangedProperties),
	PTP_OC_EXT_DEF(OLYMPUS,OMD_MFDrive),
	PTP_OC_EXT_DEF(OLYMPUS,OMD_SetProperties),

/* Olympus E series commands */

	PTP_OC_EXT_DEF(OLYMPUS,Capture),
	PTP_OC_EXT_DEF(OLYMPUS,SelfCleaning),
	PTP_OC_EXT_DEF(OLYMPUS,SetRGBGain),
	PTP_OC_EXT_DEF(OLYMPUS,SetPresetMode),
	PTP_OC_EXT_DEF(OLYMPUS,SetWBBiasAll),
	PTP_OC_EXT_DEF(OLYMPUS,GetCameraControlMode),
	PTP_OC_EXT_DEF(OLYMPUS,SetCameraControlMode),
	PTP_OC_EXT_DEF(OLYMPUS,SetWBRGBGain),
	PTP_OC_EXT_DEF(OLYMPUS,GetDeviceInfo),
	PTP_OC_EXT_DEF(OLYMPUS,OpenSession),
	PTP_OC_EXT_DEF(OLYMPUS,SetDateTime),
	PTP_OC_EXT_DEF(OLYMPUS,GetDateTime),
	PTP_OC_EXT_DEF(OLYMPUS,SetCameraID),
	PTP_OC_EXT_DEF(OLYMPUS,GetCameraID),

	{0,NULL},
};

static PTPCodeDef ptp_opcodes_ANDROID[] = {
/* Android Random I/O Extensions Codes */
	PTP_OC_EXT_DEF(ANDROID,GetPartialObject64),
	PTP_OC_EXT_DEF(ANDROID,SendPartialObject),
	PTP_OC_EXT_DEF(ANDROID,TruncateObject),
	PTP_OC_EXT_DEF(ANDROID,BeginEditObject),
	PTP_OC_EXT_DEF(ANDROID,EndEditObject),

	{0,NULL},
};

static PTPCodeDef ptp_opcodes_LEICA[] = {
/* Leica opcodes, from Lightroom tether plugin */
/* also from:
 * https://alexhude.github.io/2019/01/24/hacking-leica-m240.html */
	PTP_OC_EXT_DEF(LEICA,SetCameraSettings),
	PTP_OC_EXT_DEF(LEICA,GetCameraSettings),
	PTP_OC_EXT_DEF(LEICA,GetLensParameter),
	PTP_OC_EXT_DEF(LEICA,LEReleaseStages),
	PTP_OC_EXT_DEF(LEICA,LEOpenSession),
	PTP_OC_EXT_DEF(LEICA,LECloseSession),
	PTP_OC_EXT_DEF(LEICA,RequestObjectTransferReady),
	PTP_OC_EXT_DEF(LEICA,GetGeoTrackingData),
	PTP_OC_EXT_DEF(LEICA,OpenDebugSession),
	PTP_OC_EXT_DEF(LEICA,CloseDebugSession),
	PTP_OC_EXT_DEF(LEICA,GetDebugBuffer),
	PTP_OC_EXT_DEF(LEICA,DebugCommandString),
	PTP_OC_EXT_DEF(LEICA,GetDebugRoute),
	PTP_OC_EXT_DEF(LEICA,SetIPTCData),
	PTP_OC_EXT_DEF(LEICA,GetIPTCData),
	PTP_OC_EXT_DEF(LEICA,LEControlAutoFocus),
	PTP_OC_EXT_DEF(LEICA,LEControlBulbExposure),
	PTP_OC_EXT_DEF(LEICA,LEControlContinuousExposure),
	PTP_OC_EXT_DEF(LEICA,901b),
	PTP_OC_EXT_DEF(LEICA,LEControlPhotoLiveView),
	PTP_OC_EXT_DEF(LEICA,LEKeepSessionActive),
	PTP_OC_EXT_DEF(LEICA,LEMoveLens),
	PTP_OC_EXT_DEF(LEICA,Get3DAxisData),
	PTP_OC_EXT_DEF(LEICA,LESetZoomMode),
	PTP_OC_EXT_DEF(LEICA,LESetFocusCrossPosition),
	PTP_OC_EXT_DEF(LEICA,LESetDisplayWindowPosition),
	PTP_OC_EXT_DEF(LEICA,LEGetStreamData),
	PTP_OC_EXT_DEF(LEICA,OpenLiveViewSession),
	PTP_OC_EXT_DEF(LEICA,CloseLiveViewSession),
	PTP_OC_EXT_DEF(LEICA,LESetDateTime),
	PTP_OC_EXT_DEF(LEICA,GetObjectPropListPaginated),
	PTP_OC_EXT_DEF(LEICA,OpenProductionSession),
	PTP_OC_EXT_DEF(LEICA,CloseProductionSession),
	PTP_OC_EXT_DEF(LEICA,UpdateFirmware),
	PTP_OC_EXT_DEF(LEICA,OpenOSDSession),
	PTP_OC_EXT_DEF(LEICA,CloseOSDSession),
	PTP_OC_EXT_DEF(LEICA,GetOSDData),
	PTP_OC_EXT_DEF(LEICA,GetFirmwareStruct),
	PTP_OC_EXT_DEF(LEICA,GetDebugMenu),
	PTP_OC_EXT_DEF(LEICA,SetDebugMenu),
	PTP_OC_EXT_DEF(LEICA,OdinMessage),
	PTP_OC_EXT_DEF(LEICA,GetDebugObjectHandles),
	PTP_OC_EXT_DEF(LEICA,GetDebugObject),
	PTP_OC_EXT_DEF(LEICA,DeleteDebugObject),
	PTP_OC_EXT_DEF(LEICA,GetDebugObjectInfo),
	PTP_OC_EXT_DEF(LEICA,WriteDebugObject),
	PTP_OC_EXT_DEF(LEICA,CreateDebugObject),
	PTP_OC_EXT_DEF(LEICA,Calibrate3DAxis),
	PTP_OC_EXT_DEF(LEICA,MagneticCalibration),
	PTP_OC_EXT_DEF(LEICA,GetViewFinderData),
	{0,NULL},
};

static PTPCodeDef ptp_opcodes_PARROT[] = {
	PTP_OC_EXT_DEF(PARROT,GetSunshineValues),
	PTP_OC_EXT_DEF(PARROT,GetTemperatureValues),
	PTP_OC_EXT_DEF(PARROT,GetAngleValues),
	PTP_OC_EXT_DEF(PARROT,GetGpsValues),
	PTP_OC_EXT_DEF(PARROT,GetGyroscopeValues),
	PTP_OC_EXT_DEF(PARROT,GetAccelerometerValues),
	PTP_OC_EXT_DEF(PARROT,GetMagnetometerValues),
	PTP_OC_EXT_DEF(PARROT,GetImuValues),
	PTP_OC_EXT_DEF(PARROT,GetStatusMask),
	PTP_OC_EXT_DEF(PARROT,EjectStorage),
	PTP_OC_EXT_DEF(PARROT,StartMagnetoCalib),
	PTP_OC_EXT_DEF(PARROT,StopMagnetoCalib),
	PTP_OC_EXT_DEF(PARROT,MagnetoCalibStatus),
	PTP_OC_EXT_DEF(PARROT,SendFirmwareUpdate),
	{0,NULL},
};

static PTPCodeDef ptp_opcodes_PANASONIC[] = {
	PTP_OC_EXT_DEF(PANASONIC,9101),
	PTP_OC_EXT_DEF(PANASONIC,OpenSession),
	PTP_OC_EXT_DEF(PANASONIC,CloseSession),
	PTP_OC_EXT_DEF(PANASONIC,9104),

	PTP_OC_EXT_DEF(PANASONIC,9107),
	PTP_OC_EXT_DEF(PANASONIC,ListProperty),
	PTP_OC_EXT_DEF(PANASONIC,9110),
	PTP_OC_EXT_DEF(PANASONIC,9112),
	PTP_OC_EXT_DEF(PANASONIC,9113),

	PTP_OC_EXT_DEF(PANASONIC,9401),
	PTP_OC_EXT_DEF(PANASONIC,GetProperty),
	PTP_OC_EXT_DEF(PANASONIC,SetProperty),
	PTP_OC_EXT_DEF(PANASONIC,InitiateCapture),
	PTP_OC_EXT_DEF(PANASONIC,9405),
	PTP_OC_EXT_DEF(PANASONIC,9406),
	PTP_OC_EXT_DEF(PANASONIC,9408),
	PTP_OC_EXT_DEF(PANASONIC,9409),
	PTP_OC_EXT_DEF(PANASONIC,GetCaptureTarget),
	PTP_OC_EXT_DEF(PANASONIC,SetCaptureTarget),
	PTP_OC_EXT_DEF(PANASONIC,MovieRecControl),
	PTP_OC_EXT_DEF(PANASONIC,PowerControl),
	PTP_OC_EXT_DEF(PANASONIC,PlayControl),
	PTP_OC_EXT_DEF(PANASONIC,PlayControlPlay),
	PTP_OC_EXT_DEF(PANASONIC,9410),
	PTP_OC_EXT_DEF(PANASONIC,SetGPSDataInfo),
	PTP_OC_EXT_DEF(PANASONIC,Liveview),
	PTP_OC_EXT_DEF(PANASONIC,PollEvents),
	PTP_OC_EXT_DEF(PANASONIC,GetLiveViewParameters),
	PTP_OC_EXT_DEF(PANASONIC,SetLiveViewParameters),
	PTP_OC_EXT_DEF(PANASONIC,ManualFocusDrive),

	PTP_OC_EXT_DEF(PANASONIC,ChangeEvent),
	PTP_OC_EXT_DEF(PANASONIC,GetFromEventInfo),
	PTP_OC_EXT_DEF(PANASONIC,SendDataInfo),
	PTP_OC_EXT_DEF(PANASONIC,StartSendData),

	PTP_OC_EXT_DEF(PANASONIC,9703),
	PTP_OC_EXT_DEF(PANASONIC,9704),
	PTP_OC_EXT_DEF(PANASONIC,9705),
	PTP_OC_EXT_DEF(PANASONIC,LiveviewImage),
	PTP_OC_EXT_DEF(PANASONIC,9707),

	{0,NULL},
};

static PTPCodeDef ptp_opcodes_FUJI[] = {
/* These opcodes are probably FUJI Wifi only (but not USB) */
	PTP_OC_EXT_DEF(FUJI,InitiateMovieCapture),
	PTP_OC_EXT_DEF(FUJI,TerminateMovieCapture),
	PTP_OC_EXT_DEF(FUJI,GetCapturePreview),
	PTP_OC_EXT_DEF(FUJI,SetFocusPoint),
	PTP_OC_EXT_DEF(FUJI,ResetFocusPoint),
	PTP_OC_EXT_DEF(FUJI,GetDeviceInfo),
	PTP_OC_EXT_DEF(FUJI,SetShutterSpeed),
	PTP_OC_EXT_DEF(FUJI,SetAperture),
	PTP_OC_EXT_DEF(FUJI,SetExposureCompensation),
	PTP_OC_EXT_DEF(FUJI,CancelInitiateCapture),
	PTP_OC_EXT_DEF(FUJI,FmSendObjectInfo),
	PTP_OC_EXT_DEF(FUJI,FmSendObject),
	PTP_OC_EXT_DEF(FUJI,FmSendPartialObject),

	{0,NULL},
};

static PTPCodeDef ptp_opcodes_SIGMA[] = {
	PTP_OC_EXT_DEF(SIGMA,FP_GetCamConfig),
	PTP_OC_EXT_DEF(SIGMA,FP_GetCamStatus),
	PTP_OC_EXT_DEF(SIGMA,FP_GetDataGroup1),
	PTP_OC_EXT_DEF(SIGMA,FP_GetDataGroup2),
	PTP_OC_EXT_DEF(SIGMA,FP_GetDataGroup3),
	PTP_OC_EXT_DEF(SIGMA,FP_GetCaptureStatus),
	PTP_OC_EXT_DEF(SIGMA,FP_SetDataGroup1),
	PTP_OC_EXT_DEF(SIGMA,FP_SetDataGroup2),
	PTP_OC_EXT_DEF(SIGMA,FP_SetDataGroup3),
	PTP_OC_EXT_DEF(SIGMA,FP_ClockAdjust),
	PTP_OC_EXT_DEF(SIGMA,FP_Snap),
	PTP_OC_EXT_DEF(SIGMA,FP_ClearImageDBSingle),
	PTP_OC_EXT_DEF(SIGMA,FP_ClearImageDBAll),
	PTP_OC_EXT_DEF(SIGMA,FP_GetPictFileInfo),
	PTP_OC_EXT_DEF(SIGMA,FP_GetPartialPictFile),
	PTP_OC_EXT_DEF(SIGMA,FP_GetBigPartialPictFile),
	PTP_OC_EXT_DEF(SIGMA,FP_GetDataGroup4),
	PTP_OC_EXT_DEF(SIGMA,FP_SetDataGroup4),
	PTP_OC_EXT_DEF(SIGMA,FP_GetCamSentInfo2),
	PTP_OC_EXT_DEF(SIGMA,FP_GetCamSentInfo3),
	PTP_OC_EXT_DEF(SIGMA,FP_GetDataGroup5),
	PTP_OC_EXT_DEF(SIGMA,FP_SetDataGroup5),
	PTP_OC_EXT_DEF(SIGMA,FP_GetDataGroup6),
	PTP_OC_EXT_DEF(SIGMA,FP_SetDataGroup6),
	PTP_OC_EXT_DEF(SIGMA,FP_GetCamViewFrame),
	PTP_OC_EXT_DEF(SIGMA,FP_GetCamStatus2),
	PTP_OC_EXT_DEF(SIGMA,FP_GetPictFileInfo2),
	PTP_OC_EXT_DEF(SIGMA,FP_GetCamCanSetInfo5),
	PTP_OC_EXT_DEF(SIGMA,FP_GetCamDataGroupFocus),
	PTP_OC_EXT_DEF(SIGMA,FP_SetCamDataGroupFocus),
	PTP_OC_EXT_DEF(SIGMA,FP_GetCamDataGroupMovie),
	PTP_OC_EXT_DEF(SIGMA,FP_SetCamDataGroupMovie),
	PTP_OC_EXT_DEF(SIGMA,FP_GetCameraInfo),
	PTP_OC_EXT_DEF(SIGMA,FP_GetMovieFileInfo),
	PTP_OC_EXT_DEF(SIGMA,FP_GetPartialMovieFile),

	{0,NULL},
};

// vendor / extensions without known response codes are NULL below
//#define ptp_rcodes_MTP			NULL
//#define ptp_rcodes_MTP_EXT		NULL
#define ptp_rcodes_ANDROID		NULL

//#define ptp_rcodes_CANON		NULL
//#define ptp_rcodes_EK			NULL
//#define ptp_rcodes_NIKON		NULL
#define ptp_rcodes_CASIO		NULL
#define ptp_rcodes_SONY			NULL
#define ptp_rcodes_OLYMPUS		NULL
#define ptp_rcodes_LEICA		NULL
#define ptp_rcodes_PARROT		NULL
#define ptp_rcodes_PANASONIC	NULL
#define ptp_rcodes_FUJI			NULL
#define ptp_rcodes_SIGMA		NULL

// event codes
//#define ptp_evcodes_MTP			NULL
#define ptp_evcodes_MTP_EXT		NULL
#define ptp_evcodes_ANDROID		NULL

//#define ptp_evcodes_CANON		NULL
#define ptp_evcodes_EK			NULL
//#define ptp_evcodes_NIKON		NULL
#define ptp_evcodes_CASIO		NULL
//#define ptp_evcodes_SONY		NULL
//#define ptp_evcodes_OLYMPUS		NULL
#define ptp_evcodes_LEICA		NULL
//#define ptp_evcodes_PARROT		NULL
//#define ptp_evcodes_PANASONIC	NULL
//#define ptp_evcodes_FUJI		NULL
#define ptp_evcodes_SIGMA		NULL

// object format codes
//#define ptp_ofcodes_MTP			NULL
#define ptp_ofcodes_MTP_EXT		NULL
#define ptp_ofcodes_ANDROID		NULL

//#define ptp_ofcodes_CANON		NULL
//#define ptp_ofcodes_EK			NULL
#define ptp_ofcodes_NIKON		NULL
#define ptp_ofcodes_CASIO		NULL
//#define ptp_ofcodes_SONY		NULL
#define ptp_ofcodes_OLYMPUS		NULL
#define ptp_ofcodes_LEICA		NULL
#define ptp_ofcodes_PARROT		NULL
#define ptp_ofcodes_PANASONIC	NULL
#define ptp_ofcodes_FUJI		NULL
#define ptp_ofcodes_SIGMA		NULL

// device property codes
//#define ptp_dpcodes_MTP			NULL
//#define ptp_dpcodes_MTP_EXT		NULL
#define ptp_dpcodes_ANDROID		NULL

//#define ptp_dpcodes_CANON		NULL
//#define ptp_dpcodes_EK			NULL
//#define ptp_dpcodes_NIKON		NULL
//#define ptp_dpcodes_CASIO		NULL
//#define ptp_dpcodes_SONY		NULL
//#define ptp_dpcodes_OLYMPUS		NULL
//#define ptp_dpcodes_LEICA		NULL
//#define ptp_dpcodes_PARROT		NULL
#define ptp_dpcodes_PANASONIC	NULL
//#define ptp_dpcodes_FUJI		NULL
#define ptp_dpcodes_SIGMA		NULL


#define PTP_CODE_LIST_DEF(name) { \
	PTP_USB_VENDOR_##name, \
	PTP_EXT_VENDOR_##name, \
	PTP_VENDOR_NAME_##name, \
	PTP_VENDOR_STR_##name, \
	ptp_opcodes_##name, \
	ptp_rcodes_##name, \
	ptp_evcodes_##name, \
	ptp_ofcodes_##name, \
	ptp_dpcodes_##name, \
}

PTPCodeListDef ptp_code_list[] = {
	PTP_CODE_LIST_DEF(STD),
	PTP_CODE_LIST_DEF(MTP),
	PTP_CODE_LIST_DEF(MTP_EXT),
	PTP_CODE_LIST_DEF(ANDROID),

	PTP_CODE_LIST_DEF(CANON),
	PTP_CODE_LIST_DEF(EK),
	PTP_CODE_LIST_DEF(NIKON),
	PTP_CODE_LIST_DEF(CASIO),
	PTP_CODE_LIST_DEF(SONY),
	PTP_CODE_LIST_DEF(OLYMPUS),
	PTP_CODE_LIST_DEF(LEICA),
	PTP_CODE_LIST_DEF(PARROT),
	PTP_CODE_LIST_DEF(PANASONIC),
	PTP_CODE_LIST_DEF(FUJI),
	PTP_CODE_LIST_DEF(SIGMA),

	{0,0,NULL,NULL,NULL},
};

const PTPCodeListDef *ptp_get_code_list() {
	return ptp_code_list;
}

// these don't really fit in the generic code list, since they only apply to MTP
/* tables of object prop code, name, 0 terminated */
#define MTP_OPC_DEF(name) {PTP_OPC_##name,#name}

static PTPCodeDef mtp_opc_list[] = {
/* Microsoft/MTP specific */
/* MTP specific Object Properties */
	MTP_OPC_DEF(StorageID),
	MTP_OPC_DEF(ObjectFormat),
	MTP_OPC_DEF(ProtectionStatus),
	MTP_OPC_DEF(ObjectSize),
	MTP_OPC_DEF(AssociationType),
	MTP_OPC_DEF(AssociationDesc),
	MTP_OPC_DEF(ObjectFileName),
	MTP_OPC_DEF(DateCreated),
	MTP_OPC_DEF(DateModified),
	MTP_OPC_DEF(Keywords),
	MTP_OPC_DEF(ParentObject),
	MTP_OPC_DEF(AllowedFolderContents),
	MTP_OPC_DEF(Hidden),
	MTP_OPC_DEF(SystemObject),
	MTP_OPC_DEF(PersistantUniqueObjectIdentifier),
	MTP_OPC_DEF(SyncID),
	MTP_OPC_DEF(PropertyBag),
	MTP_OPC_DEF(Name),
	MTP_OPC_DEF(CreatedBy),
	MTP_OPC_DEF(Artist),
	MTP_OPC_DEF(DateAuthored),
	MTP_OPC_DEF(Description),
	MTP_OPC_DEF(URLReference),
	MTP_OPC_DEF(LanguageLocale),
	MTP_OPC_DEF(CopyrightInformation),
	MTP_OPC_DEF(Source),
	MTP_OPC_DEF(OriginLocation),
	MTP_OPC_DEF(DateAdded),
	MTP_OPC_DEF(NonConsumable),
	MTP_OPC_DEF(CorruptOrUnplayable),
	MTP_OPC_DEF(ProducerSerialNumber),
	MTP_OPC_DEF(RepresentativeSampleFormat),
	MTP_OPC_DEF(RepresentativeSampleSize),
	MTP_OPC_DEF(RepresentativeSampleHeight),
	MTP_OPC_DEF(RepresentativeSampleWidth),
	MTP_OPC_DEF(RepresentativeSampleDuration),
	MTP_OPC_DEF(RepresentativeSampleData),
	MTP_OPC_DEF(Width),
	MTP_OPC_DEF(Height),
	MTP_OPC_DEF(Duration),
	MTP_OPC_DEF(Rating),
	MTP_OPC_DEF(Track),
	MTP_OPC_DEF(Genre),
	MTP_OPC_DEF(Credits),
	MTP_OPC_DEF(Lyrics),
	MTP_OPC_DEF(SubscriptionContentID),
	MTP_OPC_DEF(ProducedBy),
	MTP_OPC_DEF(UseCount),
	MTP_OPC_DEF(SkipCount),
	MTP_OPC_DEF(LastAccessed),
	MTP_OPC_DEF(ParentalRating),
	MTP_OPC_DEF(MetaGenre),
	MTP_OPC_DEF(Composer),
	MTP_OPC_DEF(EffectiveRating),
	MTP_OPC_DEF(Subtitle),
	MTP_OPC_DEF(OriginalReleaseDate),
	MTP_OPC_DEF(AlbumName),
	MTP_OPC_DEF(AlbumArtist),
	MTP_OPC_DEF(Mood),
	MTP_OPC_DEF(DRMStatus),
	MTP_OPC_DEF(SubDescription),
	MTP_OPC_DEF(IsCropped),
	MTP_OPC_DEF(IsColorCorrected),
	MTP_OPC_DEF(ImageBitDepth),
	MTP_OPC_DEF(Fnumber),
	MTP_OPC_DEF(ExposureTime),
	MTP_OPC_DEF(ExposureIndex),
	MTP_OPC_DEF(DisplayName),
	MTP_OPC_DEF(BodyText),
	MTP_OPC_DEF(Subject),
	MTP_OPC_DEF(Priority),
	MTP_OPC_DEF(GivenName),
	MTP_OPC_DEF(MiddleNames),
	MTP_OPC_DEF(FamilyName),
	MTP_OPC_DEF(Prefix),
	MTP_OPC_DEF(Suffix),
	MTP_OPC_DEF(PhoneticGivenName),
	MTP_OPC_DEF(PhoneticFamilyName),
	MTP_OPC_DEF(EmailPrimary),
	MTP_OPC_DEF(EmailPersonal1),
	MTP_OPC_DEF(EmailPersonal2),
	MTP_OPC_DEF(EmailBusiness1),
	MTP_OPC_DEF(EmailBusiness2),
	MTP_OPC_DEF(EmailOthers),
	MTP_OPC_DEF(PhoneNumberPrimary),
	MTP_OPC_DEF(PhoneNumberPersonal),
	MTP_OPC_DEF(PhoneNumberPersonal2),
	MTP_OPC_DEF(PhoneNumberBusiness),
	MTP_OPC_DEF(PhoneNumberBusiness2),
	MTP_OPC_DEF(PhoneNumberMobile),
	MTP_OPC_DEF(PhoneNumberMobile2),
	MTP_OPC_DEF(FaxNumberPrimary),
	MTP_OPC_DEF(FaxNumberPersonal),
	MTP_OPC_DEF(FaxNumberBusiness),
	MTP_OPC_DEF(PagerNumber),
	MTP_OPC_DEF(PhoneNumberOthers),
	MTP_OPC_DEF(PrimaryWebAddress),
	MTP_OPC_DEF(PersonalWebAddress),
	MTP_OPC_DEF(BusinessWebAddress),
	MTP_OPC_DEF(InstantMessengerAddress),
	MTP_OPC_DEF(InstantMessengerAddress2),
	MTP_OPC_DEF(InstantMessengerAddress3),
	MTP_OPC_DEF(PostalAddressPersonalFull),
	MTP_OPC_DEF(PostalAddressPersonalFullLine1),
	MTP_OPC_DEF(PostalAddressPersonalFullLine2),
	MTP_OPC_DEF(PostalAddressPersonalFullCity),
	MTP_OPC_DEF(PostalAddressPersonalFullRegion),
	MTP_OPC_DEF(PostalAddressPersonalFullPostalCode),
	MTP_OPC_DEF(PostalAddressPersonalFullCountry),
	MTP_OPC_DEF(PostalAddressBusinessFull),
	MTP_OPC_DEF(PostalAddressBusinessLine1),
	MTP_OPC_DEF(PostalAddressBusinessLine2),
	MTP_OPC_DEF(PostalAddressBusinessCity),
	MTP_OPC_DEF(PostalAddressBusinessRegion),
	MTP_OPC_DEF(PostalAddressBusinessPostalCode),
	MTP_OPC_DEF(PostalAddressBusinessCountry),
	MTP_OPC_DEF(PostalAddressOtherFull),
	MTP_OPC_DEF(PostalAddressOtherLine1),
	MTP_OPC_DEF(PostalAddressOtherLine2),
	MTP_OPC_DEF(PostalAddressOtherCity),
	MTP_OPC_DEF(PostalAddressOtherRegion),
	MTP_OPC_DEF(PostalAddressOtherPostalCode),
	MTP_OPC_DEF(PostalAddressOtherCountry),
	MTP_OPC_DEF(OrganizationName),
	MTP_OPC_DEF(PhoneticOrganizationName),
	MTP_OPC_DEF(Role),
	MTP_OPC_DEF(Birthdate),
	MTP_OPC_DEF(MessageTo),
	MTP_OPC_DEF(MessageCC),
	MTP_OPC_DEF(MessageBCC),
	MTP_OPC_DEF(MessageRead),
	MTP_OPC_DEF(MessageReceivedTime),
	MTP_OPC_DEF(MessageSender),
	MTP_OPC_DEF(ActivityBeginTime),
	MTP_OPC_DEF(ActivityEndTime),
	MTP_OPC_DEF(ActivityLocation),
	MTP_OPC_DEF(ActivityRequiredAttendees),
	MTP_OPC_DEF(ActivityOptionalAttendees),
	MTP_OPC_DEF(ActivityResources),
	MTP_OPC_DEF(ActivityAccepted),
	MTP_OPC_DEF(Owner),
	MTP_OPC_DEF(Editor),
	MTP_OPC_DEF(Webmaster),
	MTP_OPC_DEF(URLSource),
	MTP_OPC_DEF(URLDestination),
	MTP_OPC_DEF(TimeBookmark),
	MTP_OPC_DEF(ObjectBookmark),
	MTP_OPC_DEF(ByteBookmark),
	MTP_OPC_DEF(LastBuildDate),
	MTP_OPC_DEF(TimetoLive),
	MTP_OPC_DEF(MediaGUID),
	MTP_OPC_DEF(TotalBitRate),
	MTP_OPC_DEF(BitRateType),
	MTP_OPC_DEF(SampleRate),
	MTP_OPC_DEF(NumberOfChannels),
	MTP_OPC_DEF(AudioBitDepth),
	MTP_OPC_DEF(ScanDepth),
	MTP_OPC_DEF(AudioWAVECodec),
	MTP_OPC_DEF(AudioBitRate),
	MTP_OPC_DEF(VideoFourCCCodec),
	MTP_OPC_DEF(VideoBitRate),
	MTP_OPC_DEF(FramesPerThousandSeconds),
	MTP_OPC_DEF(KeyFrameDistance),
	MTP_OPC_DEF(BufferSize),
	MTP_OPC_DEF(EncodingQuality),
	MTP_OPC_DEF(EncodingProfile),
	MTP_OPC_DEF(BuyFlag),

/* WiFi Provisioning MTP Extension property codes */
	MTP_OPC_DEF(WirelessConfigurationFile),

	{0,NULL},
};

const PTPCodeDef *ptp_get_mtp_opc_list() {
	return mtp_opc_list;
}
