class ZCL_IM_ERP_INT_CONF definition
  public
  final
  create public .

public section.

  interfaces IF_BADI_INTERFACE .
  interfaces /SCWM/IF_EX_ERP_INT_CONF .
protected section.
private section.
ENDCLASS.



CLASS ZCL_IM_ERP_INT_CONF IMPLEMENTATION.


  METHOD /scwm/if_ex_erp_int_conf~det_doctype.

    DATA lo_std TYPE REF TO /scwm/cl_def_im_erp_int_conf.

    CREATE OBJECT lo_std.
    CALL METHOD lo_std->/scwm/if_ex_erp_int_conf~det_doctype
      EXPORTING
        iv_lgnum            = iv_lgnum
        iv_erpbskey         = iv_erpbskey
        it_bapidlvpartner   = it_bapidlvpartner
        it_header_deadlines = it_header_deadlines
        is_header           = is_header
        it_extension1       = it_extension1
        it_extension2       = it_extension2
        iv_doccat           = iv_doccat
      RECEIVING
        ev_doctype          = ev_doctype.

************* Enhancement 1V5d *******************

    TYPES:
      BEGIN OF lsty_mat_btch,
        matnr TYPE matnr,
        werks TYPE werks_d,
        charg TYPE /scwm/de_charg,
      END OF lsty_mat_btch.

    DATA:
      lt_matbtch          TYPE STANDARD TABLE OF lsty_mat_btch,
      lo_send_to_bussys   TYPE REF TO /scmb/cl_business_system,
      ls_receiving_system TYPE /scwm/s_recieving_system,
      ls_extkey           TYPE /scmb/mdl_ext_matnr_str,
      lt_extkey           TYPE /scmb/mdl_ext_matnr_tab,
      lt_extprod          TYPE /scmb/mdl_extprod_key_tab,
      ls_intkey           TYPE /scwm/dlv_matid_batchno_str,
      lt_intkey           TYPE /scwm/dlv_matid_batchno_tab,
      lo_stock_fields     TYPE REF TO /scwm/cl_ui_stock_fields.

    BREAK-POINT ID zewmdevbook_1v5d.

    CLEAR ls_receiving_system.

    "1. Get BO with receiver infos
    ls_receiving_system-bskey = iv_erpbskey.
    TRY.
        lo_send_to_bussys =
        /scmb/cl_business_system=>get_instance( iv_erpbskey ).
      CATCH /scmb/cx_business_system. "#ec no_handler
        EXIT.
    ENDTRY.
    ls_receiving_system-logsys = lo_send_to_bussys->m_v_logsys.
    "2. Get RFC-destination
    TRY.
        CALL METHOD /scwm/cl_mapout=>get_rfc_destination
          EXPORTING
            iv_erplogsys       = ls_receiving_system-logsys
          IMPORTING
            ev_rfc_destination = ls_receiving_system-rfc_destination.
      CATCH /scwm/cx_mapout. "#ec no_handler
        EXIT.
    ENDTRY.

    "3. RFC-call: get product + batch from ERP DLV
    CALL FUNCTION 'Z_EWM_GET_BATCH_FROM_DLV'
      DESTINATION ls_receiving_system-rfc_destination
      EXPORTING
        iv_vbeln              = is_header-deliv_numb
      IMPORTING
        et_matnr_charg        = lt_matbtch
      EXCEPTIONS
        communication_failure = 1
        system_failure        = 2
        OTHERS                = 3.
    IF sy-subrc <> 0 OR lt_matbtch IS INITIAL.
      EXIT.
    ENDIF.

    "4. Convert matnr to matid (prefetch)
    LOOP AT lt_matbtch ASSIGNING FIELD-SYMBOL(<matbtch>).
      CLEAR ls_extkey.
      ls_extkey-ext_matnr = <matbtch>-matnr.
      COLLECT ls_extkey INTO lt_extkey.
    ENDLOOP.
    TRY.
        CALL FUNCTION '/SCMB/MDL_EXTPROD_READ_MULTI'
          EXPORTING
            iv_logsys = ls_receiving_system-logsys
            it_extkey = lt_extkey
          IMPORTING
            et_data   = lt_extprod.
      CATCH /scmb/cx_mdl. "#ec no_handler
        EXIT.
    ENDTRY.

    LOOP AT lt_matbtch ASSIGNING <matbtch>.
      "lt_extprod is sorted
      READ TABLE lt_extprod ASSIGNING FIELD-SYMBOL(<extprod>)
                 WITH KEY ext_matnr = <matbtch>-matnr
      BINARY SEARCH.
      IF sy-subrc = 0.
        ls_intkey-productid = <extprod>-matid.
        ls_intkey-batchno = <matbtch>-charg.
        APPEND ls_intkey TO lt_intkey.
      ENDIF.
    ENDLOOP.

    IF lt_intkey[] IS INITIAL.
      EXIT.
    ENDIF.

    IF NOT lo_stock_fields IS BOUND.
      CREATE OBJECT lo_stock_fields.
    ENDIF.

    "5. Check if batch master exists
    DO 10 TIMES.
      CALL METHOD lo_stock_fields->prefetch_batchid_by_no
        EXPORTING
          it_matid_charg    = lt_intkey
        IMPORTING
          et_batchid_extkey = DATA(lt_batch).
      SORT lt_batch BY batchno productid.
      LOOP AT lt_intkey ASSIGNING FIELD-SYMBOL(<intkey>).
        READ TABLE lt_batch ASSIGNING FIELD-SYMBOL(<batch>)
                   WITH KEY batchno = <intkey>-batchno
                          productid = <intkey>-productid
                   BINARY SEARCH.
        IF sy-subrc IS INITIAL AND
        <batch>-batchid IS NOT INITIAL. "batch exists
          DELETE lt_intkey.
        ENDIF.
      ENDLOOP.
      "Every batch exists -> lt_inkey is empty
      IF lt_intkey[] IS INITIAL.
        EXIT.
      ENDIF.
      WAIT UP TO 2 SECONDS.
      "Reset buffer for batches
      /scwm/cl_batch_appl=>cleanup( ).
      CLEAR lt_batch.
    ENDDO.

  ENDMETHOD.


  METHOD /scwm/if_ex_erp_int_conf~det_erp_dlvtype.

    DATA lo_std TYPE REF TO /scwm/cl_def_im_erp_int_conf.

    CREATE OBJECT lo_std.
    CALL METHOD lo_std->/scwm/if_ex_erp_int_conf~det_erp_dlvtype
      EXPORTING
        iv_lgnum       = iv_lgnum
        iv_erp_bskey   = iv_erp_bskey
        iv_doctype     = iv_doctype
        is_head        = is_head
      RECEIVING
        ev_erp_dlvtype = ev_erp_dlvtype.

  ENDMETHOD.


  METHOD /scwm/if_ex_erp_int_conf~det_itemtype.

    DATA lo_std TYPE REF TO /scwm/cl_def_im_erp_int_conf.

    CREATE OBJECT lo_std.
    CALL METHOD lo_std->/scwm/if_ex_erp_int_conf~det_itemtype
      EXPORTING
        iv_lgnum                   = iv_lgnum
        is_item                    = is_item
        iv_itmmapdif               = iv_itmmapdif
        iv_cw_rel                  = iv_cw_rel
        is_item_reference_order    = is_item_reference_order
        is_item_ref_purchase_order = is_item_ref_purchase_order
        iv_doctype                 = iv_doctype
      RECEIVING
        ev_itemtype                = ev_itemtype.

  ENDMETHOD.
ENDCLASS.
