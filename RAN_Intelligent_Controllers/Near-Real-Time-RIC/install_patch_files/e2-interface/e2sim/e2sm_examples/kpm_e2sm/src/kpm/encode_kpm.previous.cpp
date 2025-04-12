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
#include <iostream>
#include <unistd.h>
#include <vector>

#include "encode_kpm.hpp"

using namespace std;

void encode_kpm_function_description(E2SM_KPM_RANfunction_Description_t* ranfunc_desc) {

  printf("kpm0\n");

  uint8_t *buf = (uint8_t*)"ORAN-E2SM-KPM";
  uint8_t *buf2 = (uint8_t*)"KPM monitor";
  uint8_t *buf3 = (uint8_t*)"OID123";

  OCTET_STRING_t *sname = (OCTET_STRING_t*)calloc(1, sizeof(OCTET_STRING_t));
  sname->buf = (uint8_t*)calloc(1,13);
  
  memcpy(sname->buf, buf, 13);
  sname->size = strlen((char*)buf);
  ranfunc_desc->ranFunction_Name.ranFunction_ShortName = *sname;

  long inst = 1;

  ASN_STRUCT_RESET(asn_DEF_E2SM_KPM_RANfunction_Description, ranfunc_desc);

  //  ranfunc_desc->ranFunction_Name.ranFunction_Description = (OCTET_STRING_t*)calloc(1, sizeof(OCTET_STRING_t));
  ranfunc_desc->ranFunction_Name.ranFunction_Description.buf = (uint8_t*)calloc(1,strlen((char*)buf2));
  memcpy(ranfunc_desc->ranFunction_Name.ranFunction_Description.buf, buf2, strlen((char*)buf2));
  ranfunc_desc->ranFunction_Name.ranFunction_Description.size = strlen((char*)buf2);
  ranfunc_desc->ranFunction_Name.ranFunction_Instance = &inst;

  printf("kpm0.9\n");

  //  ranfunc_desc->ranFunction_Name.ranFunction_E2SM_OID = (OCTET_STRING_t*)calloc(1, sizeof(OCTET_STRING_t));
  ranfunc_desc->ranFunction_Name.ranFunction_E2SM_OID.buf = (uint8_t*)calloc(1,strlen((char*)buf3));
  memcpy(ranfunc_desc->ranFunction_Name.ranFunction_E2SM_OID.buf, buf3, strlen((char*)buf3));
  ranfunc_desc->ranFunction_Name.ranFunction_E2SM_OID.size = strlen((char*)buf3);

  printf("kpm2\n");
  

  RIC_EventTriggerStyle_List_t *trigger_style =
    (RIC_EventTriggerStyle_List_t*)calloc(1, sizeof(RIC_EventTriggerStyle_List_t));
  trigger_style->ric_EventTriggerStyle_Type = 1;
  uint8_t *buf4 = (uint8_t*)"Periodic report";
  //  trigger_style->ric_EventTriggerStyle_Name = (OCTET_STRING_t*)calloc(1, sizeof(OCTET_STRING_t));
  trigger_style->ric_EventTriggerStyle_Name.buf = (uint8_t*)calloc(1,strlen((char*)buf4));
  memcpy(trigger_style->ric_EventTriggerStyle_Name.buf, buf4, strlen((char*)buf4));
  trigger_style->ric_EventTriggerStyle_Name.size = strlen((char*)buf4);
  trigger_style->ric_EventTriggerFormat_Type = 5;

  printf("kpm3\n");

  ranfunc_desc->e2SM_KPM_RANfunction_Item.ric_EventTriggerStyle_List =
    (E2SM_KPM_RANfunction_Description::E2SM_KPM_RANfunction_Description__e2SM_KPM_RANfunction_Item::E2SM_KPM_RANfunction_Description__e2SM_KPM_RANfunction_Item__ric_EventTriggerStyle_List*)calloc(1,sizeof(E2SM_KPM_RANfunction_Description::E2SM_KPM_RANfunction_Description__e2SM_KPM_RANfunction_Item::E2SM_KPM_RANfunction_Description__e2SM_KPM_RANfunction_Item__ric_EventTriggerStyle_List));

  int ret = ASN_SEQUENCE_ADD(&ranfunc_desc->e2SM_KPM_RANfunction_Item.ric_EventTriggerStyle_List->list , trigger_style);
  printf("ret is %d\n", ret);

  RIC_ReportStyle_List_t *report_style1 = (RIC_ReportStyle_List_t*)calloc(1, sizeof(RIC_ReportStyle_List_t));
  report_style1->ric_ReportStyle_Type = 1;

  uint8_t *buf5 = (uint8_t*)"O-DU Measurement Container for the 5GC connected deployment";

  printf("kpm4\n");  
  
  //  report_style1->ric_ReportStyle_Name = (OCTET_STRING_t*)calloc(1, sizeof(OCTET_STRING_t));
  report_style1->ric_ReportStyle_Name.buf = (uint8_t*)calloc(1,strlen((char*)buf5));
  memcpy(report_style1->ric_ReportStyle_Name.buf, buf5, strlen((char*)buf5));
  report_style1->ric_ReportStyle_Name.size = strlen((char*)buf5);  
  report_style1->ric_IndicationHeaderFormat_Type = 1;
  report_style1->ric_IndicationMessageFormat_Type = 1;
  
  printf("kpm5\n");  

  RIC_ReportStyle_List_t *report_style2 = (RIC_ReportStyle_List_t*)calloc(1, sizeof(RIC_ReportStyle_List_t));
  report_style2->ric_ReportStyle_Type = 2;
  
  uint8_t *buf6 = (uint8_t*)"O-DU Measurement Container for the EPC connected deployment";
  
  //  report_style2->ric_ReportStyle_Name = (OCTET_STRING_t*)calloc(1, sizeof(OCTET_STRING_t));

  
  report_style2->ric_ReportStyle_Name.buf = (uint8_t*)calloc(1,strlen((char*)buf6));
  memcpy(report_style2->ric_ReportStyle_Name.buf, buf6, strlen((char*)buf6));
  report_style2->ric_ReportStyle_Name.size = strlen((char*)buf6);  
  report_style2->ric_IndicationHeaderFormat_Type = 1;
  report_style2->ric_IndicationMessageFormat_Type = 1;

  printf("kpm6\n");  

  RIC_ReportStyle_List_t *report_style3 = (RIC_ReportStyle_List_t*)calloc(1, sizeof(RIC_ReportStyle_List_t));
  report_style3->ric_ReportStyle_Type = 3;

  uint8_t *buf7 = (uint8_t*)"O-CU-CP Measurement Container for the 5GC connected deployment";

  //  report_style3->ric_ReportStyle_Name = (OCTET_STRING_t*)calloc(1, sizeof(OCTET_STRING_t));
  report_style3->ric_ReportStyle_Name.buf = (uint8_t*)calloc(1,strlen((char*)buf7));
  memcpy(report_style3->ric_ReportStyle_Name.buf, buf7, strlen((char*)buf7));
  report_style3->ric_ReportStyle_Name.size = strlen((char*)buf7);
  report_style3->ric_IndicationHeaderFormat_Type = 1;
  report_style3->ric_IndicationMessageFormat_Type = 1;

  RIC_ReportStyle_List_t *report_style4 = (RIC_ReportStyle_List_t*)calloc(1, sizeof(RIC_ReportStyle_List_t));
  report_style4->ric_ReportStyle_Type = 4;

  uint8_t *buf8 = (uint8_t*)"O-CU-CP Measurement Container for the EPC connected deployment";

  //  report_style3->ric_ReportStyle_Name = (OCTET_STRING_t*)calloc(1, sizeof(OCTET_STRING_t));
  report_style4->ric_ReportStyle_Name.buf = (uint8_t*)calloc(1,strlen((char*)buf8));
  memcpy(report_style4->ric_ReportStyle_Name.buf, buf8, strlen((char*)buf8));
  report_style4->ric_ReportStyle_Name.size = strlen((char*)buf8);
  report_style4->ric_IndicationHeaderFormat_Type = 1;
  report_style4->ric_IndicationMessageFormat_Type = 1;

  RIC_ReportStyle_List_t *report_style5 = (RIC_ReportStyle_List_t*)calloc(1, sizeof(RIC_ReportStyle_List_t));
  report_style5->ric_ReportStyle_Type = 5;

  uint8_t *buf9 = (uint8_t*)"O-CU-UP Measurement Container for the 5GC connected deployment";

  //  report_style3->ric_ReportStyle_Name = (OCTET_STRING_t*)calloc(1, sizeof(OCTET_STRING_t));
  report_style5->ric_ReportStyle_Name.buf = (uint8_t*)calloc(1,strlen((char*)buf9));
  memcpy(report_style5->ric_ReportStyle_Name.buf, buf9, strlen((char*)buf9));
  report_style5->ric_ReportStyle_Name.size = strlen((char*)buf9);
  report_style5->ric_IndicationHeaderFormat_Type = 1;
  report_style5->ric_IndicationMessageFormat_Type = 1;


  RIC_ReportStyle_List_t *report_style6 = (RIC_ReportStyle_List_t*)calloc(1, sizeof(RIC_ReportStyle_List_t));
  report_style6->ric_ReportStyle_Type = 6;

  uint8_t *buf10 = (uint8_t*)"O-CU-UP Measurement Container for the EPC connected deployment";

  //  report_style3->ric_ReportStyle_Name = (OCTET_STRING_t*)calloc(1, sizeof(OCTET_STRING_t));
  report_style6->ric_ReportStyle_Name.buf = (uint8_t*)calloc(1,strlen((char*)buf10));
  memcpy(report_style6->ric_ReportStyle_Name.buf, buf10, strlen((char*)buf10));
  report_style6->ric_ReportStyle_Name.size = strlen((char*)buf10);
  report_style6->ric_IndicationHeaderFormat_Type = 1;
  report_style6->ric_IndicationMessageFormat_Type = 1;
  

  ranfunc_desc->e2SM_KPM_RANfunction_Item.ric_ReportStyle_List =
    (E2SM_KPM_RANfunction_Description::E2SM_KPM_RANfunction_Description__e2SM_KPM_RANfunction_Item::E2SM_KPM_RANfunction_Description__e2SM_KPM_RANfunction_Item__ric_ReportStyle_List*)calloc(1,sizeof(E2SM_KPM_RANfunction_Description::E2SM_KPM_RANfunction_Description__e2SM_KPM_RANfunction_Item::E2SM_KPM_RANfunction_Description__e2SM_KPM_RANfunction_Item__ric_ReportStyle_List));
  
  ASN_SEQUENCE_ADD(&ranfunc_desc->e2SM_KPM_RANfunction_Item.ric_ReportStyle_List->list, report_style1);
  ASN_SEQUENCE_ADD(&ranfunc_desc->e2SM_KPM_RANfunction_Item.ric_ReportStyle_List->list, report_style2);
  ASN_SEQUENCE_ADD(&ranfunc_desc->e2SM_KPM_RANfunction_Item.ric_ReportStyle_List->list, report_style3);
  ASN_SEQUENCE_ADD(&ranfunc_desc->e2SM_KPM_RANfunction_Item.ric_ReportStyle_List->list, report_style4);
  ASN_SEQUENCE_ADD(&ranfunc_desc->e2SM_KPM_RANfunction_Item.ric_ReportStyle_List->list, report_style5);
  ASN_SEQUENCE_ADD(&ranfunc_desc->e2SM_KPM_RANfunction_Item.ric_ReportStyle_List->list, report_style6);

  xer_fprint(stderr, &asn_DEF_E2SM_KPM_RANfunction_Description, ranfunc_desc);

}

