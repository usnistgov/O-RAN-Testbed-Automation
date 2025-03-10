#include <errno.h>
#include "wrapper.h"
#include <stdio.h>

/*
static int write_out(const void *buffer, size_t size, void *app_key) {
        FILE *out_fp = app_key;
        size_t wrote = fwrite(buffer, 1, size, out_fp);
        return (wrote == size) ? 0 :-1;
}
*/
ranCellUeKpi_t buildRanCellUeKpi(const char *hex_values)
{
        int BUFFER_SIZE = 10240;
        // Calculate the length of the hex string
        size_t hex_len = strlen(hex_values);

        // Allocate memory for a char array to store the hex values
        char *hex_buffer = (char *)malloc(hex_len / 2 + 1); // Each byte is represented by 2 characters, +1 for null terminator
        ranCellUeKpi_t res;
        if (hex_buffer == NULL)
        {
                fprintf(stderr, "Memory allocation failed\n");
                return res;
        }

        // Convert the hex string to binary data
        for (size_t i = 0; i < hex_len; i += 2)
        {
                char byte[3] = {hex_values[i], hex_values[i + 1], '\0'};
                hex_buffer[i / 2] = (char)strtol(byte, NULL, 16);
        }

        // Null-terminate the char array
        hex_buffer[hex_len / 2] = '\0';

        // Now hex_buffer contains the binary data corresponding to the hex values

        // Print the result
        printf("Hex values as a string: %s\n", hex_buffer);
        char **name_format1;
        char **name_format3;
        int sz1 = 0;
        int sz3 = 0;

        E2SM_KPM_RANfunction_Description_t *e2smKpmRanFunctDescrip = (E2SM_KPM_RANfunction_Description_t *)calloc(1, sizeof(E2SM_KPM_RANfunction_Description_t));

        enum asn_transfer_syntax syntax;

        syntax = ATS_ALIGNED_BASIC_PER;

        asn_dec_rval_t rval = asn_decode(NULL, syntax, &asn_DEF_E2SM_KPM_RANfunction_Description, (void **)&e2smKpmRanFunctDescrip, hex_buffer, hex_len);

        if (rval.code == RC_OK)
        {
                printf("[INFO] E2SM KPM RAN Function Description decode successful rval.code = %d \n", rval.code);

                // asn_fprint(stdout, &asn_DEF_E2SM_KPM_RANfunction_Description, e2smKpmRanFunctDescrip);

                for (int i = 0; i < e2smKpmRanFunctDescrip->ric_ReportStyle_List->list.count; i++)
                {
                        if (e2smKpmRanFunctDescrip->ric_ReportStyle_List->list.array[i]->ric_ActionFormat_Type == 1)
                        {
                                sz1 = e2smKpmRanFunctDescrip->ric_ReportStyle_List->list.array[i]->measInfo_Action_List.list.count;
                                name_format1 = (char **)malloc(sz1 * sizeof(char *));
                                for (int j = 0; j < sz1; j++)
                                {
                                        size_t bufsize = e2smKpmRanFunctDescrip->ric_ReportStyle_List->list.array[i]->measInfo_Action_List.list.array[j]->measName.size;
                                        name_format1[j] = (char *)malloc(bufsize + 1); // For null terminator
                                        memcpy(name_format1[j], e2smKpmRanFunctDescrip->ric_ReportStyle_List->list.array[i]->measInfo_Action_List.list.array[j]->measName.buf, bufsize);
                                        name_format1[j][bufsize] = '\0';
                                }
                        }

                        if (e2smKpmRanFunctDescrip->ric_ReportStyle_List->list.array[i]->ric_ActionFormat_Type == 3)
                        {
                                sz3 = e2smKpmRanFunctDescrip->ric_ReportStyle_List->list.array[i]->measInfo_Action_List.list.count;
                                name_format3 = (char **)malloc(sz3 * sizeof(char *));
                                for (int j = 0; j < sz3; j++)
                                {
                                        size_t bufsize = e2smKpmRanFunctDescrip->ric_ReportStyle_List->list.array[i]->measInfo_Action_List.list.array[j]->measName.size;
                                        name_format3[j] = (char *)malloc(bufsize + 1); // For null terminator
                                        memcpy(name_format3[j], e2smKpmRanFunctDescrip->ric_ReportStyle_List->list.array[i]->measInfo_Action_List.list.array[j]->measName.buf, bufsize);
                                        name_format3[j][bufsize] = '\0';
                                }
                        }
                }
        }
        else
        {
                printf("[INFO] E2SM KPM RAN Function Description decode failed rval.code = %d \n", rval.code);
        }

        res.ueKpi = name_format3;
        res.cellKpi = name_format1;
        res.ueKpiSize = sz3;
        res.cellKpiSize = sz1;
        return res;
}

void freeMemorydRanCellUeKpi(ranCellUeKpi_t res)
{
        if (res.cellKpi != NULL)
        {

                for (int i = 0; i < res.cellKpiSize; i++)
                {
                        free(res.cellKpi[i]);
                }

                free(res.cellKpi);
        }

        if (res.ueKpi != NULL)
        {
                for (int i = 0; i < res.ueKpiSize; i++)
                {
                        free(res.ueKpi[i]);
                }
                free(res.ueKpi);
        }
}
// determine
// 1 for format1 by id, 2 for format1 by name , 3 for format3 by id, 4 for format3 by name
struct encode_act_Def_result encode_action_Definition(const char *hex_values, int determine)
{

        encode_act_Def_result_t res = {0};
        int BUFFER_SIZE = 10240;
        // Calculate the length of the hex string
        size_t hex_len = strlen(hex_values);

        // Allocate memory for a char array to store the hex values
        char *hex_buffer = (char *)malloc(hex_len / 2 + 1); // Each byte is represented by 2 characters, +1 for null terminator

        if (hex_buffer == NULL)
        {
                fprintf(stderr, "Memory allocation failed\n");
                return res;
        }

        // Convert the hex string to binary data
        for (size_t i = 0; i < hex_len; i += 2)
        {
                char byte[3] = {hex_values[i], hex_values[i + 1], '\0'};
                hex_buffer[i / 2] = (char)strtol(byte, NULL, 16);
        }

        // Null-terminate the char array
        hex_buffer[hex_len / 2] = '\0';

        // Now hex_buffer contains the binary data corresponding to the hex values

        // Print the result
        printf("Hex values as a string: %s\n", hex_buffer);

        long *id_format1;
        long *id_format3;
        char **name_format1;
        char **name_format3;
        int sz1 = 0;
        int sz3 = 0;

        E2SM_KPM_RANfunction_Description_t *e2smKpmRanFunctDescrip = (E2SM_KPM_RANfunction_Description_t *)calloc(1, sizeof(E2SM_KPM_RANfunction_Description_t));

        enum asn_transfer_syntax syntax;

