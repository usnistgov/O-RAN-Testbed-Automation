/*
 * Licensed to the OpenAirInterface (OAI) Software Alliance under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The OpenAirInterface Software Alliance licenses this file to You under
 * the OAI Public License, Version 1.1  (the "License"); you may not use this file
 * except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.openairinterface.org/?page_id=698
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *-------------------------------------------------------------------------------
 * For more information about the OpenAirInterface (OAI) Software Alliance:
 *      contact@openairinterface.org
 */

/*! \file gNB_scheduler_uci.c
 * \brief MAC procedures related to UCI
 * \date 2020
 * \version 1.0
 * \company Eurecom
 */

#include <softmodem-common.h>
#include "NR_MAC_gNB/nr_mac_gNB.h"
#include "NR_MAC_gNB/mac_proto.h"
#include "common/ran_context.h"
#include "common/utils/nr/nr_common.h"
#include "nfapi/oai_integration/vendor_ext.h"
static void nr_fill_nfapi_pucch(gNB_MAC_INST *nrmac, frame_t frame, slot_t slot, const NR_sched_pucch_t *pucch, NR_UE_info_t* UE)
{

  const int index = ul_buffer_index(pucch->frame,
                                    pucch->ul_slot,
                                    nrmac->frame_structure.numb_slots_frame,
                                    nrmac->UL_tti_req_ahead_size);
  nfapi_nr_ul_tti_request_t *future_ul_tti_req = &nrmac->UL_tti_req_ahead[0][index];
  if (future_ul_tti_req->SFN != pucch->frame || future_ul_tti_req->Slot != pucch->ul_slot)
    LOG_W(NR_MAC,
          "Current %d.%d : future UL_tti_req's frame.slot %4d.%2d does not match PUCCH %4d.%2d\n",
          frame,slot,
          future_ul_tti_req->SFN,
          future_ul_tti_req->Slot,
          pucch->frame,
          pucch->ul_slot);

  // n_pdus is number of pdus, so, in the array, it is the index of the next free element
  if (future_ul_tti_req->n_pdus >= sizeofArray(future_ul_tti_req->pdus_list) ) {
    LOG_E(NR_MAC,
          "future_ul_tti_req->n_pdus %d is full, slot: %d, sr flag %d dropping request\n",
	  future_ul_tti_req->n_pdus,
	  pucch->ul_slot,
	  pucch->sr_flag);
    return;
  }
  future_ul_tti_req->pdus_list[future_ul_tti_req->n_pdus].pdu_type = NFAPI_NR_UL_CONFIG_PUCCH_PDU_TYPE;
  future_ul_tti_req->pdus_list[future_ul_tti_req->n_pdus].pdu_size = sizeof(nfapi_nr_pucch_pdu_t);
  nfapi_nr_pucch_pdu_t *pucch_pdu = &future_ul_tti_req->pdus_list[future_ul_tti_req->n_pdus].pucch_pdu;
  memset(pucch_pdu, 0, sizeof(nfapi_nr_pucch_pdu_t));
  future_ul_tti_req->n_pdus += 1;

  LOG_D(NR_MAC,
        "%s %4d.%2d Scheduling pucch reception in %4d.%2d: bits SR %d, DAI %d, CSI %d on res %d\n",
        pucch->dai_c>0 ? "pucch_acknack" : "",
        frame,
        slot,
        pucch->frame,
        pucch->ul_slot,
        pucch->sr_flag,
        pucch->dai_c,
        pucch->csi_bits,
        pucch->resource_indicator);
  NR_COMMON_channels_t * common_ch=nrmac->common_channels;
  NR_ServingCellConfigCommon_t *scc = common_ch->ServingCellConfigCommon;

  LOG_D(NR_MAC,
        "%4d.%2d Calling nr_configure_pucch (pucch_Config %p,r_pucch %d) pucch to be scheduled in %4d.%2d\n",
        frame,
        slot,
        UE->current_UL_BWP.pucch_Config,
        pucch->r_pucch,
        pucch->frame,
        pucch->ul_slot);

  nr_configure_pucch(pucch_pdu,
                     scc,
                     UE,
                     pucch->resource_indicator,
                     pucch->csi_bits,
                     pucch->dai_c,
                     pucch->sr_flag,
                     pucch->r_pucch);
}

#define MIN_RSRP_VALUE -141
#define MAX_RSRP_VALUE -43

//Measured RSRP Values Table 10.1.16.1-1 from 38.133
//Stored all the upper limits[Max RSRP Value of corresponding index]
//stored -1 for invalid values
static const int L1_SSB_CSI_RSRP_measReport_mapping_38133_10_1_6_1_1[128] = {
    -1,   -1,   -1,   -1,   -1,      -1,   -1,      -1,   -1,   -1, // 0 - 9
    -1,   -1,   -1,   -1,   -1, -1, MIN_RSRP_VALUE, -140, -139, -138, // 10 - 19
    -137, -136, -135, -134, -133,    -132, -131,    -130, -129, -128, // 20 - 29
    -127, -126, -125, -124, -123,    -122, -121,    -120, -119, -118, // 30 - 39
    -117, -116, -115, -114, -113,    -112, -111,    -110, -109, -108, // 40 - 49
    -107, -106, -105, -104, -103,    -102, -101,    -100, -99,  -98, // 50 - 59
    -97,  -96,  -95,  -94,  -93,     -92,  -91,     -90,  -89,  -88, // 60 - 69
    -87,  -86,  -85,  -84,  -83,     -82,  -81,     -80,  -79,  -78, // 70 - 79
    -77,  -76,  -75,  -74,  -73,     -72,  -71,     -70,  -69,  -68, // 80 - 89
    -67,  -66,  -65,  -64,  -63,     -62,  -61,     -60,  -59,  -58, // 90 - 99
    -57,  -56,  -55,  -54,  -53,     -52,  -51,     -50,  -49,  -48, // 100 - 109
    -47,  -46,  -45,  -44, MAX_RSRP_VALUE, -1, -1,  -1,   -1,   -1, // 110 - 119
    -1,   -1,   -1,   -1,   -1,      -1,   -1,      -1 // 120 - 127
};

//Differential RSRP values Table 10.1.6.1-2 from 38.133
//Stored the upper limits[MAX RSRP Value]
static const int diff_rsrp_ssb_csi_meas_10_1_6_1_2[16] = {
    0,
    -2,
    -4,
    -6,
    -8,
    -10,
    -12,
    -14,
    -16,
    -18, // 0 - 9
    -20,
    -22,
    -24,
    -26,
    -28,
    -30 // 10 - 15
};

static int get_pucch_index(int frame, int slot, const frame_structure_t *fs, int sched_pucch_size)
{
  // PUCCH structures are indexed by slot in the PUCCH period determined by sched_pucch_size number of UL slots
  // this functions return the index to the structure for slot passed to the function
  const int n_ul_slots_period = get_ul_slots_per_period(fs);
  const int n_ul_slots_frame = get_ul_slots_per_frame(fs);
  // (frame * n_ul_slots_frame) adds up the number of UL slots in the previous frames
  const int frame_start      = frame * n_ul_slots_frame;
  // ((slot / nr_slots_period) * n_ul_slots_period) adds up the number of UL slots in the previous TDD periods of this frame
  const int ul_period_start  = (slot / fs->numb_slots_period) * n_ul_slots_period;
  // ((slot % nr_slots_period) - first_ul_slot_period) gives the progressive number of the slot in this TDD period
  int ul_period_slot = -1;
  for (int i = 0; i <= slot % fs->numb_slots_period; i++) {
    if (is_ul_slot(i, fs)) {
      ul_period_slot++;
    }
  }
  LOG_D(NR_MAC,
        "PUCCH frame/slot:  request %4d.%2d:frame_start %d,ul_period_start %d, ul_period_slot %d  pucch_index %d pucch_size %d "
        "scheduling PUCCH\n",
        frame,
        slot,
        frame_start,
        ul_period_start,
        ul_period_slot,
        ((frame_start + ul_period_start + ul_period_slot) % sched_pucch_size),
        sched_pucch_size);
  // the sum gives the index of current UL slot in the frame which is normalized wrt sched_pucch_size
  return (frame_start + ul_period_start + ul_period_slot) % sched_pucch_size;
}