void encode_e2sm_kpm_indication_header(E2SM_KPM_IndicationHeader_t *ihead, uint8_t *plmnid_buf, uint8_t *sst_buf, uint8_t *sd_buf,
				       long fqival, long qcival, uint8_t *nrcellid_buf, uint8_t *gnbid_buf, int gnbid_unused,
				       uint8_t *cuupid_buf, uint8_t *duid_buf, uint8_t *cuupname_buf) {

  
  //uint8_t *plmnid_buf = (uint8_t*)"747";
  //uint8_t *sst_buf = (uint8_t*)"1";
  //uint8_t *sd_buf = (uint8_t*)"100";
  
  E2SM_KPM_IndicationHeader_Format1_t* ind_header =
    (E2SM_KPM_IndicationHeader_Format1_t*)calloc(1,sizeof(E2SM_KPM_IndicationHeader_Format1_t));
  
  OCTET_STRING_t *plmnid = (OCTET_STRING_t*)calloc(1,sizeof(OCTET_STRING_t));
  plmnid->buf = (uint8_t*)calloc(3,1);
  plmnid->size = 3;
  memcpy(plmnid->buf, plmnid_buf, plmnid->size);
  
  //  long fqival = 9;
  //  long qcival = 9;
  
  OCTET_STRING_t *sst = (OCTET_STRING_t*)calloc(1, sizeof(OCTET_STRING_t));
  sst->size = 6;
  sst->buf = (uint8_t*)calloc(1,6);
  memcpy(sst->buf,sst_buf,sst->size);
  
  
  OCTET_STRING_t *sds = (OCTET_STRING_t*)calloc(1, sizeof(OCTET_STRING_t));
  sds->size = 3;
  sds->buf = (uint8_t*)calloc(1,3);
  memcpy(sds->buf, sd_buf, sds->size);
  
  
  SNSSAI_t *snssai = (SNSSAI_t*)calloc(1, sizeof(SNSSAI_t));
  ASN_STRUCT_RESET(asn_DEF_SNSSAI,snssai);
  snssai->sST.buf = (uint8_t*)calloc(1,1);
  snssai->sST.size = 1;
  memcpy(snssai->sST.buf, sst_buf, 1);
  snssai->sD = (OCTET_STRING_t*)calloc(1, sizeof(OCTET_STRING_t));
  snssai->sD->buf = (uint8_t*)calloc(1,3);
  snssai->sD->size = 3;
  memcpy(snssai->sD->buf, sd_buf, 3);
      
  BIT_STRING_t *nrcellid = (BIT_STRING_t*)calloc(1, sizeof(BIT_STRING_t));;
  nrcellid->buf = (uint8_t*)calloc(1,5);
  nrcellid->size = 5;
  memcpy(nrcellid->buf, nrcellid_buf, 5);
  /*
  nrcellid->buf[0] = 0x22;
  nrcellid->buf[1] = 0x5B;
  nrcellid->buf[2] = 0xD6;
  nrcellid->buf[3] = 0x00;
  nrcellid->buf[4] = 0x70;
  */  
  nrcellid->bits_unused = 4;
  
  BIT_STRING_t *gnb_bstring = (BIT_STRING_t*)calloc(1, sizeof(BIT_STRING_t));;
  gnb_bstring->buf = (uint8_t*)calloc(1,4);
  gnb_bstring->size = 4;
  memcpy(gnb_bstring->buf, gnbid_buf, 4);
  /*
  gnb_bstring->buf[0] = 0xB5;
  gnb_bstring->buf[1] = 0xC6;
  gnb_bstring->buf[2] = 0x77;
  gnb_bstring->buf[3] = 0x88;
  */
  
  gnb_bstring->bits_unused = gnbid_unused;
  
  INTEGER_t *cuup_id = (INTEGER_t*)calloc(1, sizeof(INTEGER_t));
  //  uint8_t buffer[1];
  //  buffer[0] = 20000;
  cuup_id->buf = (uint8_t*)calloc(1,1);
  memcpy(cuup_id->buf, cuupid_buf, 1);
  cuup_id->size = 1;

  INTEGER_t *du_id = (INTEGER_t*)calloc(1, sizeof(INTEGER_t));
  //  uint8_t buffer_duid[1];
  //  buffer_duid[0] = 20000;
  du_id->buf = (uint8_t*)calloc(1,1);
  memcpy(du_id->buf, duid_buf, 1);
  du_id->size = 1;


  //  uint8_t *buf5 = (uint8_t*)"GNBCUUP5";
  OCTET_STRING_t *cuupname = (OCTET_STRING_t*)calloc(1, sizeof(OCTET_STRING_t));
  cuupname->size = 8;
  cuupname->buf = (uint8_t*)calloc(1,8);
  memcpy(cuupname->buf, cuupname_buf, cuupname->size);


  ind_header->id_GlobalKPMnode_ID = (GlobalKPMnode_ID*)calloc(1,sizeof(GlobalKPMnode_ID));
  ind_header->id_GlobalKPMnode_ID->present = GlobalKPMnode_ID_PR_gNB;
  ind_header->id_GlobalKPMnode_ID->choice.gNB.global_gNB_ID.gnb_id.present = GNB_ID_Choice_PR_gnb_ID;
  ind_header->id_GlobalKPMnode_ID->choice.gNB.global_gNB_ID.gnb_id.choice.gnb_ID = *gnb_bstring;
  ind_header->id_GlobalKPMnode_ID->choice.gNB.global_gNB_ID.plmn_id = *plmnid;
  ind_header->id_GlobalKPMnode_ID->choice.gNB.gNB_CU_UP_ID = cuup_id;


  
  ind_header->nRCGI = (NRCGI*)calloc(1,sizeof(NRCGI));
  ind_header->nRCGI->pLMN_Identity = *plmnid;
  ind_header->nRCGI->nRCellIdentity = *nrcellid;
  
  ind_header->pLMN_Identity = plmnid;
  //  memcpy(ind_header->fiveQI, &fqival, 4);
  
  ind_header->sliceID = snssai;
  //  memcpy(ind_header->qci, &qcival, 4);


  ind_header->gNB_Name = (GNB_Name*)calloc(1,sizeof(GNB_Name));
  ind_header->gNB_Name->present = GNB_Name_PR_gNB_CU_UP_Name;
  ind_header->gNB_Name->choice.gNB_CU_UP_Name = *cuupname;

 
  ind_header->global_GNB_ID = (GlobalgNB_ID*)calloc(1,sizeof(GlobalgNB_ID));
  ind_header->global_GNB_ID->plmn_id = *plmnid;
  ind_header->global_GNB_ID->gnb_id.present = GNB_ID_Choice_PR_gnb_ID;
  ind_header->global_GNB_ID->gnb_id.choice.gnb_ID = *gnb_bstring;


  //  long msg_type = 2;
  //  ind_header->message_Type = &msg_type;
  ind_header->gNB_DU_ID = du_id;

  
  ihead->present = E2SM_KPM_IndicationHeader_PR_indicationHeader_Format1;
  ihead->choice.indicationHeader_Format1 = *ind_header;
  
  xer_fprint(stderr, &asn_DEF_E2SM_KPM_IndicationHeader, ihead);
  
}



