/*
 * SPDX-License-Identifier: LicenseRef-CSSL-1.0
 */
// RIC-TaaP xApps
// Zero-Touch ES with cell utilization xApp

#include "../../../../src/xApp/e42_xapp_api.h"
#include "../../../../src/sm/rc_sm/ie/ir/ran_param_struct.h"
#include "../../../../src/sm/rc_sm/ie/ir/ran_param_list.h"
#include "../../../../src/util/time_now_us.h"
#include "../../../../src/util/alg_ds/ds/lock_guard/lock_guard.h"
#include "../../../../src/sm/rc_sm/rc_sm_id.h"
#include "../../../../src/sm/rc_sm/ie/rc_data_ie.h"
#include "../../../../src/util/e.h"

#include <unistd.h>

#define MIN_SINR -10

typedef struct {
    const e2_node_arr_xapp_t* nodes;
    struct SINRNeighboringValues* neighCells;
    int ueID;
    uint8_t frmCurntCell;
    uint8_t toTargetCell;
} callback_data_t;

typedef uint16_t (*Callback)(callback_data_t);

typedef enum {
    CONNECTED_MODE_MOBILITY = 3,
    ENERGY_STATE = 300
} rc_ctrl_service_style_id_e;
  
typedef enum {
    CELL_OFF = '0',
    CELL_ON = '1',  
    CELL_SLEEP = '2',
} cell_state_e;
  
typedef enum {
    QOS_FLOW_ID_1 = 1,
    QOS_FLOW_ID_10 = 10
} qos_flow_id_e;

typedef enum {
    DRB_ID_3 = 3
} drb_id_e;
  
typedef enum {
    PDU_SESSION_ID_5 = 5
} pdu_session_id_e;
  
static ue_id_e2sm_t ue_id;

static uint64_t const period_ms = 100;

static pthread_mutex_t mtx;

/*
each cell has connected UEs(with SINR value),
each Cell have neighbours of cells(with SINR value)
All of them in one indication message per Cell
*/

// ctrl after this
const int MAX_NUM_OF_RIC_INDICATIONS = 5;
struct SINRNeighboringValues 
{
  bool is_available;
  uint16_t neighCellID;
  double sinr;
  int counter;
};

struct SINRServingValues 
{
  bool is_available;
  uint16_t ueID;
  double sinr;
  struct SINRNeighboringValues* neighCells;  // array
  size_t numOfNeighCells;
  bool handover_in_progress;
};

// Per Cell
struct SINR_Map 
{
  uint16_t cellID;
  struct SINRServingValues* connectedUEs;  // array
  size_t numOfConnectedUEs;
  bool is_running;
  bool pending_shutdown;  // Track if cell is marked for shutdown
  time_t shutdown_start_time; // Track when shutdown process started
};

struct registeredCells {
  bool is_registered;
  struct SINR_Map* sinrMap;
};

#define MAX_REGISTERED_CELLS 10
#define MAX_REGISTERED_UES 20
#define MAX_REGISTERED_NEIGHBOURS 20

struct registeredCells cells_sinr_map[MAX_REGISTERED_CELLS] = {{false, NULL}};

/*

struct SINR_MapCells
{
  struct SINR_Map* sinrMapForCells;
  size_t numOfsinrMapForCells;
};

L3servingSINR3gpp_cell_5_UEID_00002, sinr= 2.0000 [db]
L3neighSINRListOf_UEID_00002, Neighbour=4
L3neighSINRListOf_UEID_00002, sinr= -12.0000 [db]
L3neighSINRListOf_UEID_00002, Neighbour=2
L3neighSINRListOf_UEID_00002, sinr= -13.0000 [db]
L3neighSINRListOf_UEID_00002, Neighbour=3
L3neighSINRListOf_UEID_00002, sinr= -16.0000 [db]

Based on SINR
struct targetCell{
UEid(IMSI), cellID
}

// int x -->> int* y = &x;  --> int** z = &y
// int* a = &z

*/

static
struct SINR_Map* add_SINR(const uint16_t cellID) 
{
  assert(cellID != 0);
  if (cells_sinr_map[cellID].sinrMap == NULL && !cells_sinr_map[cellID].is_registered) {
    cells_sinr_map[cellID].sinrMap = (struct SINR_Map*)calloc(1, sizeof(struct SINR_Map));
    cells_sinr_map[cellID].is_registered = true;
    cells_sinr_map[cellID].sinrMap->cellID = cellID;
    cells_sinr_map[cellID].sinrMap->connectedUEs = NULL;
    cells_sinr_map[cellID].sinrMap->numOfConnectedUEs = 0;
    cells_sinr_map[cellID].sinrMap->pending_shutdown = false;
    cells_sinr_map[cellID].sinrMap->shutdown_start_time = 0;
  }
  return cells_sinr_map[cellID].sinrMap;
}

// Serving msg
static
void add_UE(struct SINR_Map* cell, const uint16_t ueID, const double sinr) 
{
  assert(cell != NULL);
  if (cell->connectedUEs == NULL /*&& cell->numOfConnectedUEs == 0*/) {
    cell->connectedUEs = (struct SINRServingValues*)calloc(MAX_REGISTERED_UES, sizeof(struct SINRServingValues));

    // struct SINRServingValues* UE = &cell->connectedUEs[ueID];//cell->numOfConnectedUEs];
    cell->connectedUEs[ueID].ueID = ueID;
    cell->connectedUEs[ueID].sinr = sinr;
    cell->connectedUEs[ueID].neighCells = NULL;
    cell->connectedUEs[ueID].numOfNeighCells = 0;
    cell->connectedUEs[ueID].handover_in_progress = false;
  } else 
  {
    assert(cell->connectedUEs != NULL);
    assert(cell->numOfConnectedUEs != 0);
    assert(ueID <= MAX_REGISTERED_UES);

    // cell->connectedUEs = (struct SINRServingValues*) realloc(cell->connectedUEs, (cell->numOfConnectedUEs + 1) * sizeof(struct SINRServingValues));
    // struct SINRServingValues* UE = &cell->connectedUEs[cell->numOfConnectedUEs+1];
    // struct SINRServingValues* UE = &cell->connectedUEs[ueID];
    cell->connectedUEs[ueID].ueID = ueID;
    cell->connectedUEs[  ueID].sinr = sinr;
  }
  cell->connectedUEs[ueID].is_available = true;
  cell->numOfConnectedUEs += 1;
}

static
struct SINRServingValues* get_UE(const uint16_t cellID, const uint16_t ueID) 
{
  if (cells_sinr_map[cellID].is_registered) {
    assert(cells_sinr_map[cellID].sinrMap->connectedUEs[ueID].ueID == ueID);

    return &(cells_sinr_map[cellID].sinrMap->connectedUEs[ueID]);
    // printf("x->ueID=%d, ueID=%d\n", x->ueID , ueID);
    // return x;
    // for (size_t i = 0; i < cells_sinr_map[cellID].sinrMap->numOfConnectedUEs; i++)
    // {
    //   if(cells_sinr_map[cellID].sinrMap->connectedUEs[i].ueID == ueID) {
    //     return &cells_sinr_map[cellID].sinrMap->connectedUEs[i];
    //   }
    // }
  }
  return NULL;
}

/*
DoRecvLteMmWaveHandoverCompleted
*/