static void schedule_pucch_core(gNB_MAC_INST *nrmac, NR_UE_info_t *UE, frame_t frame, slot_t slot)
{
  NR_UE_sched_ctrl_t *sched_ctrl = &UE->UE_sched_ctrl;
  const int pucch_index = get_pucch_index(frame, slot, &nrmac->frame_structure, sched_ctrl->sched_pucch_size);
  NR_sched_pucch_t *curr_pucch = &UE->UE_sched_ctrl.sched_pucch[pucch_index];
  if (!curr_pucch->active)
    return;
  if (frame != curr_pucch->frame || slot != curr_pucch->ul_slot) {
    LOG_E(NR_MAC,
          "PUCCH frame/slot mismatch: current %4d.%2d vs. request %4d.%2d: not scheduling PUCCH\n",
          curr_pucch->frame,
          curr_pucch->ul_slot,
          frame,
          slot);
    memset(curr_pucch, 0, sizeof(*curr_pucch));;
    return;
  }

  const uint16_t O_ack = curr_pucch->dai_c;
  const uint16_t O_csi = curr_pucch->csi_bits;
  const uint8_t O_sr = curr_pucch->sr_flag;
  LOG_D(NR_MAC,
        "Scheduling PUCCH[%d] RX for UE %04x in %4d.%2d O_ack %d, O_sr %d, O_csi %d\n",
        pucch_index,
        UE->rnti,
        curr_pucch->frame,
        curr_pucch->ul_slot,
        O_ack,O_sr,
        O_csi);
  nr_fill_nfapi_pucch(nrmac, frame, slot, curr_pucch, UE);
  memset(curr_pucch, 0, sizeof(*curr_pucch));
}

void nr_schedule_pucch(gNB_MAC_INST *nrmac, frame_t frame, slot_t slot)
{
  /* already mutex protected: held in gNB_dlsch_ulsch_scheduler() */
  NR_SCHED_ENSURE_LOCKED(&nrmac->sched_lock);

  if (!is_ul_slot(slot, &nrmac->frame_structure))
    return;

  UE_iterator(nrmac->UE_info.access_ue_list, init_UE) {
    if (init_UE->ra->ra_state == nrRA_WAIT_Msg4_MsgB_ACK)
      schedule_pucch_core(nrmac, init_UE, frame, slot);
  }

  UE_iterator(nrmac->UE_info.connected_ue_list, UE) {
    schedule_pucch_core(nrmac, UE, frame, slot);
  }
}

void nr_csi_meas_reporting(int Mod_idP,frame_t frame, slot_t slot)
{
  const int CC_id = 0;
  gNB_MAC_INST *nrmac = RC.nrmac[Mod_idP];
  const NR_ServingCellConfigCommon_t *scc = nrmac->common_channels[CC_id].ServingCellConfigCommon;
  const int NTN_gNB_Koffset = get_NTN_Koffset(scc);

  /* already mutex protected: held in gNB_dlsch_ulsch_scheduler() */
  NR_SCHED_ENSURE_LOCKED(&nrmac->sched_lock);

  UE_iterator(nrmac->UE_info.connected_ue_list, UE) {
    NR_UE_sched_ctrl_t *sched_ctrl = &UE->UE_sched_ctrl;
    NR_UE_UL_BWP_t *ul_bwp = &UE->current_UL_BWP;
    const int n_slots_frame = nrmac->frame_structure.numb_slots_frame;
    if (nr_timer_is_active(&sched_ctrl->transm_interrupt) || (sched_ctrl->ul_failure && !get_softmodem_params()->phy_test)) {
      continue;
    }
    const NR_CSI_MeasConfig_t *csi_measconfig = UE->sc_info.csi_MeasConfig;
    if (!csi_measconfig)
      continue;
    AssertFatal(csi_measconfig->csi_ReportConfigToAddModList->list.count > 0,
                "NO CSI report configuration available");
    NR_PUCCH_Config_t *pucch_Config = ul_bwp->pucch_Config;

    for (int csi_report_id = 0; csi_report_id < csi_measconfig->csi_ReportConfigToAddModList->list.count; csi_report_id++){
      NR_CSI_ReportConfig_t *csirep = csi_measconfig->csi_ReportConfigToAddModList->list.array[csi_report_id];

      AssertFatal(csirep->reportConfigType.choice.periodic,
                  "Only periodic CSI reporting is implemented currently\n");

      const NR_PUCCH_CSI_Resource_t *pucchcsires = csirep->reportConfigType.choice.periodic->pucch_CSI_ResourceList.list.array[0];
      if(pucchcsires->uplinkBandwidthPartId != ul_bwp->bwp_id)
        continue;

      // we schedule CSI reporting max_fb_time slots in advance
      int period, offset;
      csi_period_offset(csirep, NULL, &period, &offset);
      const int sched_slot = (slot + ul_bwp->max_fb_time + NTN_gNB_Koffset) % n_slots_frame;
      const int sched_frame = (frame + ((slot + ul_bwp->max_fb_time + NTN_gNB_Koffset) / n_slots_frame)) % MAX_FRAME_NUMBER;
      // prepare to schedule csi measurement reception according to 5.2.1.4 in 38.214
      if ((sched_frame * n_slots_frame + sched_slot - offset) % period != 0)
        continue;

      AssertFatal(is_ul_slot(sched_slot, &nrmac->frame_structure), "CSI reporting slot %d is not set for an uplink slot\n", sched_slot);
      LOG_D(NR_MAC, "CSI reporting in frame %d slot %d CSI report ID %ld\n", sched_frame, sched_slot, csirep->reportConfigId);

      const NR_PUCCH_ResourceSet_t *pucchresset = pucch_Config->resourceSetToAddModList->list.array[1]; // set with formats >1
      const int n = pucchresset->resourceList.list.count;
      int res_index = 0;
      for (; res_index < n; res_index++)
        if (*pucchresset->resourceList.list.array[res_index] == pucchcsires->pucch_Resource)
          break;
      AssertFatal(res_index < n,
                  "CSI pucch resource %ld not found among PUCCH resources\n", pucchcsires->pucch_Resource);

      const int pucch_index = get_pucch_index(sched_frame, sched_slot, &nrmac->frame_structure, sched_ctrl->sched_pucch_size);
      NR_sched_pucch_t *curr_pucch = &sched_ctrl->sched_pucch[pucch_index];
      AssertFatal(curr_pucch->active == false, "CSI structure is scheduled in advance. It should be free!\n");
      curr_pucch->r_pucch = -1;
      curr_pucch->frame = sched_frame;
      curr_pucch->ul_slot = sched_slot;
      curr_pucch->resource_indicator = res_index;
      curr_pucch->csi_bits += nr_get_csi_bitlen(&UE->csi_report_template[csi_report_id]);
      curr_pucch->active = true;

      int bwp_start = ul_bwp->BWPStart;

      // going through the list of PUCCH resources to find the one indexed by resource_id
      NR_beam_alloc_t beam = beam_allocation_procedure(&nrmac->beam_info, sched_frame, sched_slot, UE->UE_beam_index, n_slots_frame);
      AssertFatal(beam.idx >= 0, "Cannot allocate CSI measurements on PUCCH in any available beam\n");
      const int index = ul_buffer_index(sched_frame, sched_slot, n_slots_frame, nrmac->vrb_map_UL_size);
      uint16_t *vrb_map_UL = &nrmac->common_channels[0].vrb_map_UL[beam.idx][index * MAX_BWP_SIZE];
      const int m = pucch_Config->resourceToAddModList->list.count;
      for (int j = 0; j < m; j++) {
        NR_PUCCH_Resource_t *pucchres = pucch_Config->resourceToAddModList->list.array[j];
        if (pucchres->pucch_ResourceId != *pucchresset->resourceList.list.array[res_index])
          continue;
        int start = pucchres->startingPRB;
        int len = 1;
        uint64_t mask = 0;
        switch(pucchres->format.present){
          case NR_PUCCH_Resource__format_PR_format2:
            len = pucchres->format.choice.format2->nrofPRBs;
            mask = SL_to_bitmap(pucchres->format.choice.format2->startingSymbolIndex, pucchres->format.choice.format2->nrofSymbols);
            curr_pucch->simultaneous_harqcsi = pucch_Config->format2->choice.setup->simultaneousHARQ_ACK_CSI;
            LOG_D(NR_MAC,
                  "%d.%d Allocating PUCCH format 2, startPRB %d, nPRB %d, simulHARQ %d, num_bits %d\n",
                  sched_frame,
                  sched_slot,
                  start,
                  len,
                  curr_pucch->simultaneous_harqcsi,
                  curr_pucch->csi_bits);
            break;
          case NR_PUCCH_Resource__format_PR_format3:
            len = pucchres->format.choice.format3->nrofPRBs;
            mask = SL_to_bitmap(pucchres->format.choice.format3->startingSymbolIndex, pucchres->format.choice.format3->nrofSymbols);
            curr_pucch->simultaneous_harqcsi = pucch_Config->format3->choice.setup->simultaneousHARQ_ACK_CSI;
            break;
          case NR_PUCCH_Resource__format_PR_format4:
            mask = SL_to_bitmap(pucchres->format.choice.format4->startingSymbolIndex, pucchres->format.choice.format4->nrofSymbols);
            curr_pucch->simultaneous_harqcsi = pucch_Config->format4->choice.setup->simultaneousHARQ_ACK_CSI;
            break;
        default:
          AssertFatal(0, "Invalid PUCCH format type\n");
        }
        // verify resources are free
        for (int i = start; i < start + len; ++i) {
          if((vrb_map_UL[i+bwp_start] & mask) != 0) {
            LOG_E(NR_MAC,
                  "%4d.%2d VRB MAP in %4d.%2d not free. Can't schedule CSI reporting on PUCCH.\n",
                  frame,
                  slot,
                  sched_frame,
                  sched_slot);
            memset(curr_pucch, 0, sizeof(*curr_pucch));
          }
          else
            vrb_map_UL[i+bwp_start] |= mask;
        }
      }
    }
  }
}

