/*****************************************************************************
#                                                                            *
# Copyright 2020 AT&T Intellectual Property                                  *
#                                                                            *
# Licensed under the Apache License, Version 2.0 (the "License");            *
# you may not use this file except in compliance with the License.           *
# You may obtain a copy of the License at                                    *
#                                                                            *
#      http://www.apache.org/licenses/LICENSE-2.0                            *
#                                                                            *
# Unless required by applicable law or agreed to in writing, software        *
# distributed under the License is distributed on an "AS IS" BASIS,          *
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   *
# See the License for the specific language governing permissions and        *
# limitations under the License.                                             *
#                                                                            *
******************************************************************************/

#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include <iostream>
#include <vector>

#include "encode_kpm.hpp"
#include "e2sim_defs.h"
using namespace std;

const char* performance_measurements[] = {
  "DRB.RlcSduTransmittedVolumeDL",
  "DRB.RlcSduTransmittedVolumeUL",
  "DRB.PerDataVolumeDLDist.Bin",
  "DRB.PerDataVolumeULDist.Bin",
  "DRB.RlcPacketDropRateDLDist",
  "DRB.PacketLossRateULDist",
  "L1M.DL-SS-RSRP.SSB",
  "L1M.DL-SS-SINR.SSB",
  "L1M.UL-SRS-RSRP"
  };

int NUMBER_MEASUREMENTS = 9;

void encode_kpm_function_description(E2SM_KPM_RANfunction_Description_t* ranfunc_desc) {
  uint8_t* short_name = (uint8_t*)"ORAN-E2SM-KPM";
  uint8_t* func_desc = (uint8_t*)"KPM Monitor";
  uint8_t* e2sm_odi = (uint8_t*)"OID123";

  LOG_I("short_name: %s, func_desc: %s, e2sm_odi: %s", short_name, func_desc, e2sm_odi);
  ASN_STRUCT_RESET(asn_DEF_E2SM_KPM_RANfunction_Description, ranfunc_desc);

  ranfunc_desc->ranFunction_Name.ranFunction_ShortName.size = strlen((char*)short_name);
  ranfunc_desc->ranFunction_Name.ranFunction_ShortName.buf =
      (uint8_t*)calloc(strlen((char*)short_name), sizeof(uint8_t));
  memcpy(ranfunc_desc->ranFunction_Name.ranFunction_ShortName.buf, short_name,
         ranfunc_desc->ranFunction_Name.ranFunction_ShortName.size);

  ranfunc_desc->ranFunction_Name.ranFunction_Description.buf =
      (uint8_t*)calloc(1, strlen((char*)func_desc));
  memcpy(ranfunc_desc->ranFunction_Name.ranFunction_Description.buf, func_desc,
         strlen((char*)func_desc));
  ranfunc_desc->ranFunction_Name.ranFunction_Description.size = strlen((char*)func_desc);
  ranfunc_desc->ranFunction_Name.ranFunction_Instance = (long *)calloc(1, sizeof(long));
  *ranfunc_desc->ranFunction_Name.ranFunction_Instance = 1;

  ranfunc_desc->ranFunction_Name.ranFunction_E2SM_OID.buf =
      (uint8_t*)calloc(1, strlen((char*)e2sm_odi));
  memcpy(ranfunc_desc->ranFunction_Name.ranFunction_E2SM_OID.buf, e2sm_odi,
         strlen((char*)e2sm_odi));
  ranfunc_desc->ranFunction_Name.ranFunction_E2SM_OID.size = strlen((char*)e2sm_odi);

  LOG_I("Initialize event trigger style list structure");

  RIC_EventTriggerStyle_Item_t* trigger_style =
      (RIC_EventTriggerStyle_Item_t*)calloc(1, sizeof(RIC_EventTriggerStyle_Item_t));
  trigger_style->ric_EventTriggerStyle_Type = 1;
  uint8_t* style_name = (uint8_t*)"Periodic Report";
  trigger_style->ric_EventTriggerStyle_Name.buf = (uint8_t*)calloc(1, strlen((char*)style_name));
  memcpy(trigger_style->ric_EventTriggerStyle_Name.buf, style_name, strlen((char*)style_name));
  trigger_style->ric_EventTriggerStyle_Name.size = strlen((char*)style_name);
  trigger_style->ric_EventTriggerFormat_Type = 1;

  ranfunc_desc->ric_EventTriggerStyle_List =
      (E2SM_KPM_RANfunction_Description::
           E2SM_KPM_RANfunction_Description__ric_EventTriggerStyle_List*)
          calloc(1, sizeof(E2SM_KPM_RANfunction_Description::
                               E2SM_KPM_RANfunction_Description__ric_EventTriggerStyle_List));

  int ret = ASN_SEQUENCE_ADD(&ranfunc_desc->ric_EventTriggerStyle_List->list, trigger_style);

  LOG_I("Initialize report style structure");

  MeasurementInfo_Action_List_t* measInfo_Action_List =
      (MeasurementInfo_Action_List_t*)calloc(1, sizeof(MeasurementInfo_Action_List_t));

  for (int i = 0; i < NUMBER_MEASUREMENTS; i++) {
    uint8_t* metrics = (uint8_t *)performance_measurements[i];
    MeasurementInfo_Action_Item_t* measItem =
        (MeasurementInfo_Action_Item_t*)calloc(1, sizeof(MeasurementInfo_Action_Item_t));
    measItem->measName.buf = (uint8_t*)calloc(1, strlen((char*)metrics));
    memcpy(measItem->measName.buf, metrics, strlen((char*)metrics));

    measItem->measName.size = strlen((char*)metrics);

    measItem->measID = (MeasurementTypeID_t*)calloc(1, sizeof(MeasurementTypeID_t));
    *measItem->measID = i+1;

    ASN_SEQUENCE_ADD(&measInfo_Action_List->list, measItem);
  }

  RIC_ReportStyle_Item_t* report_style1 =
      (RIC_ReportStyle_Item_t*)calloc(1, sizeof(RIC_ReportStyle_Item_t));
  report_style1->ric_ReportStyle_Type = 1;

  uint8_t* buf5 = (uint8_t*)"E2 Node Measurement";
  report_style1->ric_ReportStyle_Name.buf = (uint8_t*)calloc(1, strlen((char*)buf5));
  memcpy(report_style1->ric_ReportStyle_Name.buf, buf5, strlen((char*)buf5));
  report_style1->ric_ReportStyle_Name.size = strlen((char*)buf5);
  report_style1->ric_ActionFormat_Type = 1;
  report_style1->ric_IndicationHeaderFormat_Type = 1;
  report_style1->ric_IndicationMessageFormat_Type = 1;
  report_style1->measInfo_Action_List = *measInfo_Action_List;

  RIC_ReportStyle_Item_t* report_style2 =
      (RIC_ReportStyle_Item_t*)calloc(1, sizeof(RIC_ReportStyle_Item_t));
  report_style2->ric_ReportStyle_Type = 2;

  uint8_t* buf6 = (uint8_t*)"E2 Node Measurement for a single UE";
  report_style2->ric_ReportStyle_Name.buf = (uint8_t*)calloc(1, strlen((char*)buf6));
  memcpy(report_style2->ric_ReportStyle_Name.buf, buf6, strlen((char*)buf6));
  report_style2->ric_ReportStyle_Name.size = strlen((char*)buf6);
  report_style2->ric_ActionFormat_Type = 2;
  report_style2->ric_IndicationHeaderFormat_Type = 1;
  report_style2->ric_IndicationMessageFormat_Type = 1;
  report_style2->measInfo_Action_List = *measInfo_Action_List;

  RIC_ReportStyle_Item_t* report_style3 =
      (RIC_ReportStyle_Item_t*)calloc(1, sizeof(RIC_ReportStyle_Item_t));
  report_style3->ric_ReportStyle_Type = 3;

  uint8_t* buf7 = (uint8_t*)"Condition-based, UE-level E2 Node Measurement";

  report_style3->ric_ReportStyle_Name.buf = (uint8_t*)calloc(1, strlen((char*)buf7));
  memcpy(report_style3->ric_ReportStyle_Name.buf, buf7, strlen((char*)buf7));
  report_style3->ric_ReportStyle_Name.size = strlen((char*)buf7);
  report_style3->ric_ActionFormat_Type = 3;
  report_style3->ric_IndicationHeaderFormat_Type = 1;
  report_style3->ric_IndicationMessageFormat_Type = 2;
  report_style3->measInfo_Action_List = *measInfo_Action_List;

  RIC_ReportStyle_Item_t* report_style4 =
      (RIC_ReportStyle_Item_t*)calloc(1, sizeof(RIC_ReportStyle_Item_t));
  report_style4->ric_ReportStyle_Type = 4;

  uint8_t* buf8 = (uint8_t*)"Common Condition-based, UE-level Measurement";

  report_style4->ric_ReportStyle_Name.buf = (uint8_t*)calloc(1, strlen((char*)buf8));
  memcpy(report_style4->ric_ReportStyle_Name.buf, buf8, strlen((char*)buf8));
  report_style4->ric_ReportStyle_Name.size = strlen((char*)buf8);
  report_style4->ric_ActionFormat_Type = 4;
  report_style4->ric_IndicationHeaderFormat_Type = 1;
  report_style4->ric_IndicationMessageFormat_Type = 3;
  report_style4->measInfo_Action_List = *measInfo_Action_List;

  RIC_ReportStyle_Item_t* report_style5 =
      (RIC_ReportStyle_Item_t*)calloc(1, sizeof(RIC_ReportStyle_Item_t));
  report_style5->ric_ReportStyle_Type = 5;

  uint8_t* buf9 = (uint8_t*)"E2 Node Measurement for multiple UEs";

  report_style5->ric_ReportStyle_Name.buf = (uint8_t*)calloc(1, strlen((char*)buf9));
  memcpy(report_style5->ric_ReportStyle_Name.buf, buf9, strlen((char*)buf9));
  report_style5->ric_ReportStyle_Name.size = strlen((char*)buf9);
  report_style5->ric_ActionFormat_Type = 5;
  report_style5->ric_IndicationHeaderFormat_Type = 1;
  report_style5->ric_IndicationMessageFormat_Type = 3;
  report_style5->measInfo_Action_List = *measInfo_Action_List;

  ranfunc_desc->ric_ReportStyle_List =
      (E2SM_KPM_RANfunction_Description::E2SM_KPM_RANfunction_Description__ric_ReportStyle_List*)
          calloc(1, sizeof(E2SM_KPM_RANfunction_Description::
                               E2SM_KPM_RANfunction_Description__ric_ReportStyle_List));

  ASN_SEQUENCE_ADD(&ranfunc_desc->ric_ReportStyle_List->list, report_style1);
  ASN_SEQUENCE_ADD(&ranfunc_desc->ric_ReportStyle_List->list, report_style2);
  ASN_SEQUENCE_ADD(&ranfunc_desc->ric_ReportStyle_List->list, report_style3);
  ASN_SEQUENCE_ADD(&ranfunc_desc->ric_ReportStyle_List->list, report_style4);
  ASN_SEQUENCE_ADD(&ranfunc_desc->ric_ReportStyle_List->list, report_style5);

  // xer_fprint(stderr, &asn_DEF_E2SM_KPM_RANfunction_Description, ranfunc_desc);
}