// m_rrc
// m_lastMmWaveCell[[a-z]+\] =
// m_lastMmWaveCell[m_[a-z]+\] =
// m_lastMmWaveCell[m
// DoRecvLteMmWaveHandoverCompleted
// UeManager::RecvRrcConnectionReconfigurationCompleted(MC_CONNECTION_RECONFIGURATION OR CONNECTION_RECONFIGURATION)

// LteEnbRrc::DoRecvRrcConnectionReconfigurationCompleted
// LteEnbRrc::DoRecvLteMmWaveHandoverCompleted --> IMP (m_lastMmWaveCell[imsi] = params.targetCellId;)

#define MAX_NUM_OF_RIC_INDICATIONS 5

static
void add_neighCell(struct SINRServingValues* UE, const uint16_t neighCellID, const double sinr) 
{
  assert(UE != NULL);

  // Initialize neighbor cells array if needed
  if (UE->neighCells == NULL) {
    UE->neighCells = (struct SINRNeighboringValues*)calloc(MAX_REGISTERED_NEIGHBOURS,
                                                           sizeof(struct SINRNeighboringValues));
    assert(UE->neighCells != NULL);
  }

  // Get reference to this neighbor cell
  struct SINRNeighboringValues* neighCell = &UE->neighCells[neighCellID];

  // Initialize new neighbor cell
  if (!neighCell->is_available) {
    neighCell->neighCellID = neighCellID;
    neighCell->sinr = sinr;
    neighCell->counter = 1;
    neighCell->is_available = true;
    UE->numOfNeighCells++;

    printf("New neighbor cell %d added for UE %d with initial SINR %.2f\n", neighCellID, UE->ueID, sinr);
  }
  // Update existing neighbor cell
  else {
    // Track measurements until we have MAX_NUM_OF_RIC_INDICATIONS samples
    if (neighCell->counter < MAX_NUM_OF_RIC_INDICATIONS) {
      // Update running sum
      neighCell->sinr = ((neighCell->sinr * neighCell->counter) + sinr) / (neighCell->counter + 1);
      neighCell->counter++;

      printf("Updated neighbor cell %d for UE %d: SINR %.2f (sample %d/%d)\n", neighCellID, UE->ueID,
             neighCell->sinr, neighCell->counter, MAX_NUM_OF_RIC_INDICATIONS);
    }
    // Reset after MAX_NUM_OF_RIC_INDICATIONS samples
    else 
    {
      neighCell->sinr = sinr;
      neighCell->counter = 1;

      printf("Reset neighbor cell %d for UE %d with new SINR %.2f\n", neighCellID, UE->ueID, sinr);
    }
  }
}

static
uint16_t getTargetCellID(callback_data_t data)
{
  assert(data.neighCells != NULL);

  double max_sinr = MIN_SINR;
  uint16_t targetCell = 0;

  printf("\n=== Target Cell Selection for UE %d ===\n", data.ueID);
  printf("Current Cell: %d\n", data.frmCurntCell);

  // Find cell with best SINR among neighbors
  for (int i = 0; i < MAX_REGISTERED_NEIGHBOURS; i++)
  {
    if (data.neighCells[i].is_available && 
        data.neighCells[i].counter >= MAX_NUM_OF_RIC_INDICATIONS) {
      
      // Skip cells marked for shutdown
      if (cells_sinr_map[i].sinrMap != NULL && 
          cells_sinr_map[i].sinrMap->pending_shutdown) {
        printf("Skipping Cell %d: marked for shutdown\n", i);
        continue;
      }

      printf("Evaluating Cell %d: SINR %.2f dB\n", i, data.neighCells[i].sinr);

      if (data.neighCells[i].sinr > MIN_SINR && 
          data.neighCells[i].sinr > max_sinr) {
        max_sinr = data.neighCells[i].sinr;
        targetCell = i;
        printf("Found better cell: %d (SINR: %.2f dB)\n", targetCell, max_sinr);
      }
    }
  }

  if (targetCell != 0) {
    printf("Selected Target Cell: %d (SINR: %.2f dB)\n", targetCell, max_sinr);
  } else 
  {
    printf("No suitable target cell found (SINR > %d dB required)\n", MIN_SINR);
  }

  return targetCell;
}

// TODO
void remove_UE() {}
void remove_neighCell() {}

// T Search(fp);
// GetIMSI, getSINR, findX, getTargetCell(sinrMap, targetCell)
// seach(findXX);

struct InfoObj 
{
  uint16_t cellID;
  uint16_t ueID;
};

// struct InfoObj parseStr()
static
struct InfoObj parseServingMsg(const char* msg) 
{
  struct InfoObj info;

  int ret = sscanf(msg, "L3servingSINR3gpp_cell_%hd_UEID_%hd", &info.cellID, &info.ueID);

  if (ret == 2)
    return info;

  info.cellID = -1;
  info.ueID = -1;
  return info;
}

static
struct InfoObj parseNeighMsg(const char* msg) 
{
  struct InfoObj info;

  int ret = sscanf(msg, "L3neighSINRListOf_UEID_%hd_of_Cell_%hd", &info.ueID, &info.cellID);

  if (ret == 2)
    return info;

  info.ueID = -1;
  info.cellID = -1;
  return info;
}

static
bool isMeasNameContains(const char* meas_name, const char* name) 
{
  return strncmp(meas_name, name, strlen(name)) == 0;
}

static
void log_kpm_measurements(kpm_ind_msg_format_1_t const* msg_frm_1)
{
  assert(msg_frm_1->meas_info_lst_len > 0 && "Cannot correctly print measurements");

  // assert(msg_frm_1->meas_info_lst_len == msg_frm_1->meas_data_lst_len && "meas_info_lst_len not equal
  // meas_data_lst_len");
  if (msg_frm_1->meas_info_lst_len != msg_frm_1->meas_data_lst_len) {
    printf("Error: meas_info_lst_len= (%ld) not equal meas_data_lst_len= (%ld)\n", msg_frm_1->meas_info_lst_len,
           msg_frm_1->meas_data_lst_len);
    return;
  }

  // UE Measurements per granularity period
  for (size_t i = 0; i < msg_frm_1->meas_info_lst_len; i++) 
  {
    meas_type_t const meas_type = msg_frm_1->meas_info_lst[i].meas_type;
    meas_data_lst_t const data_item = msg_frm_1->meas_data_lst[i];

    for (size_t j = 0; j < data_item.meas_record_len;) {
      meas_record_lst_t const record_item = data_item.meas_record_lst[j];

      if (meas_type.type == NAME_MEAS_TYPE) {
        char *meas_name_str = cp_ba_to_str(meas_type.name);
        if (isMeasNameContains(meas_name_str, "L3servingSINR3gpp_cell_")) {
          struct InfoObj info = parseServingMsg(meas_name_str);
          double sinr = record_item.real_val;

          struct SINR_Map* cell = add_SINR(info.cellID);
          add_UE(cell, info.ueID, sinr);

          printf("Serving Cell %d - UE %d: %.2f dB\n", info.cellID, info.ueID, sinr);

        } else if (isMeasNameContains(meas_name_str, "L3neighSINRListOf_UEID_")) {
          struct InfoObj info = parseNeighMsg(meas_name_str);

          meas_record_lst_t const sinr = record_item;
          meas_record_lst_t const NeighbourID = data_item.meas_record_lst[j + 1];

          struct SINRServingValues* UE = get_UE(info.cellID, info.ueID);
          assert(UE != NULL);

          add_neighCell(UE, NeighbourID.int_val, sinr.real_val);
          j += 2;
          continue;
        }
        free(meas_name_str);
      }
      j++;
    }
  }
}