int get_pucch_resourceid(NR_PUCCH_Config_t *pucch_Config, int O_uci, int pucch_resource)
{
  NR_PUCCH_ResourceId_t *resource_id = NULL;
  AssertFatal(pucch_Config->resourceSetToAddModList != NULL, "PUCCH resourceSetToAddModList is null\n");

  int n_set = pucch_Config->resourceSetToAddModList->list.count;
  AssertFatal(n_set > 0, "PUCCH resourceSetToAddModList is empty\n");

  LOG_D(NR_MAC, "UCI n_set= %d\n", n_set);

  int N2 = 2;
  // procedure to select pucch resource id from resource sets according to
  // number of uci bits and pucch resource indicator pucch_resource
  // ( see table 9.2.3.2 in 38.213)
  for (int i = 0; i < n_set; i++) {
    NR_PUCCH_ResourceSet_t *pucchresset = pucch_Config->resourceSetToAddModList->list.array[i];
    int n_list = pucchresset->resourceList.list.count;
    if (pucchresset->pucch_ResourceSetId == 0 && O_uci < 3) {
      if (pucch_resource < n_list)
        resource_id = pucchresset->resourceList.list.array[pucch_resource];
      else
        AssertFatal(1 == 0,
                    "Couldn't find pucch resource indicator %d in PUCCH resource set %d for %d UCI bits",
                    pucch_resource,
                    i,
                    O_uci);
    }
    if (pucchresset->pucch_ResourceSetId == 1 && O_uci > 2) {
      int N3 = pucchresset->maxPayloadSize != NULL ? *pucchresset->maxPayloadSize : 1706;
      if (N2 < O_uci && N3 > O_uci) {
        if (pucch_resource < n_list)
          resource_id = pucchresset->resourceList.list.array[pucch_resource];
        else
          AssertFatal(1 == 0,
                      "Couldn't find pucch resource indicator %d in PUCCH resource set %d for %d UCI bits",
                      pucch_resource,
                      i,
                      O_uci);
      } else
        N2 = N3;
    }
  }
  AssertFatal(resource_id != NULL, "Couldn't find any matching PUCCH resource in the PUCCH resource sets");
  return *resource_id;
}

static void handle_dl_harq(NR_UE_info_t * UE,
                           int8_t harq_pid,
                           bool success,
                           int harq_round_max)
{
  NR_UE_sched_ctrl_t *sched_ctrl = &UE->UE_sched_ctrl;
  NR_UE_harq_t *harq = &sched_ctrl->harq_processes[harq_pid];
  harq->feedback_slot = -1;
  harq->is_waiting = false;
  if (success) {
    finish_nr_dl_harq(sched_ctrl, harq_pid);
  } else if (harq->round >= harq_round_max - 1) {
    abort_nr_dl_harq(UE, harq_pid);
    LOG_D(NR_MAC, "retransmission error for UE %04x (total %"PRIu64")\n", UE->rnti, UE->mac_stats.dl.errors);
  } else {
    LOG_D(PHY,"NACK for: pid %d, ue %04x\n",harq_pid, UE->rnti);
    add_tail_nr_list(&sched_ctrl->retrans_dl_harq, harq_pid);
    harq->round++;
  }
}

//returns the measured RSRP value (upper limit)
static bool get_measured_rsrp(uint8_t index, int *rsrp)
{
  //if index is invalid returning minimum rsrp -140
  if (index <= 15)
    return false;
  if (index >= 114)
    return false;

  *rsrp = L1_SSB_CSI_RSRP_measReport_mapping_38133_10_1_6_1_1[index];
  return true;
}

//returns the differential RSRP value (upper limit)
static int get_diff_rsrp(uint8_t index, int strongest_rsrp)
{
  if(strongest_rsrp != -1)
    return strongest_rsrp + diff_rsrp_ssb_csi_meas_10_1_6_1_2[index];
  else
    return MIN_RSRP_VALUE;
}

static uint8_t pickandreverse_bits(uint8_t *payload, uint16_t bitlen, uint8_t start_bit)
{
  uint8_t rev_bits = 0;
  for (int i = 0; i < bitlen; i++)
    rev_bits |= ((payload[(start_bit + i) / 8] >> ((start_bit + i) % 8)) & 0x01) << (bitlen - i - 1);
  return rev_bits;
}

static void evaluate_sinr_report(gNB_MAC_INST *nrmac,
                                 NR_UE_info_t *UE,
                                 NR_UE_sched_ctrl_t *sched_ctrl,
                                 uint8_t csi_report_id,
                                 uint8_t *payload,
                                 int *cumul_bits,
                                 NR_CSI_ReportConfig__ext2__reportQuantity_r16_PR reportQuantity_type_r16)
{
  /*! As per the spec 38.212 and table:  6.3.1.1.2-12 in a single UCI sequence we can have multiple CSI_report
   * the number of CSI_report will depend on number of CSI resource sets that are configured in CSI-ResourceConfig RRC IE
   * From spec 38.331 from the IE CSI-ResourceConfig for SSB RSRP reporting we can configure only one resource set
   * From spec 38.214 section 5.2.1.2 For periodic and semi-persistent CSI Resource Settings, the number of CSI-RS Resource Sets
   * configured is limited to S=1
   */

  /** from 38.214 sec 5.2.1.4.2
  - if the UE is configured with the higher layer parameter groupBasedBeamReporting set to 'disabled', the UE is
    not required to update measurements for more than 64 CSI-RS and/or SSB resources, and the UE shall report in
    a single report nrofReportedRS (higher layer configured) different CRI or SSBRI for each report setting

  - if the UE is configured with the higher layer parameter groupBasedBeamReporting set to 'enabled', the UE is not
    required to update measurements for more than 64 CSI-RS and/or SSB resources, and the UE shall report in a
    single reporting instance two different CRI or SSBRI for each report setting, where CSI-RS and/or SSB
    resources can be received simultaneously by the UE either with a single spatial domain receive filter, or with
    multiple simultaneous spatial domain receive filter
  */

  nr_csi_report_t *csi_report = &UE->csi_report_template[csi_report_id];
  RSRP_report_t *sinr_report;
  long **index_list;
  switch (reportQuantity_type_r16) {
    case NR_CSI_ReportConfig__ext2__reportQuantity_r16_PR_ssb_Index_SINR_r16:
      sinr_report = &sched_ctrl->CSI_report.ssb_rsrp_report;
      index_list = csi_report->SSB_Index_list;
      break;
    case NR_CSI_ReportConfig__ext2__reportQuantity_r16_PR_cri_SINR_r16:
      sinr_report = &sched_ctrl->CSI_report.csirs_rsrp_report;
      index_list = csi_report->CSI_Index_list;
      break;
    default:
      AssertFatal(false, "Invalid RSRP report type\n");
  }

  sinr_report->nr_reports = csi_report->CSI_report_bitlen.nb_ssbri_cri;
  uint16_t curr_payload;
  for (int i = 0; i < sinr_report->nr_reports; i++) {
    int bitlen = csi_report->CSI_report_bitlen.cri_ssbri_bitlen;
    curr_payload = pickandreverse_bits(payload, bitlen, *cumul_bits);
    sinr_report->resource_id[i] = *(index_list[bitlen > 0 ? ((curr_payload) & ~(~1U << (bitlen - 1))) : bitlen]);
    LOG_D(MAC, "SSB/CSI-RS index = %d\n", sinr_report->resource_id[i]);
    *cumul_bits += bitlen;
  }

  curr_payload = pickandreverse_bits(payload, 7, *cumul_bits);
  sinr_report->SINR_index[0] = curr_payload & 0x7f;
  *cumul_bits += 7;

  csi_report->nb_of_csi_ssb_report++;
  if (sinr_report->SINR_index[0] < 0 || sinr_report->SINR_index[0] > 127) {
    LOG_E(NR_MAC, "UE %04x: reported SINR index %d invalid\n", UE->rnti, sinr_report->SINR_index[0]);
    return;
  }

  for (int i = 1; i < sinr_report->nr_reports; i++) {
    curr_payload = pickandreverse_bits(payload, 4, *cumul_bits);
    sinr_report->SINR_index[i] = curr_payload & 0x0f;
    *cumul_bits += 4;
  }

  LOG_D(MAC, "Reported SSB-SINR index = %d\n", sinr_report->SINR_index[0]);
}