void kpm_report_indication_header_initialized(E2SM_KPM_IndicationHeader_t* ihead,
                                              uint8_t* plmnid_buf, uint8_t* sst_buf,
                                              uint8_t* sd_buf, long fqival, long qcival,
                                              uint8_t* nrcellid_buf, uint8_t* gnbid_buf,
                                              int gnbid_unused, uint8_t* cuupid_buf,
                                              uint8_t* duid_buf, uint8_t* cuupname_buf) {
  LOG_I("Start initializing mocked indication header");
  E2SM_KPM_IndicationHeader_Format1_t* ind_header =
      (E2SM_KPM_IndicationHeader_Format1_t*)calloc(1, sizeof(E2SM_KPM_IndicationHeader_Format1_t));

  ASN_STRUCT_RESET(asn_DEF_E2SM_KPM_IndicationMessage_Format1, ind_header);

  uint8_t* buf2 = (uint8_t*)"ORANSim";
  ind_header->senderName = (PrintableString_t*)calloc(1, sizeof(PrintableString_t));
  ind_header->senderName->buf = (uint8_t*)calloc(1, strlen((char*)buf2));
  memcpy(ind_header->senderName->buf, buf2, strlen((char*)buf2));
  ind_header->senderName->size = strlen((char*)buf2);

  uint8_t* buf3 = (uint8_t*)"simulator";
  ind_header->senderType = (PrintableString_t*)calloc(1, sizeof(PrintableString_t));
  ind_header->senderType->buf = (uint8_t*)calloc(1, strlen((char*)buf3));
  memcpy(ind_header->senderType->buf, buf3, strlen((char*)buf3));
  ind_header->senderType->size = strlen((char*)buf3);

  uint8_t* buf4 = (uint8_t*)"ORAN-SC";
  ind_header->vendorName = (PrintableString_t*)calloc(1, sizeof(PrintableString_t));
  ind_header->vendorName->buf = (uint8_t*)calloc(1, strlen((char*)buf4));
  memcpy(ind_header->vendorName->buf, buf4, strlen((char*)buf4));
  ind_header->vendorName->size = strlen((char*)buf4);

  uint8_t* buf = (uint8_t*)"20200613";
  TimeStamp_t* ts = (TimeStamp_t*)calloc(1, sizeof(TimeStamp_t));
  ts->buf = (uint8_t*)calloc(strlen((char*)buf), 1);
  ts->size = strlen((char*)buf);
  memcpy(ts->buf, buf, ts->size);

  ind_header->colletStartTime = *ts;
  if (ts) free(ts);

  ihead->indicationHeader_formats.present =
      E2SM_KPM_IndicationHeader__indicationHeader_formats_PR_indicationHeader_Format1;
  ihead->indicationHeader_formats.choice.indicationHeader_Format1 = ind_header;

}