void encode_kpm_ocuup_user_level(RAN_Container_t *ranco,
				 uint8_t *plmnid_buf,
				 uint8_t *nrcellid_buf,
				 uint8_t *crnti_buf,
				 int bytes_dl,
				 int bytes_ul) {

  uint8_t *buf = (uint8_t*)"2020.06.13 13:01:05.222";
  Timestamp_t *ts = (Timestamp_t*)calloc(1,sizeof(Timestamp_t));
  ts->buf = (uint8_t*)calloc(strlen((char*)buf),1);
  ts->size = strlen((char*)buf);
  memcpy(ts->buf,buf,ts->size);

  printf("enc1\n");

  CU_UP_Usage_Report_CellResourceReportItem_t  *report_item =
    (CU_UP_Usage_Report_CellResourceReportItem_t*)calloc(1,sizeof(CU_UP_Usage_Report_CellResourceReportItem_t));

  //  uint8_t *buf2 = (uint8_t*)"747";
  
  OCTET_STRING_t *plmnidstr = (OCTET_STRING_t*)calloc(1,sizeof(OCTET_STRING_t));
  plmnidstr->buf = (uint8_t*)calloc(3,1);
  plmnidstr->size = 3;
  memcpy(plmnidstr->buf, plmnid_buf, plmnidstr->size);

  printf("enc2\n");  

  NRCellIdentity_t *nrcellid = (NRCellIdentity_t*)calloc(1,sizeof(NRCellIdentity_t));
  //  uint8_t* buf3 = (uint8_t*)"12340";
  nrcellid->buf = (uint8_t*)calloc(1,5);
  memcpy(nrcellid->buf, nrcellid_buf, 5);
  nrcellid->size = 5;
  nrcellid->bits_unused = 4;

  NRCGI *nrcgi = (NRCGI*)calloc(1,sizeof(NRCGI));
  nrcgi->pLMN_Identity = *plmnidstr;
  nrcgi->nRCellIdentity = *nrcellid;
 
  printf("enc3\n");
  
  report_item->nRCGI = *nrcgi;

  CU_UP_Usage_Report_UeResourceReportItem *ue_report_item =
    (CU_UP_Usage_Report_UeResourceReportItem*)calloc(1,sizeof(CU_UP_Usage_Report_UeResourceReportItem));

  printf("enc3.2\n");   
  
  //  uint8_t* crnti_str = (uint8_t*)"1111";
  OCTET_STRING *crnti = (OCTET_STRING*)calloc(1,sizeof(OCTET_STRING));
  crnti->buf = (uint8_t*)calloc(1,4);
  
  printf("enc3.3\n");
  
  crnti->size = strlen((char*)crnti_buf);

  printf("enc3.4\n");
  memcpy(crnti->buf, crnti_buf, crnti->size);

  printf("enc4\n");

  INTEGER_t *bytesdl = (INTEGER_t*)calloc(1, sizeof(INTEGER_t));
  int array_size_dl;

  if (bytes_dl <= 64) {
    array_size_dl = 1;

    uint8_t buffer[array_size_dl];
    buffer[0] = bytes_dl & 0xFF;
    bytesdl->buf = (uint8_t*)calloc(1,1);
    memcpy(bytesdl->buf,buffer,1);
    bytesdl->size = 1;

  } else if (bytes_dl <= 16384) {
    array_size_dl = 2;

    uint8_t buffer[array_size_dl];
    buffer[0] = (bytes_dl >> 8) & 0xFF;
    buffer[1] = bytes_dl & 0xFF;
    bytesdl->buf = (uint8_t*)calloc(2,1);
    memcpy(bytesdl->buf,buffer,2);
    bytesdl->size = 2;
    
  } else if (bytes_dl <= 4194304) {
    array_size_dl = 3;

    uint8_t buffer[array_size_dl];
    buffer[0] = (bytes_dl >> 16) & 0xFF;
    buffer[1] = (bytes_dl >> 8) & 0xFF;
    buffer[2] = bytes_dl & 0xFF;
    bytesdl->buf = (uint8_t*)calloc(3,1);
    memcpy(bytesdl->buf,buffer,3);
    bytesdl->size = 3;    
    
  } else if (bytes_dl <= 1073741824) {
    array_size_dl = 4;
    uint8_t buffer[array_size_dl];
    buffer[0] = (bytes_dl >> 24) & 0xFF;
    buffer[1] = (bytes_dl >> 16) & 0xFF;
    buffer[2] = (bytes_dl >> 8) & 0xFF;
    buffer[3] = bytes_dl & 0xFF;
    bytesdl->buf = (uint8_t*)calloc(4,1);
    memcpy(bytesdl->buf,buffer,4);
    bytesdl->size = 4;
  }
  

  INTEGER_t *bytesul = (INTEGER_t*)calloc(1, sizeof(INTEGER_t));

  int array_size_ul;

  if (bytes_ul <= 64) {
    array_size_ul = 1;

    uint8_t buffer[array_size_ul];
    buffer[0] = bytes_ul & 0xFF;
    bytesul->buf = (uint8_t*)calloc(1,1);
    memcpy(bytesul->buf,buffer,1);
    bytesul->size = 1;

  } else if (bytes_ul <= 16384) {
    array_size_ul = 2;

    uint8_t buffer[array_size_ul];
    buffer[0] = (bytes_ul >> 8) & 0xFF;
    buffer[1] = bytes_ul & 0xFF;
    bytesul->buf = (uint8_t*)calloc(2,1);
    memcpy(bytesul->buf,buffer,2);
    bytesul->size = 2;
    
  } else if (bytes_ul <= 4194304) {
    array_size_ul = 3;

    uint8_t buffer[array_size_ul];
    buffer[0] = (bytes_ul >> 16) & 0xFF;
    buffer[1] = (bytes_ul >> 8) & 0xFF;
    buffer[2] = bytes_ul & 0xFF;
    bytesul->buf = (uint8_t*)calloc(3,1);
    memcpy(bytesul->buf,buffer,3);
    bytesul->size = 3;    
    
  } else if (bytes_ul <= 1073741824) {
    array_size_ul = 4;
    uint8_t buffer[array_size_ul];
    buffer[0] = (bytes_ul >> 24) & 0xFF;
    buffer[1] = (bytes_ul >> 16) & 0xFF;
    buffer[2] = (bytes_ul >> 8) & 0xFF;
    buffer[3] = bytes_ul & 0xFF;
    bytesul->buf = (uint8_t*)calloc(4,1);
    memcpy(bytesul->buf,buffer,4);
    bytesul->size = 4;
  }
  
  
  
  ue_report_item->c_RNTI = *crnti;
  ue_report_item->pDCPBytesDL = bytesdl;
  ue_report_item->pDCPBytesUL = bytesul;


  ASN_SEQUENCE_ADD(&report_item->ueResourceReportList.list, ue_report_item);  

  ranco->timestamp = *ts;
  ranco->reportContainer.present = RAN_Container__reportContainer_PR_oCU_UP_UE;
  ASN_SEQUENCE_ADD(&ranco->reportContainer.choice.oCU_UP_UE.cellResourceReportList.list, report_item);

  xer_fprint(stderr, &asn_DEF_RAN_Container, ranco);

}

void encode_kpm_ocucp_user_level(RAN_Container_t *ranco,
				 uint8_t *plmnid_buf,
				 uint8_t *nrcellid_buf,
				 uint8_t *crnti_buf,
				 const uint8_t *serving_buf,
				 const uint8_t *neighbor_buf) {
  uint8_t *buf = (uint8_t*)"2020.06.13 13:01:05.222";
  Timestamp_t *ts = (Timestamp_t*)calloc(1,sizeof(Timestamp_t));
  ts->buf = (uint8_t*)calloc(strlen((char*)buf),1);
  ts->size = strlen((char*)buf);
  memcpy(ts->buf,buf,ts->size);

  printf("enc1\n");

  CU_CP_Usage_Report_CellResourceReportItem_t  *report_item =
    (CU_CP_Usage_Report_CellResourceReportItem_t*)calloc(1,sizeof(CU_CP_Usage_Report_CellResourceReportItem_t));

  int plmnid_size = strlen((char*)plmnid_buf);  
  OCTET_STRING_t *plmnidstr = (OCTET_STRING_t*)calloc(1,sizeof(OCTET_STRING_t));
  plmnidstr->buf = (uint8_t*)calloc(plmnid_size,1);
  plmnidstr->size = plmnid_size;
  memcpy(plmnidstr->buf, plmnid_buf, plmnidstr->size);

  printf("enc2\n");

  NRCellIdentity_t *nrcellid = (NRCellIdentity_t*)calloc(1,sizeof(NRCellIdentity_t));

  //  int nrcellid_size = strlen((char*)nrcellid_buf);
  int nrcellid_size = 5;
  nrcellid->buf = (uint8_t*)calloc(1, nrcellid_size);
  memcpy(nrcellid->buf, nrcellid_buf, nrcellid_size);
  nrcellid->size = 5;
  nrcellid->bits_unused = 4;

  NRCGI *nrcgi = (NRCGI*)calloc(1,sizeof(NRCGI));
  nrcgi->pLMN_Identity = *plmnidstr;
  nrcgi->nRCellIdentity = *nrcellid;
 
  printf("enc3\n");
  
  report_item->nRCGI = *nrcgi;

  CU_CP_Usage_Report_UeResourceReportItem *ue_report_item =
    (CU_CP_Usage_Report_UeResourceReportItem*)calloc(1,sizeof(CU_CP_Usage_Report_UeResourceReportItem));

  printf("enc3.2\n");


  int crnti_size = strlen((char*)crnti_buf);
  OCTET_STRING *crnti = (OCTET_STRING*)calloc(1,sizeof(OCTET_STRING));
  crnti->buf = (uint8_t*)calloc(1, crnti_size);
  
  printf("enc3.3\n");
  
  crnti->size = strlen((char*)crnti_buf);

  printf("enc3.4\n");
  memcpy(crnti->buf, crnti_buf, crnti->size);

  //  uint8_t *buf_serving = (uint8_t*)"RSRP10";

  int serving_buf_len = strlen((char*)serving_buf);
  OCTET_STRING_t *servingstr = (OCTET_STRING_t*)calloc(1,sizeof(OCTET_STRING_t));
  servingstr->buf = (uint8_t*)calloc(serving_buf_len,1);
  servingstr->size = serving_buf_len;
  memcpy(servingstr->buf, serving_buf, servingstr->size);


  int neighbor_buf_len = strlen((char*)neighbor_buf);
  //  uint8_t *buf_neighbor = (uint8_t*)"-10,-15";
  OCTET_STRING_t *neighborstr = (OCTET_STRING_t*)calloc(1,sizeof(OCTET_STRING_t));
  ts->buf = (uint8_t*)calloc(neighbor_buf_len,1);
  neighborstr->buf = (uint8_t*)calloc(neighbor_buf_len,1);
  neighborstr->size = neighbor_buf_len;
  memcpy(neighborstr->buf, neighbor_buf, neighborstr->size);

  ue_report_item->c_RNTI = *crnti;
  ue_report_item->serving_Cell_RF_Type = servingstr;
  ue_report_item->neighbor_Cell_RF = neighborstr;


  ASN_SEQUENCE_ADD(&report_item->ueResourceReportList.list, ue_report_item);  

  ranco->timestamp = *ts;
  ranco->reportContainer.present = RAN_Container__reportContainer_PR_oCU_CP_UE;
  ASN_SEQUENCE_ADD(&ranco->reportContainer.choice.oCU_CP_UE.cellResourceReportList.list, report_item);

  xer_fprint(stderr, &asn_DEF_RAN_Container, ranco);
  

}

