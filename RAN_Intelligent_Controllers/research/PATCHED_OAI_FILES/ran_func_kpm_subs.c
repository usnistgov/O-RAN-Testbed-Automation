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

#include "ran_func_kpm_subs.h"

#include <search.h>
#include <math.h> // For log10 in fill_RSRQ

/* measurements that need to store values from previous reporting period have a limitation
   when it comes to multiple subscriptions to the same UEs; ric_req_id is unique per subscription */
typedef struct uldlcounter {
  uint32_t dl;
  uint32_t ul;
} uldlcounter_t;

static uldlcounter_t last_pdcp_sdu_total_bytes[MAX_MOBILES_PER_GNB] = {0};

static nr_pdcp_statistics_t get_pdcp_stats_per_drb(const uint32_t rrc_ue_id, const int rb_id)
{
  nr_pdcp_statistics_t pdcp = {0};
  const int srb_flag = 0;

  // Get PDCP stats for specific DRB
  const bool rc = nr_pdcp_get_statistics(rrc_ue_id, srb_flag, rb_id, &pdcp);
  assert(rc == true && "Cannot get PDCP stats\n");

  return pdcp;
}

/* 3GPP TS 28.522 - section 5.1.2.1.1.1
  note: this measurement is calculated as per spec */
static meas_record_lst_t fill_DRB_PdcpSduVolumeDL(__attribute__((unused))uint32_t gran_period_ms, cudu_ue_info_pair_t ue_info, const size_t ue_idx)
{
  meas_record_lst_t meas_record = {0};

  // Get PDCP stats per DRB
  const int rb_id = 1;  // at the moment, only 1 DRB is supported
  nr_pdcp_statistics_t pdcp = get_pdcp_stats_per_drb(ue_info.rrc_ue_id, rb_id);

  meas_record.value = INTEGER_MEAS_VALUE;

  // Get DL data volume delivered to PDCP layer
  meas_record.int_val = (pdcp.rxsdu_bytes - last_pdcp_sdu_total_bytes[ue_idx].dl)*8/1000;   // [kb]
  last_pdcp_sdu_total_bytes[ue_idx].dl = pdcp.rxsdu_bytes;

  return meas_record;
}

/* 3GPP TS 28.522 - section 5.1.2.1.2.1
  note: this measurement is calculated as per spec */
static meas_record_lst_t fill_DRB_PdcpSduVolumeUL(__attribute__((unused))uint32_t gran_period_ms, cudu_ue_info_pair_t ue_info, const size_t ue_idx)
{
  meas_record_lst_t meas_record = {0};

  // Get PDCP stats per DRB
  const int rb_id = 1;  // at the moment, only 1 DRB is supported
  nr_pdcp_statistics_t pdcp = get_pdcp_stats_per_drb(ue_info.rrc_ue_id, rb_id);

  meas_record.value = INTEGER_MEAS_VALUE;

  // Get UL data volume delivered from PDCP layer
  meas_record.int_val = (pdcp.txsdu_bytes - last_pdcp_sdu_total_bytes[ue_idx].ul)*8/1000;   // [kb]
  last_pdcp_sdu_total_bytes[ue_idx].ul = pdcp.txsdu_bytes;

  return meas_record;
}

// Added metric for research purposes only
static meas_record_lst_t fill_RSRP_Mean(__attribute__((unused))uint32_t gran_period_ms, cudu_ue_info_pair_t ue_info, __attribute__((unused))const size_t ue_idx)
{
  meas_record_lst_t meas_record = {0};

  meas_record.value = REAL_MEAS_VALUE;

  // Calculate the average value of RSRP
  if (ue_info.ue->mac_stats.e2_num_rsrp_meas > 0) {
    meas_record.real_val = (double)ue_info.ue->mac_stats.e2_cumul_rsrp / (double)ue_info.ue->mac_stats.e2_num_rsrp_meas; // [dBm]
  } else {
    meas_record.real_val = NAN;
  }
  
  return meas_record;
}