void ue_meas_kpm_report_indication_message_initialized(
    E2SM_KPM_IndicationMessage_t* indicationmessage, uint8_t* nrcellid_buf, uint8_t* crnti_buf,
    const uint8_t* serving_buf, const uint8_t* neighbor_buf) {

  // Allocate memory for MeasurementRecord
  MeasurementRecord_t* measDataItem_record = (MeasurementRecord_t*)calloc(1, sizeof(MeasurementRecord_t));
  if (!measDataItem_record) {
    LOG_I("Memory allocation for measDataItem_record failed");
    exit(1);
  }

  // Populate MeasurementRecord with MeasurementRecordItems
  for (size_t i = 0; i < NUMBER_MEASUREMENTS; i++) {
    MeasurementRecordItem_t* measDataRecordItem = (MeasurementRecordItem_t*)calloc(1, sizeof(MeasurementRecordItem_t));
    if (!measDataRecordItem) {
      LOG_I("Memory allocation for measDataRecordItem failed");
      exit(1);
    }
    
    measDataRecordItem->present = MeasurementRecordItem_PR_integer;
    measDataRecordItem->choice.integer = 1;

    if (ASN_SEQUENCE_ADD(&measDataItem_record->list, measDataRecordItem) != 0) {
      LOG_I("ASN_SEQUENCE_ADD failed for MeasurementRecordItem");
      exit(1);
    }
  }

  // Allocate memory for MeasurementDataItem and set its fields
  MeasurementDataItem_t* measDataItem = (MeasurementDataItem_t*)calloc(1, sizeof(MeasurementDataItem_t));
  if (!measDataItem) {
    LOG_I("Memory allocation for measDataItem failed");
    exit(1);
  }
  measDataItem->measRecord = *measDataItem_record;
  measDataItem->incompleteFlag = (long*)calloc(1, sizeof(long));
  if (!measDataItem->incompleteFlag) {
    LOG_I("Memory allocation for incompleteFlag failed");
    exit(1);
  }
  *measDataItem->incompleteFlag = 0;

  // Allocate memory for MeasurementData and add MeasurementDataItem
  MeasurementData_t* measData = (MeasurementData_t*)calloc(1, sizeof(MeasurementData_t));
  if (!measData) {
    LOG_I("Memory allocation for measData failed");
    exit(1);
  }
  if (ASN_SEQUENCE_ADD(&measData->list, measDataItem) != 0) {
    LOG_I("ASN_SEQUENCE_ADD failed for MeasurementDataItem");
    exit(1);
  }

  // Allocate memory for MeasurementInfoList and populate it
  MeasurementInfoList_t* measList = (MeasurementInfoList_t*)calloc(1, sizeof(MeasurementInfoList_t));
  if (!measList) {
    LOG_I("Memory allocation for measList failed");
    exit(1);
  }
  for (size_t i = 0; i < NUMBER_MEASUREMENTS; i++) {
    MeasurementLabel_t* measLabel = (MeasurementLabel_t*)calloc(1, sizeof(MeasurementLabel_t));
    if (!measLabel) {
      LOG_I("Memory allocation for measLabel failed");
      exit(1);
    }
    measLabel->noLabel = (long *)calloc(1, sizeof(long));
    if (!measLabel->noLabel) {
      LOG_I("Memory allocation for noLabel failed");
      exit(1);
    }
    *measLabel->noLabel = 0;

    LabelInfoItem_t* labelItem = (LabelInfoItem_t*)calloc(1, sizeof(LabelInfoItem_t));
    if (!labelItem) {
      LOG_I("Memory allocation for labelItem failed");
      exit(1);
    }
    labelItem->measLabel = *measLabel;

    LabelInfoList_t* labelList = (LabelInfoList_t*)calloc(1, sizeof(LabelInfoList_t));
    if (!labelList) {
      LOG_I("Memory allocation for labelList failed");
      exit(1);
    }
    if (ASN_SEQUENCE_ADD(&labelList->list, labelItem) != 0) {
      LOG_I("ASN_SEQUENCE_ADD failed for LabelInfoItem");
      exit(1);
    }

    MeasurementType_t measType;
    measType.present = MeasurementType_PR_measID;
    uint8_t* metrics = (uint8_t *)performance_measurements[i];
    measType.choice.measName.buf = (uint8_t*)calloc(strlen((char*)metrics) + 1, sizeof(uint8_t));
    if (!measType.choice.measName.buf) {
      LOG_I("Memory allocation for measName.buf failed");
      exit(1);
    }
    memcpy(measType.choice.measName.buf, metrics, strlen((char*)metrics));
    measType.choice.measName.size = strlen((char*)metrics);

    MeasurementInfoItem_t* measItem = (MeasurementInfoItem_t*)calloc(1, sizeof(MeasurementInfoItem_t));
    if (!measItem) {
      LOG_I("Memory allocation for measItem failed");
      exit(1);
    }
    measItem->measType = measType;
    measItem->labelInfoList = *labelList;

    if (labelList) free(labelList);

    if (ASN_SEQUENCE_ADD(&measList->list, measItem) != 0) {
      LOG_I("ASN_SEQUENCE_ADD failed for MeasurementInfoItem");
      exit(1);
    }
  }

  // Allocate memory for E2SM_KPM_IndicationMessage_Format1 and set its fields
  E2SM_KPM_IndicationMessage_Format1_t* format = (E2SM_KPM_IndicationMessage_Format1_t*)calloc(
      1, sizeof(E2SM_KPM_IndicationMessage_Format1_t));
  if (!format) {
    LOG_I("Memory allocation for E2SM_KPM_IndicationMessage_Format1 failed");
    exit(1);
  }
  format->granulPeriod = (GranularityPeriod_t*)calloc(1, sizeof(GranularityPeriod_t));
  if (!format->granulPeriod) {
    LOG_I("Memory allocation for granulPeriod failed");
    exit(1);
  }
  *format->granulPeriod = 1;
  format->measData = *measData;
  format->measInfoList = measList;

  E2SM_KPM_IndicationMessage__indicationMessage_formats_PR pres =
      E2SM_KPM_IndicationMessage__indicationMessage_formats_PR_indicationMessage_Format1;

  indicationmessage->indicationMessage_formats.present = pres;
  indicationmessage->indicationMessage_formats.choice.indicationMessage_Format1 = format;

  char error_buf[300] = {0};
  size_t errlen = 0;

  // Perform constraint check
  // LOG_I("print asn def %s", asn_DEF_E2SM_KPM_IndicationMessage.name);
  // LOG_I("print indication message %s", indicationmessage->indicationMessage_formats.choice.indicationMessage_Format1->measData.list.array[0]->measRecord.list.array[0]->choice.integer);
  // LOG_I("print error buf %s", error_buf); 

  // int ret = asn_check_constraints(&asn_DEF_E2SM_KPM_IndicationMessage, indicationmessage, error_buf, &errlen);
  // if (ret) {
  //   LOG_I("Constraint validation of indication message failed: %s", error_buf);
  //   exit(1);
  // } else {
  //   LOG_I("Constraint validation of indication message succeeded");
  // }

  // Optional: Print the encoded message for debugging purposes
  // xer_fprint(stderr, &asn_DEF_E2SM_KPM_IndicationMessage, indicationmessage);
}