        syntax = ATS_ALIGNED_BASIC_PER;

        asn_dec_rval_t rval = asn_decode(NULL, syntax, &asn_DEF_E2SM_KPM_RANfunction_Description, (void **)&e2smKpmRanFunctDescrip, hex_buffer, hex_len);

        if (rval.code == RC_OK)
        {
                printf("[INFO] E2SM KPM RAN Function Description decode successful rval.code = %d \n", rval.code);

                // asn_fprint(stdout, &asn_DEF_E2SM_KPM_RANfunction_Description, e2smKpmRanFunctDescrip);

                for (int i = 0; i < e2smKpmRanFunctDescrip->ric_ReportStyle_List->list.count; i++)
                {

                        if (e2smKpmRanFunctDescrip->ric_ReportStyle_List->list.array[i]->ric_ActionFormat_Type == 1)
                        {
                                sz1 = e2smKpmRanFunctDescrip->ric_ReportStyle_List->list.array[i]->measInfo_Action_List.list.count;
                                id_format1 = (long *)calloc(sz1, sizeof(long));
                                name_format1 = (char **)malloc(sz1 * sizeof(char *));
                                for (int j = 0; j < sz1; j++)
                                {
                                        if (e2smKpmRanFunctDescrip->ric_ReportStyle_List->list.array[i]->measInfo_Action_List.list.array[j]->measID != NULL)
                                        {
                                                id_format1[j] = *(e2smKpmRanFunctDescrip->ric_ReportStyle_List->list.array[i]->measInfo_Action_List.list.array[j]->measID);
                                        }
                                        else
                                        {
                                                fprintf(stderr, "Null pointer encountered for id_format1: measID at index %d\n", j);
                                                id_format1[j] = j + 1; // = -1;
                                        }
                                        size_t bufsize = e2smKpmRanFunctDescrip->ric_ReportStyle_List->list.array[i]->measInfo_Action_List.list.array[j]->measName.size;
                                        name_format1[j] = (char *)malloc(bufsize + 1); // For null terminator
                                        memcpy(name_format1[j], e2smKpmRanFunctDescrip->ric_ReportStyle_List->list.array[i]->measInfo_Action_List.list.array[j]->measName.buf, bufsize);
                                        name_format1[j][bufsize] = '\0';
                                }
                        }

                        if (e2smKpmRanFunctDescrip->ric_ReportStyle_List->list.array[i]->ric_ActionFormat_Type == 3)
                        {
                                sz3 = e2smKpmRanFunctDescrip->ric_ReportStyle_List->list.array[i]->measInfo_Action_List.list.count;
                                id_format3 = (long *)calloc(sz3, sizeof(long));
                                name_format3 = (char **)malloc(sz3 * sizeof(char *));
                                for (int j = 0; j < sz3; j++)
                                {
                                        if (e2smKpmRanFunctDescrip->ric_ReportStyle_List->list.array[i]->measInfo_Action_List.list.array[j]->measID != NULL)
                                        {
                                                id_format3[j] = *(e2smKpmRanFunctDescrip->ric_ReportStyle_List->list.array[i]->measInfo_Action_List.list.array[j]->measID);
                                        }
                                        else
                                        {
                                                fprintf(stderr, "Null pointer encountered for id_format3: measID at index %d\n", j);
                                                id_format3[j] = j + 1; // = -1;
                                        }
                                        size_t bufsize = e2smKpmRanFunctDescrip->ric_ReportStyle_List->list.array[i]->measInfo_Action_List.list.array[j]->measName.size;
                                        name_format3[j] = (char *)malloc(bufsize + 1); // For null terminator
                                        memcpy(name_format3[j], e2smKpmRanFunctDescrip->ric_ReportStyle_List->list.array[i]->measInfo_Action_List.list.array[j]->measName.buf, bufsize);
                                        name_format3[j][bufsize] = '\0';
                                }
                        }
                }
        }
        else
        {
                printf("[INFO] E2SM KPM RAN Function Description decode failed rval.code = %d \n", rval.code);
                // Don't forget to free the allocated memory when done
                if (hex_buffer)
                {
                        free(hex_buffer);
                        hex_buffer = NULL;
                }
                if (id_format1)
                {
                        free(id_format1);
                        id_format1 = NULL;
                }
                if (name_format1)
                {
                        for (int i = 0; i < sz1; i++)
                        {
                                if (name_format1[i] != NULL)
                                {
                                        free(name_format1[i]);
                                        name_format1[i] = NULL;
                                }
                        }
                        free(name_format1);
                        name_format1 = NULL;
                }
                if (id_format3)
                {
                        free(id_format3);
                        id_format3 = NULL;
                }
                if (name_format3)
                {
                        for (int i = 0; i < sz3; i++)
                        {
                                if (name_format3[i] != NULL)
                                {
                                        free(name_format3[i]);
                                        name_format3[i] = NULL;
                                }
                        }
                        free(name_format3);
                        name_format3 = NULL;
                }
                return res;
        }
        printf("\n");
        printf("measID format 1\n");
        for (int i = 0; i < sz1; i++)
        {
                printf("%ld, ", id_format1[i]);
        }
        printf("\n");
        printf("measName format 1\n");
        for (int i = 0; i < sz1; i++)
        {
                printf("%s, ", name_format1[i]);
        }
        printf("\n");
        printf("measID format 3\n");
        for (int i = 0; i < sz3; i++)
        {
                printf("%ld, ", id_format3[i]);
        }
        printf("\n");
        printf("measName format 3\n");
        for (int i = 0; i < sz3; i++)
        {
                printf("%s, ", name_format3[i]);
        }

        unsigned char bufFormat3[BUFFER_SIZE];
        size_t buf_sizeFormat3 = BUFFER_SIZE;

        long ricStyleTypeFormat3 = 3;
        unsigned long granulPeriod = 10000;

        int encodedLengthFormat3ByName = e2sm_encode_ric_action_definition_format3_by_name(&bufFormat3[0], &buf_sizeFormat3, name_format3, sz3, ricStyleTypeFormat3, granulPeriod);
        printf("length of buff= %ld \n", strlen(bufFormat3));
        printf("size of buff= %ld \n", sizeof(bufFormat3));
        printf("declared size of buff= %ld \n", BUFFER_SIZE);
        printf("encoded length of buff= %ld \n", encodedLengthFormat3ByName);
        int arrayFormat3ByName[encodedLengthFormat3ByName];
        for (int i = 0; i < encodedLengthFormat3ByName; i++)
        {
                // printf("%d ",(int)bufFormat3[i]);
                arrayFormat3ByName[i] = (int)bufFormat3[i];
        }

        unsigned char bufFormat1[BUFFER_SIZE];
        size_t buf_sizeFormat1 = BUFFER_SIZE;

        long ricStyleTypeFormat1 = 1;
        // unsigned long granulPeriod = 10000;