static void evaluate_rsrp_report(gNB_MAC_INST *nrmac,
                                 NR_UE_info_t *UE,
                                 NR_UE_sched_ctrl_t *sched_ctrl,
                                 uint8_t csi_report_id,
                                 uint8_t *payload,
                                 int *cumul_bits,
                                 NR_CSI_ReportConfig__reportQuantity_PR reportQuantity_type)
{
  /*! As per the spec 38.212 and table:  6.3.1.1.2-12 in a single UCI sequence we can have multiple CSI_report
  * the number of CSI_report will depend on number of CSI resource sets that are configured in CSI-ResourceConfig RRC IE
  * From spec 38.331 from the IE CSI-ResourceConfig for SSB RSRP reporting we can configure only one resource set
  * From spec 38.214 section 5.2.1.2 For periodic and semi-persistent CSI Resource Settings, the number of CSI-RS Resource Sets configured is limited to S=1
  */

  /** from 38.214 sec 5.2.1.4.2
  - if the UE is configured with the higher layer parameter groupBasedBeamReporting set to 'disabled', the UE is
    not required to update measurements for more than 64 CSI-RS and/or SSB resources, and the UE shall report in
    a single report nrofReportedRS (higher layer configured) different CRI or SSBRI for each report setting

  - if the UE is configured with the higher layer parameter groupBasedBeamReporting set to 'enabled', the UE is not
    required to update measurements for more than 64 CSI-RS and/or SSB resources, and the UE shall report in a
    single reporting instance two different CRI or SSBRI for each report setting, where CSI-RS and/or SSB
    resources can be received simultaneously by the UE either with a single spatial domain receive filter, or with
    multiple simultaneous spatial domain receive filter
  */
  nr_csi_report_t *csi_report = &UE->csi_report_template[csi_report_id];
  RSRP_report_t *rsrp_report;
  long **index_list;
  switch (reportQuantity_type) {
    case NR_CSI_ReportConfig__reportQuantity_PR_ssb_Index_RSRP:
      rsrp_report = &sched_ctrl->CSI_report.ssb_rsrp_report;
      index_list = csi_report->SSB_Index_list;
      break;
    case NR_CSI_ReportConfig__reportQuantity_PR_cri_RSRP :
      rsrp_report = &sched_ctrl->CSI_report.csirs_rsrp_report;
      index_list = csi_report->CSI_Index_list;
      break;
    default :
      AssertFatal(false, "Invalid RSRP report type\n");
  }

  rsrp_report->nr_reports = csi_report->CSI_report_bitlen.nb_ssbri_cri;
  uint16_t curr_payload;
  for (int i = 0; i < rsrp_report->nr_reports; i++) {
    int bitlen = csi_report->CSI_report_bitlen.cri_ssbri_bitlen;
    curr_payload = pickandreverse_bits(payload, bitlen, *cumul_bits);
    rsrp_report->resource_id[i] = *(index_list[bitlen > 0 ? ((curr_payload) & ~(~1U << (bitlen - 1))) : bitlen]);
    LOG_D(MAC,"SSB/CSI-RS index = %d\n", rsrp_report->resource_id[i]);
    *cumul_bits += bitlen;
  }

  curr_payload = pickandreverse_bits(payload, 7, *cumul_bits);
  int rsrp_index = curr_payload & 0x7f;
  *cumul_bits += 7;

  csi_report->nb_of_csi_ssb_report++;
  bool valid = get_measured_rsrp(rsrp_index, &rsrp_report->RSRP[0]);
  if (!valid) {
    LOG_E(NR_MAC, "UE %04x: reported RSRP index %d invalid\n", UE->rnti, rsrp_index);
    return;
  }

  for (int i = 1; i < rsrp_report->nr_reports; i++) {
    curr_payload = pickandreverse_bits(payload, 4, *cumul_bits);
    rsrp_report->RSRP[i] = get_diff_rsrp(curr_payload & 0x0f, rsrp_report->RSRP[0]);
    *cumul_bits += 4;
  }

  NR_mac_stats_t *stats = &UE->mac_stats;
  // including ssb rsrp in mac stats
  stats->cumul_rsrp += rsrp_report->RSRP[0];
  stats->num_rsrp_meas++;
}

static void evaluate_cri_report(uint8_t *payload, uint8_t cri_bitlen, int cumul_bits, NR_UE_sched_ctrl_t *sched_ctrl)
{
  uint8_t temp_cri = pickandreverse_bits(payload, cri_bitlen, cumul_bits);
  sched_ctrl->CSI_report.cri_ri_li_pmi_cqi_report.cri = temp_cri;
}

static int evaluate_ri_report(uint8_t *payload,
                              uint8_t ri_bitlen,
                              uint8_t ri_restriction,
                              int cumul_bits,
                              NR_UE_sched_ctrl_t *sched_ctrl)
{
  uint8_t ri_index = pickandreverse_bits(payload, ri_bitlen, cumul_bits);
  int count = 0;
  for (int i = 0; i < 8; i++) {
     if ((ri_restriction >> i) & 0x01) {
       if(count == ri_index) {
         sched_ctrl->CSI_report.cri_ri_li_pmi_cqi_report.ri = i;
         LOG_D(MAC,"CSI Reported Rank %d\n", i + 1);
         return i;
       }
       count++;
     }
  }
  AssertFatal(1==0, "Decoded ri %d does not correspond to any valid value in ri_restriction %d\n",ri_index,ri_restriction);
}

static void evaluate_cqi_report(uint8_t *payload,
                                nr_csi_report_t *csi_report,
                                int cumul_bits,
                                uint8_t ri,
                                NR_UE_info_t *UE,
                                uint8_t cqi_Table)
{

  NR_UE_sched_ctrl_t *sched_ctrl = &UE->UE_sched_ctrl;

  //TODO sub-band CQI report not yet implemented
  int cqi_bitlen = csi_report->csi_meas_bitlen.cqi_bitlen[ri];

  uint8_t temp_cqi = pickandreverse_bits(payload, 4, cumul_bits);

  // NR_CSI_ReportConfig__cqi_Table_table1	= 0
  // NR_CSI_ReportConfig__cqi_Table_table2	= 1
  // NR_CSI_ReportConfig__cqi_Table_table3	= 2
  sched_ctrl->CSI_report.cri_ri_li_pmi_cqi_report.cqi_table = cqi_Table;
  sched_ctrl->CSI_report.cri_ri_li_pmi_cqi_report.wb_cqi_1tb = temp_cqi;
  LOG_D(MAC,"Wide-band CQI for the first TB %d\n", temp_cqi);
  if (cqi_bitlen > 4) {
    temp_cqi = pickandreverse_bits(payload, 4, cumul_bits);
    sched_ctrl->CSI_report.cri_ri_li_pmi_cqi_report.wb_cqi_2tb = temp_cqi;
    LOG_D(MAC,"Wide-band CQI for the second TB %d\n", temp_cqi);
  }

  // TODO for wideband case and multiple TB
  const int cqi_idx = sched_ctrl->CSI_report.cri_ri_li_pmi_cqi_report.wb_cqi_1tb;
  const int mcs_table = UE->current_DL_BWP.mcsTableIdx;
  sched_ctrl->dl_max_mcs = get_mcs_from_cqi(mcs_table, cqi_Table, cqi_idx);
}

static uint8_t evaluate_pmi_report(uint8_t *payload,
                                   nr_csi_report_t *csi_report,
                                   int cumul_bits,
                                   uint8_t ri,
                                   NR_UE_sched_ctrl_t *sched_ctrl)
{
  int x1_bitlen = csi_report->csi_meas_bitlen.pmi_x1_bitlen[ri];
  int x2_bitlen = csi_report->csi_meas_bitlen.pmi_x2_bitlen[ri];

  //in case of 2 port CSI configuration x1 is empty and the information bits are in x2
  int starting_bit = cumul_bits;
  sched_ctrl->CSI_report.cri_ri_li_pmi_cqi_report.pmi_x1 = pickandreverse_bits(payload, x1_bitlen, starting_bit);
  starting_bit += x1_bitlen;
  sched_ctrl->CSI_report.cri_ri_li_pmi_cqi_report.pmi_x2 = pickandreverse_bits(payload, x2_bitlen, starting_bit);
  LOG_D(NR_MAC,
        "PMI Report: X1 %d X2 %d\n",
        sched_ctrl->CSI_report.cri_ri_li_pmi_cqi_report.pmi_x1,
        sched_ctrl->CSI_report.cri_ri_li_pmi_cqi_report.pmi_x2);

  return x1_bitlen + x2_bitlen;
}

static int evaluate_li_report(uint8_t *payload,
                              nr_csi_report_t *csi_report,
                              int cumul_bits,
                              uint8_t ri,
                              NR_UE_sched_ctrl_t *sched_ctrl)
{
  int li_bitlen = csi_report->csi_meas_bitlen.li_bitlen[ri];

  if (li_bitlen>0) {
    int temp_li = pickandreverse_bits(payload, li_bitlen, cumul_bits);
    LOG_D(MAC,"LI %d\n",temp_li);
    sched_ctrl->CSI_report.cri_ri_li_pmi_cqi_report.li = temp_li;
  }
  return li_bitlen;
}