// void ue_meas_kpm_report_indication_message_initialized(
//     E2SM_KPM_IndicationMessage_t* indicationmessage, uint8_t* nrcellid_buf, uint8_t* crnti_buf,
//     const uint8_t* serving_buf, const uint8_t* neighbor_buf) {
  
//   MeasurementRecord_t* measDataItem_record = (MeasurementRecord_t*)calloc(1, sizeof(MeasurementRecord_t));

//   if (!measDataItem_record) {
//     LOG_I("Memory allocation for measDataItem_record failed");
//     exit(1);
//   }

//   for (size_t i = 0; i < NUMBER_MEASUREMENTS; i++)
//   {
//     MeasurementRecordItem_t* measDataRecordItem = (MeasurementRecordItem_t*)calloc(1, sizeof(MeasurementRecordItem_t));
//     if (!measDataRecordItem) {
//         LOG_I("Memory allocation for measDataRecordItem failed");
//         exit(1);
//     }

//     measDataRecordItem->present = MeasurementRecordItem_PR_integer;
//     measDataRecordItem->choice.integer = 1;

//     ASN_SEQUENCE_ADD(&measDataItem_record->list, measDataRecordItem);
//   }

//   MeasurementDataItem_t* measDataItem = (MeasurementDataItem_t*)calloc(1, sizeof(MeasurementDataItem_t));
//   measDataItem->measRecord = *measDataItem_record;
//   measDataItem->incompleteFlag = (long*)calloc(1, sizeof(long));
//   *measDataItem->incompleteFlag = 0;

//   MeasurementData_t* measData = (MeasurementData_t*)calloc(1, sizeof(MeasurementData_t));
//   ASN_SEQUENCE_ADD(&measData->list, measDataItem);

//   MeasurementInfoList_t* measList = (MeasurementInfoList_t*)calloc(1, sizeof(MeasurementInfoList_t));
//   for (size_t i = 0; i < NUMBER_MEASUREMENTS; i++)
//   {
//     MeasurementLabel_t* measLabel = (MeasurementLabel_t*)calloc(1, sizeof(MeasurementLabel_t));
//     measLabel->noLabel = (long *)calloc(1, sizeof(long));
//     *measLabel->noLabel = 0;

//     LabelInfoItem_t* labelItem = (LabelInfoItem_t*)calloc(1, sizeof(LabelInfoItem_t));
//     labelItem->measLabel = *measLabel;

//     LabelInfoList_t* labelList = (LabelInfoList_t*)calloc(1, sizeof(LabelInfoList_t));
//     ASN_SEQUENCE_ADD(&labelList->list, labelItem);

//     MeasurementType_t measType;
//     measType.present = MeasurementType_PR_measID;
//     uint8_t* metrics = (uint8_t *)performance_measurements[i];
//     measType.choice.measName.buf = (uint8_t*)calloc(1, strlen((char*)metrics));
//     memcpy(measType.choice.measName.buf, metrics, strlen((char*)metrics));
//     measType.choice.measName.size = strlen((char*)metrics);

//     MeasurementInfoItem_t* measItem = (MeasurementInfoItem_t*)calloc(1, sizeof(MeasurementInfoItem_t));
//     measItem->measType = measType;
//     measItem->labelInfoList = *labelList;
//     if (labelList) free(labelList);
    
//     ASN_SEQUENCE_ADD(&measList->list, measItem);
//   }
  
//   E2SM_KPM_IndicationMessage_Format1_t* format = (E2SM_KPM_IndicationMessage_Format1_t*)calloc(
//       1, sizeof(E2SM_KPM_IndicationMessage_Format1_t));
//   format->granulPeriod = (GranularityPeriod_t*)calloc(1, sizeof(GranularityPeriod_t));
//   *format->granulPeriod = 1;
//   format->measData = *measData;
//   format->measInfoList = measList;

//   E2SM_KPM_IndicationMessage__indicationMessage_formats_PR pres =
//       E2SM_KPM_IndicationMessage__indicationMessage_formats_PR_indicationMessage_Format1;

//   indicationmessage->indicationMessage_formats.present = pres;
//   indicationmessage->indicationMessage_formats.choice.indicationMessage_Format1 = format;

//   char error_buf[300] = {
//       0,
//   };
//   size_t errlen = 0;

//   int ret = asn_check_constraints(&asn_DEF_E2SM_KPM_IndicationMessage, indicationmessage, error_buf,
//                                   &errlen);

//   if (ret) {
//     LOG_I("Constraint validation of indication message failed: %s", error_buf);
//     exit(1);
//   }

//   // xer_fprint(stderr, &asn_DEF_E2SM_KPM_IndicationMessage, indicationmessage);
// }

