FUNCTION z_ewm_get_batch_from_dlv.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     REFERENCE(IV_VBELN) TYPE  VBELN
*"  EXPORTING
*"     REFERENCE(ET_MATNR_CHARG) TYPE  MCHA_KEY_TABLE
*"----------------------------------------------------------------------
  DATA:
    ls_vbeln       TYPE bapidlv_range_vbeln,
    lt_vbeln       TYPE STANDARD TABLE OF bapidlv_range_vbeln,
    ls_dlv_item    TYPE bapidlvitem,
    lt_dlv_item    TYPE bapidlvitem_t,
    ls_dlv_control TYPE bapidlvbuffercontrol,
    ls_matnr_charg TYPE mcha_key,
    lv_lines       TYPE i.

  "1. Set read options
  ls_dlv_control-bypassing_buffer = abap_true.
  ls_dlv_control-item = abap_true.

  ls_vbeln-sign = 'I'.
  ls_vbeln-option = 'EQ'.
  ls_vbeln-deliv_numb_low = iv_vbeln.
  APPEND ls_vbeln TO lt_vbeln.

  "2. Get delivery
  CALL FUNCTION 'BAPI_DELIVERY_GETLIST'
    EXPORTING
      is_dlv_data_control = ls_dlv_control
    TABLES
      it_vbeln            = lt_vbeln
      et_delivery_item    = lt_dlv_item.

  "3. Fill return table
  LOOP AT lt_dlv_item INTO ls_dlv_item.
    MOVE-CORRESPONDING ls_dlv_item TO ls_matnr_charg.

    CHECK NOT ls_matnr_charg-charg IS INITIAL.

    READ TABLE et_matnr_charg TRANSPORTING NO FIELDS
    WITH KEY matnr = ls_matnr_charg-matnr
    charg = ls_matnr_charg-charg.
    IF sy-subrc NE 0.
      DESCRIBE TABLE et_matnr_charg LINES lv_lines.
      ADD 1 TO lv_lines.
      INSERT ls_matnr_charg INTO et_matnr_charg
      INDEX lv_lines.
    ENDIF.
  ENDLOOP.
ENDFUNCTION.