void encode_kpm_ocucp_user_level(RAN_Container_t *ranco) {

  uint8_t *buf = (uint8_t*)"2020.06.13 13:01:05.222";
  Timestamp_t *ts = (Timestamp_t*)calloc(1,sizeof(Timestamp_t));
  ts->buf = (uint8_t*)calloc(strlen((char*)buf),1);
  ts->size = strlen((char*)buf);
  memcpy(ts->buf,buf,ts->size);

  printf("enc1\n");

  CU_CP_Usage_Report_CellResourceReportItem_t  *report_item =
    (CU_CP_Usage_Report_CellResourceReportItem_t*)calloc(1,sizeof(CU_CP_Usage_Report_CellResourceReportItem_t));

  uint8_t *buf2 = (uint8_t*)"747";
  
  OCTET_STRING_t *plmnidstr = (OCTET_STRING_t*)calloc(1,sizeof(OCTET_STRING_t));
  plmnidstr->buf = (uint8_t*)calloc(3,1);
  plmnidstr->size = 3;
  memcpy(plmnidstr->buf, buf2, plmnidstr->size);

  printf("enc2\n");

  NRCellIdentity_t *nrcellid = (NRCellIdentity_t*)calloc(1,sizeof(NRCellIdentity_t));
  uint8_t* buf3 = (uint8_t*)"12340";
  nrcellid->buf = (uint8_t*)calloc(1,5);
  memcpy(nrcellid->buf, buf3, 5);
  nrcellid->size = 5;
  nrcellid->bits_unused = 4;

  NRCGI *nrcgi = (NRCGI*)calloc(1,sizeof(NRCGI));
  nrcgi->pLMN_Identity = *plmnidstr;
  nrcgi->nRCellIdentity = *nrcellid;
 
  printf("enc3\n");
  
  report_item->nRCGI = *nrcgi;

  CU_CP_Usage_Report_UeResourceReportItem *ue_report_item =
    (CU_CP_Usage_Report_UeResourceReportItem*)calloc(1,sizeof(CU_CP_Usage_Report_UeResourceReportItem));

  printf("enc3.2\n");

  uint8_t* crnti_str = (uint8_t*)"1111";
  OCTET_STRING *crnti = (OCTET_STRING*)calloc(1,sizeof(OCTET_STRING));
  crnti->buf = (uint8_t*)calloc(1,4);
  
  printf("enc3.3\n");
  
  crnti->size = strlen((char*)crnti_str);

  printf("enc3.4\n");
  memcpy(crnti->buf, crnti_str, crnti->size);

  uint8_t *buf_serving = (uint8_t*)"RSRP10";
  OCTET_STRING_t *servingstr = (OCTET_STRING_t*)calloc(1,sizeof(OCTET_STRING_t));
  servingstr->buf = (uint8_t*)calloc(6,1);
  servingstr->size = 6;
  memcpy(servingstr->buf, buf_serving, servingstr->size);

  uint8_t *buf_neighbor = (uint8_t*)"-10,-15";
  OCTET_STRING_t *neighborstr = (OCTET_STRING_t*)calloc(1,sizeof(OCTET_STRING_t));
  neighborstr->buf = (uint8_t*)calloc(7,1);
  neighborstr->size = 7;
  memcpy(neighborstr->buf, buf_neighbor, neighborstr->size);

  ue_report_item->c_RNTI = *crnti;
  ue_report_item->serving_Cell_RF_Type = servingstr;
  ue_report_item->neighbor_Cell_RF = neighborstr;


  ASN_SEQUENCE_ADD(&report_item->ueResourceReportList.list, ue_report_item);  

  ranco->timestamp = *ts;
  ranco->reportContainer.present = RAN_Container__reportContainer_PR_oCU_CP_UE;
  ASN_SEQUENCE_ADD(&ranco->reportContainer.choice.oCU_CP_UE.cellResourceReportList.list, report_item);

  xer_fprint(stderr, &asn_DEF_RAN_Container, ranco);

}


void encode_kpm_odu_user_level(RAN_Container_t *ranco,
			       uint8_t *plmnid_buf,
			       uint8_t *nrcellid_buf,
			       uint8_t *crnti_buf,
			       long prb_usage_dl,
			       long prb_usage_ul) {

  uint8_t *buf = (uint8_t*)"2020.06.13 13:01:05.222";
  Timestamp_t *ts = (Timestamp_t*)calloc(1,sizeof(Timestamp_t));
  ts->buf = (uint8_t*)calloc(strlen((char*)buf),1);
  ts->size = strlen((char*)buf);
  memcpy(ts->buf,buf,ts->size);

  printf("enc1\n");

  DU_Usage_Report_CellResourceReportItem_t *report_item =
    (DU_Usage_Report_CellResourceReportItem_t*)calloc(1,sizeof(DU_Usage_Report_CellResourceReportItem_t));

  //  uint8_t *buf2 = (uint8_t*)"747";

  int plmnid_size = strlen((char*)plmnid_buf);  
  OCTET_STRING_t *plmnidstr = (OCTET_STRING_t*)calloc(1,sizeof(OCTET_STRING_t));
  plmnidstr->buf = (uint8_t*)calloc(plmnid_size,1);
  plmnidstr->size = plmnid_size;
  memcpy(plmnidstr->buf, plmnid_buf, plmnidstr->size);

  printf("enc2\n");  

  NRCellIdentity_t *nrcellid = (NRCellIdentity_t*)calloc(1,sizeof(NRCellIdentity_t));

  //  int nrcellid_size = strlen((char*)nrcellid_buf);
  int nrcellid_size = 5;
  nrcellid->buf = (uint8_t*)calloc(1,nrcellid_size);
  memcpy(nrcellid->buf, nrcellid_buf, nrcellid_size);
  nrcellid->size = nrcellid_size;
  nrcellid->bits_unused = 4;

  NRCGI *nrcgi = (NRCGI*)calloc(1,sizeof(NRCGI));
  nrcgi->pLMN_Identity = *plmnidstr;
  nrcgi->nRCellIdentity = *nrcellid;
 
  printf("enc3\n"); 
  
  report_item->nRCGI = *nrcgi;

  printf("enc3.1\n");   

  DU_Usage_Report_UeResourceReportItem *ue_report_item =
    (DU_Usage_Report_UeResourceReportItem*)calloc(1,sizeof(DU_Usage_Report_UeResourceReportItem));

  printf("enc3.2\n");   

  int crnti_size = strlen((char*)crnti_buf);

  OCTET_STRING *crnti = (OCTET_STRING*)calloc(1,sizeof(OCTET_STRING));
  crnti->buf = (uint8_t*)calloc(1,crnti_size);
  
  printf("enc3.3\n");
  
  crnti->size = strlen((char*)crnti_buf);

  printf("enc3.4\n");
  memcpy(crnti->buf, crnti_buf, crnti->size);

  printf("enc4\n");  

  
  ue_report_item->c_RNTI = *crnti;
  ue_report_item->dl_PRBUsage = &prb_usage_dl;

  printf("enc5\n");
  
  ue_report_item->ul_PRBUsage = &prb_usage_ul;

  printf("enc6\n");
  
  ASN_SEQUENCE_ADD(&report_item->ueResourceReportList.list, ue_report_item);

  
  ranco->timestamp = *ts;
  ranco->reportContainer.present = RAN_Container__reportContainer_PR_oDU_UE;
  ASN_SEQUENCE_ADD(&ranco->reportContainer.choice.oDU_UE.cellResourceReportList.list, report_item);

  xer_fprint(stderr, &asn_DEF_RAN_Container, ranco);

  
}

void encode_kpm_report_rancontainer_du_parameterized(E2SM_KPM_IndicationMessage_t* indicationmessage,
						     uint8_t *plmnid_buf,
						     uint8_t *nrcellid_buf,
						     uint8_t *crnti_buf,
						     long prb_usage_dl,
						     long prb_usage_ul) {
  
  RAN_Container_t *ranco = (RAN_Container_t*)calloc(1,sizeof(RAN_Container_t));
  encode_kpm_odu_user_level(ranco,plmnid_buf,nrcellid_buf,crnti_buf,prb_usage_dl,prb_usage_ul);

  printf("After creating RAN container, xer printing it\n");
  xer_fprint(stderr, &asn_DEF_RAN_Container, ranco);

  PM_Containers_List_t *containers_list = (PM_Containers_List_t*)calloc(1, sizeof(PM_Containers_List_t));
  ASN_STRUCT_RESET(asn_DEF_PM_Containers_List, containers_list);
  containers_list->theRANContainer = ranco;

  E2SM_KPM_IndicationMessage_Format1_t *format =
    (E2SM_KPM_IndicationMessage_Format1_t*)calloc(1, sizeof(E2SM_KPM_IndicationMessage_Format1_t));
  ASN_STRUCT_RESET(asn_DEF_E2SM_KPM_IndicationMessage_Format1, format);

  int ret = ASN_SEQUENCE_ADD(&format->pm_Containers.list, containers_list);
  
  E2SM_KPM_IndicationMessage__indicationMessage_PR pres = E2SM_KPM_IndicationMessage__indicationMessage_PR_indicationMessage_Format1;

  indicationmessage->indicationMessage.present = pres;

  indicationmessage->indicationMessage.choice.indicationMessage_Format1 = *format;

  char *error_buf = (char*)calloc(300, sizeof(char));
  size_t errlen;

  asn_check_constraints(&asn_DEF_E2SM_KPM_IndicationMessage, indicationmessage, error_buf, &errlen);
  printf("error length %d\n", errlen);
  printf("error buf %s\n", error_buf);

  xer_fprint(stderr, &asn_DEF_E2SM_KPM_IndicationMessage, indicationmessage);

  asn_codec_ctx_t *opt_cod;

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
  fprintf(stderr, "after encoding message\n");


}