// Added metric for research purposes only
static meas_record_lst_t fill_RSRP_Minimum(__attribute__((unused))uint32_t gran_period_ms, cudu_ue_info_pair_t ue_info, __attribute__((unused))const size_t ue_idx)
{
  meas_record_lst_t meas_record = {0};

  meas_record.value = REAL_MEAS_VALUE;

  if (ue_info.ue->mac_stats.e2_rsrp_meas_sorted_capacity == 0) {
    meas_record.real_val = NAN;
    return meas_record;
  }

  // Find the minimum
  for (int i = 0; i < ue_info.ue->mac_stats.e2_rsrp_meas_sorted_capacity; i++) {
    if (i == 0 || ue_info.ue->mac_stats.e2_rsrp_meas_sorted[i] < meas_record.real_val) {
      meas_record.real_val = (double)ue_info.ue->mac_stats.e2_rsrp_meas_sorted[i]; // [dBm]
    }
  }
  
  return meas_record;
}

// Added metric for research purposes only
static meas_record_lst_t fill_RSRP_Quartile1(__attribute__((unused))uint32_t gran_period_ms, cudu_ue_info_pair_t ue_info, __attribute__((unused))const size_t ue_idx)
{
  meas_record_lst_t meas_record = {0};

  meas_record.value = REAL_MEAS_VALUE;

  if (ue_info.ue->mac_stats.e2_rsrp_meas_sorted_capacity == 0) {
    meas_record.real_val = NAN;
    return meas_record;
  }

  // Calculate the first quartile (Q1) of RSRP
  if (ue_info.ue->mac_stats.e2_rsrp_meas_sorted_capacity > 0) {
    // Calculate Q1
    size_t q1_index = ue_info.ue->mac_stats.e2_rsrp_meas_sorted_capacity / 4;
    if (ue_info.ue->mac_stats.e2_rsrp_meas_sorted_capacity % 4 == 0) {
      meas_record.real_val = (double)(ue_info.ue->mac_stats.e2_rsrp_meas_sorted[q1_index - 1] +
                                      ue_info.ue->mac_stats.e2_rsrp_meas_sorted[q1_index]) / 2.0; // [dBm]
    } else {
      meas_record.real_val = (double)ue_info.ue->mac_stats.e2_rsrp_meas_sorted[q1_index]; // [dBm]
    }
  } else {
    meas_record.real_val = NAN;
  }

  return meas_record;
}

// Added metric for research purposes only
static meas_record_lst_t fill_RSRP_Median(__attribute__((unused))uint32_t gran_period_ms, cudu_ue_info_pair_t ue_info, __attribute__((unused))const size_t ue_idx)
{
  meas_record_lst_t meas_record = {0};

  meas_record.value = REAL_MEAS_VALUE;

  if (ue_info.ue->mac_stats.e2_rsrp_meas_sorted_capacity == 0) {
    meas_record.real_val = NAN;
    return meas_record;
  }

  // Calculate the median value of RSRP
  if (ue_info.ue->mac_stats.e2_rsrp_meas_sorted_capacity > 0) {
    // Calculate the median
    if (ue_info.ue->mac_stats.e2_rsrp_meas_sorted_capacity % 2 == 0) {
      meas_record.real_val = (double)(ue_info.ue->mac_stats.e2_rsrp_meas_sorted[ue_info.ue->mac_stats.e2_rsrp_meas_sorted_capacity / 2 - 1] +
                                      ue_info.ue->mac_stats.e2_rsrp_meas_sorted[ue_info.ue->mac_stats.e2_rsrp_meas_sorted_capacity / 2]) / 2.0; // [dBm]
    } else {
      meas_record.real_val = (double)ue_info.ue->mac_stats.e2_rsrp_meas_sorted[ue_info.ue->mac_stats.e2_rsrp_meas_sorted_capacity / 2]; // [dBm]
    }
  } else {
    meas_record.real_val = NAN;
  }
  
  return meas_record;
}