void cell_meas_kpm_report_indication_message_style_1_initialized(
    E2SM_KPM_IndicationMessage_t* indicationmessage, long fiveqi, long dl_prb_usage,
    long ul_prb_usage, uint8_t* nrcellid_buf, long* dl_prbs, long* ul_prbs) {
  LOG_I("Preparing indication message for cell measurement report");

  asn_codec_ctx_t* opt_cod;

  GranularityPeriod_t period = 1;
  MeasurementData_t* measData = (MeasurementData_t*)calloc(1, sizeof(MeasurementData_t));
  MeasurementDataItem_t* measDataItem =
      (MeasurementDataItem_t*)calloc(1, sizeof(MeasurementDataItem_t));
  MeasurementRecord_t* measDataItem_record =
      (MeasurementRecord_t*)calloc(1, sizeof(MeasurementRecord_t));
  MeasurementRecordItem_t* measDataRecordItem =
      (MeasurementRecordItem_t*)calloc(1, sizeof(MeasurementRecordItem_t));

  measDataRecordItem->present = MeasurementRecordItem_PR_integer;
  measDataRecordItem->choice.integer = 1;

  ASN_SEQUENCE_ADD(&measDataItem_record->list, measDataRecordItem);

  measDataItem->measRecord = *measDataItem_record;
  measDataItem->incompleteFlag = (long*)calloc(1, sizeof(long));
  *measDataItem->incompleteFlag = 0;
  ASN_SEQUENCE_ADD(&measData->list, measDataItem);

  E2SM_KPM_IndicationMessage_Format1_t* format = (E2SM_KPM_IndicationMessage_Format1_t*)calloc(
      1, sizeof(E2SM_KPM_IndicationMessage_Format1_t));
  format->granulPeriod = (GranularityPeriod_t*)calloc(1, sizeof(GranularityPeriod_t));
  *format->granulPeriod = period;
  format->measData = *measData;

  MeasurementInfoList_t* measList =
      (MeasurementInfoList_t*)calloc(1, sizeof(MeasurementInfoList_t));
  MeasurementInfoItem_t* measItem =
      (MeasurementInfoItem_t*)calloc(1, sizeof(MeasurementInfoItem_t));
  LabelInfoList_t* labelList = (LabelInfoList_t*)calloc(1, sizeof(LabelInfoList_t));
  LabelInfoItem_t* labelItem = (LabelInfoItem_t*)calloc(1, sizeof(LabelInfoItem_t));
  MeasurementLabel_t* measLabel = (MeasurementLabel_t*)calloc(1, sizeof(MeasurementLabel_t));

  uint8_t* plmnid_buf = (uint8_t*)"747";
  uint8_t* sst_buf = (uint8_t*)"1";
  uint8_t* sd_buf = (uint8_t*)"100";

  S_NSSAI_t* snssai = (S_NSSAI_t*)calloc(1, sizeof(S_NSSAI_t));
  snssai->sST.buf = (uint8_t*)calloc(strlen((char*)sst_buf), sizeof(uint8_t));
  snssai->sST.size = strlen((char*)sst_buf);
  memcpy(snssai->sST.buf, sst_buf, strlen((char*)sst_buf));

  snssai->sD = (SD_t*)calloc(1, sizeof(SD_t));
  snssai->sD->buf = (uint8_t*)calloc(strlen((char*)sd_buf), sizeof(uint8_t));
  snssai->sD->size = strlen((char*)sd_buf);
  memcpy(snssai->sD->buf, sd_buf, strlen((char*)sd_buf));

  int plmnid_size = strlen((char*)plmnid_buf);
  PLMNIdentity_t* plmnidstr = (PLMNIdentity_t*)calloc(1, sizeof(PLMNIdentity_t));
  plmnidstr->buf = (uint8_t*)calloc(plmnid_size, 1);
  plmnidstr->size = plmnid_size;
  memcpy(plmnidstr->buf, plmnid_buf, plmnidstr->size);

  measLabel->plmnID = plmnidstr;
  measLabel->sliceID = snssai;

  labelItem->measLabel = *measLabel;
  ASN_SEQUENCE_ADD(&labelList->list, labelItem);
  measItem->labelInfoList = *labelList;
  if (labelList) free(labelList);
  MeasurementType_t measType;
  measType.present = MeasurementType_PR_measID;
  measType.choice.measID = 1;
  measItem->measType = measType;
  ASN_SEQUENCE_ADD(&measList->list, measItem);

  format->measInfoList = measList;

  E2SM_KPM_IndicationMessage__indicationMessage_formats_PR pres =
      E2SM_KPM_IndicationMessage__indicationMessage_formats_PR_indicationMessage_Format1;

  indicationmessage->indicationMessage_formats.present = pres;
  indicationmessage->indicationMessage_formats.choice.indicationMessage_Format1 = format;

  char error_buf[300] = {
      0,
  };
  size_t errlen = 0;

  int ret = asn_check_constraints(&asn_DEF_E2SM_KPM_IndicationMessage, indicationmessage, error_buf,
                                  &errlen);

  if (ret) {
    LOG_I("Constraint validation of indication message failed: %s\n", error_buf);
    exit(1);
  }
}

void encode_kpm_report_style1(E2SM_KPM_IndicationMessage_t* indicationmessage) {
  long fiveqi = 8;
  long dl_prb_usage = 50;
  long ul_prb_usage = 70;

  asn_codec_ctx_t* opt_cod;

  GranularityPeriod_t period = 1;
  MeasurementData_t measData;
  MeasurementDataItem_t measDataItem;
  MeasurementRecord_t measDataItem_record;
  MeasurementRecordItem_t measDataRecordItem;

  measDataRecordItem.present = MeasurementRecordItem_PR_real;
  measDataRecordItem.choice.real = 1.5;

  ASN_SEQUENCE_ADD(&measDataItem_record.list, &measDataRecordItem);

  measDataItem.measRecord = measDataItem_record;
  ASN_SEQUENCE_ADD(&measData.list, &measDataItem);

  E2SM_KPM_IndicationMessage_Format1_t* format = (E2SM_KPM_IndicationMessage_Format1_t*)calloc(
      1, sizeof(E2SM_KPM_IndicationMessage_Format1_t));
  ASN_STRUCT_RESET(asn_DEF_E2SM_KPM_IndicationMessage_Format1, format);

  format->granulPeriod = &period;
  format->measData = measData;

  E2SM_KPM_IndicationMessage__indicationMessage_formats_PR pres =
      E2SM_KPM_IndicationMessage__indicationMessage_formats_PR_indicationMessage_Format1;

  indicationmessage->indicationMessage_formats.present = pres;

  indicationmessage->indicationMessage_formats.choice.indicationMessage_Format1 = format;
  if (format) free(format);

  char error_buf[300] = {
      0,
  };
  size_t errlen = 0;

  int ret = asn_check_constraints(&asn_DEF_E2SM_KPM_IndicationMessage, indicationmessage, error_buf,
                                  &errlen);

  if (ret) {
    LOG_I("Constraint validation of indication message failed: %s\n", error_buf);
    exit(1);
  }

  uint8_t e2smbuffer[8192] = {
      0,
  };
  size_t e2smbuffer_size = 8192;

  asn_enc_rval_t er =
      asn_encode_to_buffer(opt_cod, ATS_ALIGNED_BASIC_PER, &asn_DEF_E2SM_KPM_IndicationMessage,
                           indicationmessage, e2smbuffer, e2smbuffer_size);

  if (er.encoded == -1) {
    LOG_E("Failed to serialize message. Detail: %s.\n", asn_DEF_E2SM_KPM_IndicationMessage.name);
    exit(1);
  } else if (er.encoded > e2smbuffer_size) {
    LOG_E("Buffer of size %zu is too small for %s, need %zu\n", e2smbuffer_size, asn_DEF_E2SM_KPM_IndicationMessage.name, er.encoded);
    exit(1);
  }
}