void encode_kpm_report_rancontainer_cucp_parameterized(E2SM_KPM_IndicationMessage_t* indicationmessage,
						       uint8_t *plmnid_buf,
						       uint8_t *nrcellid_buf,
						       uint8_t *crnti_buf,
						       const uint8_t *serving_buf,
						       const uint8_t *neighbor_buf) {

  RAN_Container_t *ranco = (RAN_Container_t*)calloc(1,sizeof(RAN_Container_t));
  encode_kpm_ocucp_user_level(ranco, plmnid_buf,
			      nrcellid_buf, crnti_buf,
			      serving_buf, neighbor_buf);

  printf("After creating RAN container, xer printing it\n");
  xer_fprint(stderr, &asn_DEF_RAN_Container, ranco);
  

  PM_Containers_List_t *containers_list = (PM_Containers_List_t*)calloc(1, sizeof(PM_Containers_List_t));
  ASN_STRUCT_RESET(asn_DEF_PM_Containers_List, containers_list);
  containers_list->theRANContainer = ranco;

  E2SM_KPM_IndicationMessage_Format1_t *format =
    (E2SM_KPM_IndicationMessage_Format1_t*)calloc(1, sizeof(E2SM_KPM_IndicationMessage_Format1_t));
  ASN_STRUCT_RESET(asn_DEF_E2SM_KPM_IndicationMessage_Format1, format);

  int ret = ASN_SEQUENCE_ADD(&format->pm_Containers.list, containers_list);
  
  E2SM_KPM_IndicationMessage__indicationMessage_PR pres = E2SM_KPM_IndicationMessage__indicationMessage_PR_indicationMessage_Format1;

  indicationmessage->indicationMessage.present = pres;

  indicationmessage->indicationMessage.choice.indicationMessage_Format1 = *format;

  char *error_buf = (char*)calloc(300, sizeof(char));
  size_t errlen;

  asn_check_constraints(&asn_DEF_E2SM_KPM_IndicationMessage, indicationmessage, error_buf, &errlen);
  printf("error length %d\n", errlen);
  printf("error buf %s\n", error_buf);

  xer_fprint(stderr, &asn_DEF_E2SM_KPM_IndicationMessage, indicationmessage);

  asn_codec_ctx_t *opt_cod;

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
  fprintf(stderr, "after encoding message\n");
  
}
						       
						       
void encode_kpm_report_rancontainer_cucp(E2SM_KPM_IndicationMessage_t* indicationmessage) {

  RAN_Container_t *ranco = (RAN_Container_t*)calloc(1,sizeof(RAN_Container_t));
  encode_kpm_ocucp_user_level(ranco);

  PM_Containers_List_t *containers_list = (PM_Containers_List_t*)calloc(1, sizeof(PM_Containers_List_t));
  ASN_STRUCT_RESET(asn_DEF_PM_Containers_List, containers_list);
  containers_list->theRANContainer = ranco;

  E2SM_KPM_IndicationMessage_Format1_t *format =
    (E2SM_KPM_IndicationMessage_Format1_t*)calloc(1, sizeof(E2SM_KPM_IndicationMessage_Format1_t));
  ASN_STRUCT_RESET(asn_DEF_E2SM_KPM_IndicationMessage_Format1, format);

  int ret = ASN_SEQUENCE_ADD(&format->pm_Containers.list, containers_list);
  
  E2SM_KPM_IndicationMessage__indicationMessage_PR pres = E2SM_KPM_IndicationMessage__indicationMessage_PR_indicationMessage_Format1;

  indicationmessage->indicationMessage.present = pres;

  indicationmessage->indicationMessage.choice.indicationMessage_Format1 = *format;

  char *error_buf = (char*)calloc(300, sizeof(char));
  size_t errlen;

  asn_check_constraints(&asn_DEF_E2SM_KPM_IndicationMessage, indicationmessage, error_buf, &errlen);
  printf("error length %d\n", errlen);
  printf("error buf %s\n", error_buf);

  //  xer_fprint(stderr, &asn_DEF_E2SM_KPM_IndicationMessage, indicationmessage);

  asn_codec_ctx_t *opt_cod;

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
  fprintf(stderr, "after encoding message\n");


}

void encode_kpm_report_rancontainer_cuup_parameterized(E2SM_KPM_IndicationMessage_t* indicationmessage,
						       uint8_t *plmnid_buf,
						       uint8_t *nrcellid_buf,
						       uint8_t *crnti_buf,
						       int pdcp_bytesdl,
						       int pdcp_bytesul) {

  RAN_Container_t *ranco = (RAN_Container_t*)calloc(1,sizeof(RAN_Container_t));
  encode_kpm_ocuup_user_level(ranco,plmnid_buf,nrcellid_buf,crnti_buf,pdcp_bytesdl,pdcp_bytesul);

  fprintf(stderr, "After creating RAN container, xer printing it\n");
  xer_fprint(stderr, &asn_DEF_RAN_Container, ranco);  

  PM_Containers_List_t *containers_list = (PM_Containers_List_t*)calloc(1, sizeof(PM_Containers_List_t));
  ASN_STRUCT_RESET(asn_DEF_PM_Containers_List, containers_list);
  containers_list->theRANContainer = ranco;

  E2SM_KPM_IndicationMessage_Format1_t *format =
    (E2SM_KPM_IndicationMessage_Format1_t*)calloc(1, sizeof(E2SM_KPM_IndicationMessage_Format1_t));
  ASN_STRUCT_RESET(asn_DEF_E2SM_KPM_IndicationMessage_Format1, format);

  int ret = ASN_SEQUENCE_ADD(&format->pm_Containers.list, containers_list);
  
  E2SM_KPM_IndicationMessage__indicationMessage_PR pres = E2SM_KPM_IndicationMessage__indicationMessage_PR_indicationMessage_Format1;

  indicationmessage->indicationMessage.present = pres;

  indicationmessage->indicationMessage.choice.indicationMessage_Format1 = *format;

  char *error_buf = (char*)calloc(300, sizeof(char));
  size_t errlen;

  asn_check_constraints(&asn_DEF_E2SM_KPM_IndicationMessage, indicationmessage, error_buf, &errlen);
  printf("error length %d\n", errlen);
  printf("error buf %s\n", error_buf);

  xer_fprint(stderr, &asn_DEF_E2SM_KPM_IndicationMessage, indicationmessage);

  asn_codec_ctx_t *opt_cod;

  uint8_t e2smbuffer[8192];
  size_t e2smbuffer_size = 8192;

  uint8_t e2smbuffer2[8192];
  size_t e2smbuffer_size2 = 8192;

  //  xer_fprint(stderr, &asn_DEF_E2SM_KPM_IndicationMessage, indicationmessage);  

  asn_enc_rval_t er =
    asn_encode_to_buffer(opt_cod,
			 ATS_ALIGNED_BASIC_PER,
			 &asn_DEF_E2SM_KPM_IndicationMessage,
			 indicationmessage, e2smbuffer, e2smbuffer_size);

  fprintf(stderr, "er encded is %d\n", er.encoded);
  fprintf(stderr, "after encoding message\n");  


}