// Added metric for research purposes only
static meas_record_lst_t fill_RSRP_Quartile3(__attribute__((unused))uint32_t gran_period_ms, cudu_ue_info_pair_t ue_info, __attribute__((unused))const size_t ue_idx)
{
  meas_record_lst_t meas_record = {0};

  meas_record.value = REAL_MEAS_VALUE;

  if (ue_info.ue->mac_stats.e2_rsrp_meas_sorted_capacity == 0) {
    meas_record.real_val = NAN;
    return meas_record;
  }

  // Calculate the third quartile (Q3) of RSRP
  if (ue_info.ue->mac_stats.e2_rsrp_meas_sorted_capacity > 0) {
    // Calculate Q3
    size_t q3_index = (3 * ue_info.ue->mac_stats.e2_rsrp_meas_sorted_capacity) / 4;
    if (ue_info.ue->mac_stats.e2_rsrp_meas_sorted_capacity % 4 == 0) {
      meas_record.real_val = (double)(ue_info.ue->mac_stats.e2_rsrp_meas_sorted[q3_index - 1] +
                                      ue_info.ue->mac_stats.e2_rsrp_meas_sorted[q3_index]) / 2.0; // [dBm]
    } else {
      meas_record.real_val = (double)ue_info.ue->mac_stats.e2_rsrp_meas_sorted[q3_index]; // [dBm]
    }
  } else {
    meas_record.real_val = NAN;
  }

  return meas_record;
}

// Added metric for research purposes only
static meas_record_lst_t fill_RSRP_Maximum(__attribute__((unused))uint32_t gran_period_ms, cudu_ue_info_pair_t ue_info, __attribute__((unused))const size_t ue_idx)
{
  meas_record_lst_t meas_record = {0};

  meas_record.value = REAL_MEAS_VALUE;

  if (ue_info.ue->mac_stats.e2_rsrp_meas_sorted_capacity == 0) {
    meas_record.real_val = NAN;
    return meas_record;
  }

  // Find the maximum
  for (int i = 0; i < ue_info.ue->mac_stats.e2_rsrp_meas_sorted_capacity; i++) {
    if (i == 0 || ue_info.ue->mac_stats.e2_rsrp_meas_sorted[i] > meas_record.real_val) {
      meas_record.real_val = (double)ue_info.ue->mac_stats.e2_rsrp_meas_sorted[i]; // [dBm]
    }
  }
  
  return meas_record;
}

// Comparison function for integers used in qsort
static int compare_int(const void *a, const void *b) {
  return (*(int *)a - *(int *)b);
}

// Added metric for research purposes only
// This function will also update the previous RSRP values
static meas_record_lst_t fill_RSRP_Count(__attribute__((unused))uint32_t gran_period_ms, cudu_ue_info_pair_t ue_info, __attribute__((unused))const size_t ue_idx)
{
  meas_record_lst_t meas_record = {0};

  meas_record.value = INTEGER_MEAS_VALUE;

  // Get the value of the number of RSRP measurements
  meas_record.int_val = ue_info.ue->mac_stats.e2_num_rsrp_meas;

  return meas_record;
}

// Added metric for research purposes only
static meas_record_lst_t fill_N_PRB(__attribute__((unused))uint32_t gran_period_ms, cudu_ue_info_pair_t ue_info, __attribute__((unused))const size_t ue_idx)
{
  meas_record_lst_t meas_record = {0};

  meas_record.value = INTEGER_MEAS_VALUE;

  // Get the value of NPRB
  meas_record.int_val = ue_info.ue->mac_stats.NPRB;

  return meas_record;
}