static void skip_zero_padding(int *cumul_bits, nr_csi_report_t *csi_report, uint8_t ri, uint16_t max_bitlen)
{
  // actual number of reported bits depends on the reported rank
  // zero padding bits are added to have a predetermined max bit length to decode

  uint16_t reported_bitlen = csi_report->csi_meas_bitlen.cri_bitlen+
                             csi_report->csi_meas_bitlen.ri_bitlen+
                             csi_report->csi_meas_bitlen.li_bitlen[ri]+
                             csi_report->csi_meas_bitlen.cqi_bitlen[ri]+
                             csi_report->csi_meas_bitlen.pmi_x1_bitlen[ri]+
                             csi_report->csi_meas_bitlen.pmi_x2_bitlen[ri];

  *cumul_bits+=(max_bitlen-reported_bitlen);
}

static void extract_pucch_csi_report(NR_CSI_MeasConfig_t *csi_MeasConfig,
                                     const nfapi_nr_uci_pucch_pdu_format_2_3_4_t *uci_pdu,
                                     frame_t frame,
                                     slot_t slot,
                                     NR_UE_info_t *UE,
                                     gNB_MAC_INST *nrmac)
{
  /** From Table 6.3.1.1.2-3: RI, LI, CQI, and CRI of codebookType=typeI-SinglePanel */
  uint8_t *payload = uci_pdu->csi_part1.csi_part1_payload;
  uint16_t bitlen = uci_pdu->csi_part1.csi_part1_bit_len;
  NR_CSI_ReportConfig__reportQuantity_PR reportQuantity_type = NR_CSI_ReportConfig__reportQuantity_PR_NOTHING;
  NR_CSI_ReportConfig__ext2__reportQuantity_r16_PR reportQuantity_type_r16 =
      NR_CSI_ReportConfig__ext2__reportQuantity_r16_PR_NOTHING;
  NR_UE_sched_ctrl_t *sched_ctrl = &UE->UE_sched_ctrl;
  NR_UE_UL_BWP_t *ul_bwp = &UE->current_UL_BWP;
  NR_UE_DL_BWP_t *dl_bwp = &UE->current_DL_BWP;
  const int n_slots_frame = nrmac->frame_structure.numb_slots_frame;
  int cumul_bits = 0;
  int r_index = -1;
  for (int csi_report_id = 0; csi_report_id < csi_MeasConfig->csi_ReportConfigToAddModList->list.count; csi_report_id++) {
    nr_csi_report_t *csi_report = &UE->csi_report_template[csi_report_id];
    csi_report->nb_of_csi_ssb_report = 0;
    uint8_t cri_bitlen = 0;
    uint8_t ri_bitlen = 0;
    uint8_t li_bitlen = 0;
    uint8_t pmi_bitlen = 0;
    NR_CSI_ReportConfig_t *csirep = csi_MeasConfig->csi_ReportConfigToAddModList->list.array[csi_report_id];
    uint8_t cqi_table = (dl_bwp->dci_format == NR_DL_DCI_FORMAT_1_1 && csirep->cqi_Table) ? *csirep->cqi_Table : NR_CSI_ReportConfig__cqi_Table_table1;
    const NR_PUCCH_CSI_Resource_t *pucchcsires = csirep->reportConfigType.choice.periodic->pucch_CSI_ResourceList.list.array[0];
    if(pucchcsires->uplinkBandwidthPartId != ul_bwp->bwp_id)
      continue;
    int period, offset;
    csi_period_offset(csirep, NULL, &period, &offset);
    // verify if report with current id has been scheduled for this frame and slot
    if ((n_slots_frame*frame + slot - offset)%period == 0) {
      reportQuantity_type = csi_report->reportQuantity_type;
      reportQuantity_type_r16 = csi_report->reportQuantity_type_r16;
      LOG_D(MAC, "SFN/SF:%d/%d reportQuantity type = %d, type_r16 = %d\n", frame, slot, reportQuantity_type, reportQuantity_type_r16);
      if (reportQuantity_type_r16 == NR_CSI_ReportConfig__ext2__reportQuantity_r16_PR_cri_SINR_r16
          || reportQuantity_type_r16 == NR_CSI_ReportConfig__ext2__reportQuantity_r16_PR_ssb_Index_SINR_r16) {
        evaluate_sinr_report(nrmac, UE, sched_ctrl, csi_report_id, payload, &cumul_bits, reportQuantity_type_r16);
      } else {
        // phy-test has hardcoded allocation, so no use to handle CSI reports except RSRP
        if (get_softmodem_params()->phy_test
            && reportQuantity_type != NR_CSI_ReportConfig__reportQuantity_PR_ssb_Index_RSRP
            && reportQuantity_type != NR_CSI_ReportConfig__reportQuantity_PR_cri_RSRP)
          continue;
        switch (reportQuantity_type) {
          case NR_CSI_ReportConfig__reportQuantity_PR_cri_RSRP:
            evaluate_rsrp_report(nrmac, UE, sched_ctrl, csi_report_id, payload, &cumul_bits, reportQuantity_type);
            break;
          case NR_CSI_ReportConfig__reportQuantity_PR_ssb_Index_RSRP:
            evaluate_rsrp_report(nrmac, UE, sched_ctrl, csi_report_id, payload, &cumul_bits, reportQuantity_type);
            beam_selection_procedures(nrmac, UE);
            break;
          case NR_CSI_ReportConfig__reportQuantity_PR_cri_RI_CQI:
            sched_ctrl->CSI_report.cri_ri_li_pmi_cqi_report.print_report = true;
            cri_bitlen = csi_report->csi_meas_bitlen.cri_bitlen;
            if (cri_bitlen)
              evaluate_cri_report(payload, cri_bitlen, cumul_bits, sched_ctrl);
            cumul_bits += cri_bitlen;
            ri_bitlen = csi_report->csi_meas_bitlen.ri_bitlen;
            if (ri_bitlen)
              r_index = evaluate_ri_report(payload, ri_bitlen, csi_report->csi_meas_bitlen.ri_restriction, cumul_bits, sched_ctrl);
            cumul_bits += ri_bitlen;
            if (r_index != -1)
              skip_zero_padding(&cumul_bits, csi_report, r_index, bitlen);
            evaluate_cqi_report(payload, csi_report, cumul_bits, r_index, UE, cqi_table);
            break;
          case NR_CSI_ReportConfig__reportQuantity_PR_cri_RI_PMI_CQI:
            sched_ctrl->CSI_report.cri_ri_li_pmi_cqi_report.print_report = true;
            cri_bitlen = csi_report->csi_meas_bitlen.cri_bitlen;
            if (cri_bitlen)
              evaluate_cri_report(payload, cri_bitlen, cumul_bits, sched_ctrl);
            cumul_bits += cri_bitlen;
            ri_bitlen = csi_report->csi_meas_bitlen.ri_bitlen;
            if (ri_bitlen)
              r_index = evaluate_ri_report(payload, ri_bitlen, csi_report->csi_meas_bitlen.ri_restriction, cumul_bits, sched_ctrl);
            cumul_bits += ri_bitlen;
            if (r_index != -1)
              skip_zero_padding(&cumul_bits, csi_report, r_index, bitlen);
            pmi_bitlen = evaluate_pmi_report(payload, csi_report, cumul_bits, r_index, sched_ctrl);
            sched_ctrl->CSI_report.cri_ri_li_pmi_cqi_report.csi_report_id = csi_report_id;
            cumul_bits += pmi_bitlen;
            evaluate_cqi_report(payload, csi_report, cumul_bits, r_index, UE, cqi_table);
            break;
          case NR_CSI_ReportConfig__reportQuantity_PR_cri_RI_LI_PMI_CQI:
            sched_ctrl->CSI_report.cri_ri_li_pmi_cqi_report.print_report = true;
            cri_bitlen = csi_report->csi_meas_bitlen.cri_bitlen;
            if (cri_bitlen)
              evaluate_cri_report(payload, cri_bitlen, cumul_bits, sched_ctrl);
            cumul_bits += cri_bitlen;
            ri_bitlen = csi_report->csi_meas_bitlen.ri_bitlen;
            if (ri_bitlen)
              r_index = evaluate_ri_report(payload, ri_bitlen, csi_report->csi_meas_bitlen.ri_restriction, cumul_bits, sched_ctrl);
            cumul_bits += ri_bitlen;
            li_bitlen = evaluate_li_report(payload, csi_report, cumul_bits, r_index, sched_ctrl);
            cumul_bits += li_bitlen;
            if (r_index != -1)
              skip_zero_padding(&cumul_bits, csi_report, r_index, bitlen);
            pmi_bitlen = evaluate_pmi_report(payload, csi_report, cumul_bits, r_index, sched_ctrl);
            sched_ctrl->CSI_report.cri_ri_li_pmi_cqi_report.csi_report_id = csi_report_id;
            cumul_bits += pmi_bitlen;
            evaluate_cqi_report(payload, csi_report, cumul_bits, r_index, UE, cqi_table);
            break;
          default:
            AssertFatal(1 == 0, "Invalid or not supported CSI measurement report\n");
        }
      }
    }
  }
}