static
void sm_cb_kpm(sm_ag_if_rd_t const* rd)
{
  assert(rd != NULL);
  assert(rd->type == INDICATION_MSG_AGENT_IF_ANS_V0);
  assert(rd->ind.type == KPM_STATS_V3_0);

  // Reading Indication Message Format 3
  kpm_ind_data_t const* ind = &rd->ind.kpm.ind;
  kpm_ind_msg_format_3_t const* msg_frm_3 = &ind->msg.frm_3;

  // uint64_t const now = time_now_us();
  static int counter = 1;
  {
    lock_guard(&mtx);

    // Reported list of measurements per UE
    for (size_t i = 0; i < msg_frm_3->ue_meas_report_lst_len; i++) 
    {
      // Save UE ID for filling RC Control message
      free_ue_id_e2sm(&ue_id);
      ue_id = cp_ue_id_e2sm(&msg_frm_3->meas_report_per_ue[i].ue_meas_report_lst);

      // log measurements
      log_kpm_measurements(&msg_frm_3->meas_report_per_ue[i].ind_msg_format_1);
    }
    counter++;
  }
}

static
test_info_lst_t filter_predicate(test_cond_type_e type, test_cond_e cond, int value)
{
  test_info_lst_t dst = {0};

  dst.test_cond_type = type;
  dst.IsStat = TRUE_TEST_COND_TYPE;

  // Allocate memory for test_cond and set its value
  dst.test_cond = calloc(1, sizeof(test_cond_e));
  assert(dst.test_cond != NULL && "Memory allocation failed for test_cond");
  *dst.test_cond = cond;

  // Allocate memory for test_cond_value
  dst.test_cond_value = calloc(1, sizeof(test_cond_value_t));
  assert(dst.test_cond_value != NULL && "Memory allocation failed for test_cond_value");
  dst.test_cond_value->type = INTEGER_TEST_COND_VALUE;

  // Allocate memory for int_value and set its value
  int64_t* int_value = calloc(1, sizeof(int64_t));
  assert(int_value != NULL && "Memory allocation failed for int_value");
  *int_value = value;
  dst.test_cond_value->int_value = int_value;
  return dst;
}

static
label_info_lst_t fill_kpm_label(void)
{
  label_info_lst_t label_item = {0};

  label_item.noLabel = ecalloc(1, sizeof(enum_value_e));
  *label_item.noLabel = TRUE_ENUM_VALUE;

  return label_item;
}

static
kpm_act_def_format_1_t fill_act_def_frm_1(ric_report_style_item_t const* report_item)
{
  assert(report_item != NULL);

  kpm_act_def_format_1_t ad_frm_1 = {0};

  size_t const sz = report_item->meas_info_for_action_lst_len;

  // [1, 65535]
  ad_frm_1.meas_info_lst_len = sz;
  ad_frm_1.meas_info_lst = calloc(sz, sizeof(meas_info_format_1_lst_t));
  assert(ad_frm_1.meas_info_lst != NULL && "Memory exhausted");

  for (size_t i = 0; i < sz; i++) 
  {
    meas_info_format_1_lst_t* meas_item = &ad_frm_1.meas_info_lst[i];
    // 8.3.9
    // Measurement Name
    meas_item->meas_type.type = NAME_MEAS_TYPE;
    meas_item->meas_type.name = copy_byte_array(report_item->meas_info_for_action_lst[i].name);

    // [1, 2147483647]
    // 8.3.11
    meas_item->label_info_lst_len = 1;
    meas_item->label_info_lst = ecalloc(1, sizeof(label_info_lst_t));
    meas_item->label_info_lst[0] = fill_kpm_label();
  }

  // 8.3.8 [0, 4294967295]
  ad_frm_1.gran_period_ms = period_ms;

  // 8.3.20 - OPTIONAL
  ad_frm_1.cell_global_id = NULL;

#if defined KPM_V2_03 || defined KPM_V3_00
  // [0, 65535]
  ad_frm_1.meas_bin_range_info_lst_len = 0;
  ad_frm_1.meas_bin_info_lst = NULL;
#endif

  return ad_frm_1;
}

static
kpm_act_def_t fill_report_style_4(ric_report_style_item_t const* report_item)
{
  assert(report_item != NULL);
  assert(report_item->act_def_format_type == FORMAT_4_ACTION_DEFINITION);

  kpm_act_def_t act_def = {.type = FORMAT_4_ACTION_DEFINITION};

  // Fill matching condition
  // [1, 32768]
  act_def.frm_4.matching_cond_lst_len = 1;
  act_def.frm_4.matching_cond_lst =
      calloc(act_def.frm_4.matching_cond_lst_len, sizeof(matching_condition_format_4_lst_t));
  assert(act_def.frm_4.matching_cond_lst != NULL && "Memory exhausted");
  // Filter connected UEs by S-NSSAI criteria
  test_cond_type_e const type = IsStat_TEST_COND_TYPE;  // CQI_TEST_COND_TYPE
  test_cond_e const condition = LESSTHAN_TEST_COND;     // GREATERTHAN_TEST_COND
  int const value = 40;
  act_def.frm_4.matching_cond_lst[0].test_info_lst = filter_predicate(type, condition, value);

  // Fill Action Definition Format 1
  // 8.2.1.2.1
  act_def.frm_4.action_def_format_1 = fill_act_def_frm_1(report_item);

  return act_def;
}

typedef kpm_act_def_t (*fill_kpm_act_def)(ric_report_style_item_t const* report_item);

static
fill_kpm_act_def get_kpm_act_def[END_RIC_SERVICE_REPORT] =
{
    NULL,
    NULL,
    NULL,
    fill_report_style_4,
    NULL,
};

static
kpm_sub_data_t gen_kpm_subs(kpm_ran_function_def_t const* ran_func)
{
  assert(ran_func != NULL);
  assert(ran_func->ric_event_trigger_style_list != NULL);

  kpm_sub_data_t kpm_sub = {0};

  // Generate Event Trigger
  assert(ran_func->ric_event_trigger_style_list[0].format_type == FORMAT_1_RIC_EVENT_TRIGGER);
  kpm_sub.ev_trg_def.type = FORMAT_1_RIC_EVENT_TRIGGER;
  kpm_sub.ev_trg_def.kpm_ric_event_trigger_format_1.report_period_ms = period_ms;

  // Generate Action Definition
  kpm_sub.sz_ad = 1;
  kpm_sub.ad = calloc(kpm_sub.sz_ad, sizeof(kpm_act_def_t));
  assert(kpm_sub.ad != NULL && "Memory exhausted");

  // Multiple Action Definitions in one SUBSCRIPTION message is not supported in this project
  // Multiple REPORT Styles = Multiple Action Definition = Multiple SUBSCRIPTION messages
  ric_report_style_item_t* const report_item = &ran_func->ric_report_style_list[0];
  ric_service_report_e const report_style_type = report_item->report_style_type;
  *kpm_sub.ad = get_kpm_act_def[report_style_type](report_item);

  return kpm_sub;
}