void encode_kpm_report_rancontainer_cuup(E2SM_KPM_IndicationMessage_t* indicationmessage) {

  RAN_Container_t *ranco = (RAN_Container_t*)calloc(1,sizeof(RAN_Container_t));
  //encode_kpm_ocuup_user_level(ranco);

  
  uint8_t *buf = (uint8_t*)"2020.06.13 13:01:05.222";
  Timestamp_t *ts = (Timestamp_t*)calloc(1,sizeof(Timestamp_t));
  ts->buf = (uint8_t*)calloc(strlen((char*)buf),1);
  ts->size = strlen((char*)buf);
  memcpy(ts->buf,buf,ts->size);

  printf("enc1\n");

  CU_CP_Usage_Report_CellResourceReportItem_t  *report_item =
    (CU_CP_Usage_Report_CellResourceReportItem_t*)calloc(1,sizeof(CU_CP_Usage_Report_CellResourceReportItem_t));

  uint8_t *buf2 = (uint8_t*)"747";
  
  OCTET_STRING_t *plmnidstr = (OCTET_STRING_t*)calloc(1,sizeof(OCTET_STRING_t));
  plmnidstr->buf = (uint8_t*)calloc(3,1);
  plmnidstr->size = 3;
  memcpy(plmnidstr->buf, buf2, plmnidstr->size);

  printf("enc2\n");  

  NRCellIdentity_t *nrcellid = (NRCellIdentity_t*)calloc(1,sizeof(NRCellIdentity_t));
  uint8_t* buf3 = (uint8_t*)"12340";
  nrcellid->buf = (uint8_t*)calloc(1,5);
  memcpy(nrcellid->buf, buf3, 5);
  nrcellid->size = 5;
  nrcellid->bits_unused = 4;

  NRCGI *nrcgi = (NRCGI*)calloc(1,sizeof(NRCGI));
  nrcgi->pLMN_Identity = *plmnidstr;
  nrcgi->nRCellIdentity = *nrcellid;
 
  printf("enc3\n"); 
  
  report_item->nRCGI = *nrcgi;

  CU_CP_Usage_Report_UeResourceReportItem *ue_report_item =
    (CU_CP_Usage_Report_UeResourceReportItem*)calloc(1,sizeof(CU_CP_Usage_Report_UeResourceReportItem));

  printf("enc3.2\n");

  uint8_t* crnti_str = (uint8_t*)"1111";
  OCTET_STRING *crnti = (OCTET_STRING*)calloc(1,sizeof(OCTET_STRING));
  crnti->buf = (uint8_t*)calloc(1,4);
  
  printf("enc3.3\n");
  
  crnti->size = strlen((char*)crnti_str);

  printf("enc3.4\n");
  memcpy(crnti->buf, crnti_str, crnti->size);

  uint8_t *buf_serving = (uint8_t*)"RSRP10";
  OCTET_STRING_t *servingstr = (OCTET_STRING_t*)calloc(1,sizeof(OCTET_STRING_t));
  servingstr->buf = (uint8_t*)calloc(6,1);
  servingstr->size = 6;
  memcpy(servingstr->buf, buf_serving, servingstr->size);

  uint8_t *buf_neighbor = (uint8_t*)"-10,-15";
  OCTET_STRING_t *neighborstr = (OCTET_STRING_t*)calloc(1,sizeof(OCTET_STRING_t));
  neighborstr->buf = (uint8_t*)calloc(7,1);
  neighborstr->size = 7;
  memcpy(neighborstr->buf, buf_neighbor, neighborstr->size);

  ue_report_item->c_RNTI = *crnti;
  ue_report_item->serving_Cell_RF_Type = servingstr;
  ue_report_item->neighbor_Cell_RF = neighborstr;


  ASN_SEQUENCE_ADD(&report_item->ueResourceReportList.list, ue_report_item);

  ranco->timestamp = *ts;
  ranco->reportContainer.present = RAN_Container__reportContainer_PR_oCU_CP_UE;
  ASN_SEQUENCE_ADD(&ranco->reportContainer.choice.oCU_CP_UE.cellResourceReportList.list, report_item);

  //  xer_fprint(stderr, &asn_DEF_RAN_Container, ranco);
  

  PM_Containers_List_t *containers_list = (PM_Containers_List_t*)calloc(1, sizeof(PM_Containers_List_t));
  ASN_STRUCT_RESET(asn_DEF_PM_Containers_List, containers_list);
  containers_list->theRANContainer = ranco;

  E2SM_KPM_IndicationMessage_Format1_t *format =
    (E2SM_KPM_IndicationMessage_Format1_t*)calloc(1, sizeof(E2SM_KPM_IndicationMessage_Format1_t));
  ASN_STRUCT_RESET(asn_DEF_E2SM_KPM_IndicationMessage_Format1, format);

  int ret = ASN_SEQUENCE_ADD(&format->pm_Containers.list, containers_list);
  
  E2SM_KPM_IndicationMessage__indicationMessage_PR pres = E2SM_KPM_IndicationMessage__indicationMessage_PR_indicationMessage_Format1;

  indicationmessage->indicationMessage.present = pres;

  indicationmessage->indicationMessage.choice.indicationMessage_Format1 = *format;

  char *error_buf = (char*)calloc(300, sizeof(char));
  size_t errlen;

  asn_check_constraints(&asn_DEF_E2SM_KPM_IndicationMessage, indicationmessage, error_buf, &errlen);
  printf("error length %d\n", errlen);
  printf("error buf %s\n", error_buf);

  xer_fprint(stderr, &asn_DEF_E2SM_KPM_IndicationMessage, indicationmessage);

  asn_codec_ctx_t *opt_cod;

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
  fprintf(stderr, "after encoding message\n");


}

void encode_kpm_report_style1_parameterized(E2SM_KPM_IndicationMessage_t* indicationmessage,
					    long fiveqi,
					    long dl_prb_usage,
					    long ul_prb_usage,
					    uint8_t* sd_buf,
					    uint8_t* sst_buf,
					    uint8_t* plmnid_buf,
					    uint8_t* nrcellid_buf,
					    long *dl_prbs,
					    long *ul_prbs) {


  asn_codec_ctx_t *opt_cod;

  FQIPERSlicesPerPlmnPerCellListItem_t *fqi_item =
    (FQIPERSlicesPerPlmnPerCellListItem_t*)calloc(1,sizeof(FQIPERSlicesPerPlmnPerCellListItem_t));
  fqi_item->fiveQI = fiveqi;
  fqi_item->dl_PRBUsage = &dl_prb_usage;
  fqi_item->ul_PRBUsage = &ul_prb_usage;

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
  memcpy(snssai->sST.buf, sst_buf, 1);
  snssai->sD = (OCTET_STRING_t*)calloc(1, sizeof(OCTET_STRING_t));
  snssai->sD->buf = (uint8_t*)calloc(1,3);
  snssai->sD->size = 3;
  memcpy(snssai->sD->buf, sd_buf, 3);
  
  
  SlicePerPlmnPerCellListItem_t *sliceitem =
    (SlicePerPlmnPerCellListItem_t*)calloc(1,sizeof(SlicePerPlmnPerCellListItem_t));
  sliceitem->sliceID = *snssai;
  ASN_SEQUENCE_ADD(&sliceitem->fQIPERSlicesPerPlmnPerCellList.list, fqi_item);

  uint8_t *buf2 = (uint8_t*)"747";
  
  OCTET_STRING_t *plmnid = (OCTET_STRING_t*)calloc(1,sizeof(OCTET_STRING_t));
  plmnid->buf = (uint8_t*)calloc(3,1);
  plmnid->size = 3;
  memcpy(plmnid->buf, plmnid_buf, plmnid->size);  

  ServedPlmnPerCellListItem_t *percellitem1 =
    (ServedPlmnPerCellListItem_t*)calloc(1,sizeof(ServedPlmnPerCellListItem_t));
  percellitem1->pLMN_Identity = *plmnid;
  percellitem1->du_PM_5GC = (FGC_DU_PM_Container*)calloc(1,sizeof(FGC_DU_PM_Container));
  ASN_SEQUENCE_ADD(&percellitem1->du_PM_5GC->slicePerPlmnPerCellList.list, sliceitem);

  OCTET_STRING_t *plmnidstr = (OCTET_STRING_t*)calloc(1,sizeof(OCTET_STRING_t));
  plmnidstr->buf = (uint8_t*)calloc(3,1);
  plmnidstr->size = 3;
  memcpy(plmnidstr->buf, plmnid_buf, plmnidstr->size);

  printf("enc2\n");  

  NRCellIdentity_t *nrcellid = (NRCellIdentity_t*)calloc(1,sizeof(NRCellIdentity_t));
  uint8_t* buf3 = (uint8_t*)"12340";
  nrcellid->buf = (uint8_t*)calloc(1,5);
  memcpy(nrcellid->buf, nrcellid_buf, 5);
  nrcellid->size = 5;
  nrcellid->bits_unused = 4;

  NRCGI *nrcgi = (NRCGI*)calloc(1,sizeof(NRCGI));
  nrcgi->pLMN_Identity = *plmnidstr;
  nrcgi->nRCellIdentity = *nrcellid;
    

  CellResourceReportListItem_t *listitem1 = (CellResourceReportListItem_t*)calloc(1,sizeof(CellResourceReportListItem_t));
  listitem1->nRCGI = *nrcgi;
  listitem1->dl_TotalofAvailablePRBs = dl_prbs;
  listitem1->ul_TotalofAvailablePRBs = ul_prbs;
  ASN_SEQUENCE_ADD(&listitem1->servedPlmnPerCellList.list, percellitem1);
  

  ODU_PF_Container_t *ducont = (ODU_PF_Container_t*)calloc(1,sizeof(ODU_PF_Container_t));
  ASN_STRUCT_RESET(asn_DEF_ODU_PF_Container, ducont);
  int ret = ASN_SEQUENCE_ADD(&ducont->cellResourceReportList.list, listitem1);
  
  PF_Container_PR pres1 = PF_Container_PR_oDU;

  PF_Container_t *pfcontainer = (PF_Container_t*)calloc(1, sizeof(PF_Container_t));
  ASN_STRUCT_RESET(asn_DEF_PF_Container, pfcontainer);
  pfcontainer->present = pres1;
  pfcontainer->choice.oDU = *ducont;

  PM_Containers_List_t *containers_list = (PM_Containers_List_t*)calloc(1, sizeof(PM_Containers_List_t));
  ASN_STRUCT_RESET(asn_DEF_PM_Containers_List, containers_list);
  containers_list->performanceContainer = pfcontainer;

  E2SM_KPM_IndicationMessage_Format1_t *format =
    (E2SM_KPM_IndicationMessage_Format1_t*)calloc(1, sizeof(E2SM_KPM_IndicationMessage_Format1_t));
  ASN_STRUCT_RESET(asn_DEF_E2SM_KPM_IndicationMessage_Format1, format);

  ret = ASN_SEQUENCE_ADD(&format->pm_Containers.list, containers_list);
  
  E2SM_KPM_IndicationMessage__indicationMessage_PR pres = E2SM_KPM_IndicationMessage__indicationMessage_PR_indicationMessage_Format1;

  indicationmessage->indicationMessage.present = pres;

  indicationmessage->indicationMessage.choice.indicationMessage_Format1 = *format;

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
  fprintf(stderr, "after encoding message\n");


}