// Added metric for research purposes only
static meas_record_lst_t fill_RSSI(__attribute__((unused))uint32_t gran_period_ms, cudu_ue_info_pair_t ue_info, __attribute__((unused))const size_t ue_idx)
{
  meas_record_lst_t meas_record = {0};

  meas_record.value = REAL_MEAS_VALUE;

  // Retrieve the cumulative RSRP in dBm averaged over the number of measurements
  double RSRP = ue_info.ue->mac_stats.e2_num_rsrp_meas > 0 ? (double)ue_info.ue->mac_stats.e2_cumul_rsrp / ue_info.ue->mac_stats.e2_num_rsrp_meas : NAN;

  if (isnan(RSRP)) {
    meas_record.real_val = NAN;
    return meas_record;
  }

  // Retrieve the number of Resource Blocks over which RSSI is measured
  double N = ue_info.ue->mac_stats.NPRB;


  // Based on https://www.techplayon.com/rssi : RSRP (dBM) = RSSI - 10*log(12*N)
  double RSSI = RSRP + 10 * log10(12 * N);

  meas_record.real_val = RSSI;

  return meas_record;
}

// Added metric for research purposes only
static meas_record_lst_t fill_RSRQ(__attribute__((unused))uint32_t gran_period_ms, cudu_ue_info_pair_t ue_info, __attribute__((unused))const size_t ue_idx)
{
  meas_record_lst_t meas_record = {0};

  meas_record.value = REAL_MEAS_VALUE;

  // Retrieve the cumulative RSRP in dBm averaged over the number of measurements
  double RSRP = ue_info.ue->mac_stats.e2_num_rsrp_meas > 0 ? (double)ue_info.ue->mac_stats.e2_cumul_rsrp / ue_info.ue->mac_stats.e2_num_rsrp_meas : 0.0;

  // Retrieve the number of Resource Blocks over which RSSI is measured
  double N = ue_info.ue->mac_stats.NPRB;

  // Based on https://www.techplayon.com/rssi : RSRP (dBM) = RSSI - 10*log(12*N)
  double RSSI = RSRP + 10 * log10(12 * N);

  // RSRQ=(N*RSRP)/RSSI
  double RSRQ = (N * RSRP) / RSSI;

  meas_record.real_val = RSRQ;

  // The last metric utilizing RSRP measurements needs to reset the RSRP measurements for the next reporting period
  bool reset_rsrp = true;
  if (reset_rsrp) {
    // Reset the cumulative RSRP and the number of measurements
    ue_info.ue->mac_stats.e2_num_rsrp_meas = 0;
    ue_info.ue->mac_stats.e2_cumul_rsrp = 0;
    
    // Sort e2_rsrp_meas in place and then copy to e2_rsrp_meas_sorted
    qsort(ue_info.ue->mac_stats.e2_rsrp_meas, ue_info.ue->mac_stats.e2_rsrp_meas_capacity, sizeof(int), compare_int);
    ue_info.ue->mac_stats.e2_rsrp_meas_sorted_capacity = ue_info.ue->mac_stats.e2_rsrp_meas_capacity;
    memcpy(ue_info.ue->mac_stats.e2_rsrp_meas_sorted, ue_info.ue->mac_stats.e2_rsrp_meas, sizeof(ue_info.ue->mac_stats.e2_rsrp_meas));

    // Clear the array of individual RSRP measurements
    memset(ue_info.ue->mac_stats.e2_rsrp_meas, 0, sizeof(ue_info.ue->mac_stats.e2_rsrp_meas));
    ue_info.ue->mac_stats.e2_rsrp_meas_capacity = 0;
  }

  return meas_record;
}

// Added metric for research purposes only
static meas_record_lst_t fill_PUSCH_SNR(__attribute__((unused))uint32_t gran_period_ms, cudu_ue_info_pair_t ue_info, __attribute__((unused))const size_t ue_idx)
{
  meas_record_lst_t meas_record = {0};

  meas_record.value = REAL_MEAS_VALUE;

  // Calculate SNR from pusch_snrx10, which is SNR * 10; divide by 10 to get the actual SNR
  meas_record.real_val = ue_info.ue->UE_sched_ctrl.pusch_snrx10 / 10.0; // [dB]

  return meas_record;
}