static
size_t find_sm_idx(sm_ran_function_t* rf, size_t sz, bool (*f)(sm_ran_function_t const*, int const),
                          int const id) 
{
  for (size_t i = 0; i < sz; i++) 
  {
    if (f(&rf[i], id))
      return i;
  }

  assert(0 != 0 && "SM ID could not be found in the RAN Function List");
  return 0;
}

//*************************************************************** *//
static
e2sm_rc_ctrl_hdr_frmt_1_t gen_rc_ctrl_hdr_frmt_1(ue_id_e2sm_t ue_id, uint32_t ric_style_type,
                                                         uint16_t ctrl_act_id)
{
  e2sm_rc_ctrl_hdr_frmt_1_t dst = {0};

  // 6.2.2.6
  dst.ue_id = cp_ue_id_e2sm(&ue_id);

  dst.ric_style_type = ric_style_type;
  dst.ctrl_act_id = ctrl_act_id;

  return dst;
}

static
e2sm_rc_ctrl_hdr_t gen_rc_ctrl_hdr(e2sm_rc_ctrl_hdr_e hdr_frmt, ue_id_e2sm_t ue_id,
                                           uint32_t ric_style_type, uint16_t ctrl_act_id) 
{
  e2sm_rc_ctrl_hdr_t dst = {0};

  if (hdr_frmt == FORMAT_1_E2SM_RC_CTRL_HDR) {
    dst.format = FORMAT_1_E2SM_RC_CTRL_HDR;
    dst.frmt_1 = gen_rc_ctrl_hdr_frmt_1(ue_id, ric_style_type, ctrl_act_id);
  } else 
  {
    assert(0 != 0 && "not implemented the fill func for this ctrl hdr frmt");
  }

  return dst;
}

static
void set_EUTRA_CGI(seq_ran_param_t* EUTRA_CGI, const char targetcell)
{
  // Input validation
  assert(EUTRA_CGI != NULL);
  assert(targetcell >= '0' && targetcell <= '9');

  // Validate flag_false is allocated
  if (EUTRA_CGI->ran_param_val.flag_false == NULL) {
    EUTRA_CGI->ran_param_val.flag_false = calloc(1, sizeof(ran_parameter_value_t));
    assert(EUTRA_CGI->ran_param_val.flag_false != NULL && "Memory exhausted");
  }

  EUTRA_CGI->ran_param_val.flag_false->type = BIT_STRING_RAN_PARAMETER_VALUE;

  // Convert target cell to byte array
  byte_array_t target_ba = {0};
  target_ba.len = 1;
  target_ba.buf = malloc(sizeof(uint8_t));
  assert(target_ba.buf != NULL && "Memory exhausted");
  target_ba.buf[0] = targetcell;

  EUTRA_CGI->ran_param_val.flag_false->octet_str_ran.len = target_ba.len;
  EUTRA_CGI->ran_param_val.flag_false->octet_str_ran.buf = target_ba.buf;
}

static
void gen_Target_Primary_Cell_ID(seq_ran_param_t* Target_Primary_Cell_ID, char targetcell)
{
  // Target Primary Cell ID, STRUCTURE (len 1)

  Target_Primary_Cell_ID->ran_param_id = TARGET_PRIMARY_CELL_ID_8_4_4_1;
  Target_Primary_Cell_ID->ran_param_val.type = STRUCTURE_RAN_PARAMETER_VAL_TYPE;
  Target_Primary_Cell_ID->ran_param_val.strct = calloc(1, sizeof(ran_param_struct_t));
  assert(Target_Primary_Cell_ID->ran_param_val.strct != NULL && "Memory exhausted");
  Target_Primary_Cell_ID->ran_param_val.strct->sz_ran_param_struct = 1;
  Target_Primary_Cell_ID->ran_param_val.strct->ran_param_struct = calloc(1, sizeof(seq_ran_param_t));
  assert(Target_Primary_Cell_ID->ran_param_val.strct->ran_param_struct != NULL && "Memory exhausted");

  // > CHOICE Target Cell, STRUCTURE (len 2)
  seq_ran_param_t* CHOICE_Target_Cell = &Target_Primary_Cell_ID->ran_param_val.strct->ran_param_struct[0];
  CHOICE_Target_Cell->ran_param_id = CHOICE_TARGET_CELL_8_4_4_1;
  CHOICE_Target_Cell->ran_param_val.type = STRUCTURE_RAN_PARAMETER_VAL_TYPE;
  CHOICE_Target_Cell->ran_param_val.strct = calloc(1, sizeof(ran_param_struct_t));
  assert(CHOICE_Target_Cell->ran_param_val.strct != NULL && "Memory exhausted");
  CHOICE_Target_Cell->ran_param_val.strct->sz_ran_param_struct = 2;
  CHOICE_Target_Cell->ran_param_val.strct->ran_param_struct = calloc(2, sizeof(seq_ran_param_t));
  assert(CHOICE_Target_Cell->ran_param_val.strct->ran_param_struct != NULL && "Memory exhausted");

  // >>  NR Cell, STRUCTURE (len 1))
  seq_ran_param_t* NR_Cell = &CHOICE_Target_Cell->ran_param_val.strct->ran_param_struct[0];
  NR_Cell->ran_param_id = NR_CELL_8_4_4_1;
  NR_Cell->ran_param_val.type = STRUCTURE_RAN_PARAMETER_VAL_TYPE;
  NR_Cell->ran_param_val.strct = calloc(1, sizeof(ran_param_struct_t));
  assert(NR_Cell->ran_param_val.strct != NULL && "Memory exhausted");
  NR_Cell->ran_param_val.strct->sz_ran_param_struct = 1;
  NR_Cell->ran_param_val.strct->ran_param_struct = calloc(1, sizeof(seq_ran_param_t));

  // >>> NR CGI, ELEMENT   NR CGI is usually written in the format: PLMN ID + NR Cell Identity.
  seq_ran_param_t* NR_CGI = &NR_Cell->ran_param_val.strct->ran_param_struct[0];
  NR_CGI->ran_param_id = NR_CGI_8_4_4_1;
  NR_CGI->ran_param_val.type = ELEMENT_KEY_FLAG_FALSE_RAN_PARAMETER_VAL_TYPE;
  NR_CGI->ran_param_val.flag_false = calloc(1, sizeof(ran_parameter_value_t));
  assert(NR_CGI->ran_param_val.flag_false != NULL && "Memory exhausted");
  NR_CGI->ran_param_val.flag_false->type = BIT_STRING_RAN_PARAMETER_VALUE;
  // NR_CGI->ran_param_val.flag_false->int_ran=  TARGET_CELL;
  char nr_cgi_str[1] = {targetcell};

  byte_array_t nr_cgi = cp_str_to_ba(nr_cgi_str);
  NR_CGI->ran_param_val.flag_false->octet_str_ran.len = nr_cgi.len;
  NR_CGI->ran_param_val.flag_false->octet_str_ran.buf = nr_cgi.buf;

  // >>E-UTRA Cell, STRUCTURE (len 1)
  seq_ran_param_t* EUTRA_Cell = &CHOICE_Target_Cell->ran_param_val.strct->ran_param_struct[1];
  EUTRA_Cell->ran_param_id = EUTRA_CELL_8_4_4_1;
  EUTRA_Cell->ran_param_val.type = STRUCTURE_RAN_PARAMETER_VAL_TYPE;
  EUTRA_Cell->ran_param_val.strct = calloc(1, sizeof(ran_param_struct_t));
  assert(EUTRA_Cell->ran_param_val.strct != NULL && "Memory exhausted");
  EUTRA_Cell->ran_param_val.strct->sz_ran_param_struct = 1;
  EUTRA_Cell->ran_param_val.strct->ran_param_struct = calloc(1, sizeof(seq_ran_param_t));

  // >>>E-UTRA CGI, ELEMENT  The E-UTRA CGI is typically written in the format: PLMN ID + E-UTRAN Cell Identity.
  seq_ran_param_t* EUTRA_CGI = &EUTRA_Cell->ran_param_val.strct->ran_param_struct[0];
  EUTRA_CGI->ran_param_id = EUTRA_CGI_8_4_4_1;
  EUTRA_CGI->ran_param_val.type = ELEMENT_KEY_FLAG_FALSE_RAN_PARAMETER_VAL_TYPE;
  EUTRA_CGI->ran_param_val.flag_false = calloc(1, sizeof(ran_parameter_value_t));
  assert(EUTRA_CGI->ran_param_val.flag_false != NULL && "Memory exhausted");
  EUTRA_CGI->ran_param_val.flag_false->type = BIT_STRING_RAN_PARAMETER_VALUE;

  set_EUTRA_CGI(EUTRA_CGI, targetcell);

  // char eUTRA_cgi_str [2] ;
  // eUTRA_cgi_str[0] = targetcell;
  // eUTRA_cgi_str [1] = '\0';

  // byte_array_t eUTRA_cgi = cp_str_to_ba(eUTRA_cgi_str);
  // EUTRA_CGI->ran_param_val.flag_false->octet_str_ran.len = eUTRA_cgi.len;
  // EUTRA_CGI->ran_param_val.flag_false->octet_str_ran.buf = eUTRA_cgi.buf;
  return;
}