void encode_kpm(E2SM_KPM_IndicationMessage_t* indicationmessage) {
  /*
  ASN_STRUCT_RESET(asn_DEF_E2SM_KPM_IndicationMessage, indicationmessage);
  //std::string gn = "GNBCUUP5";
  //std::vector<uint8_t> gnvec(gn.begin(), gn.end());
  //uint8_t *buf = &gnvec[0];
  uint8_t *buf = (uint8_t*)"GNBCUUP5";
  OCTET_STRING_t *gnbcuupname = (OCTET_STRING_t*)calloc(1, sizeof(OCTET_STRING_t));
  gnbcuupname->size = 8;
  gnbcuupname->buf = (uint8_t*)calloc(1,8);
  memcpy(gnbcuupname->buf, buf, gnbcuupname->size);


  INTEGER_t *bytesdl = (INTEGER_t*)calloc(1, sizeof(INTEGER_t));
  uint8_t buffer[1];
  buffer[0]= 40000;
  bytesdl->buf = (uint8_t*)calloc(1,1);
  memcpy(bytesdl->buf, buffer,1);
  bytesdl->size = 1;

  INTEGER_t *bytesul = (INTEGER_t*)calloc(1, sizeof(INTEGER_t));
  uint8_t buffer1[1];
  buffer1[0] = 50000;
  bytesul->buf = (uint8_t*)calloc(1,1);
  memcpy(bytesul->buf, buffer1, 1);
  bytesul->size = 1;

  FQIPERSlicesPerPlmnListItem_t *fqilistitem = (FQIPERSlicesPerPlmnListItem_t*)calloc(1,
  sizeof(FQIPERSlicesPerPlmnListItem_t)); ASN_STRUCT_RESET(asn_DEF_FQIPERSlicesPerPlmnListItem,
  fqilistitem); fqilistitem->fiveQI = 9; fqilistitem->pDCPBytesDL = bytesdl;
  fqilistitem->pDCPBytesUL = bytesul;



  //  std::string sl = "SLICE4";
  //  std::vector<uint8_t> slvec(sl.begin(), sl.end());
  //  uint8_t *buf1 = &slvec[0];
  uint8_t *buf1 = (uint8_t*)"4";
  OCTET_STRING_t *sst = (OCTET_STRING_t*)calloc(1, sizeof(OCTET_STRING_t));
  sst->size = 6;
  sst->buf = (uint8_t*)calloc(1,6);
  memcpy(sst->buf,buf1,sst->size);

  //  std::string sd = "SD1";
  //  std::vector<uint8_t> sdvec(sd.begin(), sd.end());
  //  uint8_t *bufz = &sdvec[0];
  uint8_t *bufz = (uint8_t*)"SD1";
  OCTET_STRING_t *sds = (OCTET_STRING_t*)calloc(1, sizeof(OCTET_STRING_t));
  sds->size = 3;
  sds->buf = (uint8_t*)calloc(1,3);
  memcpy(sds->buf, bufz, sds->size);


  SNSSAI_t *snssai = (SNSSAI_t*)calloc(1, sizeof(SNSSAI_t));
  ASN_STRUCT_RESET(asn_DEF_SNSSAI,snssai);
  snssai->sST.buf = (uint8_t*)calloc(1,1);
  snssai->sST.size = 1;
  memcpy(snssai->sST.buf, buf1, 1);
  snssai->sD = (OCTET_STRING_t*)calloc(1, sizeof(OCTET_STRING_t));
  snssai->sD->buf = (uint8_t*)calloc(1,3);
  snssai->sD->size = 3;
  memcpy(snssai->sD->buf, bufz, 3);



  SliceToReportListItem_t *slicelistitem =
  (SliceToReportListItem_t*)calloc(1,sizeof(SliceToReportListItem_t));
  ASN_STRUCT_RESET(asn_DEF_SliceToReportListItem, slicelistitem);
  slicelistitem->sliceID = *snssai;
  int ret = ASN_SEQUENCE_ADD(&slicelistitem->fQIPERSlicesPerPlmnList.list, fqilistitem);

  asn_codec_ctx_t *opt_cod;


  uint8_t e2smbuffera[8192];
  size_t e2smbuffer_sizea = 8192;



  asn_enc_rval_t era =
    asn_encode_to_buffer(opt_cod,
       ATS_ALIGNED_BASIC_PER,
       &asn_DEF_SliceToReportListItem,
       slicelistitem, e2smbuffera, e2smbuffer_sizea);
  fprintf(stderr, "inner er encded is %d\n", era.encoded);
  fprintf(stderr, "after encoding message");



  FGC_CUUP_PM_Format_t *pm_format = (FGC_CUUP_PM_Format_t*)calloc(1,sizeof(FGC_CUUP_PM_Format_t));
  ASN_STRUCT_RESET(asn_DEF_FGC_CUUP_PM_Format, pm_format);
  ret = ASN_SEQUENCE_ADD(&pm_format->sliceToReportList.list, slicelistitem);

  uint8_t *buf2 = (uint8_t*)"747";
  //  std::string pl = "PLMNID7";
  //  std::vector<uint8_t> plvec(pl.begin(), pl.end());
  //  uint8_t *buf2 = &plvec[0];

  OCTET_STRING_t *plmnid = (OCTET_STRING_t*)calloc(1,sizeof(OCTET_STRING_t));
  plmnid->buf = (uint8_t*)calloc(3,1);
  plmnid->size = 3;
  memcpy(plmnid->buf, buf2, plmnid->size);


  PlmnID_List_t *plmnidlist = (PlmnID_List_t*)calloc(1,sizeof(PlmnID_List_t));
  ASN_STRUCT_RESET(asn_DEF_PlmnID_List, plmnidlist);
  plmnidlist->pLMN_Identity = *plmnid;
  plmnidlist->cu_UP_PM_5GC = pm_format;

  CUUPMeasurement_Container_t *meas_cont = (CUUPMeasurement_Container_t*)calloc(1,
  sizeof(CUUPMeasurement_Container_t)); ASN_STRUCT_RESET(asn_DEF_CUUPMeasurement_Container,
  meas_cont); ret = ASN_SEQUENCE_ADD(&meas_cont->plmnList.list, plmnidlist);




  PF_ContainerListItem_t *listitem1 = (PF_ContainerListItem_t*)calloc(1,
  sizeof(PF_ContainerListItem_t)); ASN_STRUCT_RESET(asn_DEF_PF_ContainerListItem, listitem1);
  listitem1->interface_type = 2;
  listitem1->o_CU_UP_PM_Container = *meas_cont;

  OCUUP_PF_Container_t *cuupcont = (OCUUP_PF_Container_t*)calloc(1,sizeof(OCUUP_PF_Container_t));
  ASN_STRUCT_RESET(asn_DEF_OCUUP_PF_Container, cuupcont);
  cuupcont->gNB_CU_UP_Name = gnbcuupname;
  ret = ASN_SEQUENCE_ADD(&cuupcont->pf_ContainerList.list, listitem1);

  PF_Container_PR pres1 = PF_Container_PR_oCU_UP;

  PF_Container_t *pfcontainer = (PF_Container_t*)calloc(1, sizeof(PF_Container_t));
  ASN_STRUCT_RESET(asn_DEF_PF_Container, pfcontainer);
  pfcontainer->present = pres1;
  pfcontainer->choice.oCU_UP = *cuupcont;

  PM_Containers_List_t *containers_list = (PM_Containers_List_t*)calloc(1,
  sizeof(PM_Containers_List_t)); ASN_STRUCT_RESET(asn_DEF_PM_Containers_List, containers_list);
  containers_list->performanceContainer = pfcontainer;

  E2SM_KPM_IndicationMessage_Format1_t *format =
    (E2SM_KPM_IndicationMessage_Format1_t*)calloc(1, sizeof(E2SM_KPM_IndicationMessage_Format1_t));
  ASN_STRUCT_RESET(asn_DEF_E2SM_KPM_IndicationMessage_Format1, format);

  ret = ASN_SEQUENCE_ADD(&format->pm_Containers.list, containers_list);

  E2SM_KPM_IndicationMessage_PR pres = E2SM_KPM_IndicationMessage_PR_indicationMessage_Format1;

  indicationmessage->present = pres;

  indicationmessage->choice.indicationMessage_Format1 = *format;

  char *error_buf = (char*)calloc(300, sizeof(char));
  size_t errlen;

  asn_check_constraints(&asn_DEF_E2SM_KPM_IndicationMessage, indicationmessage, error_buf, &errlen);
  printf("error length %d\n", errlen);
  printf("error buf %s\n", error_buf);

  xer_fprint(stderr, &asn_DEF_E2SM_KPM_IndicationMessage, indicationmessage);


  uint8_t e2smbuffer[8192];
  size_t e2smbuffer_size = 8192;

  uint8_t e2smbuffer2[8192];
  size_t e2smbuffer_size2 = 8192;

  asn_enc_rval_t er =
    asn_encode_to_buffer(opt_cod,
       ATS_ALIGNED_BASIC_PER,
       &asn_DEF_E2SM_KPM_IndicationMessage,
       indicationmessage, e2smbuffer, e2smbuffer_size);

  fprintf(stderr, "er encded is %d\n", er.encoded);
  fprintf(stderr, "after encoding message");

  */
}

