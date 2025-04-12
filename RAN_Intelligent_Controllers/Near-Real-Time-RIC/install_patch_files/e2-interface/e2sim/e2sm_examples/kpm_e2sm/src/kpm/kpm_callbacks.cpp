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

#include <iostream>
#include <fstream>
#include <vector>



extern "C" {
  #include "OCTET_STRING.h"
  #include "asn_application.h"
  #include "E2SM-KPM-IndicationMessage.h"
  #include "E2SM-KPM-RANfunction-Description.h"
  #include "E2SM-KPM-IndicationHeader-Format1.h"
  #include "E2SM-KPM-IndicationHeader.h"
  #include "E2AP-PDU.h"
  #include "RICsubscriptionRequest.h"
  #include "RICsubscriptionResponse.h"
  #include "RICactionType.h"
  #include "ProtocolIE-Field.h"
  #include "ProtocolIE-SingleContainer.h"
  #include "InitiatingMessage.h"
}

#include "kpm_callbacks.hpp"
#include "encode_kpm.hpp"

#include "encode_e2apv1.hpp"

#include <nlohmann/json.hpp>
#include <thread>
#include <chrono>

#include "viavi_connector.hpp"
#include "errno.h"
#include "e2sim_defs.h"
#include <cstdlib>

using json = nlohmann::json;

using namespace std;
class E2Sim;
int gFuncId;

E2Sim e2sim;

int main(int argc, char* argv[]) {

  LOG_I("Starting KPM simulator");

  uint8_t *nrcellid_buf = (uint8_t*)calloc(1,5);
  nrcellid_buf[0] = 0x22;
  nrcellid_buf[1] = 0x5B;
  nrcellid_buf[2] = 0xD6;
  nrcellid_buf[3] = 0x00;
  nrcellid_buf[4] = 0x70;

  asn_codec_ctx_t *opt_cod;
  
  E2SM_KPM_RANfunction_Description_t *ranfunc_desc =
    (E2SM_KPM_RANfunction_Description_t*)calloc(1,sizeof(E2SM_KPM_RANfunction_Description_t));
  encode_kpm_function_description(ranfunc_desc);
  
  uint8_t e2smbuffer[8192] = {0, };
  size_t e2smbuffer_size = 8192;
  
  asn_enc_rval_t er =
    asn_encode_to_buffer(opt_cod,
			 ATS_ALIGNED_BASIC_PER,
			 &asn_DEF_E2SM_KPM_RANfunction_Description,
			 ranfunc_desc, e2smbuffer, e2smbuffer_size);
  
  if(er.encoded == -1) {
	LOG_I("Failed to serialize function description data. Detail: %s.", asn_DEF_E2SM_KPM_RANfunction_Description.name);
  } else if(er.encoded > e2smbuffer_size) {
	LOG_I("Buffer of size %zu is too small for %s, need %zu", e2smbuffer_size, asn_DEF_E2SM_KPM_RANfunction_Description.name, er.encoded);
  }

  uint8_t *ranfuncdesc = (uint8_t*)calloc(1,er.encoded);
  memcpy(ranfuncdesc, e2smbuffer, er.encoded);
  
  OCTET_STRING_t *ranfunc_ostr = (OCTET_STRING_t*)calloc(1,sizeof(OCTET_STRING_t));
  ranfunc_ostr->buf = (uint8_t*)calloc(1,er.encoded);
  ranfunc_ostr->size = er.encoded;
  memcpy(ranfunc_ostr->buf,e2smbuffer,er.encoded);

  const char* func_id_str = std::getenv("RAN_FUNC_ID");
  /*::gFuncId = func_id_str == nullptr ? 0 : std::stoi(func_id_str);*/
  ::gFuncId = 2;

  e2sim.register_e2sm(gFuncId, ranfunc_ostr);
  e2sim.register_subscription_callback(gFuncId, &callback_kpm_subscription_request);
  e2sim.run_loop(argc, argv);

}