void encode_kpm_report_style1(E2SM_KPM_IndicationMessage_t* indicationmessage) {

  long fiveqi = 8;
  long dl_prb_usage = 50;
  long ul_prb_usage = 70;

  asn_codec_ctx_t *opt_cod;

  FQIPERSlicesPerPlmnPerCellListItem_t *fqi_item =
    (FQIPERSlicesPerPlmnPerCellListItem_t*)calloc(1,sizeof(FQIPERSlicesPerPlmnPerCellListItem_t));
  fqi_item->fiveQI = fiveqi;
  fqi_item->dl_PRBUsage = &dl_prb_usage;
  fqi_item->ul_PRBUsage = &ul_prb_usage;

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
  
  
  SlicePerPlmnPerCellListItem_t *sliceitem =
    (SlicePerPlmnPerCellListItem_t*)calloc(1,sizeof(SlicePerPlmnPerCellListItem_t));
  sliceitem->sliceID = *snssai;
  ASN_SEQUENCE_ADD(&sliceitem->fQIPERSlicesPerPlmnPerCellList.list, fqi_item);

  uint8_t *buf2 = (uint8_t*)"747";
  
  OCTET_STRING_t *plmnid = (OCTET_STRING_t*)calloc(1,sizeof(OCTET_STRING_t));
  plmnid->buf = (uint8_t*)calloc(3,1);
  plmnid->size = 3;
  memcpy(plmnid->buf, buf2, plmnid->size);  

  ServedPlmnPerCellListItem_t *percellitem1 =
    (ServedPlmnPerCellListItem_t*)calloc(1,sizeof(ServedPlmnPerCellListItem_t));
  percellitem1->pLMN_Identity = *plmnid;
  percellitem1->du_PM_5GC = (FGC_DU_PM_Container*)calloc(1,sizeof(FGC_DU_PM_Container));
  ASN_SEQUENCE_ADD(&percellitem1->du_PM_5GC->slicePerPlmnPerCellList.list, sliceitem);

  OCTET_STRING_t *plmnidstr = (OCTET_STRING_t*)calloc(1,sizeof(OCTET_STRING_t));
  plmnidstr->buf = (uint8_t*)calloc(3,1);
  plmnidstr->size = 3;
  memcpy(plmnidstr->buf, buf2, plmnidstr->size);

  printf("enc2\n");  

  NRCellIdentity_t *nrcellid = (NRCellIdentity_t*)calloc(1,sizeof(NRCellIdentity_t));
  uint8_t* buf3 = (uint8_t*)"12340";
  nrcellid->buf = (uint8_t*)calloc(1,5);
  memcpy(nrcellid->buf, buf3, 5);
  nrcellid->size = 5;
  nrcellid->bits_unused = 4;

  NRCGI *nrcgi = (NRCGI*)calloc(1,sizeof(NRCGI));
  nrcgi->pLMN_Identity = *plmnidstr;
  nrcgi->nRCellIdentity = *nrcellid;
    
  long dl_prbs = (long)100;
  long ul_prbs = (long)120;

  CellResourceReportListItem_t *listitem1 = (CellResourceReportListItem_t*)calloc(1,sizeof(CellResourceReportListItem_t));
  listitem1->nRCGI = *nrcgi;
  listitem1->dl_TotalofAvailablePRBs = &dl_prbs;
  listitem1->ul_TotalofAvailablePRBs = &ul_prbs;
  ASN_SEQUENCE_ADD(&listitem1->servedPlmnPerCellList.list, percellitem1);
  

  ODU_PF_Container_t *ducont = (ODU_PF_Container_t*)calloc(1,sizeof(ODU_PF_Container_t));
  ASN_STRUCT_RESET(asn_DEF_ODU_PF_Container, ducont);
  int ret = ASN_SEQUENCE_ADD(&ducont->cellResourceReportList.list, listitem1);
  
  PF_Container_PR pres1 = PF_Container_PR_oDU;

  PF_Container_t *pfcontainer = (PF_Container_t*)calloc(1, sizeof(PF_Container_t));
  ASN_STRUCT_RESET(asn_DEF_PF_Container, pfcontainer);
  pfcontainer->present = pres1;
  pfcontainer->choice.oDU = *ducont;

  PM_Containers_List_t *containers_list = (PM_Containers_List_t*)calloc(1, sizeof(PM_Containers_List_t));
  ASN_STRUCT_RESET(asn_DEF_PM_Containers_List, containers_list);
  containers_list->performanceContainer = pfcontainer;

  E2SM_KPM_IndicationMessage_Format1_t *format =
    (E2SM_KPM_IndicationMessage_Format1_t*)calloc(1, sizeof(E2SM_KPM_IndicationMessage_Format1_t));
  ASN_STRUCT_RESET(asn_DEF_E2SM_KPM_IndicationMessage_Format1, format);

  ret = ASN_SEQUENCE_ADD(&format->pm_Containers.list, containers_list);
  
  E2SM_KPM_IndicationMessage__indicationMessage_PR pres = E2SM_KPM_IndicationMessage__indicationMessage_PR_indicationMessage_Format1;

  indicationmessage->indicationMessage.present = pres;

  indicationmessage->indicationMessage.choice.indicationMessage_Format1 = *format;

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
  fprintf(stderr, "after encoding message\n");


}

void encode_kpm_report_style5_parameterized(E2SM_KPM_IndicationMessage_t* indicationmessage,
					    uint8_t *gnbcuupname_buf,
					    int bytes_dl,
					    int bytes_ul,
					    uint8_t *sst_buf,
					    uint8_t *sd_buf,
					    uint8_t *plmnid_buf) {
  
  ASN_STRUCT_RESET(asn_DEF_E2SM_KPM_IndicationMessage, indicationmessage);


  //  uint8_t *buf = (uint8_t*)"GNBCUUP5";
  OCTET_STRING_t *gnbcuupname = (OCTET_STRING_t*)calloc(1, sizeof(OCTET_STRING_t));
  gnbcuupname->size = 8;
  gnbcuupname->buf = (uint8_t*)calloc(1,8);
  memcpy(gnbcuupname->buf, gnbcuupname_buf, gnbcuupname->size);


  //We need to convert bytes_dl into array of uint8_t

  int array_size_dl;

  INTEGER_t *bytesdl = (INTEGER_t*)calloc(1, sizeof(INTEGER_t));

  if (bytes_dl <= 64) {
    array_size_dl = 1;

    uint8_t buffer[array_size_dl];
    buffer[0] = bytes_dl & 0xFF;
    bytesdl->buf = (uint8_t*)calloc(1,1);
    memcpy(bytesdl->buf,buffer,1);
    bytesdl->size = 1;

  } else if (bytes_dl <= 16384) {
    array_size_dl = 2;

    uint8_t buffer[array_size_dl];
    buffer[0] = (bytes_dl >> 8) & 0xFF;
    buffer[1] = bytes_dl & 0xFF;
    bytesdl->buf = (uint8_t*)calloc(2,1);
    memcpy(bytesdl->buf,buffer,2);
    bytesdl->size = 2;
    
  } else if (bytes_dl <= 4194304) {
    array_size_dl = 3;

    uint8_t buffer[array_size_dl];
    buffer[0] = (bytes_dl >> 16) & 0xFF;
    buffer[1] = (bytes_dl >> 8) & 0xFF;
    buffer[2] = bytes_dl & 0xFF;
    bytesdl->buf = (uint8_t*)calloc(3,1);
    memcpy(bytesdl->buf,buffer,3);
    bytesdl->size = 3;    
    
  } else if (bytes_dl <= 1073741824) {
    array_size_dl = 4;
    uint8_t buffer[array_size_dl];
    buffer[0] = (bytes_dl >> 24) & 0xFF;
    buffer[1] = (bytes_dl >> 16) & 0xFF;
    buffer[2] = (bytes_dl >> 8) & 0xFF;
    buffer[3] = bytes_dl & 0xFF;
    bytesdl->buf = (uint8_t*)calloc(4,1);
    memcpy(bytesdl->buf,buffer,4);
    bytesdl->size = 4;
  }
  
  
  //We need to convert bytes_ul into array of uint8_t
  INTEGER_t *bytesul = (INTEGER_t*)calloc(1, sizeof(INTEGER_t));

  int array_size_ul;

  if (bytes_ul <= 64) {
    array_size_ul = 1;

    uint8_t buffer[array_size_ul];
    buffer[0] = bytes_ul & 0xFF;
    bytesul->buf = (uint8_t*)calloc(1,1);
    memcpy(bytesul->buf,buffer,1);
    bytesul->size = 1;

  } else if (bytes_ul <= 16384) {
    array_size_ul = 2;

    uint8_t buffer[array_size_ul];
    buffer[0] = (bytes_ul >> 8) & 0xFF;
    buffer[1] = bytes_ul & 0xFF;
    bytesul->buf = (uint8_t*)calloc(2,1);
    memcpy(bytesul->buf,buffer,2);
    bytesul->size = 2;
    
  } else if (bytes_ul <= 4194304) {
    array_size_ul = 3;

    uint8_t buffer[array_size_ul];
    buffer[0] = (bytes_ul >> 16) & 0xFF;
    buffer[1] = (bytes_ul >> 8) & 0xFF;
    buffer[2] = bytes_ul & 0xFF;
    bytesul->buf = (uint8_t*)calloc(3,1);
    memcpy(bytesul->buf,buffer,3);
    bytesul->size = 3;    
    
  } else if (bytes_ul <= 1073741824) {
    array_size_ul = 4;
    uint8_t buffer[array_size_ul];
    buffer[0] = (bytes_ul >> 24) & 0xFF;
    buffer[1] = (bytes_ul >> 16) & 0xFF;
    buffer[2] = (bytes_ul >> 8) & 0xFF;
    buffer[3] = bytes_ul & 0xFF;
    bytesul->buf = (uint8_t*)calloc(4,1);
    memcpy(bytesul->buf,buffer,4);
    bytesul->size = 4;
  }
  
  long fqi = 9;
  FQIPERSlicesPerPlmnListItem_t *fqilistitem = (FQIPERSlicesPerPlmnListItem_t*)calloc(1, sizeof(FQIPERSlicesPerPlmnListItem_t));
  ASN_STRUCT_RESET(asn_DEF_FQIPERSlicesPerPlmnListItem, fqilistitem);
  fqilistitem->fiveQI = fqi;
  fqilistitem->pDCPBytesDL = bytesdl;
  fqilistitem->pDCPBytesUL = bytesul;


  uint8_t *buf1 = (uint8_t*)"4";  
  OCTET_STRING_t *sst = (OCTET_STRING_t*)calloc(1, sizeof(OCTET_STRING_t));
  sst->size = 6;
  sst->buf = (uint8_t*)calloc(1,6);
  memcpy(sst->buf,sst_buf,sst->size);


  uint8_t *bufz = (uint8_t*)"SD1";
  OCTET_STRING_t *sds = (OCTET_STRING_t*)calloc(1, sizeof(OCTET_STRING_t));
  sds->size = 3;
  sds->buf = (uint8_t*)calloc(1,3);
  memcpy(sds->buf, sd_buf, sds->size);

  
  SNSSAI_t *snssai = (SNSSAI_t*)calloc(1, sizeof(SNSSAI_t));
  ASN_STRUCT_RESET(asn_DEF_SNSSAI,snssai);
  snssai->sST.buf = (uint8_t*)calloc(1,1);
  snssai->sST.size = 1;
  memcpy(snssai->sST.buf, sst_buf, 1);
  snssai->sD = (OCTET_STRING_t*)calloc(1, sizeof(OCTET_STRING_t));
  snssai->sD->buf = (uint8_t*)calloc(1,3);
  snssai->sD->size = 3;
  memcpy(snssai->sD->buf, sd_buf, 3);

  

  SliceToReportListItem_t *slicelistitem = (SliceToReportListItem_t*)calloc(1,sizeof(SliceToReportListItem_t));
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
  fprintf(stderr, "after encoding message\n");      



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
  memcpy(plmnid->buf, plmnid_buf, plmnid->size);


  PlmnID_List_t *plmnidlist = (PlmnID_List_t*)calloc(1,sizeof(PlmnID_List_t));
  ASN_STRUCT_RESET(asn_DEF_PlmnID_List, plmnidlist);
  plmnidlist->pLMN_Identity = *plmnid;
  plmnidlist->cu_UP_PM_5GC = pm_format;

  CUUPMeasurement_Container_t *meas_cont = (CUUPMeasurement_Container_t*)calloc(1, sizeof(CUUPMeasurement_Container_t));
  ASN_STRUCT_RESET(asn_DEF_CUUPMeasurement_Container, meas_cont);
  ret = ASN_SEQUENCE_ADD(&meas_cont->plmnList.list, plmnidlist);


  
  
  PF_ContainerListItem_t *listitem1 = (PF_ContainerListItem_t*)calloc(1, sizeof(PF_ContainerListItem_t));
  ASN_STRUCT_RESET(asn_DEF_PF_ContainerListItem, listitem1);
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

  PM_Containers_List_t *containers_list = (PM_Containers_List_t*)calloc(1, sizeof(PM_Containers_List_t));
  ASN_STRUCT_RESET(asn_DEF_PM_Containers_List, containers_list);
  containers_list->performanceContainer = pfcontainer;

  E2SM_KPM_IndicationMessage_Format1_t *format =
    (E2SM_KPM_IndicationMessage_Format1_t*)calloc(1, sizeof(E2SM_KPM_IndicationMessage_Format1_t));
  ASN_STRUCT_RESET(asn_DEF_E2SM_KPM_IndicationMessage_Format1, format);

  ret = ASN_SEQUENCE_ADD(&format->pm_Containers.list, containers_list);
  
  E2SM_KPM_IndicationMessage__indicationMessage_PR pres = E2SM_KPM_IndicationMessage__indicationMessage_PR_indicationMessage_Format1;

  indicationmessage->indicationMessage.present = pres;

  indicationmessage->indicationMessage.choice.indicationMessage_Format1 = *format;

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
  fprintf(stderr, "after encoding message\n");  


}