        // get plmn id during run time of kpimon
        unsigned char p[] = {0x00, 0x1F, 0x01};

        // get nr cell id for 5g cell or eutra cell id for 4g cell
        unsigned char nR[] = {0x12, 0x34, 0x56, 0x00, 0x10};

        int encodedLengthFormat1ByName = e2sm_encode_ric_action_definition_format1_by_name(&bufFormat1[0], &buf_sizeFormat1, name_format1, sz1, ricStyleTypeFormat1, granulPeriod, p, nR);
        printf("\n\n\n");
        int arrayFormat1ByName[encodedLengthFormat1ByName];
        for (int i = 0; i < encodedLengthFormat1ByName; i++)
        {
                // printf("%d ",(int)bufFormat1[i]);
                arrayFormat1ByName[i] = (int)bufFormat1[i];
        }

        unsigned char bufFormat1ById[BUFFER_SIZE];
        size_t buf_sizeFormat1ById = BUFFER_SIZE;

        int encodedLengthFormat1ById = e2sm_encode_ric_action_definition_format1_by_id(&bufFormat1ById[0], &buf_sizeFormat1ById, id_format1, sz1, ricStyleTypeFormat1, granulPeriod, p, nR);
        printf("\n\n\n");
        int arrayFormat1ById[encodedLengthFormat1ById];
        for (int i = 0; i < encodedLengthFormat1ById; i++)
        {
                // printf("%d ",(int)bufFormat1ById[i]);
                arrayFormat1ById[i] = (int)bufFormat1ById[i];
        }

        unsigned char bufFormat3ById[BUFFER_SIZE];
        size_t buf_sizeFormat3ById = BUFFER_SIZE;

        int encodedLengthFormat3ById = e2sm_encode_ric_action_definition_format3_by_id(&bufFormat3ById[0], &buf_sizeFormat3ById, id_format3, sz3, ricStyleTypeFormat3, granulPeriod);
        printf("\n\n\n");
        int arrayFormat3ById[encodedLengthFormat3ById];
        for (int i = 0; i < encodedLengthFormat3ById; i++)
        {
                // printf("%d ",(int)bufFormat3ById[i]);
                arrayFormat3ById[i] = (int)bufFormat3ById[i];
        }

        ASN_STRUCT_FREE(asn_DEF_E2SM_KPM_RANfunction_Description, e2smKpmRanFunctDescrip);

        // Don't forget to free the allocated memory when done
        if (hex_buffer)
        {
                free(hex_buffer);
                hex_buffer = NULL;
        }
        if (id_format1)
        {
                free(id_format1);
                id_format1 = NULL;
        }
        if (name_format1)
        {
                for (int i = 0; i < sz1; i++)
                {
                        if (name_format1[i] != NULL)
                        {
                                free(name_format1[i]);
                                name_format1[i] = NULL;
                        }
                }
                free(name_format1);
                name_format1 = NULL;
        }
        if (id_format3)
        {
                free(id_format3);
                id_format3 = NULL;
        }
        if (name_format3)
        {
                for (int i = 0; i < sz3; i++)
                {
                        if (name_format3[i] != NULL)
                        {
                                free(name_format3[i]);
                                name_format3[i] = NULL;
                        }
                }
                free(name_format3);
                name_format3 = NULL;
        }

        switch (determine)
        {
        case 1:
                res.array = arrayFormat1ById;
                res.length = encodedLengthFormat1ById - 8; // removing hardcoded plmn and cellid
                return res;
        case 2:
                res.array = arrayFormat1ByName;
                res.length = encodedLengthFormat1ByName - 8; // removing hardcoded plmn and cellid
                return res;
        case 3:
                res.array = arrayFormat3ById;
                res.length = encodedLengthFormat3ById;
                return res;
        case 4:
                res.array = arrayFormat3ByName;
                res.length = encodedLengthFormat3ByName;
                return res;
                break;
        }
        return res;
}