// Added metric for research purposes only
static meas_record_lst_t fill_PUCCH_SNR(__attribute__((unused))uint32_t gran_period_ms, cudu_ue_info_pair_t ue_info, __attribute__((unused))const size_t ue_idx)
{
  meas_record_lst_t meas_record = {0};

  meas_record.value = REAL_MEAS_VALUE;

  // Calculate SNR from pusch_snrx10, which is SNR * 10; divide by 10 to get the actual SNR
  meas_record.real_val = ue_info.ue->UE_sched_ctrl.pucch_snrx10 / 10.0; // [dB]

  return meas_record;
}

// Added metric for research purposes only
static meas_record_lst_t fill_MCS_UL(__attribute__((unused))uint32_t gran_period_ms, cudu_ue_info_pair_t ue_info, __attribute__((unused))const size_t ue_idx)
{
  meas_record_lst_t meas_record = {0};

  meas_record.value = INTEGER_MEAS_VALUE;

  // Fetch the MCS value
  meas_record.int_val = ue_info.ue->UE_sched_ctrl.ul_bler_stats.mcs;

  return meas_record;
}

// Added metric for research purposes only
static meas_record_lst_t fill_MCS_DL(__attribute__((unused))uint32_t gran_period_ms, cudu_ue_info_pair_t ue_info, __attribute__((unused))const size_t ue_idx)
{
  meas_record_lst_t meas_record = {0};

  meas_record.value = INTEGER_MEAS_VALUE;

  // Fetch the MCS value
  meas_record.int_val = ue_info.ue->UE_sched_ctrl.dl_bler_stats.mcs;
  // Fetch the MCS table index
  return meas_record;
}
// Added metric for research purposes only
static meas_record_lst_t fill_BLER_UL(__attribute__((unused))uint32_t gran_period_ms, cudu_ue_info_pair_t ue_info, __attribute__((unused))const size_t ue_idx)
{
  meas_record_lst_t meas_record = {0};

  meas_record.value = REAL_MEAS_VALUE;

  // Calculate the Block Error Rate (BLER) for UL
  meas_record.real_val = (double)ue_info.ue->UE_sched_ctrl.ul_bler_stats.bler;

  return meas_record;
}

// Added metric for research purposes only
static meas_record_lst_t fill_BLER_DL(__attribute__((unused))uint32_t gran_period_ms, cudu_ue_info_pair_t ue_info, __attribute__((unused))const size_t ue_idx)
{
  meas_record_lst_t meas_record = {0};

  meas_record.value = REAL_MEAS_VALUE;

  // Calculate the Block Error Rate (BLER) for DL
  meas_record.real_val = (double)ue_info.ue->UE_sched_ctrl.dl_bler_stats.bler;

  return meas_record;
}

// Added metric for research purposes only
static meas_record_lst_t fill_DRB_MacSduRetransmissionRateDl(__attribute__((unused))uint32_t gran_period_ms, cudu_ue_info_pair_t ue_info, __attribute__((unused))const size_t ue_idx)
{
  meas_record_lst_t meas_record = {0};

  meas_record.value = REAL_MEAS_VALUE;

  // Calculate the RB retransmission rate (RBs retransmitted / total RBs allocated for initial transmissions)
  meas_record.real_val = (double)ue_info.ue->mac_stats.dl.total_rbs_retx / (double)ue_info.ue->mac_stats.dl.total_rbs;

  return meas_record;
}

// Added metric for research purposes only
static meas_record_lst_t fill_DRB_MacSduErrorRateDl(__attribute__((unused))uint32_t gran_period_ms, cudu_ue_info_pair_t ue_info, __attribute__((unused))const size_t ue_idx)
{
  meas_record_lst_t meas_record = {0};

  meas_record.value = REAL_MEAS_VALUE;

  // Calculate the SDU-level packet drop rate (SDUs failed due to HARQ failures / total SDUs transmitted)
  meas_record.real_val = (double)ue_info.ue->mac_stats.dl.sdu_errors / (double)ue_info.ue->mac_stats.dl.num_mac_sdu;
  return meas_record;
}