static
void gen_List_of_PDU_sessions_for_handover(seq_ran_param_t* List_PDU_sessions_ho)
{
  int num_PDU_session = 1;

  // List of PDU sessions for handover, LIST (len 1)
  List_PDU_sessions_ho->ran_param_id = LIST_OF_PDU_SESSIONS_FOR_HANDOVER_8_4_4_1;
  List_PDU_sessions_ho->ran_param_val.type = LIST_RAN_PARAMETER_VAL_TYPE;
  List_PDU_sessions_ho->ran_param_val.lst = calloc(1, sizeof(ran_param_list_t));
  assert(List_PDU_sessions_ho->ran_param_val.lst != NULL && "Memory exhausted");
  List_PDU_sessions_ho->ran_param_val.lst->sz_lst_ran_param = num_PDU_session;
  List_PDU_sessions_ho->ran_param_val.lst->lst_ran_param = calloc(num_PDU_session, sizeof(lst_ran_param_t));
  assert(List_PDU_sessions_ho->ran_param_val.lst->lst_ran_param != NULL && "Memory exhausted");

  // > PDU session Item for handover, STRUCTURE (len 2)
  lst_ran_param_t* PDU_session_item = &List_PDU_sessions_ho->ran_param_val.lst->lst_ran_param[0];
  PDU_session_item->ran_param_struct.sz_ran_param_struct = 2;
  PDU_session_item->ran_param_struct.ran_param_struct = calloc(2, sizeof(seq_ran_param_t));
  assert(PDU_session_item->ran_param_struct.ran_param_struct != NULL && "Memory exhausted");

  // >> PDU Session ID, ELEMENT
  seq_ran_param_t* PDU_Session_ID = &PDU_session_item->ran_param_struct.ran_param_struct[0];
  PDU_Session_ID->ran_param_id = PDU_SESSION_ID_8_4_4_1;
  PDU_Session_ID->ran_param_val.type = ELEMENT_KEY_FLAG_TRUE_RAN_PARAMETER_VAL_TYPE;
  PDU_Session_ID->ran_param_val.flag_false = calloc(1, sizeof(ran_parameter_value_t));
  assert(PDU_Session_ID->ran_param_val.flag_false != NULL && "Memory exhausted");
  PDU_Session_ID->ran_param_val.flag_false->type = OCTET_STRING_RAN_PARAMETER_VALUE;

  // Use enum for PDU Session ID
  char pduid_str[2];
  snprintf(pduid_str, sizeof(pduid_str), "%d", PDU_SESSION_ID_5);
  byte_array_t pduid = cp_str_to_ba(pduid_str);
  PDU_Session_ID->ran_param_val.flag_false->octet_str_ran.len = pduid.len;
  PDU_Session_ID->ran_param_val.flag_false->octet_str_ran.buf = pduid.buf;

  // >> List of QoS flows in the PDU session, LIST (len 1)
  seq_ran_param_t* List_of_QoS_flows = &PDU_session_item->ran_param_struct.ran_param_struct[1];
  List_of_QoS_flows->ran_param_id = LIST_OF_QOS_FLOWS_IN_THE_PDU_SESSION_8_4_4_1;
  List_of_QoS_flows->ran_param_val.type = LIST_RAN_PARAMETER_VAL_TYPE;
  List_of_QoS_flows->ran_param_val.lst = calloc(1, sizeof(ran_param_list_t));
  assert(List_of_QoS_flows->ran_param_val.lst != NULL && "Memory exhausted");
  List_of_QoS_flows->ran_param_val.lst->sz_lst_ran_param = 1;
  List_of_QoS_flows->ran_param_val.lst->lst_ran_param = calloc(1, sizeof(lst_ran_param_t));
  assert(List_of_QoS_flows->ran_param_val.lst->lst_ran_param != NULL && "Memory exhausted");

  // >>> QoS flow Item, STRUCTURE (len 1)
  lst_ran_param_t* QoS_flow_Item = &List_of_QoS_flows->ran_param_val.lst->lst_ran_param[0];
  QoS_flow_Item->ran_param_struct.sz_ran_param_struct = 1;
  QoS_flow_Item->ran_param_struct.ran_param_struct = calloc(1, sizeof(seq_ran_param_t));
  assert(QoS_flow_Item->ran_param_struct.ran_param_struct != NULL && "Memory exhausted");

  // >>>> QoS Flow Identifier, ELEMENT
  seq_ran_param_t* QoS_Flow_Id = &QoS_flow_Item->ran_param_struct.ran_param_struct[0];
  QoS_Flow_Id->ran_param_id = QOS_FLOW_IDENTIFIER_8_4_4_1;
  QoS_Flow_Id->ran_param_val.type = ELEMENT_KEY_FLAG_TRUE_RAN_PARAMETER_VAL_TYPE;
  QoS_Flow_Id->ran_param_val.flag_false = calloc(1, sizeof(ran_parameter_value_t));
  assert(QoS_Flow_Id->ran_param_val.flag_false != NULL && "Memory exhausted");
  QoS_Flow_Id->ran_param_val.flag_false->type = OCTET_STRING_RAN_PARAMETER_VALUE;

  // Use enum for QoS Flow ID
  char qosid_str[3];
  snprintf(qosid_str, sizeof(qosid_str), "%d", QOS_FLOW_ID_1);
  byte_array_t qosid = cp_str_to_ba(qosid_str);
  QoS_Flow_Id->ran_param_val.flag_false->octet_str_ran.len = qosid.len;
  QoS_Flow_Id->ran_param_val.flag_false->octet_str_ran.buf = qosid.buf;

  return;
}