size_t e2sm_encode_ric_action_definition_format1_by_name(unsigned char *buf, size_t *buf_size, const char **id_tmp, size_t measIdcount, long ric_style_type, unsigned long granulPeriod, unsigned char *p, unsigned char *nR)
{
        E2SM_KPM_ActionDefinition_t *actionDef = (E2SM_KPM_ActionDefinition_t *)calloc(1, sizeof(E2SM_KPM_ActionDefinition_t));
        if (!actionDef)
        {
                fprintf(stderr, "alloc RIC ActionDefinition failed\n");
                return -1;
        }

        E2SM_KPM_ActionDefinition_Format1_t *actionDefFor1 = (E2SM_KPM_ActionDefinition_Format1_t *)calloc(1, sizeof(E2SM_KPM_ActionDefinition_Format1_t));
        if (!actionDefFor1)
        {
                ASN_STRUCT_FREE(asn_DEF_E2SM_KPM_ActionDefinition, actionDef);
                fprintf(stderr, "alloc RIC ActionDefinition failed\n");
                return -1;
        }
        CGI_t *cellGlobal = (CGI_t *)calloc(1, sizeof(CGI_t));
        if (!cellGlobal)
        {
                fprintf(stderr, "alloc RIC ActionDefinition failed\n");
                return -1;
        }

        NR_CGI_t *nrCGIs = (NR_CGI_t *)calloc(1, sizeof(NR_CGI_t));
        if (!nrCGIs)
        {
                fprintf(stderr, "alloc RIC ActionDefinition failed\n");
                return -1;
        }

        PLMNIdentity_t *PLM = (PLMNIdentity_t *)calloc(1, sizeof(PLMNIdentity_t));
        PLM->buf = (uint8_t *)calloc(3, sizeof(uint8_t));
        memcpy(PLM->buf, p, 3);
        PLM->size = 3;

        NRCellIdentity_t *NRC = (NRCellIdentity_t *)calloc(1, sizeof(NRCellIdentity_t));
        NRC->buf = (uint8_t *)calloc(5, sizeof(uint8_t));
        memcpy(NRC->buf, nR, 5);
        NRC->size = 5;
        NRC->bits_unused = 4;

        nrCGIs->pLMNIdentity = *PLM;
        nrCGIs->nRCellIdentity = *NRC;

        cellGlobal->present = CGI_PR_nR_CGI;
        cellGlobal->choice.nR_CGI = nrCGIs;

        MeasurementInfoItem_t **infoItem = (MeasurementInfoItem_t **)calloc(measIdcount, sizeof(MeasurementInfoItem_t *));
        int Label_Item_count = 1;

        long *no_label = (long *)calloc(1, sizeof(long)); // not giving label to the cell metrics/// don't know its bheaviour
        *no_label = 0;
        int index = 0;
        int c = 0;
        while (index < measIdcount)
        {

                infoItem[index] = (MeasurementInfoItem_t *)calloc(1, sizeof(MeasurementInfoItem_t));
                MeasurementType_t *Mtype = (MeasurementType_t *)calloc(1, sizeof(MeasurementType_t));
                Mtype->present = MeasurementType_PR_measName;
                Mtype->choice.measName.buf = (uint8_t *)calloc(strlen(id_tmp[index]), sizeof(uint8_t));
                memcpy(Mtype->choice.measName.buf, id_tmp[index], strlen(id_tmp[index]));
                Mtype->choice.measName.size = strlen(id_tmp[index]);

                infoItem[index]->measType = *Mtype;

                LabelInfoItem_t **L_Item = (LabelInfoItem_t **)calloc(Label_Item_count, sizeof(LabelInfoItem_t *));
                MeasurementLabel_t *M_Label = (MeasurementLabel_t *)calloc(1, sizeof(MeasurementLabel_t));
                M_Label->noLabel = no_label;
                L_Item[0] = (LabelInfoItem_t *)calloc(1, sizeof(LabelInfoItem_t));
                L_Item[0]->measLabel = *M_Label;
                int result1 = ASN_SEQUENCE_ADD(&infoItem[index]->labelInfoList, L_Item[0]);
                if (result1 == -1)
                {
                        fprintf(stderr, "Unable to assign memory to add labelInfoList %s", strerror(errno));
                        return -1;
                }

                int result2 = ASN_SEQUENCE_ADD(&actionDefFor1->measInfoList, infoItem[index]);
                if (result2 == -1)
                {
                        fprintf(stderr, "Unable to assign memory to add measInfoList %s", strerror(errno));
                        return -1;
                }

                index++;
        }

        actionDefFor1->granulPeriod = granulPeriod;
        actionDefFor1->cellGlobalID = cellGlobal;

        actionDef->ric_Style_Type = ric_style_type;
        actionDef->actionDefinition_formats.present = E2SM_KPM_ActionDefinition__actionDefinition_formats_PR_actionDefinition_Format1;
        actionDef->actionDefinition_formats.choice.actionDefinition_Format1 = actionDefFor1;

        char errbuf[128];
        size_t errbuf_len = 128;

        int ret_constr = asn_check_constraints(&asn_DEF_E2SM_KPM_ActionDefinition, (void *)actionDef, errbuf, &errbuf_len);
        if (ret_constr)
        {
                fprintf(stderr, "Constraints failed for encoding subscription request, %s", strerror(errno));
                return -1;
        }
        // ATS_ALIGNED_BASIC_PER
        // ATS_ALIGNED_CANONICAL_PER
        // ATS_DER
        asn_enc_rval_t encode_result = asn_encode_to_buffer(0, ATS_ALIGNED_CANONICAL_PER, &asn_DEF_E2SM_KPM_ActionDefinition, actionDef, buf, *buf_size);
        // asn_enc_rval_t encode_result = uper_encode_to_buffer(&asn_DEF_E2SM_KPM_ActionDefinition, NULL,actionDef, buf, *buf_size);
        if (encode_result.encoded == -1)
        {
                fprintf(stderr, "Cannot encode %s: %s\n", encode_result.failed_type->name, strerror(errno));
                return -1;
        }
        else
        {
                fprintf(stderr, "successfully\n");
                // xer_fprint(stdout, &asn_DEF_E2SM_KPM_ActionDefinition, actionDef);
                /*
                FILE *fp = fopen("sandeep.bin", "wb");

                asn_enc_rval_t ec =asn_encode(0, ATS_ALIGNED_CANONICAL_PER, &asn_DEF_E2SM_KPM_ActionDefinition, actionDef, write_out, fp);
                fclose(fp);
                if(ec.encoded ==-1) {
                        fprintf(stderr, "Could not encode action def (at %s)\n”,ec.failed_type ? ec.failed_type->name : ”unknown");
                       // exit(1);
                } else {
                        fprintf(stderr, "Created sandeep binary  with ATS_ALIGNED_CANONICAL_PER encoded action def\n");
                }
                FILE *fp2 = fopen("sandy.txt", "w");
                int r=asn_fprint(fp2,&asn_DEF_E2SM_KPM_ActionDefinition,actionDef);
                fclose(fp2);
                if (r==-1)
                         fprintf(stderr, "failed asn_fprint\n");
                else
                         fprintf(stderr, "successful asn_fprint\n");
                */

                return encode_result.encoded;
        }
}