// Added metric for research purposes only
static meas_record_lst_t fill_DRB_MacSduRetransmissionRateUl(__attribute__((unused))uint32_t gran_period_ms, cudu_ue_info_pair_t ue_info, __attribute__((unused))const size_t ue_idx)
{
  meas_record_lst_t meas_record = {0};

  meas_record.value = REAL_MEAS_VALUE;

  // Calculate the RB retransmission rate (RBs retransmitted / total RBs allocated for initial transmissions)
  meas_record.real_val = (double)ue_info.ue->mac_stats.ul.total_rbs_retx / (double)ue_info.ue->mac_stats.ul.total_rbs;

  return meas_record;
}

// Added metric for research purposes only
static meas_record_lst_t fill_DRB_MacSduErrorRateUl(__attribute__((unused))uint32_t gran_period_ms, cudu_ue_info_pair_t ue_info, __attribute__((unused))const size_t ue_idx)
{
  meas_record_lst_t meas_record = {0};

  meas_record.value = REAL_MEAS_VALUE;

  // Calculate the SDU-level packet drop rate (SDUs failed due to HARQ failures / total SDUs transmitted)
  meas_record.real_val = (double)ue_info.ue->mac_stats.ul.sdu_errors / (double)ue_info.ue->mac_stats.ul.num_mac_sdu;
  return meas_record;
}

// Added metric for research purposes only
static meas_record_lst_t fill_CQI_SINGLE_CODEWORD(__attribute__((unused))uint32_t gran_period_ms, cudu_ue_info_pair_t ue_info, __attribute__((unused))const size_t ue_idx)
{
  meas_record_lst_t meas_record = {0};

  meas_record.value = INTEGER_MEAS_VALUE;

  // Fetch the CQI value
  meas_record.int_val = ue_info.ue->UE_sched_ctrl.CSI_report.cri_ri_li_pmi_cqi_report.wb_cqi_1tb;

  return meas_record;
}

// Added metric for research purposes only
static meas_record_lst_t fill_CQI_DUAL_CODEWORD(__attribute__((unused))uint32_t gran_period_ms, cudu_ue_info_pair_t ue_info, __attribute__((unused))const size_t ue_idx)
{
  meas_record_lst_t meas_record = {0};

  meas_record.value = INTEGER_MEAS_VALUE;

  // Fetch the CQI value
  meas_record.int_val = ue_info.ue->UE_sched_ctrl.CSI_report.cri_ri_li_pmi_cqi_report.wb_cqi_2tb;

  return meas_record;
}

#if defined (NGRAN_GNB_DU)
static uldlcounter_t last_rlc_pdu_total_bytes[MAX_MOBILES_PER_GNB] = {0};
static uldlcounter_t last_total_prbs[MAX_MOBILES_PER_GNB] = {0};

static nr_rlc_statistics_t get_rlc_stats_per_drb(const rnti_t rnti, const int rb_id)
{
  nr_rlc_statistics_t rlc = {0};
  const int srb_flag = 0;

  // Get RLC stats for specific DRB
  const bool rc = nr_rlc_get_statistics(rnti, srb_flag, rb_id, &rlc);
  assert(rc == true && "Cannot get RLC stats\n");

  // Activate average sojourn time at the RLC buffer for specific DRB
  nr_rlc_activate_avg_time_to_tx(rnti, rb_id+3, 1);
  
  return rlc;  
}

/* 3GPP TS 28.522 - section 5.1.3.3.3
  note: by default this measurement is calculated for previous 100ms (openair2/LAYER2/nr_rlc/nr_rlc_entity.c:118, 173, 213); please, update according to your needs */
static meas_record_lst_t fill_DRB_RlcSduDelayDl(__attribute__((unused))uint32_t gran_period_ms, cudu_ue_info_pair_t ue_info, __attribute__((unused))const size_t ue_idx)
{
  meas_record_lst_t meas_record = {0};
  
  // Get RLC stats per DRB
  const int rb_id = 1;  // at the moment, only 1 DRB is supported
  nr_rlc_statistics_t rlc = get_rlc_stats_per_drb(ue_info.ue->rnti, rb_id);

  meas_record.value = REAL_MEAS_VALUE;

  // Get the value of sojourn time at the RLC buffer
  meas_record.real_val = rlc.txsdu_avg_time_to_tx;  // [μs]

  return meas_record;
}