void encode_kpm_report_style5(E2SM_KPM_IndicationMessage_t* indicationmessage) {

  ASN_STRUCT_RESET(asn_DEF_E2SM_KPM_IndicationMessage, indicationmessage);


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

  FQIPERSlicesPerPlmnListItem_t *fqilistitem = (FQIPERSlicesPerPlmnListItem_t*)calloc(1, sizeof(FQIPERSlicesPerPlmnListItem_t));
  ASN_STRUCT_RESET(asn_DEF_FQIPERSlicesPerPlmnListItem, fqilistitem);
  fqilistitem->fiveQI = 9;
  fqilistitem->pDCPBytesDL = bytesdl;
  fqilistitem->pDCPBytesUL = bytesul;


  uint8_t *buf1 = (uint8_t*)"4";  
  OCTET_STRING_t *sst = (OCTET_STRING_t*)calloc(1, sizeof(OCTET_STRING_t));
  sst->size = 6;
  sst->buf = (uint8_t*)calloc(1,6);
  memcpy(sst->buf,buf1,sst->size);


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

  

  SliceToReportListItem_t *slicelistitem = (SliceToReportListItem_t*)calloc(1,sizeof(SliceToReportListItem_t));
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
  fprintf(stderr, "after encoding message\n");



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

  CUUPMeasurement_Container_t *meas_cont = (CUUPMeasurement_Container_t*)calloc(1, sizeof(CUUPMeasurement_Container_t));
  ASN_STRUCT_RESET(asn_DEF_CUUPMeasurement_Container, meas_cont);
  ret = ASN_SEQUENCE_ADD(&meas_cont->plmnList.list, plmnidlist);


  
  
  PF_ContainerListItem_t *listitem1 = (PF_ContainerListItem_t*)calloc(1, sizeof(PF_ContainerListItem_t));
  ASN_STRUCT_RESET(asn_DEF_PF_ContainerListItem, listitem1);
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

  PM_Containers_List_t *containers_list = (PM_Containers_List_t*)calloc(1, sizeof(PM_Containers_List_t));
  ASN_STRUCT_RESET(asn_DEF_PM_Containers_List, containers_list);
  containers_list->performanceContainer = pfcontainer;

  E2SM_KPM_IndicationMessage_Format1_t *format =
    (E2SM_KPM_IndicationMessage_Format1_t*)calloc(1, sizeof(E2SM_KPM_IndicationMessage_Format1_t));
  ASN_STRUCT_RESET(asn_DEF_E2SM_KPM_IndicationMessage_Format1, format);

  ret = ASN_SEQUENCE_ADD(&format->pm_Containers.list, containers_list);
  
  E2SM_KPM_IndicationMessage__indicationMessage_PR pres = E2SM_KPM_IndicationMessage__indicationMessage_PR_indicationMessage_Format1;

  indicationmessage->indicationMessage.present = pres;

  indicationmessage->indicationMessage.choice.indicationMessage_Format1 = *format;

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
  fprintf(stderr, "after encoding message\n");

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

  FQIPERSlicesPerPlmnListItem_t *fqilistitem = (FQIPERSlicesPerPlmnListItem_t*)calloc(1, sizeof(FQIPERSlicesPerPlmnListItem_t));
  ASN_STRUCT_RESET(asn_DEF_FQIPERSlicesPerPlmnListItem, fqilistitem);
  fqilistitem->fiveQI = 9;
  fqilistitem->pDCPBytesDL = bytesdl;
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

  

  SliceToReportListItem_t *slicelistitem = (SliceToReportListItem_t*)calloc(1,sizeof(SliceToReportListItem_t));
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
  fprintf(stderr, "after encoding message\n");      



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

  CUUPMeasurement_Container_t *meas_cont = (CUUPMeasurement_Container_t*)calloc(1, sizeof(CUUPMeasurement_Container_t));
  ASN_STRUCT_RESET(asn_DEF_CUUPMeasurement_Container, meas_cont);
  ret = ASN_SEQUENCE_ADD(&meas_cont->plmnList.list, plmnidlist);


  
  
  PF_ContainerListItem_t *listitem1 = (PF_ContainerListItem_t*)calloc(1, sizeof(PF_ContainerListItem_t));
  ASN_STRUCT_RESET(asn_DEF_PF_ContainerListItem, listitem1);
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

  PM_Containers_List_t *containers_list = (PM_Containers_List_t*)calloc(1, sizeof(PM_Containers_List_t));
  ASN_STRUCT_RESET(asn_DEF_PM_Containers_List, containers_list);
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
  fprintf(stderr, "after encoding message\n");

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

  FQIPERSlicesPerPlmnListItem_t *fqilistitem = (FQIPERSlicesPerPlmnListItem_t*)calloc(1, sizeof(FQIPERSlicesPerPlmnListItem_t));
  ASN_STRUCT_RESET(asn_DEF_FQIPERSlicesPerPlmnListItem, fqilistitem);
  fqilistitem->fiveQI = 9;
  fqilistitem->pDCPBytesDL = bytesdl;
  fqilistitem->pDCPBytesUL = bytesul;



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

  

  SliceToReportListItem_t *slicelistitem = (SliceToReportListItem_t*)calloc(1,sizeof(SliceToReportListItem_t));
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
  fprintf(stderr, "after encoding message\n");      

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

  CUUPMeasurement_Container_t *meas_cont = (CUUPMeasurement_Container_t*)calloc(1, sizeof(CUUPMeasurement_Container_t));
  ASN_STRUCT_RESET(asn_DEF_CUUPMeasurement_Container, meas_cont);
  ret = ASN_SEQUENCE_ADD(&meas_cont->plmnList.list, plmnidlist);


  
  
  PF_ContainerListItem_t *listitem1 = (PF_ContainerListItem_t*)calloc(1, sizeof(PF_ContainerListItem_t));
  ASN_STRUCT_RESET(asn_DEF_PF_ContainerListItem, listitem1);
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

  PM_Containers_List_t *containers_list = (PM_Containers_List_t*)calloc(1, sizeof(PM_Containers_List_t));
  ASN_STRUCT_RESET(asn_DEF_PM_Containers_List, containers_list);
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
  fprintf(stderr, "after encoding message\n");

  
}
*/