size_t e2sm_encode_ric_action_definition_format1_by_id(unsigned char *buf, size_t *buf_size, long *id, size_t measIdcount, long ric_style_type, unsigned long granulPeriod, unsigned char *p, unsigned char *nR)
{
        E2SM_KPM_ActionDefinition_t *actionDef = (E2SM_KPM_ActionDefinition_t *)calloc(1, sizeof(E2SM_KPM_ActionDefinition_t));
        if (!actionDef)
        {
                fprintf(stderr, "alloc RIC ActionDefinition failed\n");
                return -1;
        }

        E2SM_KPM_ActionDefinition_Format1_t *actionDefFor1 = (E2SM_KPM_ActionDefinition_Format1_t *)calloc(1, sizeof(E2SM_KPM_ActionDefinition_Format1_t));
        if (!actionDefFor1)
        {
                ASN_STRUCT_FREE(asn_DEF_E2SM_KPM_ActionDefinition, actionDef);
                fprintf(stderr, "alloc RIC ActionDefinition failed\n");
                return -1;
        }
        CGI_t *cellGlobal = (CGI_t *)calloc(1, sizeof(CGI_t));
        if (!cellGlobal)
        {
                fprintf(stderr, "alloc RIC ActionDefinition failed\n");
                return -1;
        }

        NR_CGI_t *nrCGIs = (NR_CGI_t *)calloc(1, sizeof(NR_CGI_t));
        if (!nrCGIs)
        {
                fprintf(stderr, "alloc RIC ActionDefinition failed\n");
                return -1;
        }

        PLMNIdentity_t *PLM = (PLMNIdentity_t *)calloc(1, sizeof(PLMNIdentity_t));
        PLM->buf = (uint8_t *)calloc(3, sizeof(uint8_t));
        memcpy(PLM->buf, p, 3);
        PLM->size = 3;

        NRCellIdentity_t *NRC = (NRCellIdentity_t *)calloc(1, sizeof(NRCellIdentity_t));
        NRC->buf = (uint8_t *)calloc(5, sizeof(uint8_t));
        memcpy(NRC->buf, nR, 5);
        NRC->size = 5;
        NRC->bits_unused = 4;

        nrCGIs->pLMNIdentity = *PLM;
        nrCGIs->nRCellIdentity = *NRC;

        cellGlobal->present = CGI_PR_nR_CGI;
        cellGlobal->choice.nR_CGI = nrCGIs;

        MeasurementInfoItem_t **infoItem = (MeasurementInfoItem_t **)calloc(measIdcount, sizeof(MeasurementInfoItem_t *));
        int Label_Item_count = 1;

        long *no_label = (long *)calloc(1, sizeof(long)); // not giving label to the cell metrics/// don't know its bheaviour
        *no_label = 0;
        int index = 0;
        while (index < measIdcount)
        {

                infoItem[index] = (MeasurementInfoItem_t *)calloc(1, sizeof(MeasurementInfoItem_t));
                MeasurementType_t *Mtype = (MeasurementType_t *)calloc(1, sizeof(MeasurementType_t));
                Mtype->present = MeasurementType_PR_measID;
                Mtype->choice.measID = id[index];
                infoItem[index]->measType = *Mtype;

                LabelInfoItem_t **L_Item = (LabelInfoItem_t **)calloc(Label_Item_count, sizeof(LabelInfoItem_t *));
                MeasurementLabel_t *M_Label = (MeasurementLabel_t *)calloc(1, sizeof(MeasurementLabel_t));
                M_Label->noLabel = no_label;
                L_Item[0] = (LabelInfoItem_t *)calloc(1, sizeof(LabelInfoItem_t));
                L_Item[0]->measLabel = *M_Label;
                int result1 = ASN_SEQUENCE_ADD(&infoItem[index]->labelInfoList, L_Item[0]);
                if (result1 == -1)
                {
                        fprintf(stderr, "Unable to assign memory to add labelInfoList %s", strerror(errno));
                        return -1;
                }

                int result2 = ASN_SEQUENCE_ADD(&actionDefFor1->measInfoList, infoItem[index]);
                if (result2 == -1)
                {
                        fprintf(stderr, "Unable to assign memory to add measInfoList %s", strerror(errno));
                        return -1;
                }

                index++;
        }

        actionDefFor1->granulPeriod = granulPeriod;
        actionDefFor1->cellGlobalID = cellGlobal;

        actionDef->ric_Style_Type = ric_style_type;
        actionDef->actionDefinition_formats.present = E2SM_KPM_ActionDefinition__actionDefinition_formats_PR_actionDefinition_Format1;
        actionDef->actionDefinition_formats.choice.actionDefinition_Format1 = actionDefFor1;

        char errbuf[128];
        size_t errbuf_len = 128;

        int ret_constr = asn_check_constraints(&asn_DEF_E2SM_KPM_ActionDefinition, (void *)actionDef, errbuf, &errbuf_len);
        if (ret_constr)
        {
                fprintf(stderr, "Constraints failed for encoding subscription request, %s", strerror(errno));
                return -1;
        }
        // ATS_ALIGNED_BASIC_PER
        // ATS_ALIGNED_CANONICAL_PER
        // ATS_DER
        asn_enc_rval_t encode_result = asn_encode_to_buffer(0, ATS_ALIGNED_CANONICAL_PER, &asn_DEF_E2SM_KPM_ActionDefinition, actionDef, buf, *buf_size);
        // asn_enc_rval_t encode_result = uper_encode_to_buffer(&asn_DEF_E2SM_KPM_ActionDefinition, NULL,actionDef, buf, *buf_size);
        if (encode_result.encoded == -1)
        {
                fprintf(stderr, "Cannot encode %s: %s\n", encode_result.failed_type->name, strerror(errno));
                return -1;
        }
        else
        {
                fprintf(stderr, "successfully\n");
                // xer_fprint(stdout, &asn_DEF_E2SM_KPM_ActionDefinition, actionDef);
                /*
                FILE *fp = fopen("sandeep.bin", "wb");

                asn_enc_rval_t ec =asn_encode(0, ATS_ALIGNED_CANONICAL_PER, &asn_DEF_E2SM_KPM_ActionDefinition, actionDef, write_out, fp);
                fclose(fp);
                if(ec.encoded ==-1) {
                        fprintf(stderr, "Could not encode action def (at %s)\n”,ec.failed_type ? ec.failed_type->name : ”unknown");
                        exit(1);
                } else {
                        fprintf(stderr, "Created sandeep binary  with ATS_ALIGNED_CANONICAL_PER encoded action def\n");
                }
                FILE *fp2 = fopen("sandy.txt", "w");
                int r=asn_fprint(fp2,&asn_DEF_E2SM_KPM_ActionDefinition,actionDef);
                fclose(fp2);
                if (r==-1)
                         fprintf(stderr, "failed asn_fprint\n");
                else
                         fprintf(stderr, "successful asn_fprint\n");
                */

                return encode_result.encoded;
        }
}