void get_cell_id(uint8_t *nrcellid_buf, char *cid_return_buf) {

  uint8_t nr0 = nrcellid_buf[0] >> 4;
  uint8_t nr1 = nrcellid_buf[0] << 4;
  nr1 = nr1 >> 4;

  uint8_t nr2 = nrcellid_buf[1] >> 4;
  uint8_t nr3 = nrcellid_buf[1] << 4;
  nr3 = nr3 >> 4;

  uint8_t nr4 = nrcellid_buf[2] >> 4;
  uint8_t nr5 = nrcellid_buf[2] << 4;
  nr5 = nr5 >> 4;

  uint8_t nr6 = nrcellid_buf[3] >> 4;
  uint8_t nr7 = nrcellid_buf[3] << 4;
  nr7 = nr7 >> 4;

  uint8_t nr8 = nrcellid_buf[4] >> 4;
  
  sprintf(cid_return_buf, "373437%d%d%d%d%d%d%d%d%d", nr0,nr1,nr2,nr3,nr4,nr5,nr6,nr7,nr8);  

}

void run_report_loop(long requestorId, long instanceId, long ranFunctionId, long actionId)
{
  std::filebuf reports_json;
  std::streambuf *input_filebuf = &reports_json;

  std::unique_ptr<viavi::RICTesterReceiver> viavi_connector;
  if (!reports_json.open("/playpen/src/reports_file_full.json", std::ios::in)) {
    std::cerr << "Can't open reports.json, enabling VIAVI connector instead..." << endl;
	viavi_connector.reset(new viavi::RICTesterReceiver {3001, nullptr});
	input_filebuf = viavi_connector->get_data_filebuf();
  }

  std::istream input {input_filebuf};

  long seqNum = 1;

  std::string str;
  
  while ( getline(input, str) ) {

    json all_ues_json;

    long fqival = 9;
    long qcival = 9;

    uint8_t *plmnid_buf = (uint8_t*)"747";
    uint8_t *sst_buf = (uint8_t*)"1";
    uint8_t *sd_buf = (uint8_t*)"100";
    

    LOG_I("Current line: %s", str.c_str());

    bool valid = false;

    try {
      all_ues_json = json::parse(str);
      valid = true;
    } catch (...) {
      LOG_I("Exception on reading json");
	  exit(1);
    }

    if (valid) {

      std::string first_key = all_ues_json.begin().key();
      LOG_I("First key is %s\n", first_key.c_str());
      
      if (first_key.compare("ueMeasReport") == 0) {

		json::json_pointer du_id(std::string("/ueMeasReport/du-id"));
		int duid = all_ues_json[du_id].get<int>();
	
		LOG_I("Start sending UE measurement reports with DU id %d", duid);

		int numMeasReports = (all_ues_json["/ueMeasReport/ueMeasReportList"_json_pointer]).size();
		
		for (int i = 0; i < numMeasReports; i++) {
			int nextCellId;
			int nextRsrp;
			int nextRsrq;
			int nextRssinr;
			float tput;
			int prb_usage;
			std::string ueId;

			json::json_pointer p001(std::string("/ueMeasReport/ueMeasReportList/") + std::to_string(i) +"/ue-id");
			ueId = all_ues_json[p001].get<std::string>();

			LOG_I("Preparing report data for UE %d with id %s", i, ueId);
			
			json::json_pointer p0(std::string("/ueMeasReport/ueMeasReportList/") + std::to_string(i) +"/throughput");
			tput = all_ues_json[p0].get<float>();
			
			json::json_pointer p00(std::string("/ueMeasReport/ueMeasReportList/") + std::to_string(i) +"/prb_usage");
			prb_usage = all_ues_json[p00].get<int>();
			
			json::json_pointer p1(std::string("/ueMeasReport/ueMeasReportList/") + std::to_string(i) +"/nrCellIdentity");
			nextCellId = all_ues_json[p1].get<int>();
			
			json::json_pointer p2(std::string("/ueMeasReport/ueMeasReportList/") + std::to_string(i) +"/servingCellRfReport/rsrp");
			nextRsrp = all_ues_json[p2].get<int>();
			
			json::json_pointer p3(std::string("/ueMeasReport/ueMeasReportList/") + std::to_string(i) +"/servingCellRfReport/rsrq");
			nextRsrq = all_ues_json[p3].get<int>();
			
			json::json_pointer p4(std::string("/ueMeasReport/ueMeasReportList/") + std::to_string(i) +"/servingCellRfReport/rssinr");
			nextRssinr = all_ues_json[p4].get<int>();
			
			json::json_pointer p5(std::string("/ueMeasReport/ueMeasReportList/") + std::to_string(i) +"/neighbourCellList");
			
			uint8_t crnti_buf[3] = {0, };

			if (ueId.find("Pedestrian") != string::npos) {
				std::string ind = ueId.substr(11);
				int indval = std::stoi(ind);

				if (indval < 10) {
				crnti_buf[1] = indval;
				crnti_buf[0] = 0;
				} else {
				crnti_buf[0] = indval/10;
				crnti_buf[1] = indval % 10;
				}
				
			} else if (ueId.find("Car") != string::npos) {
				crnti_buf[0] = 4;
				crnti_buf[1] = 1;
			}
					
			std::string serving_str = "{\"rsrp\": " + std::to_string(nextRsrp) + ", \"rsrq\": " +
				std::to_string(nextRsrq) + ", \"rssinr\": " + std::to_string(nextRssinr) + "}";
			const uint8_t *serving_buf = reinterpret_cast<const uint8_t*>(serving_str.c_str());	
			
			int numNeighborCells = (all_ues_json[p5]).size();
			
			std::string neighbor_str = "[";
			
			int nextNbCell;
			int nextNbRsrp;
			int nextNbRsrq;
			int nextNbRssinr;
			
			for (int j = 0; j < numNeighborCells; j++) {
				json::json_pointer p8(std::string("/ueMeasReport/ueMeasReportList/") + std::to_string(i) +"/neighbourCellList/" + std::to_string(j) + "/nbCellIdentity");
				nextNbCell = all_ues_json[p8].get<int>();
				json::json_pointer p9(std::string("/ueMeasReport/ueMeasReportList/") + std::to_string(i)
						+"/neighbourCellList/" + std::to_string(j) + "/nbCellRfReport/rsrp");
				nextNbRsrp = all_ues_json[p9].get<int>();
				
				json::json_pointer p10(std::string("/ueMeasReport/ueMeasReportList/") + std::to_string(i)
						+"/neighbourCellList/" + std::to_string(j) + "/nbCellRfReport/rsrq");
				nextNbRsrq = all_ues_json[p10].get<int>();
				
				json::json_pointer p11(std::string("/ueMeasReport/ueMeasReportList/") + std::to_string(i)
						+"/neighbourCellList/" + std::to_string(j) + "/nbCellRfReport/rssinr");
				nextNbRssinr = all_ues_json[p11].get<int>();
				
				if (j != 0) {
					neighbor_str += ",";
				}


				uint8_t neighbor_cellid_buf[6] = {0, };
				neighbor_cellid_buf[0] = 0x22;
				neighbor_cellid_buf[1] = 0x5B;
				neighbor_cellid_buf[2] = 0xD6;
				neighbor_cellid_buf[3] = nextNbCell;
				neighbor_cellid_buf[4] = 0x70;
				
				char cid_buf[25] = {0, };
				get_cell_id(neighbor_cellid_buf,cid_buf);
				
				
				neighbor_str += "{\"CID\" : \"" + std::string(cid_buf) + "\", \"Cell-RF\" : {\"rsrp\": " + std::to_string(nextNbRsrp) +
				", \"rsrq\": " + std::to_string(nextNbRsrq) + ", \"rssinr\": " + std::to_string(nextNbRssinr) + "}}";
				
			}
			
			neighbor_str += "]";
			
			LOG_I("This is neighbor str %s\n", neighbor_str.c_str());
								
			const uint8_t *neighbor_buf = reinterpret_cast<const uint8_t*>(neighbor_str.c_str());


			uint8_t nrcellid_buf[6] = {0, };
			nrcellid_buf[0] = 0x22;
			nrcellid_buf[1] = 0x5B;
			nrcellid_buf[2] = 0xD6;
			nrcellid_buf[3] = nextCellId;
			nrcellid_buf[4] = 0x70;

			uint8_t gnbid_buf[4] = {0, };
			gnbid_buf[0] = 0x22;
			gnbid_buf[1] = 0x5B;
			gnbid_buf[2] = 0xD6;

			uint8_t cuupid_buf[2] = {0, };
			cuupid_buf[0] = 20000;

			uint8_t duid_buf[2] = {0, };
			duid_buf[0] = 20000;

			uint8_t *cuupname_buf = (uint8_t*)"GNBCUUP5";	  
			
			LOG_I("Encoding UE indication message step 1");
			
			E2SM_KPM_IndicationMessage_t *ind_msg_cucp_ue =
				(E2SM_KPM_IndicationMessage_t*)calloc(1,sizeof(E2SM_KPM_IndicationMessage_t));
			
			LOG_I("Print Indication Message KPM UE %d", &ind_msg_cucp_ue);
			
			ue_meas_kpm_report_indication_message_initialized(ind_msg_cucp_ue, nrcellid_buf, crnti_buf, serving_buf, neighbor_buf);
			
			LOG_I("Encoding UE indication message step 2");

			uint8_t e2sm_message_buf_cucp_ue[8192] = {0, };
			size_t e2sm_message_buf_size_cucp_ue = 8192;
			
			asn_codec_ctx_t *opt_cod;
			
			asn_enc_rval_t er_message_cucp_ue = asn_encode_to_buffer(opt_cod,
										ATS_ALIGNED_BASIC_PER,
										&asn_DEF_E2SM_KPM_IndicationMessage,
										ind_msg_cucp_ue, e2sm_message_buf_cucp_ue, e2sm_message_buf_size_cucp_ue);
			
			LOG_I("Encoding UE indication message step 3");

			if(er_message_cucp_ue.encoded == -1) {
				LOG_I("Failed to serialize message data. Detail: %s.\n", asn_DEF_E2SM_KPM_IndicationMessage.name);
				exit(1);
			} else if(er_message_cucp_ue.encoded > e2sm_message_buf_size_cucp_ue) {
				LOG_I("Buffer of size %zu is too small for %s, need %zu\n", e2sm_message_buf_size_cucp_ue, asn_DEF_E2SM_KPM_IndicationMessage.name, er_message_cucp_ue.encoded);
				exit(1);
			} else {
				LOG_I("Encoded UE indication message succesfully, size in bytes: %zu", er_message_cucp_ue.encoded)
			}

			ASN_STRUCT_FREE(asn_DEF_E2SM_KPM_IndicationMessage, ind_msg_cucp_ue); 

			E2SM_KPM_IndicationHeader_t* ind_header_cucp_ue =
				(E2SM_KPM_IndicationHeader_t*)calloc(1,sizeof(E2SM_KPM_IndicationHeader_t));
			kpm_report_indication_header_initialized(ind_header_cucp_ue, plmnid_buf, sst_buf, sd_buf, fqival, qcival, nrcellid_buf, gnbid_buf, 0, cuupid_buf, duid_buf, cuupname_buf);

			asn_codec_ctx_t *opt_cod1;
			uint8_t e2sm_header_buf_cucp_ue[8192] = {0, };
			size_t e2sm_header_buf_size_cucp_ue = 8192;
			
			asn_enc_rval_t er_header_cucp_ue = asn_encode_to_buffer(opt_cod1,
										ATS_ALIGNED_BASIC_PER,
										&asn_DEF_E2SM_KPM_IndicationHeader,
										ind_header_cucp_ue, e2sm_header_buf_cucp_ue, e2sm_header_buf_size_cucp_ue);

			if(er_header_cucp_ue.encoded == -1) {
				LOG_I("Failed to serialize data. Detail: %s.\n", asn_DEF_E2SM_KPM_IndicationHeader.name);
				exit(1);
			} else if(er_header_cucp_ue.encoded > e2sm_header_buf_size_cucp_ue) {
				LOG_I("Buffer of size %zu is too small for %s, need %zu\n", e2sm_header_buf_size_cucp_ue, asn_DEF_E2SM_KPM_IndicationHeader.name, er_header_cucp_ue.encoded);
				exit(1);
			} else {
				LOG_I("Encoded UE indication header succesfully, size in bytes: %zu", er_header_cucp_ue.encoded);
				for(int i = 0; i < er_header_cucp_ue.encoded; i ++) {
					printf("%x ", e2sm_header_buf_cucp_ue[i]);
				}
				
			}
			

			ASN_STRUCT_FREE(asn_DEF_E2SM_KPM_IndicationHeader, ind_header_cucp_ue);
			
			E2AP_PDU *pdu_cucp_ue = (E2AP_PDU*)calloc(1,sizeof(E2AP_PDU));
			
			encoding::generate_e2apv1_indication_request_parameterized(pdu_cucp_ue, requestorId,
											instanceId, ranFunctionId,
											actionId, seqNum, e2sm_header_buf_cucp_ue,
											er_header_cucp_ue.encoded, e2sm_message_buf_cucp_ue,
											er_message_cucp_ue.encoded);
			
			e2sim.encode_and_send_sctp_data(pdu_cucp_ue);
			LOG_I("Measurement report for UE %d has been sent", i);
			seqNum++;
			std::this_thread::sleep_for (std::chrono::milliseconds(50));
		}
      } else if (first_key.compare("cellMeasReport") == 0) {

		json::json_pointer du_id(std::string("/cellMeasReport/du-id"));
		int duid = all_ues_json[du_id].get<int>();
	
		LOG_I("Start sending Cell measurement reports with DU id %d", duid);
		
		int numMeasReports = (all_ues_json["/cellMeasReport/cellMeasReportList"_json_pointer]).size();
		
		for (int i = 0; i < numMeasReports; i++) {
			int nextCellId;

			float bytes_dl;
			float bytes_ul;
			int prb_dl;
			int prb_ul;
			int cellid;

			json::json_pointer p00(std::string("/cellMeasReport/cellMeasReportList/") + std::to_string(i) +"/nrCellIdentity");
			cellid = all_ues_json[p00].get<int>();

			LOG_I("Preparing report data for Cell %d with id %d", i, cellid);
			
			json::json_pointer p0(std::string("/cellMeasReport/cellMeasReportList/") + std::to_string(i) +"/pdcpByteMeasReport/pdcpBytesDl");
			bytes_dl = all_ues_json[p0].get<float>();

			json::json_pointer p1(std::string("/cellMeasReport/cellMeasReportList/") + std::to_string(i) +"/pdcpByteMeasReport/pdcpBytesUl");
			bytes_ul = all_ues_json[p1].get<float>();
			
			json::json_pointer p2(std::string("/cellMeasReport/cellMeasReportList/") + std::to_string(i) +"/prbMeasReport/availPrbDl");
			prb_dl = all_ues_json[p2].get<int>();

			json::json_pointer p3(std::string("/cellMeasReport/cellMeasReportList/") + std::to_string(i) +"/prbMeasReport/availPrbUl");
			prb_ul = all_ues_json[p3].get<int>();

			
			uint8_t *sst_buf = (uint8_t*)"1";
			uint8_t *sd_buf = (uint8_t*)"100";
			uint8_t *plmnid_buf = (uint8_t*)"747";

			uint8_t nrcellid_buf[6] = {0, };
			nrcellid_buf[0] = 0x22;
			nrcellid_buf[1] = 0x5B;
			nrcellid_buf[2] = 0xD6;
			nrcellid_buf[3] = cellid;
			nrcellid_buf[4] = 0x70;

			uint8_t gnbid_buf[4] = {0, };
			gnbid_buf[0] = 0x22;
			gnbid_buf[1] = 0x5B;
			gnbid_buf[2] = 0xD6;

			uint8_t cuupid_buf[2] = {0, };
			cuupid_buf[0] = 20000;

			uint8_t duid_buf[2] = {0, };
			duid_buf[0] = 20000;

			uint8_t *cuupname_buf = (uint8_t*)"GNBCUUP5";	  	  

			//Encoding Style 1 Message Body
			
			LOG_I("Encoding Style 1 Message body");	  
			asn_codec_ctx_t *opt_cod2;
			
			E2SM_KPM_IndicationMessage_t *ind_message_style1 =
				(E2SM_KPM_IndicationMessage_t*)calloc(1,sizeof(E2SM_KPM_IndicationMessage_t));
			E2AP_PDU *pdu_style1 = (E2AP_PDU*)calloc(1,sizeof(E2AP_PDU));
			
			long fiveqi = 7;
			long *l_dl_prbs = (long*)calloc(1, sizeof(long));
			long *l_ul_prbs = (long*)calloc(1, sizeof(long));
			*l_dl_prbs = (long)prb_dl;
			*l_ul_prbs = (long)prb_ul;
			
			cell_meas_kpm_report_indication_message_style_1_initialized(ind_message_style1, fiveqi,
								prb_dl, prb_ul, nrcellid_buf, l_dl_prbs, l_ul_prbs);
			
			uint8_t e2sm_message_buf_style1[8192] = {0, };
			size_t e2sm_message_buf_size_style1 = 8192;
			
			asn_enc_rval_t er_message_style1 = asn_encode_to_buffer(opt_cod2,
										ATS_ALIGNED_BASIC_PER,
										&asn_DEF_E2SM_KPM_IndicationMessage,
										ind_message_style1,
										e2sm_message_buf_style1, e2sm_message_buf_size_style1);
			
			if(er_message_style1.encoded == -1) {
				LOG_I("Failed to serialize data. Detail: %s.", asn_DEF_E2SM_KPM_IndicationMessage.name);
				exit(1);
			} else if(er_message_style1.encoded > e2sm_message_buf_size_style1) {
				LOG_I("Buffer of size %zu is too small for %s, need %zu\n", e2sm_message_buf_size_style1, asn_DEF_E2SM_KPM_IndicationMessage.name, er_message_style1.encoded);
				exit(1);
			} else {
				LOG_I("Encoded Cell indication message succesfully, size in bytes: %ld", er_message_style1.encoded)
			}

			ASN_STRUCT_FREE(asn_DEF_E2SM_KPM_IndicationMessage, ind_message_style1);
			
			uint8_t *cpid_buf2 = (uint8_t*)"CPID";
			
			E2SM_KPM_IndicationHeader_t* ind_header_style1 =
				(E2SM_KPM_IndicationHeader_t*)calloc(1,sizeof(E2SM_KPM_IndicationHeader_t));
			kpm_report_indication_header_initialized(ind_header_style1, plmnid_buf, sst_buf, sd_buf, fqival, qcival, nrcellid_buf, gnbid_buf, 0, cuupid_buf, duid_buf, cuupname_buf);

			uint8_t e2sm_header_buf_style1[8192] = {0, };
			size_t e2sm_header_buf_size_style1 = 8192;
			
			asn_enc_rval_t er_header_style1 = asn_encode_to_buffer(opt_cod2,
										ATS_ALIGNED_BASIC_PER,
										&asn_DEF_E2SM_KPM_IndicationHeader,
										ind_header_style1,
										e2sm_header_buf_style1, e2sm_header_buf_size_style1);

			if(er_header_style1.encoded == -1) {
				LOG_I("Failed to serialize data. Detail: %s.\n", asn_DEF_E2SM_KPM_IndicationHeader.name);
				exit(1);
			} else if(er_header_style1.encoded > e2sm_header_buf_size_style1) {
				LOG_I("Buffer of size %zu is too small for %s, need %zu\n", e2sm_header_buf_size_style1, asn_DEF_E2SM_KPM_IndicationHeader.name, er_header_style1.encoded);
				exit(1);
			} else {
				LOG_I("Encoded Cell indication header succesfully, size in bytes: %d", er_header_style1.encoded)
			}

			ASN_STRUCT_FREE(asn_DEF_E2SM_KPM_IndicationHeader, ind_header_style1);
			
			encoding::generate_e2apv1_indication_request_parameterized(pdu_style1, requestorId,
											instanceId, ranFunctionId,
											actionId, seqNum, e2sm_header_buf_style1,
											er_header_style1.encoded,
											e2sm_message_buf_style1, er_message_style1.encoded);

			e2sim.encode_and_send_sctp_data(pdu_style1);
			seqNum++;
			LOG_I("Measurement report for Cell %d has been sent\n", i);
			std::this_thread::sleep_for (std::chrono::milliseconds(50));	  
			
		}
	  }					           
    }
  }
}