static NR_UE_harq_t *find_harq(frame_t frame, slot_t slot, NR_UE_info_t * UE, int harq_round_max)
{
  /* In case of realtime problems: we can only identify a HARQ process by
   * timing. If the HARQ process's feedback_frame/feedback_slot is not the one we
   * expected, we assume that processing has been aborted and we need to
   * skip this HARQ process, which is what happens in the loop below.
   * Similarly, we might be "in advance", in which case we need to skip
   * this result. */
  NR_UE_sched_ctrl_t *sched_ctrl = &UE->UE_sched_ctrl;
  int8_t pid = sched_ctrl->feedback_dl_harq.head;
  if (pid < 0)
    return NULL;
  NR_UE_harq_t *harq = &sched_ctrl->harq_processes[pid];
  /* old feedbacks we missed: mark for retransmission */
  while ((harq->feedback_frame - frame + 1024 ) % 1024 > 512 // harq->feedback_frame < frame, distance of 512 is boundary to decide if feedback_frame is in the past or future
         || (harq->feedback_frame == frame && harq->feedback_slot < slot)) {
    LOG_W(NR_MAC,
          "UE %04x expected HARQ pid %d feedback at %4d.%2d, but is at %4d.%2d instead (HARQ feedback is in the past)\n",
          UE->rnti,
          pid,
          harq->feedback_frame,
          harq->feedback_slot,
          frame,
          slot);
    remove_front_nr_list(&sched_ctrl->feedback_dl_harq);
    handle_dl_harq(UE, pid, 0, harq_round_max);
    pid = sched_ctrl->feedback_dl_harq.head;
    if (pid < 0)
      return NULL;
    harq = &sched_ctrl->harq_processes[pid];
  }
  /* feedbacks that we wait for in the future: don't do anything */
  if ((frame - harq->feedback_frame + 1024 ) % 1024 > 512 // harq->feedback_frame > frame, distance of 512 is boundary to decide if feedback_frame is in the past or future
      || (harq->feedback_frame == frame && harq->feedback_slot > slot)) {

    LOG_W(NR_MAC,
          "UE %04x expected HARQ pid %d feedback at %4d.%2d, but is at %4d.%2d instead (HARQ feedback is in the future)\n",
          UE->rnti,
          pid,
          harq->feedback_frame,
          harq->feedback_slot,
          frame,
          slot);
    return NULL;
  }
  return harq;
}

void handle_nr_uci_pucch_0_1(module_id_t mod_id, frame_t frame, slot_t slot, const nfapi_nr_uci_pucch_pdu_format_0_1_t *uci_01)
{
  gNB_MAC_INST *nrmac = RC.nrmac[mod_id];
  int rssi_threshold = nrmac->pucch_rssi_threshold;
  NR_SCHED_LOCK(&nrmac->sched_lock);
  NR_UE_info_t *UE = find_nr_UE(&nrmac->UE_info, uci_01->rnti);
  bool is_ra = false;
  if (!UE) {
    UE = find_ra_UE(&nrmac->UE_info, uci_01->rnti);
    if (UE)
      is_ra = true;
    else {
      LOG_E(NR_MAC, "Unknown RNTI %04x in PUCCH UCI\n", uci_01->rnti);
      NR_SCHED_UNLOCK(&nrmac->sched_lock);
      return;
    }
  }
  NR_UE_sched_ctrl_t *sched_ctrl = &UE->UE_sched_ctrl;
  if (((uci_01->pduBitmap >> 1) & 0x01)) {
    // iterate over received harq bits
    for (int harq_bit = 0; harq_bit < uci_01->harq.num_harq; harq_bit++) {
      const uint8_t harq_value = uci_01->harq.harq_list[harq_bit].harq_value;
      const uint8_t harq_confidence = uci_01->harq.harq_confidence_level;
      NR_UE_harq_t *harq = find_harq(frame, slot, UE, nrmac->dl_bler.harq_round_max);
      if (!harq) {
        LOG_E(NR_MAC, "UE %04x: Could not find a HARQ process at %4d.%2d!\n", UE->rnti, frame, slot);
        break;
      }
      DevAssert(harq->is_waiting);
      const int8_t pid = sched_ctrl->feedback_dl_harq.head;
      remove_front_nr_list(&sched_ctrl->feedback_dl_harq);
      LOG_D(NR_MAC,"%4d.%2d bit %d pid %d ack/nack %d\n",frame, slot, harq_bit,pid,harq_value);
      nr_mac_update_pdcch_closed_loop_adjust(sched_ctrl, harq_confidence != 0);
      bool success = harq_value == 0 && harq_confidence == 0;
      handle_dl_harq(UE, pid, success, nrmac->dl_bler.harq_round_max);
      if (is_ra) {
        bool ue_rejected = nr_check_Msg4_MsgB_Ack(mod_id, frame, slot, UE, success);
        if (ue_rejected) {
          NR_SCHED_UNLOCK(&nrmac->sched_lock);
          return;
        }
      }
      if (harq_confidence == 1)
        UE->mac_stats.pucch0_DTX++;
    }

    // tpc (power control) only if we received AckNack
    if (uci_01->harq.harq_confidence_level == 0 && uci_01->ul_cqi != 0xff) {
      sched_ctrl->pucch_snrx10 = uci_01->ul_cqi * 5 - 640;
      sched_ctrl->tpc1 = nr_get_tpc(nrmac->pucch_target_snrx10, uci_01->ul_cqi, 30, 0);
    } else
      sched_ctrl->tpc1 = 1;
    sched_ctrl->tpc1 = nr_limit_tpc(sched_ctrl->tpc1, uci_01->rssi, rssi_threshold);
  }

  // check scheduling request result, confidence_level == 0 is good
  if (uci_01->pduBitmap & 0x1) {
    if (uci_01->sr.sr_indication && uci_01->sr.sr_confidence_level == 0 && uci_01->ul_cqi >= 148) {
      // SR detected with SNR >= 10dB
      sched_ctrl->SR |= true;
      LOG_D(NR_MAC, "SR UE %04x ul_cqi %d\n", uci_01->rnti, uci_01->ul_cqi);
    }

  }
  NR_SCHED_UNLOCK(&nrmac->sched_lock);
}

void handle_nr_uci_pucch_2_3_4(module_id_t mod_id, frame_t frame, slot_t slot, const nfapi_nr_uci_pucch_pdu_format_2_3_4_t *uci_234)
{
  gNB_MAC_INST *nrmac = RC.nrmac[mod_id];
  NR_SCHED_LOCK(&nrmac->sched_lock);
  int rssi_threshold = nrmac->pucch_rssi_threshold;

  NR_UE_info_t *UE = find_nr_UE(&nrmac->UE_info, uci_234->rnti);
  if (!UE) {
    NR_SCHED_UNLOCK(&nrmac->sched_lock);
    LOG_E(NR_MAC, "%s(): unknown RNTI %04x in PUCCH UCI\n", __func__, uci_234->rnti);
    return;
  }

  NR_CSI_MeasConfig_t *csi_MeasConfig = UE->sc_info.csi_MeasConfig;
  if (csi_MeasConfig == NULL) {
    NR_SCHED_UNLOCK(&nrmac->sched_lock);
    return;
  }
  NR_UE_sched_ctrl_t *sched_ctrl = &UE->UE_sched_ctrl;

  // tpc (power control)
  // TODO PUCCH2 SNR computation is not correct -> ignore the following
  if (uci_234->ul_cqi != 0xff) {
    sched_ctrl->pucch_snrx10 = uci_234->ul_cqi * 5 - 640;
    sched_ctrl->tpc1 = nr_get_tpc(nrmac->pucch_target_snrx10, uci_234->ul_cqi, 30, 0);
    sched_ctrl->tpc1 = nr_limit_tpc(sched_ctrl->tpc1, uci_234->rssi, rssi_threshold);
  }

  // TODO: handle SR
  if (uci_234->pduBitmap & 0x1) {
    free(uci_234->sr.sr_payload);
  }

  if ((uci_234->pduBitmap >> 1) & 0x01) {
    // iterate over received harq bits
    for (int harq_bit = 0; harq_bit < uci_234->harq.harq_bit_len; harq_bit++) {
      const int acknack = ((uci_234->harq.harq_payload[harq_bit >> 3]) >> harq_bit) & 0x01;
      NR_UE_harq_t *harq = find_harq(frame, slot, UE, RC.nrmac[mod_id]->dl_bler.harq_round_max);
      if (!harq) {
        LOG_E(NR_MAC, "UE %04x: Could not find a HARQ process at %4d.%2d!\n", UE->rnti, frame, slot);
        break;
      }
      DevAssert(harq->is_waiting);
      const int8_t pid = sched_ctrl->feedback_dl_harq.head;
      remove_front_nr_list(&sched_ctrl->feedback_dl_harq);
      LOG_D(NR_MAC,"%4d.%2d bit %d pid %d ack/nack %d\n",frame, slot, harq_bit, pid, acknack);
      handle_dl_harq(UE, pid, uci_234->harq.harq_crc != 1 && acknack, nrmac->dl_bler.harq_round_max);
    }
    free(uci_234->harq.harq_payload);
  }
  if ((uci_234->pduBitmap >> 2) & 0x01) {
    LOG_D(NR_MAC, "CSI CRC %d\n", uci_234->csi_part1.csi_part1_crc);
    if (uci_234->csi_part1.csi_part1_crc != 1) {
      // API to parse the csi report and store it into sched_ctrl
      extract_pucch_csi_report(csi_MeasConfig, uci_234, frame, slot, UE, nrmac);
    }
    free(uci_234->csi_part1.csi_part1_payload);
  }
  if ((uci_234->pduBitmap >> 3) & 0x01) {
    //@TODO:Handle CSI Report 2
    // nothing to free (yet)
  }
  NR_SCHED_UNLOCK(&nrmac->sched_lock);
}