size_t e2sm_encode_ric_action_definition_format3_by_name(unsigned char *buf, size_t *buf_size, char **id_tmp, size_t measIdcount, long ric_style_type, unsigned long granulPeriod)
{
        E2SM_KPM_ActionDefinition_t *actionDef = (E2SM_KPM_ActionDefinition_t *)calloc(1, sizeof(E2SM_KPM_ActionDefinition_t));
        if (!actionDef)
        {
                fprintf(stderr, "alloc RIC ActionDefinition failed\n");
                return -1;
        }

        E2SM_KPM_ActionDefinition_Format3_t *actionDefFor3 = (E2SM_KPM_ActionDefinition_Format3_t *)calloc(1, sizeof(E2SM_KPM_ActionDefinition_Format3_t));
        if (!actionDefFor3)
        {
                ASN_STRUCT_FREE(asn_DEF_E2SM_KPM_ActionDefinition, actionDef);
                fprintf(stderr, "alloc RIC ActionDefinition failed\n");
                return -1;
        }

        MeasurementCondItem_t **CondItem = (MeasurementCondItem_t **)calloc(measIdcount, sizeof(MeasurementCondItem_t *));
        int Label_Item_count = 1;

        long *no_label = (long *)calloc(1, sizeof(long)); // not giving label to the cell metrics/// don't know its bheaviour
        *no_label = 0;
        int index = 0;
        while (index < measIdcount)
        {

                CondItem[index] = (MeasurementCondItem_t *)calloc(1, sizeof(MeasurementCondItem_t));
                MeasurementType_t *Mtype = (MeasurementType_t *)calloc(1, sizeof(MeasurementType_t));
                Mtype->present = MeasurementType_PR_measName;
                Mtype->choice.measName.buf = (uint8_t *)calloc(strlen(id_tmp[index]), sizeof(uint8_t));
                memcpy(Mtype->choice.measName.buf, id_tmp[index], strlen(id_tmp[index]));
                Mtype->choice.measName.size = strlen(id_tmp[index]);
                CondItem[index]->measType = *Mtype;

                MatchingCondItem_t **M_Item = (MatchingCondItem_t **)calloc(Label_Item_count, sizeof(MatchingCondItem_t *));
                MeasurementLabel_t *M_Label = (MeasurementLabel_t *)calloc(1, sizeof(MeasurementLabel_t));
                M_Label->noLabel = no_label;
                M_Item[0] = (MatchingCondItem_t *)calloc(1, sizeof(MatchingCondItem_t));
                M_Item[0]->present = MatchingCondItem_PR_measLabel;
                M_Item[0]->choice.measLabel = M_Label;
                int result1 = ASN_SEQUENCE_ADD(&CondItem[index]->matchingCond, M_Item[0]);
                if (result1 == -1)
                {
                        fprintf(stderr, "Unable to assign memory for matchingCond to add matchingCondItem_t %s", strerror(errno));
                        return -1;
                }

                int result2 = ASN_SEQUENCE_ADD(&actionDefFor3->measCondList, CondItem[index]);
                if (result2 == -1)
                {
                        fprintf(stderr, "Unable to assign memory for measCondList to add MeasurementCondItem_t %s", strerror(errno));
                        return -1;
                }

                index++;
        }

        actionDefFor3->granulPeriod = granulPeriod;

        actionDef->ric_Style_Type = ric_style_type;
        actionDef->actionDefinition_formats.present = E2SM_KPM_ActionDefinition__actionDefinition_formats_PR_actionDefinition_Format3;
        actionDef->actionDefinition_formats.choice.actionDefinition_Format3 = actionDefFor3;

        char errbuf[128];
        size_t errbuf_len = 128;

        int ret_constr = asn_check_constraints(&asn_DEF_E2SM_KPM_ActionDefinition, (void *)actionDef, errbuf, &errbuf_len);
        if (ret_constr)
        {
                fprintf(stderr, "Constraints failed for encoding subscription request, %s", strerror(errno));
                return -1;
        }
        // ATS_ALIGNED_BASIC_PER
        // ATS_ALIGNED_CANONICAL_PER
        // ATS_DER
        asn_enc_rval_t encode_result = asn_encode_to_buffer(0, ATS_ALIGNED_CANONICAL_PER, &asn_DEF_E2SM_KPM_ActionDefinition, actionDef, buf, *buf_size);
        // asn_enc_rval_t encode_result = uper_encode_to_buffer(&asn_DEF_E2SM_KPM_ActionDefinition, NULL,actionDef, buf, *buf_size);
        if (encode_result.encoded == -1)
        {
                fprintf(stderr, "Cannot encode %s: %s\n", encode_result.failed_type->name, strerror(errno));
                return -1;
        }
        else
        {
                fprintf(stderr, "successfully\n");
                // xer_fprint(stdout, &asn_DEF_E2SM_KPM_ActionDefinition, actionDef);
                /*
                FILE *fp = fopen("sandeep.bin", "wb");

                asn_enc_rval_t ec =asn_encode(0, ATS_ALIGNED_CANONICAL_PER, &asn_DEF_E2SM_KPM_ActionDefinition, actionDef, write_out, fp);
                fclose(fp);
                if(ec.encoded ==-1) {
                        fprintf(stderr, "Could not encode action def (at %s)\n”,ec.failed_type ? ec.failed_type->name : ”unknown");
                        exit(1);
                } else {
                        fprintf(stderr, "Created sandeep binary  with ATS_ALIGNED_CANONICAL_PER encoded action def\n");
                }
                FILE *fp2 = fopen("sandy.txt", "w");
                int r=asn_fprint(fp2,&asn_DEF_E2SM_KPM_ActionDefinition,actionDef);
                fclose(fp2);
                if (r==-1)
                         fprintf(stderr, "failed asn_fprint\n");
                else
                         fprintf(stderr, "successful asn_fprint\n");
                */
                return encode_result.encoded;
        }
}
size_t e2sm_encode_ric_action_definition_format3_by_id(unsigned char *buf, size_t *buf_size, long *id, size_t measIdcount, long ric_style_type, unsigned long granulPeriod)
{
        E2SM_KPM_ActionDefinition_t *actionDef = (E2SM_KPM_ActionDefinition_t *)calloc(1, sizeof(E2SM_KPM_ActionDefinition_t));
        if (!actionDef)
        {
                fprintf(stderr, "alloc RIC ActionDefinition failed\n");
                return -1;
        }

        E2SM_KPM_ActionDefinition_Format3_t *actionDefFor3 = (E2SM_KPM_ActionDefinition_Format3_t *)calloc(1, sizeof(E2SM_KPM_ActionDefinition_Format3_t));
        if (!actionDefFor3)
        {
                ASN_STRUCT_FREE(asn_DEF_E2SM_KPM_ActionDefinition, actionDef);
                fprintf(stderr, "alloc RIC ActionDefinition failed\n");
                return -1;
        }

        MeasurementCondItem_t **CondItem = (MeasurementCondItem_t **)calloc(measIdcount, sizeof(MeasurementCondItem_t *));
        int Label_Item_count = 1;

        long *no_label = (long *)calloc(1, sizeof(long)); // not giving label to the cell metrics/// don't know its bheaviour
        *no_label = 0;
        int index = 0;
        while (index < measIdcount)
        {

                CondItem[index] = (MeasurementCondItem_t *)calloc(1, sizeof(MeasurementCondItem_t));
                MeasurementType_t *Mtype = (MeasurementType_t *)calloc(1, sizeof(MeasurementType_t));
                Mtype->present = MeasurementType_PR_measID;
                Mtype->choice.measID = id[index];
                CondItem[index]->measType = *Mtype;

                // LabelInfoList_t *L_List=(LabelInfoList_t *)calloc(1,sizeof(LabelInfoList_t ));
                MatchingCondItem_t **M_Item = (MatchingCondItem_t **)calloc(Label_Item_count, sizeof(MatchingCondItem_t *));
                MeasurementLabel_t *M_Label = (MeasurementLabel_t *)calloc(1, sizeof(MeasurementLabel_t));
                M_Label->noLabel = no_label;
                M_Item[0] = (MatchingCondItem_t *)calloc(1, sizeof(MatchingCondItem_t));
                M_Item[0]->present = MatchingCondItem_PR_measLabel;
                M_Item[0]->choice.measLabel = M_Label;
                int result1 = ASN_SEQUENCE_ADD(&CondItem[index]->matchingCond, M_Item[0]);
                if (result1 == -1)
                {
                        fprintf(stderr, "Unable to assign memory for matchingCond to add matchingCondItem_t %s", strerror(errno));
                        return -1;
                }

                int result2 = ASN_SEQUENCE_ADD(&actionDefFor3->measCondList, CondItem[index]);
                if (result2 == -1)
                {
                        fprintf(stderr, "Unable to assign memory for measCondList to add MeasurementCondItem_t %s", strerror(errno));
                        return -1;
                }

                index++;
        }

        actionDefFor3->granulPeriod = granulPeriod;
        // actionDefFor3->cellGlobalID = cellGlobal; //optional

        actionDef->ric_Style_Type = ric_style_type;
        actionDef->actionDefinition_formats.present = E2SM_KPM_ActionDefinition__actionDefinition_formats_PR_actionDefinition_Format3;
        actionDef->actionDefinition_formats.choice.actionDefinition_Format3 = actionDefFor3;

        char errbuf[128];
        size_t errbuf_len = 128;

        int ret_constr = asn_check_constraints(&asn_DEF_E2SM_KPM_ActionDefinition, (void *)actionDef, errbuf, &errbuf_len);
        if (ret_constr)
        {
                fprintf(stderr, "Constraints failed for encoding subscription request, %s", strerror(errno));
                return -1;
        }
        // ATS_ALIGNED_BASIC_PER
        // ATS_ALIGNED_CANONICAL_PER
        // ATS_DER
        asn_enc_rval_t encode_result = asn_encode_to_buffer(0, ATS_ALIGNED_CANONICAL_PER, &asn_DEF_E2SM_KPM_ActionDefinition, actionDef, buf, *buf_size);
        // asn_enc_rval_t encode_result = uper_encode_to_buffer(&asn_DEF_E2SM_KPM_ActionDefinition, NULL,actionDef, buf, *buf_size);
        if (encode_result.encoded == -1)
        {
                fprintf(stderr, "Cannot encode %s: %s\n", encode_result.failed_type->name, strerror(errno));
                return -1;
        }
        else
        {
                fprintf(stderr, "successfully\n");
                // xer_fprint(stdout, &asn_DEF_E2SM_KPM_ActionDefinition, actionDef);
                /*
                FILE *fp = fopen("sandeep.bin", "wb");

                asn_enc_rval_t ec =asn_encode(0, ATS_ALIGNED_CANONICAL_PER, &asn_DEF_E2SM_KPM_ActionDefinition, actionDef, write_out, fp);
                fclose(fp);
                if(ec.encoded ==-1) {
                        fprintf(stderr, "Could not encode action def (at %s)\n”,ec.failed_type ? ec.failed_type->name : ”unknown");
                        exit(1);
                } else {
                        fprintf(stderr, "Created sandeep binary  with ATS_ALIGNED_CANONICAL_PER encoded action def\n");
                }
                FILE *fp2 = fopen("sandy.txt", "w");
                int r=asn_fprint(fp2,&asn_DEF_E2SM_KPM_ActionDefinition,actionDef);
                fclose(fp2);
                if (r==-1)
                         fprintf(stderr, "failed asn_fprint\n");
                else
                         fprintf(stderr, "successful asn_fprint\n");
                */
                return encode_result.encoded;
        }
}
ssize_t e2sm_encode_ric_event_trigger_definition(void *buffer, size_t buf_size, size_t event_trigger_count, long *RT_periods)
{
        E2SM_KPM_EventTriggerDefinition_t *eventTriggerDef = (E2SM_KPM_EventTriggerDefinition_t *)calloc(1, sizeof(E2SM_KPM_EventTriggerDefinition_t));
        if (!eventTriggerDef)
        {
                fprintf(stderr, "Alloc EventTriggerDefinition failed\n");
                return -1;
        }

        E2SM_KPM_EventTriggerDefinition_Format1_t *innerDef = (E2SM_KPM_EventTriggerDefinition_Format1_t *)calloc(1, sizeof(E2SM_KPM_EventTriggerDefinition_Format1_t));
        if (!innerDef)
        {
                fprintf(stderr, "alloc EventTriggerDefinition Format1 failed\n");
                ASN_STRUCT_FREE(asn_DEF_E2SM_KPM_EventTriggerDefinition, eventTriggerDef);
                return -1;
        }

        eventTriggerDef->eventDefinition_formats.present = E2SM_KPM_EventTriggerDefinition__eventDefinition_formats_PR_eventDefinition_Format1;
        eventTriggerDef->eventDefinition_formats.choice.eventDefinition_Format1 = innerDef;

        // struct E2SM_KPM_EventTriggerDefinition_Format1__policyTest_List *policyTestList = (struct E2SM_KPM_EventTriggerDefinition_Format1__policyTest_List *)calloc(1, sizeof(struct E2SM_KPM_EventTriggerDefinition_Format1__policyTest_List));
        // innerDef->policyTest_List = policyTestList;

        // int index = 0;
        // while(index < event_trigger_count) {
        //      Trigger_ConditionIE_Item *triggerCondition = (Trigger_ConditionIE_Item *)calloc(1, sizeof(Trigger_ConditionIE_Item));
        //      assert(triggerCondition != 0);
        //      triggerCondition->report_Period_IE = RT_periods[index];
        //      ASN_SEQUENCE_ADD(&policyTestList->list, triggerCondition);
        //      index++;
        // }

        asn_enc_rval_t encode_result;
        encode_result = uper_encode_to_buffer(&asn_DEF_E2SM_KPM_EventTriggerDefinition, NULL, eventTriggerDef, buffer, buf_size);
        ASN_STRUCT_FREE(asn_DEF_E2SM_KPM_EventTriggerDefinition, eventTriggerDef);
        if (encode_result.encoded == -1)
        {
                fprintf(stderr, "Cannot encode %s: %s\n", encode_result.failed_type->name, strerror(errno));
                return -1;
        }
        else
        {
                return encode_result.encoded;
        }
}

