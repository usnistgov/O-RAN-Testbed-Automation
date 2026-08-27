/*
 * SPDX-License-Identifier: LicenseRef-CSSL-1.0
 */

#include <assert.h>
#include "../../../../../util/conversions.h"
#include <arpa/inet.h> // ntohl

#include "dec_ric_ind_hdr_frm_1.h"

// #define ntohll(x) ((1==ntohl(1)) ? (x) : ((uint64_t)ntohl((x) & 0xFFFFFFFF) << 32) | ntohl((x) >> 32))

// uint64_t ntohll(uint64_t x)
// {
//   return (uint64_t)((uint64_t)ntohl((x) & 0xFFFFFFFFLL) << 32) | (uint32_t)ntohl(x);
// }

// #define ntohll(x) ((((uint64_t)ntohl(x)) << 32) + ntohl((x) >> 32))

// #define NTOHLL(x) ((1==ntohl(1)) ? (x) : (((uint64_t)ntohl((x) & 0xFFFFFFFFUL)) << 32) | ntohl((uint32_t)((x) >> 32)))

uint64_t ntohll(uint64_t x)
{
  uint32_t x1 = (uint32_t)((x & 0xFFFFFFFF00000000LL) >> 32);
  uint32_t x2 = (uint32_t)(x & 0xFFFFFFFFLL);
  x1 = ntohl(x1);
  x2 = ntohl(x2);
  uint64_t v = ((uint64_t)x1) << 32 | x2;

  return v;
}


kpm_ric_ind_hdr_format_1_t kpm_dec_ind_hdr_frm_1_asn(const E2SM_KPM_IndicationHeader_Format1_t * ind_hdr_asn)
{
    kpm_ric_ind_hdr_format_1_t ind_hdr = {0};

    uint64_t reversed_ts;
    reversed_ts = octet_string_to_int_64(ind_hdr_asn->colletStartTime);
    ind_hdr.collectStartTime = ntohll(reversed_ts);
    
    if (ind_hdr_asn->fileFormatversion != NULL){
      ind_hdr.fileformat_version = calloc(1, sizeof(byte_array_t));
      ind_hdr.fileformat_version->buf = calloc(ind_hdr_asn->fileFormatversion->size + 1, sizeof(uint8_t));
      assert(ind_hdr.fileformat_version->buf != NULL && "Memory exhausted" );
      memcpy(ind_hdr.fileformat_version->buf, ind_hdr_asn->fileFormatversion->buf, ind_hdr_asn->fileFormatversion->size);
      ind_hdr.fileformat_version->len = ind_hdr_asn->fileFormatversion->size;
    }

    if (ind_hdr_asn->senderName != NULL){
      ind_hdr.sender_name = calloc(1, sizeof(byte_array_t));
      ind_hdr.sender_name->buf = calloc(ind_hdr_asn->senderName->size + 1, sizeof(uint8_t));
      assert(ind_hdr.sender_name->buf != NULL && "Memory exhausted" );
      memcpy(ind_hdr.sender_name->buf, ind_hdr_asn->senderName->buf, ind_hdr_asn->senderName->size);
      ind_hdr.sender_name->len = ind_hdr_asn->senderName->size;
    }

    if (ind_hdr_asn->senderType != NULL){
      ind_hdr.sender_type = calloc(1, sizeof(byte_array_t));
      ind_hdr.sender_type->buf = calloc(ind_hdr_asn->senderType->size + 1, sizeof(uint8_t));
      assert(ind_hdr.sender_type->buf != NULL && "Memory exhausted" );
      memcpy(ind_hdr.sender_type->buf, ind_hdr_asn->senderType->buf, ind_hdr_asn->senderType->size);
      ind_hdr.sender_type->len = ind_hdr_asn->senderType->size;
    }

    if (ind_hdr_asn->vendorName != NULL){
      ind_hdr.vendor_name = calloc(1, sizeof(byte_array_t));
      ind_hdr.vendor_name->buf = calloc(ind_hdr_asn->vendorName->size + 1, sizeof(uint8_t));
      assert(ind_hdr.vendor_name->buf != NULL && "Memory exhausted" );
      memcpy(ind_hdr.vendor_name->buf, ind_hdr_asn->vendorName->buf, ind_hdr_asn->vendorName->size);
      ind_hdr.vendor_name->len = ind_hdr_asn->vendorName->size;
    }


    return ind_hdr;
}