static
void gen_List_of_DRBs_for_handover(seq_ran_param_t* List_DRBs_ho)
{
  int num_DRBs = 1;
  // List of DRBs for handover, LIST (len 1)
  List_DRBs_ho->ran_param_id = LIST_OF_DRBS_FOR_HANDOVER_8_4_4_1;
  List_DRBs_ho->ran_param_val.type = LIST_RAN_PARAMETER_VAL_TYPE;
  List_DRBs_ho->ran_param_val.lst = calloc(1, sizeof(ran_param_list_t));
  assert(List_DRBs_ho->ran_param_val.lst != NULL && "Memory exhausted");
  List_DRBs_ho->ran_param_val.lst->sz_lst_ran_param = num_DRBs;
  List_DRBs_ho->ran_param_val.lst->lst_ran_param = calloc(num_DRBs, sizeof(lst_ran_param_t));
  assert(List_DRBs_ho->ran_param_val.lst->lst_ran_param != NULL && "Memory exhausted");

  // > DRB item for handover, STRUCTURE (len 2)
  lst_ran_param_t* DRB_item_ho = (lst_ran_param_t*)&List_DRBs_ho->ran_param_val.strct->ran_param_struct[0];

  DRB_item_ho->ran_param_struct.sz_ran_param_struct = 2;
  DRB_item_ho->ran_param_struct.ran_param_struct = calloc(2, sizeof(seq_ran_param_t));
  assert(DRB_item_ho->ran_param_struct.ran_param_struct != NULL && "Memory exhausted");

  // >> DRB ID, ELEMENT
  seq_ran_param_t* DRB_ID = &DRB_item_ho->ran_param_struct.ran_param_struct[0];
  DRB_ID->ran_param_id = DRB_ID_8_4_4_1;
  DRB_ID->ran_param_val.type = ELEMENT_KEY_FLAG_TRUE_RAN_PARAMETER_VAL_TYPE;
  DRB_ID->ran_param_val.flag_false = calloc(1, sizeof(ran_parameter_value_t));
  assert(DRB_ID->ran_param_val.flag_false != NULL && "Memory exhausted");
  DRB_ID->ran_param_val.flag_false->type = OCTET_STRING_RAN_PARAMETER_VALUE;
  char DRB_ID_str[] = "3";
  byte_array_t drpID = cp_str_to_ba(DRB_ID_str);
  DRB_ID->ran_param_val.flag_false->octet_str_ran.len = drpID.len;
  DRB_ID->ran_param_val.flag_false->octet_str_ran.buf = drpID.buf;

  // >> List of QoS flows in the DRB, LIST (len 1)
  seq_ran_param_t* List_of_QoS_flows = &DRB_item_ho->ran_param_struct.ran_param_struct[1];  //////.....//////
  List_of_QoS_flows->ran_param_id = LIST_OF_QOS_FLOWS_IN_THE_DRB_8_4_4_1;
  List_of_QoS_flows->ran_param_val.type = LIST_RAN_PARAMETER_VAL_TYPE;
  List_of_QoS_flows->ran_param_val.lst = calloc(1, sizeof(ran_param_list_t));
  assert(List_of_QoS_flows->ran_param_val.lst != NULL && "Memory exhausted");
  List_of_QoS_flows->ran_param_val.lst->sz_lst_ran_param = 1;
  List_of_QoS_flows->ran_param_val.lst->lst_ran_param = calloc(1, sizeof(lst_ran_param_t));
  assert(List_of_QoS_flows->ran_param_val.lst->lst_ran_param != NULL && "Memory exhausted");

  // >>>QoS flow Item, STRUCTURE (len 1)
  lst_ran_param_t* QoS_flow_Item = &List_of_QoS_flows->ran_param_val.lst->lst_ran_param[0];
  QoS_flow_Item->ran_param_struct.sz_ran_param_struct = 1;
  QoS_flow_Item->ran_param_struct.ran_param_struct = calloc(1, sizeof(seq_ran_param_t));
  assert(QoS_flow_Item->ran_param_struct.ran_param_struct != NULL && "Memory exhausted");

  // >>>>QoS Flow Identifier, ELEMENT
  seq_ran_param_t* QoS_Flow_Id = &QoS_flow_Item->ran_param_struct.ran_param_struct[0];
  QoS_Flow_Id->ran_param_id = QOS_FLOW_IDENTIFIER_8_4_4_1;
  QoS_Flow_Id->ran_param_val.type = ELEMENT_KEY_FLAG_TRUE_RAN_PARAMETER_VAL_TYPE;
  QoS_Flow_Id->ran_param_val.flag_false = calloc(1, sizeof(ran_parameter_value_t));
  assert(QoS_Flow_Id->ran_param_val.flag_false != NULL && "Memory exhausted");
  QoS_Flow_Id->ran_param_val.flag_false->type = OCTET_STRING_RAN_PARAMETER_VALUE;
  char QFI_str[] = "10";
  byte_array_t QFI = cp_str_to_ba(QFI_str);
  QoS_Flow_Id->ran_param_val.flag_false->octet_str_ran.len = QFI.len;
  QoS_Flow_Id->ran_param_val.flag_false->octet_str_ran.buf = QFI.buf;

  return;
}

static
void gen_List_of_Secondary_cells_to_be_setup(seq_ran_param_t* List_num_2ndCells)
{
  int num_2ndCells = 1;
  // List of Secondary cells to be setup, LIST (len 1)
  List_num_2ndCells->ran_param_id = LIST_OF_SECONDARY_CELLS_TO_BE_SETUP_8_4_4_1;
  List_num_2ndCells->ran_param_val.type = LIST_RAN_PARAMETER_VAL_TYPE;
  List_num_2ndCells->ran_param_val.lst = calloc(1, sizeof(ran_param_list_t));
  assert(List_num_2ndCells->ran_param_val.lst != NULL && "Memory exhausted");
  List_num_2ndCells->ran_param_val.lst->sz_lst_ran_param = num_2ndCells;
  List_num_2ndCells->ran_param_val.lst->lst_ran_param = calloc(num_2ndCells, sizeof(lst_ran_param_t));
  assert(List_num_2ndCells->ran_param_val.lst->lst_ran_param != NULL && "Memory exhausted");

  // >Secondary cell Item to be setup, STRUCTURE (len 1)
  lst_ran_param_t* secCell_item = (lst_ran_param_t*)&List_num_2ndCells->ran_param_val.strct->ran_param_struct[0];

  secCell_item->ran_param_struct.sz_ran_param_struct = 1;
  secCell_item->ran_param_struct.ran_param_struct = calloc(1, sizeof(seq_ran_param_t));
  assert(secCell_item->ran_param_struct.ran_param_struct != NULL && "Memory exhausted");

  // >>Secondary cell ID, ELEMENT
  seq_ran_param_t* secCell_Id = &secCell_item->ran_param_struct.ran_param_struct[0];
  secCell_Id->ran_param_id = SECONDARY_CELL_ID_8_4_4_1;
  secCell_Id->ran_param_val.type = ELEMENT_KEY_FLAG_FALSE_RAN_PARAMETER_VAL_TYPE;
  secCell_Id->ran_param_val.flag_false = calloc(1, sizeof(ran_parameter_value_t));
  assert(secCell_Id->ran_param_val.flag_false != NULL && "Memory exhausted");
  secCell_Id->ran_param_val.flag_false->type = OCTET_STRING_RAN_PARAMETER_VALUE;
  char cellID_str[] = "0";
  byte_array_t QFI = cp_str_to_ba(cellID_str);
  secCell_Id->ran_param_val.flag_false->octet_str_ran.len = QFI.len;
  secCell_Id->ran_param_val.flag_false->octet_str_ran.buf = QFI.buf;

  return;
}