/*
ssize_t e2sm_encode_ric_action_definition(void *buffer, size_t buf_size, long action_Def_count, long meas_ID, long ric_style_type, long GR_periods, Plm plm, Nrc nRc) {
        E2SM_KPM_ActionDefinition_t *actionDef = (E2SM_KPM_ActionDefinition_t *)calloc(1, sizeof(E2SM_KPM_ActionDefinition_t));
        if(!actionDef) {
                fprintf(stderr, "alloc RIC ActionDefinition failed\n");
                return -1;
        }

        E2SM_KPM_ActionDefinition_Format1_t *actionDefFor1 = (E2SM_KPM_ActionDefinition_Format1_t *)calloc(1, sizeof(E2SM_KPM_ActionDefinition_Format1_t));
        if(!actionDefFor1) {
                ASN_STRUCT_FREE(asn_DEF_E2SM_KPM_ActionDefinition, actionDef);
                fprintf(stderr, "alloc RIC ActionDefinition failed\n");
                return -1;
        }
        CGI_t *cellGlobal = (CGI_t *)calloc(1, sizeof(CGI_t));
        if(!cellGlobal) {
                fprintf(stderr, "alloc RIC ActionDefinition failed\n");
                return -1;
        }

        NR_CGI_t *nrCGIs = (NR_CGI_t *)calloc(1, sizeof(NR_CGI_t));
        if(!nrCGIs) {
                fprintf(stderr, "alloc RIC ActionDefinition failed\n");
                return -1;
        }

        actionDef->ric_Style_Type = ric_style_type;
        actionDef->actionDefinition_formats.present = E2SM_KPM_ActionDefinition__actionDefinition_formats_PR_actionDefinition_Format1;
        actionDef->actionDefinition_formats.choice.actionDefinition_Format1 = actionDefFor1;
        actionDefFor1->granulPeriod = GR_periods;
        actionDefFor1->cellGlobalID = cellGlobal;
        cellGlobal->present = CGI_PR_nR_CGI;
        cellGlobal->choice.nR_CGI = nrCGIs;


        int plmSize = plm.size;
        if(plmSize != 0) {

        }

    PLMNIdentity_t *plms = &nrCGIs->pLMNIdentity;
    plms->buf = (uint8_t *)calloc(1, plmSize);
    if(!plms->buf) {
        fprintf(stderr, "alloc plms failed\n");
            ASN_STRUCT_FREE(asn_DEF_E2SM_KPM_ActionDefinition, actionDef);
        return -1;
    }

    memcpy(plms->buf, plm.plms, plmSize);
    plms->size = plmSize;


        int nRcSize = nRc.size;

        NRCellIdentity_t *nRCs = &nrCGIs->nRCellIdentity;
    nRCs->buf = (uint8_t *)calloc(1, nRcSize);
    if(!nRCs->buf) {
        fprintf(stderr, "alloc nRCs failed\n");
            ASN_STRUCT_FREE(asn_DEF_E2SM_KPM_ActionDefinition, actionDef);
        return -1;
    }

    memcpy(nRCs->buf, nRc.nRcs, nRcSize);
    nRCs->size = nRcSize;


        MeasurementInfoList_t *infoList = &actionDefFor1->measInfoList;

        int index = 0;
        while(index < action_Def_count) {
                MeasurementInfoItem_t *infoItem = (MeasurementInfoItem_t *)calloc(1, sizeof(MeasurementInfoItem_t));
                // if(!infoItem) {
                //     fprintf(stderr, "alloc Measurement Info Item failed\n");
                //     ASN_STRUCT_FREE(asn_DEF_E2SM_KPM_ActionDefinition, actionDef);
                // return -1;
                // }
                assert(infoItem != 0);


                MeasurementType_t *measureType = &infoItem->measType;

                measureType->present = MeasurementType_PR_measID;
                measureType->choice.measID = meas_ID;


                LabelInfoList_t *lableList = &infoItem->labelInfoList;

                ASN_SEQUENCE_ADD(&infoList->list, infoItem);
        index++;
        }

        asn_enc_rval_t encode_result;
    encode_result = uper_encode_to_buffer(&asn_DEF_E2SM_KPM_ActionDefinition, NULL,actionDef, buffer, buf_size);
    ASN_STRUCT_FREE(asn_DEF_E2SM_KPM_ActionDefinition, actionDef);

        if(encode_result.encoded == -1) {
            fprintf(stderr, "Cannot encode %s: %s\n", encode_result.failed_type->name, strerror(errno));
            return -1;
        } else {
                fprintf(stderr, "successfully\n");
        return encode_result.encoded;
    }
}
*/
E2SM_KPM_IndicationHeader_t *e2sm_decode_ric_indication_header(void *buffer, size_t buf_size)
{
        asn_dec_rval_t decode_result;
        E2SM_KPM_IndicationHeader_t *indHdr = 0;
        // fprintf(stderr, "\nbuffer= %p",buffer);
        // fprintf(stdout, "\nbuf_size=%ld",buf_size);
        // fprintf(stdout, "\nE2SM_KPM_IndicationHeader_t_size=%ld",sizeof(E2SM_KPM_IndicationHeader_t));
        // decode_result = uper_decode_complete(NULL, &asn_DEF_E2SM_KPM_IndicationHeader, (void **)&indHdr, (char*)buffer, buf_size);
        // ATS_ALIGNED_CANONICAL_PER
        decode_result = asn_decode(0, ATS_ALIGNED_BASIC_PER, &asn_DEF_E2SM_KPM_IndicationHeader, (void **)&indHdr, buffer, buf_size);
        if (decode_result.code == RC_OK)
        {
                // xer_fprint(stderr, &asn_DEF_E2SM_KPM_IndicationHeader, indHdr);
                return indHdr;
        }
        else if (decode_result.code == RC_WMORE)
        {
                // xer_fprint(stderr, &asn_DEF_E2SM_KPM_IndicationHeader, indHdr);
                // fprintf(stderr, "\n decode_result.consumed= %ld \n",decode_result.consumed);
                fprintf(stderr, "\nheader RC_WMORE ");
                return indHdr;
        }

        else
        {
                ASN_STRUCT_FREE(asn_DEF_E2SM_KPM_IndicationHeader, indHdr);
                return NULL;
        }
}