static void set_pucch_allocation(const NR_UE_UL_BWP_t *ul_bwp, const int r_pucch, const int bwp_size, NR_sched_pucch_t *pucch)
{
  if(r_pucch<0){
    const NR_PUCCH_Resource_t *resource = ul_bwp->pucch_Config->resourceToAddModList->list.array[0];
    DevAssert(resource->format.present == NR_PUCCH_Resource__format_PR_format0);
    pucch->second_hop_prb = resource->secondHopPRB!= NULL ?  *resource->secondHopPRB : 0;
    pucch->nr_of_symb = resource->format.choice.format0->nrofSymbols;
    pucch->start_symb = resource->format.choice.format0->startingSymbolIndex;
    pucch->prb_start = resource->startingPRB;
  }
  else{
    int rsetindex = *ul_bwp->pucch_ConfigCommon->pucch_ResourceCommon;
    set_r_pucch_parms(rsetindex,
                      r_pucch,
                      bwp_size,
                      &pucch->prb_start,
                      &pucch->second_hop_prb,
                      &pucch->nr_of_symb,
                      &pucch->start_symb);
  }
}

static bool test_pucch0_vrb_occupation(const NR_sched_pucch_t *pucch, uint16_t *vrb_map_UL, const int bwp_start, const int bwp_size)
{
  // We assume initial cyclic shift is always 0 so different pucch resources can't overlap

  // verifying occupation of PRBs for ACK/NACK on dedicated pucch
  for (int l=0; l<pucch->nr_of_symb; l++) {
    uint16_t symb = SL_to_bitmap(pucch->start_symb+l, 1);
    int prb;
    if (l==1 && pucch->second_hop_prb != 0)
      prb = pucch->second_hop_prb;
    else
      prb = pucch->prb_start;
    if ((vrb_map_UL[bwp_start+prb] & symb) != 0) {
      return false;
      break;
    }
  }
  return true;
}

static void set_pucch0_vrb_occupation(const NR_sched_pucch_t *pucch, uint16_t *vrb_map_UL, const int bwp_start)
{
  for (int l=0; l<pucch->nr_of_symb; l++) {
    uint16_t symb = SL_to_bitmap(pucch->start_symb+l, 1);
    int prb;
    if (l==1 && pucch->second_hop_prb != 0)
      prb = pucch->second_hop_prb;
    else
      prb = pucch->prb_start;
    vrb_map_UL[bwp_start+prb] |= symb;
  }
}

bool check_bits_vs_coderate_limit(NR_PUCCH_Config_t *pucch_Config, int O_uci, int pucch_resource)
{
  int resource_id = get_pucch_resourceid(pucch_Config, O_uci, pucch_resource);
  AssertFatal(pucch_Config->resourceToAddModList != NULL, "PUCCH resourceToAddModList is null\n");

  int n_list = pucch_Config->resourceToAddModList->list.count;
  AssertFatal(n_list > 0, "PUCCH resourceToAddModList is empty\n");

  // going through the list of PUCCH resources to find the one indexed by resource_id
  for (int i = 0; i < n_list; i++) {
    NR_PUCCH_Resource_t *pucchres = pucch_Config->resourceToAddModList->list.array[i];
    if (pucchres->pucch_ResourceId == resource_id) {
      NR_PUCCH_MaxCodeRate_t *maxCodeRate = NULL;
      int nb_symbols = 0;
      int prbs = 0;
      int n_re_ctrl = 0;
      int Qm = 0;
      switch (pucchres->format.present) {
        case NR_PUCCH_Resource__format_PR_format2:
          prbs = pucchres->format.choice.format2->nrofPRBs;
          maxCodeRate = pucch_Config->format2->choice.setup->maxCodeRate;
          nb_symbols = pucchres->format.choice.format2->nrofSymbols;
          n_re_ctrl = 8;
          Qm = 2;
          break;
        case NR_PUCCH_Resource__format_PR_format3:
          prbs = pucchres->format.choice.format3->nrofPRBs;
          maxCodeRate = pucch_Config->format3->choice.setup->maxCodeRate;
          int f3_dmrs_symbols = get_f3_dmrs_symbols(pucchres, pucch_Config);
          nb_symbols = pucchres->format.choice.format3->nrofSymbols - f3_dmrs_symbols;
          n_re_ctrl = 12;
          Qm = pucch_Config->format3 ? (pucch_Config->format3->choice.setup->pi2BPSK ? 1 : 2) : 2;
          break;
        default:
          AssertFatal(false, "PUCCH format %d not handled\n", pucchres->format.present);
      }
      int O_crc = compute_pucch_crc_size(O_uci);
      int O_tot = O_uci + O_crc;
      float r = get_max_code_rate(maxCodeRate);
      return (O_tot <= (prbs * n_re_ctrl * nb_symbols * Qm * r));
    }
  }
  AssertFatal(false, "No PUCCH resource found\n");
}

