/*
 * SPDX-License-Identifier: LicenseRef-CSSL-1.0
 */

#include "../../../../../util/conversions.h"
#include <assert.h>
#include "../../../../../util/conversions.h"
#include <arpa/inet.h> // ntohl

#include "dec_ric_ind_hdr_frm_1.h"

kpm_ric_ind_hdr_format_1_t kpm_dec_ind_hdr_frm_1_asn(const E2SM_KPM_IndicationHeader_Format1_t * ind_hdr_asn)
{
    kpm_ric_ind_hdr_format_1_t ind_hdr = {0};

    uint32_t reversed_ts;
    OCTET_STRING_TO_INT32(&ind_hdr_asn->colletStartTime, reversed_ts);
    ind_hdr.collectStartTime = ntohl(reversed_ts);
    
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