static
e2sm_rc_ctrl_msg_frmt_1_t gen_rc_ctrl_msg_frmt_1_Handover_Control(char targetcell)
{
  e2sm_rc_ctrl_msg_frmt_1_t dst = {0};
  // 8.4.4.1

  // Target Primary Cell ID, STRUCTURE (len 1)
  // > CHOICE Target Cell, STRUCTURE (len 2)
  // >>  NR Cell, STRUCTURE (len 1))
  // >>> NR CGI, ELEMENT
  // >>E-UTRA Cell, STRUCTURE (len 1)
  // >>>E-UTRA CGI, ELEMENT

  // List of PDU sessions for handover, LIST (len 1)
  // >PDU session Item for handover, STRUCTURE (len 2)
  // >>PDU Session ID, ELEMENT
  // >>List of QoS flows in the PDU session, LIST (len 1)
  // >>>QoS flow Item, STRUCTURE (len 1)
  // >>>>QoS Flow Identifier, ELEMENT

  // List of DRBs for handover, LIST (len 1)
  // > DRB item for handover, STRUCTURE (len 2)
  // >> DRB ID, ELEMENT
  // >> List of QoS flows in the DRB, LIST (len 1)
  // >>> QoS flow Item, STRUCTURE (len 1)
  // >>>> QoS flow Identifier, ELEMENT

  // List of Secondary cells to be setup, LIST (len 1)
  // >Secondary cell Item to be setup, STRUCTURE (len 1)
  // >>Secondary cell ID, ELEMENT

  dst.sz_ran_param = 4;
  dst.ran_param = calloc(4, sizeof(seq_ran_param_t));
  assert(dst.ran_param != NULL && "Memory exhausted");

  gen_Target_Primary_Cell_ID(&dst.ran_param[0], targetcell);
  gen_List_of_PDU_sessions_for_handover(&dst.ran_param[1]);
  gen_List_of_DRBs_for_handover(&dst.ran_param[2]);
  gen_List_of_Secondary_cells_to_be_setup(&dst.ran_param[3]);

  return dst;
}

static
e2sm_rc_ctrl_msg_frmt_1_t gen_rc_ctrl_msg_frmt_1_cell_trigger(char targetcell)
{
  e2sm_rc_ctrl_msg_frmt_1_t dst = {0};
  // 8.4.4.1

  // Target Primary Cell ID, STRUCTURE (len 1)
  // > CHOICE Target Cell, STRUCTURE (len 2)
  // >>  NR Cell, STRUCTURE (len 1))
  // >>> NR CGI, ELEMENT
  // >>E-UTRA Cell, STRUCTURE (len 1)
  // >>>E-UTRA CGI, ELEMENT
  dst.sz_ran_param = 1;
  dst.ran_param = calloc(4, sizeof(seq_ran_param_t));
  assert(dst.ran_param != NULL && "Memory exhausted");

  gen_Target_Primary_Cell_ID(&dst.ran_param[0], targetcell);
  return dst;
}

static
e2sm_rc_ctrl_msg_t gen_handover_rc_ctrl_msg(e2sm_rc_ctrl_msg_e msg_frmt, uint8_t targetcell)
{
  e2sm_rc_ctrl_msg_t dst = {0};

  if (msg_frmt == FORMAT_1_E2SM_RC_CTRL_MSG) {
    dst.format = msg_frmt;
    dst.frmt_1 = gen_rc_ctrl_msg_frmt_1_Handover_Control(targetcell);
  } else 
  {
    assert(0 != 0 && "not implemented the fill func for this ctrl msg frmt");
  }

  return dst;
}

static
e2sm_rc_ctrl_msg_t gen_cell_trigger_rc_ctrl_msg(e2sm_rc_ctrl_msg_e msg_frmt, char targetcell)
{
  e2sm_rc_ctrl_msg_t dst = {0};

  if (msg_frmt == FORMAT_1_E2SM_RC_CTRL_MSG) {
    dst.format = msg_frmt;
    dst.frmt_1 = gen_rc_ctrl_msg_frmt_1_cell_trigger(targetcell);
  } else 
  {
    assert(0 != 0 && "not implemented the fill func for this ctrl msg frmt");
  }

  return dst;
}

static
ue_id_e2sm_t gen_rc_ue_id(ue_id_e2sm_e type, int ueid)
{
  ue_id_e2sm_t ue_id = {0};
  if (type == GNB_UE_ID_E2SM) {
    ue_id.type = GNB_UE_ID_E2SM;
    ue_id.gnb.ran_ue_id = (uint64_t*)malloc(sizeof(uint64_t));
    *(ue_id.gnb.ran_ue_id) = ueid;
  } else 
  {
    assert(0 != 0 && "not supported UE ID type");
  }
  return ue_id;
}

static
bool eq_sm(sm_ran_function_t const* elem, int const id)
{
  if (elem->id == id)
    return true;

  return false;
}

