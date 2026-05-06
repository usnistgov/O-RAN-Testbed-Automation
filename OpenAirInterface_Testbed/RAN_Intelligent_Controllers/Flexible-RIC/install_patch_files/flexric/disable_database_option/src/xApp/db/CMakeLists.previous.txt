# SPDX-License-Identifier: LicenseRef-CSSL-1.0


if(XAPP_DB STREQUAL "SQLITE3_XAPP")
  set(UE_ID_COMMON_E2SM_SRCS
    ../../sm/rc_sm/ie/asn/AMFPointer.c
    ../../sm/rc_sm/ie/asn/AMFRegionID.c
    ../../sm/rc_sm/ie/asn/AMFSetID.c
    ../../sm/rc_sm/ie/asn/AMF-UE-NGAP-ID.c
    ../../sm/rc_sm/ie/asn/ENB-ID.c
    ../../sm/rc_sm/ie/asn/ENB-UE-X2AP-ID-Extension.c
    ../../sm/rc_sm/ie/asn/ENB-UE-X2AP-ID.c
    ../../sm/rc_sm/ie/asn/GlobalENB-ID.c
    ../../sm/rc_sm/ie/asn/GlobalGNB-ID.c
    ../../sm/rc_sm/ie/asn/GlobalNgENB-ID.c
    ../../sm/rc_sm/ie/asn/GlobalNGRANNodeID.c
    ../../sm/rc_sm/ie/asn/GNB-CU-CP-UE-E1AP-ID.c
    ../../sm/rc_sm/ie/asn/GNB-CU-UE-F1AP-ID.c
    ../../sm/rc_sm/ie/asn/GNB-ID.c
    ../../sm/rc_sm/ie/asn/GUAMI.c
    ../../sm/rc_sm/ie/asn/GUMMEI.c
    ../../sm/rc_sm/ie/asn/MME-Code.c
    ../../sm/rc_sm/ie/asn/MME-Group-ID.c
    ../../sm/rc_sm/ie/asn/MME-UE-S1AP-ID.c
    ../../sm/rc_sm/ie/asn/NGENB-CU-UE-W1AP-ID.c
    ../../sm/rc_sm/ie/asn/NgENB-ID.c
    ../../sm/rc_sm/ie/asn/NG-RANnodeUEXnAPID.c
    ../../sm/rc_sm/ie/asn/PLMNIdentity.c
    ../../sm/rc_sm/ie/asn/RANUEID.c
    ../../sm/rc_sm/ie/asn/UEID-ENB.c
    ../../sm/rc_sm/ie/asn/UEID-EN-GNB.c
    ../../sm/rc_sm/ie/asn/UEID-GNB-CU-CP-E1AP-ID-Item.c
    ../../sm/rc_sm/ie/asn/UEID-GNB-CU-CP-E1AP-ID-List.c
    ../../sm/rc_sm/ie/asn/UEID-GNB-CU-CP-F1AP-ID-Item.c
    ../../sm/rc_sm/ie/asn/UEID-GNB-CU-F1AP-ID-List.c
    ../../sm/rc_sm/ie/asn/UEID-GNB-CU-UP.c
    ../../sm/rc_sm/ie/asn/UEID-GNB-DU.c
    ../../sm/rc_sm/ie/asn/UEID-GNB.c
    ../../sm/rc_sm/ie/asn/UEID.c
    ../../sm/rc_sm/ie/asn/UEID-NG-ENB-DU.c
    ../../sm/rc_sm/ie/asn/UEID-NG-ENB.c
  )

  #  add_subdirectory(sqlite3)
  add_library(e42_xapp_db_obj OBJECT 
                         ${UE_ID_COMMON_E2SM_SRCS}
                         db.c
                         sqlite3/sqlite3.c
                         sqlite3/sqlite3_wrapper.c
                         ../../util/time_now_us.c
                         )
  target_link_libraries(e42_xapp_db_obj PUBLIC asn1_nr_rrc)
else()
  message(FATAL_ERROR "Unknown XAPP_DB selected")
endif()

target_compile_definitions(e42_xapp_db_obj PRIVATE ${XAPP_DB} ${E2AP_VERSION} ${KPM_VERSION} )