/*
void encode_kpm_bak(E2SM_KPM_IndicationMessage_t* indicationmessage) {
  ASN_STRUCT_RESET(asn_DEF_E2SM_KPM_IndicationMessage, indicationmessage);
  std::string gn = "GNBCUUP5";
  std::vector<uint8_t> gnvec(gn.begin(), gn.end());
  uint8_t *buf = &gnvec[0];
  OCTET_STRING_t *gnbcuupname = (OCTET_STRING_t*)calloc(1, sizeof(OCTET_STRING_t));
  gnbcuupname->size = 8;
  gnbcuupname->buf = (uint8_t*)calloc(1,8);
  memcpy(gnbcuupname->buf, buf, gnbcuupname->size);


  INTEGER_t *bytesdl = (INTEGER_t*)calloc(1, sizeof(INTEGER_t));
  uint8_t buffer[1];
  buffer[0]= 40000;
  bytesdl->buf = (uint8_t*)calloc(1,1);
  memcpy(bytesdl->buf, buffer,1);
  bytesdl->size = 1;

  INTEGER_t *bytesul = (INTEGER_t*)calloc(1, sizeof(INTEGER_t));
  uint8_t buffer1[1];
  buffer1[0] = 50000;
  bytesul->buf = (uint8_t*)calloc(1,1);
  memcpy(bytesul->buf, buffer1, 1);
  bytesul->size = 1;

  FQIPERSlicesPerPlmnListItem_t *fqilistitem = (FQIPERSlicesPerPlmnListItem_t*)calloc(1,
sizeof(FQIPERSlicesPerPlmnListItem_t)); ASN_STRUCT_RESET(asn_DEF_FQIPERSlicesPerPlmnListItem,
fqilistitem); fqilistitem->fiveQI = 9; fqilistitem->pDCPBytesDL = bytesdl; fqilistitem->pDCPBytesUL
= bytesul;



  std::string sl = "SLICE4";
  std::vector<uint8_t> slvec(sl.begin(), sl.end());
  //  uint8_t *buf1 = &slvec[0];
  uint8_t *buf1 = (uint8_t*)"SLICE4";
  OCTET_STRING_t *sst = (OCTET_STRING_t*)calloc(1, sizeof(OCTET_STRING_t));
  sst->size = 6;
  sst->buf = (uint8_t*)calloc(1,6);
  memcpy(sst->buf,buf1,sst->size);

  std::string sd = "SD1";
  std::vector<uint8_t> sdvec(sd.begin(), sd.end());
  //  uint8_t *bufz = &sdvec[0];
  uint8_t *bufz = (uint8_t*)"SD1";
  OCTET_STRING_t *sds = (OCTET_STRING_t*)calloc(1, sizeof(OCTET_STRING_t));
  sds->size = 3;
  sds->buf = (uint8_t*)calloc(1,3);
  memcpy(sds->buf, bufz, sds->size);


  SNSSAI_t *snssai = (SNSSAI_t*)calloc(1, sizeof(SNSSAI_t));
  ASN_STRUCT_RESET(asn_DEF_SNSSAI,snssai);
  snssai->sST.buf = (uint8_t*)calloc(6,1);
  snssai->sST.size = 6;
  memcpy(snssai->sST.buf, buf1, 6);
  snssai->sD = (OCTET_STRING_t*)calloc(1, sizeof(OCTET_STRING_t));
  snssai->sD->buf = (uint8_t*)calloc(1,3);
  snssai->sD->size = 3;
  memcpy(snssai->sD->buf, bufz, 3);



  SliceToReportListItem_t *slicelistitem =
(SliceToReportListItem_t*)calloc(1,sizeof(SliceToReportListItem_t));
  ASN_STRUCT_RESET(asn_DEF_SliceToReportListItem, slicelistitem);
  slicelistitem->sliceID = *snssai;
  int ret = ASN_SEQUENCE_ADD(&slicelistitem->fQIPERSlicesPerPlmnList.list, fqilistitem);

  uint8_t e2smbuffera[8192];
  size_t e2smbuffer_sizea = 8192;

  auto era =
    asn_encode_to_buffer(nullptr,
       ATS_ALIGNED_BASIC_PER,
       &asn_DEF_SliceToReportListItem,
       slicelistitem, e2smbuffera, e2smbuffer_sizea);
  fprintf(stderr, "inner er encded is %d\n", era.encoded);
  fprintf(stderr, "after encoding message");

  FGC_CUUP_PM_Format_t *pm_format = (FGC_CUUP_PM_Format_t*)calloc(1,sizeof(FGC_CUUP_PM_Format_t));
  ASN_STRUCT_RESET(asn_DEF_FGC_CUUP_PM_Format, pm_format);
  ret = ASN_SEQUENCE_ADD(&pm_format->sliceToReportList.list, slicelistitem);

  std::string pl = "PLMNID7";
  std::vector<uint8_t> plvec(pl.begin(), pl.end());
  uint8_t *buf2 = &plvec[0];

  OCTET_STRING_t *plmnid = (OCTET_STRING_t*)calloc(1,sizeof(OCTET_STRING_t));
  plmnid->buf = (uint8_t*)calloc(1,7);
  plmnid->size = 7;
  memcpy(plmnid->buf, buf2, plmnid->size);


  PlmnID_List_t *plmnidlist = (PlmnID_List_t*)calloc(1,sizeof(PlmnID_List_t));
  ASN_STRUCT_RESET(asn_DEF_PlmnID_List, plmnidlist);
  plmnidlist->pLMN_Identity = *plmnid;
  plmnidlist->cu_UP_PM_5GC = pm_format;

  CUUPMeasurement_Container_t *meas_cont = (CUUPMeasurement_Container_t*)calloc(1,
sizeof(CUUPMeasurement_Container_t)); ASN_STRUCT_RESET(asn_DEF_CUUPMeasurement_Container,
meas_cont); ret = ASN_SEQUENCE_ADD(&meas_cont->plmnList.list, plmnidlist);




  PF_ContainerListItem_t *listitem1 = (PF_ContainerListItem_t*)calloc(1,
sizeof(PF_ContainerListItem_t)); ASN_STRUCT_RESET(asn_DEF_PF_ContainerListItem, listitem1);
  listitem1->interface_type = 2;
  listitem1->o_CU_UP_PM_Container = *meas_cont;

  OCUUP_PF_Container_t *cuupcont = (OCUUP_PF_Container_t*)calloc(1,sizeof(OCUUP_PF_Container_t));
  ASN_STRUCT_RESET(asn_DEF_OCUUP_PF_Container, cuupcont);
  cuupcont->gNB_CU_UP_Name = gnbcuupname;
  ret = ASN_SEQUENCE_ADD(&cuupcont->pf_ContainerList.list, listitem1);

  PF_Container_PR pres1 = PF_Container_PR_oCU_UP;

  PF_Container_t *pfcontainer = (PF_Container_t*)calloc(1, sizeof(PF_Container_t));
  ASN_STRUCT_RESET(asn_DEF_PF_Container, pfcontainer);
  pfcontainer->present = pres1;
  pfcontainer->choice.oCU_UP = *cuupcont;

  PM_Containers_List_t *containers_list = (PM_Containers_List_t*)calloc(1,
sizeof(PM_Containers_List_t)); ASN_STRUCT_RESET(asn_DEF_PM_Containers_List, containers_list);
  containers_list->performanceContainer = pfcontainer;

  E2SM_KPM_IndicationMessage_Format1_t *format =
    (E2SM_KPM_IndicationMessage_Format1_t*)calloc(1, sizeof(E2SM_KPM_IndicationMessage_Format1_t));
  ASN_STRUCT_RESET(asn_DEF_E2SM_KPM_IndicationMessage_Format1, format);

  ret = ASN_SEQUENCE_ADD(&format->pm_Containers.list, containers_list);

  E2SM_KPM_IndicationMessage_PR pres = E2SM_KPM_IndicationMessage_PR_indicationMessage_Format1;

  indicationmessage->present = pres;

  indicationmessage->choice.indicationMessage_Format1 = *format;

  char *error_buf = (char*)calloc(300, sizeof(char));
  size_t errlen;

  asn_check_constraints(&asn_DEF_E2SM_KPM_IndicationMessage, indicationmessage, error_buf, &errlen);
  printf("error length %d\n", errlen);
  printf("error buf %s\n", error_buf);


  uint8_t e2smbuffer[8192];
  size_t e2smbuffer_size = 8192;

  uint8_t e2smbuffer2[8192];
  size_t e2smbuffer_size2 = 8192;

  auto er =
    asn_encode_to_buffer(nullptr,
       ATS_ALIGNED_BASIC_PER,
       &asn_DEF_E2SM_KPM_IndicationMessage,
       indicationmessage, e2smbuffer, e2smbuffer_size);

  fprintf(stderr, "er encded is %d\n", er.encoded);
  fprintf(stderr, "after encoding message");


}
*/