static
void forEachCell(Callback targetCellFinding, Callback cbHOAction, Callback cbSwitchOffAction, callback_data_t data) 
{
  static bool processed_cells[MAX_REGISTERED_CELLS] = {false};
  static const int SHUTDOWN_TIMEOUT_SEC = 30; 

  printf("\n=== Evaluating Cells for Energy Saving ===\n");

  // First pass: Mark cells that are candidates for shutdown
  for (int i = 0; i < MAX_REGISTERED_CELLS; i++) 
  {
    if (cells_sinr_map[i].sinrMap != NULL && 
        cells_sinr_map[i].is_registered && 
        !processed_cells[i] &&
        !cells_sinr_map[i].sinrMap->pending_shutdown) {
      
      struct SINR_Map* cell = cells_sinr_map[i].sinrMap;
      
      // Check if cell meets shutdown criteria (low utilization, etc)
      if (cell->numOfConnectedUEs <= 1) { // Example criteria
        cell->pending_shutdown = true;
        cell->shutdown_start_time = time(NULL);
        printf("Cell %d marked for shutdown\n", cell->cellID);
      }
    }
  }

  // Second pass: Process handovers and shutdowns
  for (int i = 0; i < MAX_REGISTERED_CELLS; i++) 
  {
    if (cells_sinr_map[i].sinrMap != NULL && 
        cells_sinr_map[i].is_registered && 
        !processed_cells[i]) {
      
      struct SINR_Map* cell = cells_sinr_map[i].sinrMap;
      
      if (!cell->pending_shutdown) {
        continue; // Skip cells not marked for shutdown
      }

      printf(" Cell %d  meeting the Action Defination Condition\n", cell->cellID);

      size_t handovers_needed = 0;
      size_t handovers_completed = 0;

      // Check each UE in this cell
      for (int j = 0; j < MAX_REGISTERED_UES; j++) {
        if (cell->connectedUEs[j].is_available && 
            cell->connectedUEs[j].neighCells != NULL &&
            !cell->connectedUEs[j].handover_in_progress) {

          callback_data_t ue_data = {
            .nodes = data.nodes,
            .neighCells = cell->connectedUEs[j].neighCells,
            .ueID = cell->connectedUEs[j].ueID,
            .frmCurntCell = cell->cellID
          };

          // Find target cell, excluding cells marked for shutdown
          uint8_t target = targetCellFinding(ue_data);
          
          if (target != 0) {
            ue_data.toTargetCell = target;

            // Trigger handover
            if (cbHOAction(ue_data)) {
              handovers_needed++;
              cell->connectedUEs[j].handover_in_progress = true;
              handovers_completed++;
            }
          }
        }
      }

      // Check if we can proceed with shutdown
      time_t current_time = time(NULL);
      bool timeout_reached = (current_time - cell->shutdown_start_time) > SHUTDOWN_TIMEOUT_SEC;
      
      if ((handovers_needed > 0 && handovers_needed == handovers_completed) || 
          (timeout_reached && handovers_completed == cell->numOfConnectedUEs)) {
        
        printf("All handovers complete (%ld/%ld) or timeout reached for cell %d\n",
               handovers_completed, handovers_needed, cell->cellID);
        
        data.frmCurntCell = cell->cellID;
        if (cbSwitchOffAction(data)) {
          // Clean up cell data structures
          if (cell->connectedUEs != NULL) {
            for (int j = 0; j < MAX_REGISTERED_UES; j++) {
              if (cell->connectedUEs[j].neighCells != NULL) {
                free(cell->connectedUEs[j].neighCells);
                cell->connectedUEs[j].neighCells = NULL;
              }
            }
            free(cell->connectedUEs);
            cell->connectedUEs = NULL;
          }
          
          free(cells_sinr_map[i].sinrMap);
          cells_sinr_map[i].sinrMap = NULL;
          cells_sinr_map[i].is_registered = false;
          processed_cells[i] = true;
          
          printf("Cell %d switched off and cleaned up\n", cell->cellID);
        }
      }
    }
  }
}

// void doHandoverAction(const e2_node_arr_xapp_t * nodes, const int ueID, const uint8_t frmCurntCell, const uint8_t
// toTargetCell) {
static
uint16_t doHandoverAction(callback_data_t data) 
{
  char trgtCell = '0' + data.toTargetCell;
  printf("[xApp]: data.toTargetCell= %d ..\n", data.toTargetCell);

  if (!(trgtCell > '0' && trgtCell <= '9')) {
    printf("[xApp]: Invalid target cell %c\n", trgtCell);
    return 0;
  }

  rc_ctrl_req_data_t rc_ctrl = {0};
  ue_id_e2sm_t ue_id_1 = gen_rc_ue_id(GNB_UE_ID_E2SM, data.ueID);

  rc_ctrl.hdr = gen_rc_ctrl_hdr(FORMAT_1_E2SM_RC_CTRL_HDR, ue_id_1, CONNECTED_MODE_MOBILITY,
                                HANDOVER_CONTROL_7_6_4_1);
  rc_ctrl.msg = gen_handover_rc_ctrl_msg(FORMAT_1_E2SM_RC_CTRL_MSG, trgtCell);

  printf("[xApp]: Send Handover Control message to move IMSI %d from cellId %d to target cellId %c \n", data.ueID,
         data.frmCurntCell, trgtCell);

  bool handover_sent = false;
  for (size_t i = 0; i < (*data.nodes).len; ++i) 
  {
    sm_ans_xapp_t ans = control_sm_xapp_api(&(*data.nodes).n[i].id, SM_RC_ID, &rc_ctrl);

    if (ans.success) {
      handover_sent = true;
      printf("[xApp]: Handover request sent successfully to node %zu\n", i);
    }
  }

  free_rc_ctrl_req_data(&rc_ctrl);
  return handover_sent ? 1 : 0;
}

static
uint16_t switchOffCurrentCell(callback_data_t data)
{
  rc_ctrl_req_data_t rc_ctrl = {0};
  ue_id_e2sm_t ue_id = gen_rc_ue_id(GNB_UE_ID_E2SM, data.ueID);

  rc_ctrl.hdr = gen_rc_ctrl_hdr(FORMAT_1_E2SM_RC_CTRL_HDR, ue_id, ENERGY_STATE, CELL_OFF);
  char frmCurentCell = '0' + data.frmCurntCell;
  rc_ctrl.msg = gen_cell_trigger_rc_ctrl_msg(FORMAT_1_E2SM_RC_CTRL_MSG, frmCurentCell);

  printf("[xApp]: Send switch off Control message to switch off cell %d\n", data.frmCurntCell);
  control_sm_xapp_api(&(*data.nodes).n[0].id, SM_RC_ID, &rc_ctrl);

  free_rc_ctrl_req_data(&rc_ctrl);

  return 0;
}

int main(int argc, char* argv[]) 
{
  fr_args_t args = init_fr_args(argc, argv);
  init_xapp_api(&args);
  sleep(1);

  e2_node_arr_xapp_t nodes = e2_nodes_xapp_api();
  defer({ free_e2_node_arr_xapp(&nodes); });
  assert(nodes.len > 0);
  printf("Connected E2 nodes = %d\n", nodes.len);

  pthread_mutexattr_t attr = {0};
  int rc = pthread_mutex_init(&mtx, &attr);
  assert(rc == 0);

  // Start KPM subscription
  sm_ans_xapp_t* hndl = calloc(nodes.len, sizeof(sm_ans_xapp_t));
  assert(hndl != NULL);

  int const KPM_ran_function = 2;
  for (size_t i = 0; i < nodes.len; ++i) 
  {
    e2_node_connected_xapp_t* n = &nodes.n[i];
    size_t const idx = find_sm_idx(n->rf, n->len_rf, eq_sm, KPM_ran_function);

    if (n->rf[idx].defn.kpm.ric_report_style_list != NULL) {
      kpm_sub_data_t kpm_sub = gen_kpm_subs(&n->rf[idx].defn.kpm);
      hndl[i] = report_sm_xapp_api(&n->id, KPM_ran_function, &kpm_sub, sm_cb_kpm);
      assert(hndl[i].success == true);
      free_kpm_sub_data(&kpm_sub);
    }
  }

  // Wait for enough KPM measurements
  printf("Waiting for KPM measurements...\n");
  sleep(5);  // Wait for 5 measurement cycles

  // Check measurements and trigger handovers
  callback_data_t context = {.nodes = &nodes};

  while (1) {
    printf("\n=== Checking meeting condition and start reporting ===\n");

    // Lock to ensure measurement data is consistent
    pthread_mutex_lock(&mtx);

    // Check cells and trigger handovers
    forEachCell(getTargetCellID, doHandoverAction, switchOffCurrentCell, context);

    pthread_mutex_unlock(&mtx);

    // Wait before next check
    sleep(5);
  }

  // Cleanup
  for (int i = 0; i < nodes.len; ++i) 
  {
    if (hndl[i].success == true)
      rm_report_sm_xapp_api(hndl[i].u.handle);
  }
  free(hndl);

  while (try_stop_xapp_api() == false)
    usleep(1000);

  rc = pthread_mutex_destroy(&mtx);
  assert(rc == 0);

  printf("xApp completed successfully\n");
  return 0;
}