void e2sm_free_ric_indication_header(E2SM_KPM_IndicationHeader_t *indHdr)
{
        ASN_STRUCT_FREE(asn_DEF_E2SM_KPM_IndicationHeader, indHdr);
}

E2SM_KPM_IndicationMessage_t *e2sm_decode_ric_indication_message(void *buffer, size_t buf_size)
{
        asn_dec_rval_t decode_result;
        E2SM_KPM_IndicationMessage_t *indMsg = 0;
        // fprintf(stdout, "\nbuffer= %p",buffer);
        // fprintf(stdout, "\nbuf_size=%ld",buf_size);
        // fprintf(stdout, "\nE2SM_KPM_IndicationMessage_t size=%ld",sizeof(E2SM_KPM_IndicationMessage_t));
        // decode_result = uper_decode_complete(NULL, &asn_DEF_E2SM_KPM_IndicationMessage, (void **)&indMsg, (char *)buffer, buf_size);
        // ATS_ALIGNED_CANONICAL_PER
        decode_result = asn_decode(0, ATS_ALIGNED_BASIC_PER, &asn_DEF_E2SM_KPM_IndicationMessage, (void **)&indMsg, buffer, buf_size);
        if (decode_result.code == RC_OK)
        {
                // xer_fprint(stdout, &asn_DEF_E2SM_KPM_IndicationMessage, indMsg);
                return indMsg;
        }
        else if (decode_result.code == RC_WMORE)
        {
                // xer_fprint(stderr, &asn_DEF_E2SM_KPM_IndicationMessage, indMsg);
                // fprintf(stderr, "\n MSG decode_result.consumed= %ld \n",decode_result.consumed);
                fprintf(stderr, "\n MSG RC_WMORE ");
                return NULL;
        }

        else
        {
                ASN_STRUCT_FREE(asn_DEF_E2SM_KPM_IndicationMessage, indMsg);
                return NULL;
        }
}

void e2sm_free_ric_indication_message(E2SM_KPM_IndicationMessage_t *indMsg)
{
        ASN_STRUCT_FREE(asn_DEF_E2SM_KPM_IndicationMessage, indMsg);
}