/* 3GPP TS 28.522 - section 5.1.1.3.1
  note: per spec, average UE throughput in DL (taken into consideration values from all UEs, and averaged)
        here calculated as: UE specific throughput in DL */
static meas_record_lst_t fill_DRB_UEThpDl(uint32_t gran_period_ms, cudu_ue_info_pair_t ue_info, const size_t ue_idx)
{
  meas_record_lst_t meas_record = {0};
  
  // Get RLC stats per DRB
  const int rb_id = 1;  // at the moment, only 1 DRB is supported
  nr_rlc_statistics_t rlc = get_rlc_stats_per_drb(ue_info.ue->rnti, rb_id);
  meas_record.value = REAL_MEAS_VALUE;

  // Calculate DL Thp
  meas_record.real_val = (double)(rlc.txpdu_bytes - last_rlc_pdu_total_bytes[ue_idx].dl)*8/gran_period_ms;  // [kbps]
  last_rlc_pdu_total_bytes[ue_idx].dl = rlc.txpdu_bytes;

  return meas_record;
}

/* 3GPP TS 28.522 - section 5.1.1.3.3
  note: per spec, average UE throughput in UL (taken into consideration values from all UEs, and averaged)
        here calculated as: UE specific throughput in UL */
static meas_record_lst_t fill_DRB_UEThpUl(uint32_t gran_period_ms, cudu_ue_info_pair_t ue_info, const size_t ue_idx)
{
  meas_record_lst_t meas_record = {0};
  
  // Get RLC stats per DRB
  const int rb_id = 1;  // at the moment, only 1 DRB is supported
  nr_rlc_statistics_t rlc = get_rlc_stats_per_drb(ue_info.ue->rnti, rb_id);

  meas_record.value = REAL_MEAS_VALUE;

  // Calculate UL Thp
  meas_record.real_val = (double)(rlc.rxpdu_bytes - last_rlc_pdu_total_bytes[ue_idx].ul)*8/gran_period_ms;  // [kbps]
  last_rlc_pdu_total_bytes[ue_idx].ul = rlc.rxpdu_bytes;
  
  return meas_record;
}

/* 3GPP TS 28.522 - section 5.1.1.2.1
  note: per spec, DL PRB usage [%] = (total used PRBs for DL traffic / total available PRBs for DL traffic) * 100   
        here calculated as: aggregated DL PRBs (t) - aggregated DL PRBs (t-gran_period) */
static meas_record_lst_t fill_RRU_PrbTotDl(__attribute__((unused))uint32_t gran_period_ms, cudu_ue_info_pair_t ue_info, const size_t ue_idx)
{
  meas_record_lst_t meas_record = {0};
  
  meas_record.value = INTEGER_MEAS_VALUE;

  // Get the number of DL PRBs
  meas_record.int_val = ue_info.ue->mac_stats.dl.total_rbs - last_total_prbs[ue_idx].dl;   // [PRBs]
  last_total_prbs[ue_idx].dl = ue_info.ue->mac_stats.dl.total_rbs;

  return meas_record;
}

/* 3GPP TS 28.522 - section 5.1.1.2.2
  note: per spec, UL PRB usage [%] = (total used PRBs for UL traffic / total available PRBs for UL traffic) * 100   
        here calculated as: aggregated UL PRBs (t) - aggregated UL PRBs (t-gran_period) */
static meas_record_lst_t fill_RRU_PrbTotUl(__attribute__((unused))uint32_t gran_period_ms, cudu_ue_info_pair_t ue_info, const size_t ue_idx)
{
  meas_record_lst_t meas_record = {0};

  meas_record.value = INTEGER_MEAS_VALUE;

  // Get the number of UL PRBs
  meas_record.int_val = ue_info.ue->mac_stats.ul.total_rbs - last_total_prbs[ue_idx].ul;   // [PRBs]
  last_total_prbs[ue_idx].ul = ue_info.ue->mac_stats.ul.total_rbs;

  return meas_record;
}
#endif