// this function returns an index to NR_sched_pucch structure
// if the function returns -1 it was not possible to schedule acknack
int nr_acknack_scheduling(gNB_MAC_INST *mac,
                          NR_UE_info_t *UE,
                          frame_t frame,
                          slot_t slot,
                          int ue_beam,
                          int r_pucch,
                          int is_common)
{
  /* we assume that this function is mutex-protected from outside. Since it is
   * called often, don't try to lock every time */

  const int CC_id = 0;
  const NR_ServingCellConfigCommon_t *scc = mac->common_channels[CC_id].ServingCellConfigCommon;
  const int NTN_gNB_Koffset = get_NTN_Koffset(scc);

  const int minfbtime = mac->radio_config.minRXTXTIME + NTN_gNB_Koffset;
  const NR_UE_UL_BWP_t *ul_bwp = &UE->current_UL_BWP;
  const int n_slots_frame = mac->frame_structure.numb_slots_frame;
  const frame_structure_t *fs = &mac->frame_structure;

  NR_UE_sched_ctrl_t *sched_ctrl = &UE->UE_sched_ctrl;
  NR_PUCCH_Config_t *pucch_Config = ul_bwp->pucch_Config;

  const int bwp_start = ul_bwp->BWPStart;
  const int bwp_size = ul_bwp->BWPSize;

  nr_dci_format_t dci_format = NR_DL_DCI_FORMAT_1_0;
  if(is_common == 0)
   dci_format = UE->current_DL_BWP.dci_format;

  uint8_t pdsch_to_harq_feedback[8];
  int fb_size = get_pdsch_to_harq_feedback(pucch_Config, dci_format, pdsch_to_harq_feedback);

  for (int f = 0; f < fb_size; f++) {
    // can't schedule ACKNACK before minimum feedback time
    if((pdsch_to_harq_feedback[f] + NTN_gNB_Koffset) < minfbtime)
      continue;
    const int pucch_slot = (slot + pdsch_to_harq_feedback[f] + NTN_gNB_Koffset) % n_slots_frame;
    // check if the slot is UL
    if (fs->frame_type == TDD) {
      int mod_slot = pucch_slot % fs->numb_slots_period;
      if (!is_ul_slot(mod_slot, fs))
        continue;
    }
    const int pucch_frame = (frame + ((slot + pdsch_to_harq_feedback[f] + NTN_gNB_Koffset) / n_slots_frame)) % MAX_FRAME_NUMBER;
    // we store PUCCH resources according to slot, TDD configuration and size of the vector containing PUCCH structures
    const int pucch_index = get_pucch_index(pucch_frame, pucch_slot, &mac->frame_structure, sched_ctrl->sched_pucch_size);
    NR_sched_pucch_t *curr_pucch = &sched_ctrl->sched_pucch[pucch_index];
    if (curr_pucch->active &&
        curr_pucch->frame == pucch_frame &&
        curr_pucch->ul_slot == pucch_slot) { // if there is already a PUCCH in given frame and slot
      LOG_D(NR_MAC, "pucch_acknack DL %4d.%2d, UL_ACK %4d.%2d Bits already in current PUCCH: DAI_C %d CSI %d\n",
            frame, slot, pucch_frame, pucch_slot, curr_pucch->dai_c, curr_pucch->csi_bits);
      // we can't schedule if short pucch is already full
      if (curr_pucch->csi_bits == 0 &&
          curr_pucch->dai_c == 2)
        continue;
      // if there is CSI but simultaneous HARQ+CSI is disable we can't schedule
      if (curr_pucch->csi_bits > 0 && !curr_pucch->simultaneous_harqcsi)
        continue;
      // check if the number of bits to be scheduled can fit in current PUCCH
      // according to PUCCH code rate (if not we search for another allocation)
      // the number of bits in the check need to include possible SR (1 bit)
      // and the ack/nack bit to be scheduled (1 bit)
      // so the number of bits already scheduled in current pucch + 2
      if (curr_pucch->csi_bits > 0
          && !check_bits_vs_coderate_limit(pucch_Config,
                                           curr_pucch->csi_bits + curr_pucch->dai_c + 2,
                                           curr_pucch->resource_indicator))
        continue;
      // TODO temporarily limit ack/nak to 3 bits because of performances of polar for PUCCH (required for > 11 bits)
      if (curr_pucch->csi_bits > 0 && curr_pucch->dai_c >= 3)
        continue;

      // otherwise we can schedule in this active PUCCH
      // no need to check VRB occupation because already done when PUCCH has been activated
      curr_pucch->timing_indicator = f;
      curr_pucch->dai_c++;
      LOG_D(NR_MAC, "DL %4d.%2d, UL_ACK %4d.%2d Scheduling ACK/NACK in PUCCH %d with timing indicator %d DAI %d CSI %d\n",
            frame,slot,curr_pucch->frame,curr_pucch->ul_slot,pucch_index,f,curr_pucch->dai_c,curr_pucch->csi_bits);
      return pucch_index; // index of current PUCCH structure
    }
    else if (curr_pucch->active) {
      LOG_E(NR_MAC,
            "current PUCCH inactive: curr_pucch frame.slot %d.%d not matching with computed frame.slot %d.%d\n",
            curr_pucch->frame,
            curr_pucch->ul_slot,
            pucch_frame,
            pucch_slot);
      memset(curr_pucch, 0, sizeof(*curr_pucch));
    }
    else { // unoccupied occasion
      // checking if in ul_slot the resources potentially to be assigned to this PUCCH are available
      set_pucch_allocation(ul_bwp, r_pucch, bwp_size, curr_pucch);
      NR_beam_alloc_t beam = beam_allocation_procedure(&mac->beam_info, pucch_frame, pucch_slot, ue_beam, n_slots_frame);
      if (beam.idx < 0) {
        LOG_D(NR_MAC,
              "DL %4d.%2d, UL_ACK %4d.%2d beam resources for this occasion are already occupied, move to the following occasion\n",
              frame,
              slot,
              pucch_frame,
              pucch_slot);
        continue;
      }
      const int index = ul_buffer_index(pucch_frame, pucch_slot, n_slots_frame, mac->vrb_map_UL_size);
      uint16_t *vrb_map_UL = &mac->common_channels[CC_id].vrb_map_UL[beam.idx][index * MAX_BWP_SIZE];
      bool ret = test_pucch0_vrb_occupation(curr_pucch, vrb_map_UL, bwp_start, bwp_size);
      if(!ret) {
        LOG_D(NR_MAC,
              "DL %4d.%2d, UL_ACK %4d.%2d PRB resources for this occasion are already occupied, move to the following occasion\n",
              frame,
              slot,
              pucch_frame,
              pucch_slot);
        reset_beam_status(&mac->beam_info, pucch_frame, pucch_slot, ue_beam, n_slots_frame, beam.new_beam);
        continue;
      }
      // allocating a new PUCCH structure for this occasion
      curr_pucch->active = true;
      curr_pucch->frame = pucch_frame;
      curr_pucch->ul_slot = pucch_slot;
      curr_pucch->timing_indicator = f; // index in the list of timing indicators
      curr_pucch->dai_c++;
      curr_pucch->resource_indicator = 0; // each UE has dedicated PUCCH resources
      curr_pucch->r_pucch=r_pucch;

      LOG_D(NR_MAC, "DL %4d.%2d, UL_ACK %4d.%2d Scheduling ACK/NACK in PUCCH %d with timing indicator %d DAI %d\n",
            frame, slot, curr_pucch->frame, curr_pucch->ul_slot, pucch_index, f, curr_pucch->dai_c);

      // blocking resources for current PUCCH in VRB map
      set_pucch0_vrb_occupation(curr_pucch, vrb_map_UL, bwp_start);

      return pucch_index; // index of current PUCCH structure
    }
  }
  LOG_D(NR_MAC, "DL %4d.%2d, Couldn't find scheduling occasion for this HARQ process\n", frame, slot);
  return -1;
}


void nr_sr_reporting(gNB_MAC_INST *nrmac, frame_t SFN, slot_t slot)
{
  /* already mutex protected: held in gNB_dlsch_ulsch_scheduler() */
  NR_SCHED_ENSURE_LOCKED(&nrmac->sched_lock);

  if (!is_ul_slot(slot, &nrmac->frame_structure))
    return;
  const int CC_id = 0;
  UE_iterator(nrmac->UE_info.connected_ue_list, UE) {
    NR_UE_sched_ctrl_t *sched_ctrl = &UE->UE_sched_ctrl;
    NR_UE_UL_BWP_t *ul_bwp = &UE->current_UL_BWP;
    const int n_slots_frame = nrmac->frame_structure.numb_slots_frame;
    if (sched_ctrl->ul_failure || nr_timer_is_active(&sched_ctrl->transm_interrupt))
      continue;
    NR_PUCCH_Config_t *pucch_Config = ul_bwp->pucch_Config;

    if (!pucch_Config || !pucch_Config->schedulingRequestResourceToAddModList)
      continue;

    AssertFatal(pucch_Config->schedulingRequestResourceToAddModList->list.count>0,"NO SR configuration available");

    for (int SR_resource_id = 0; SR_resource_id < pucch_Config->schedulingRequestResourceToAddModList->list.count;SR_resource_id++) {
      NR_SchedulingRequestResourceConfig_t *SchedulingRequestResourceConfig = pucch_Config->schedulingRequestResourceToAddModList->list.array[SR_resource_id];

      int SR_period; int SR_offset;

      find_period_offset_SR(SchedulingRequestResourceConfig, &SR_period, &SR_offset);
      // convert to int to avoid underflow of uint
      int sfn_sf = SFN * n_slots_frame + slot;
      LOG_D(NR_MAC,"SR_resource_id %d: SR_period %d, SR_offset %d\n", SR_resource_id, SR_period, SR_offset);
      if ((sfn_sf - SR_offset) % SR_period != 0)
        continue;
      LOG_D(NR_MAC, "%4d.%2d Scheduling Request UE %04x identified\n", SFN, slot, UE->rnti);
      NR_PUCCH_ResourceId_t *PucchResourceId = SchedulingRequestResourceConfig->resource;

      int idx = -1;
      NR_PUCCH_ResourceSet_t *pucchresset = pucch_Config->resourceSetToAddModList->list.array[0]; // set with formats 0,1
      int n_list = pucchresset->resourceList.list.count;
       for (int i=0; i<n_list; i++) {
        if (*pucchresset->resourceList.list.array[i] == *PucchResourceId )
          idx = i;
      }
      AssertFatal(idx > -1, "SR resource not found among PUCCH resources");

      const int pucch_index = get_pucch_index(SFN, slot, &nrmac->frame_structure, sched_ctrl->sched_pucch_size);
      NR_sched_pucch_t *curr_pucch = &sched_ctrl->sched_pucch[pucch_index];

      if (curr_pucch->active && curr_pucch->frame == SFN && curr_pucch->ul_slot == slot && curr_pucch->resource_indicator == idx)
        curr_pucch->sr_flag = true;
      else if (curr_pucch->active) {
        LOG_E(NR_MAC,
              "current PUCCH inactive: curr_pucch frame.slot %d.%d not matching with computed frame.slot %d.%d\n",
              curr_pucch->frame,
              curr_pucch->ul_slot,
              SFN,
              slot);
        memset(curr_pucch, 0, sizeof(*curr_pucch));
        continue;
      }
      else {
        NR_beam_alloc_t beam = beam_allocation_procedure(&nrmac->beam_info, SFN, slot, UE->UE_beam_index, n_slots_frame);
        AssertFatal(beam.idx >= 0, "Cannot allocate SR in any available beam\n");
        const int index = ul_buffer_index(SFN, slot, n_slots_frame, nrmac->vrb_map_UL_size);
        uint16_t *vrb_map_UL = &nrmac->common_channels[CC_id].vrb_map_UL[beam.idx][index * MAX_BWP_SIZE];
        const int bwp_start = ul_bwp->BWPStart;
        const int bwp_size = ul_bwp->BWPSize;
        set_pucch_allocation(ul_bwp, -1, bwp_size, curr_pucch);
        bool ret = test_pucch0_vrb_occupation(curr_pucch,
                                              vrb_map_UL,
                                              bwp_start,
                                              bwp_size);
        if (!ret) {
          LOG_E(NR_MAC,"Cannot schedule SR. PRBs not available\n");
          continue;
        }
        curr_pucch->frame = SFN;
        curr_pucch->ul_slot = slot;
        curr_pucch->sr_flag = true;
        curr_pucch->resource_indicator = idx;
        curr_pucch->r_pucch = -1;
        curr_pucch->active = true;
        set_pucch0_vrb_occupation(curr_pucch, vrb_map_UL, bwp_start);
      }
    }
  }
}