void callback_kpm_subscription_request(E2AP_PDU_t *sub_req_pdu) {

  //Record RIC Request ID
  //Go through RIC action to be Setup List
  //Find first entry with REPORT action Type
  //Record ricActionID
  //Encode subscription response

  RICsubscriptionRequest_t orig_req =
    sub_req_pdu->choice.initiatingMessage->value.choice.RICsubscriptionRequest;
  
  RICsubscriptionResponse_IEs_t *ricreqid =
    (RICsubscriptionResponse_IEs_t*)calloc(1, sizeof(RICsubscriptionResponse_IEs_t));
					   
  int count = orig_req.protocolIEs.list.count;
  int size = orig_req.protocolIEs.list.size;
  
  RICsubscriptionRequest_IEs_t **ies = (RICsubscriptionRequest_IEs_t**)orig_req.protocolIEs.list.array;

  RICsubscriptionRequest_IEs__value_PR pres;

  long reqRequestorId;
  long reqInstanceId;
  long reqActionId;

  std::vector<long> actionIdsAccept;
  std::vector<long> actionIdsReject;

  for (int i=0; i < count; i++) {
    RICsubscriptionRequest_IEs_t *next_ie = ies[i];
    pres = next_ie->value.present;
    
    LOG_I("The next present value %d", pres);

    switch(pres) {
		case RICsubscriptionRequest_IEs__value_PR_RICrequestID: {
			LOG_I("in case request id");
			RICrequestID_t reqId = next_ie->value.choice.RICrequestID;
			long requestorId = reqId.ricRequestorID;
			long instanceId = reqId.ricInstanceID;

			LOG_I("requestorId: %ld, InstanceID: %ld", requestorId, instanceId);

			reqRequestorId = requestorId;
			reqInstanceId = instanceId;

			break;
		}
		case RICsubscriptionRequest_IEs__value_PR_RANfunctionID: {
			LOG_I("in case ran func id");
			break;
		}
		case RICsubscriptionRequest_IEs__value_PR_RICsubscriptionDetails: {
			RICsubscriptionDetails_t subDetails = next_ie->value.choice.RICsubscriptionDetails;
			RICeventTriggerDefinition_t triggerDef = subDetails.ricEventTriggerDefinition;
			RICactions_ToBeSetup_List_t actionList = subDetails.ricAction_ToBeSetup_List;
			//We are ignoring the trigger definition

			//We identify the first action whose type is REPORT
			//That is the only one accepted; all others are rejected

			int actionCount = actionList.list.count;
			LOG_I("Action count%d", actionCount);

			auto **item_array = actionList.list.array;

			bool foundAction = false;

			for (int i=0; i < actionCount; i++) {
				auto *next_item = item_array[i];
				RICactionID_t actionId = ((RICaction_ToBeSetup_ItemIEs*)next_item)->value.choice.RICaction_ToBeSetup_Item.ricActionID;
				RICactionType_t actionType = ((RICaction_ToBeSetup_ItemIEs*)next_item)->value.choice.RICaction_ToBeSetup_Item.ricActionType;

				if (!foundAction && actionType == RICactionType_report) {
					reqActionId = actionId;
					actionIdsAccept.push_back(reqActionId);
					foundAction = true;
				} else {
					reqActionId = actionId;
					actionIdsReject.push_back(reqActionId);
				}
			}

			break;
		}
		default: {
			break;
		}
    }
    
  }

  LOG_I("After Processing Subscription Request");

  for (int i=0; i < actionIdsAccept.size(); i++) {
    LOG_D("Action ID %d %ld\n", i, actionIdsAccept.at(i));
  }

  E2AP_PDU *e2ap_pdu = (E2AP_PDU*)calloc(1,sizeof(E2AP_PDU));

  long *accept_array = &actionIdsAccept[0];
  long *reject_array = &actionIdsReject[0];
  int accept_size = actionIdsAccept.size();
  int reject_size = actionIdsReject.size();

  encoding::generate_e2apv1_subscription_response_success(e2ap_pdu, accept_array, reject_array, accept_size, reject_size, reqRequestorId, reqInstanceId);
  
  LOG_I("Encode and sending E2AP subscription success response via SCTP");
  e2sim.encode_and_send_sctp_data(e2ap_pdu);

  LOG_I("Now generating data for subscription request");
  run_report_loop(reqRequestorId, reqInstanceId, gFuncId, reqActionId);

}