static kv_measure_t lst_measure[] = {
  {.key = "DRB.PdcpSduVolumeDL", .value = fill_DRB_PdcpSduVolumeDL }, 
  {.key = "DRB.PdcpSduVolumeUL", .value = fill_DRB_PdcpSduVolumeUL },
  {.key = "RSRP.Mean", .value = fill_RSRP_Mean },
  {.key = "RSRP.Minimum", .value = fill_RSRP_Minimum },
  {.key = "RSRP.Quartile1", .value = fill_RSRP_Quartile1 },
  {.key = "RSRP.Median", .value = fill_RSRP_Median },
  {.key = "RSRP.Quartile3", .value = fill_RSRP_Quartile3 },
  {.key = "RSRP.Maximum", .value = fill_RSRP_Maximum },
  {.key = "RSRP.Count", .value = fill_RSRP_Count },
  {.key = "N_PRB", .value = fill_N_PRB },
  {.key = "RSSI", .value = fill_RSSI },
  {.key = "RSRQ", .value = fill_RSRQ },
  {.key = "PUSCH_SNR", .value = fill_PUSCH_SNR },
  {.key = "PUCCH_SNR", .value = fill_PUCCH_SNR },
  {.key = "DRB.HarqMcsUl", .value = fill_MCS_UL },
  {.key = "DRB.HarqMcsDl", .value = fill_MCS_DL },
  {.key = "DRB.HarqBlockErrorRateUl", .value = fill_BLER_UL },
  {.key = "DRB.HarqBlockErrorRateDl", .value = fill_BLER_DL },
  {.key = "DRB.MacSduRetransmissionRateUl", .value = fill_DRB_MacSduRetransmissionRateUl },
  {.key = "DRB.MacSduRetransmissionRateDl", .value = fill_DRB_MacSduRetransmissionRateDl },
  {.key = "DRB.MacSduErrorRateUl", .value = fill_DRB_MacSduErrorRateUl },
  {.key = "DRB.MacSduErrorRateDl", .value = fill_DRB_MacSduErrorRateDl },
  {.key = "CQI_SINGLE_CODEWORD", .value = fill_CQI_SINGLE_CODEWORD },
  {.key = "CQI_DUAL_CODEWORD", .value = fill_CQI_DUAL_CODEWORD },
#if defined (NGRAN_GNB_DU)
  {.key = "DRB.RlcSduDelayDl", .value =  fill_DRB_RlcSduDelayDl }, 
  {.key = "DRB.UEThpDl", .value =  fill_DRB_UEThpDl }, 
  {.key = "DRB.UEThpUl", .value =  fill_DRB_UEThpUl }, 
  {.key = "RRU.PrbTotDl", .value =  fill_RRU_PrbTotDl }, 
  {.key = "RRU.PrbTotUl", .value =  fill_RRU_PrbTotUl }, 
#endif
}; 

void init_kpm_subs_data(void)
{
  const size_t ht_len = sizeof(lst_measure) / sizeof(lst_measure[0]);
  hcreate(ht_len);

  ENTRY kv_pair;

  for (size_t i = 0; i < ht_len; i++) {
    kv_pair.key = lst_measure[i].key;
    kv_pair.data = &lst_measure[i];
    hsearch(kv_pair, ENTER);
  }
}

meas_record_lst_t get_kpm_meas_value(char* kpm_meas_name, uint32_t gran_period_ms, cudu_ue_info_pair_t ue_info, const size_t ue_idx)
{
  assert(kpm_meas_name != NULL);

  ENTRY search_entry = {.key = kpm_meas_name};
  ENTRY *found_entry = hsearch(search_entry, FIND);
  assert(found_entry != NULL && "Unsupported KPM measurement name");

  kv_measure_t *kv_found = (kv_measure_t *)found_entry->data;
  meas_record_lst_t meas_record = kv_found->value(gran_period_ms, ue_info, ue_idx);

  return meas_record;
}
