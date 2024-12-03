CREATE OR REPLACE PACKAGE PKG_TRIGONIS_UCS_XML
AS
/*------------------------------------------------------------------------------------------------*/
/*  Name                  :     PKG_TRIGNOS_UCS_XML                                               */
/*  Author                :     Hexaware Technologies                                             */
/*  Purpose               :     Creates company wise xml file generation with business logic      */
/*                                                                                                */
/*  Initial Verison       :                                                                       */
/*  <<Ver No>>        <<Modified By>>   <<Modified Date>>                                         */
/*      0.1           Benjamine S          15-Oct-2007                                            */
/*                                                                                                */
/*  Modified  Verison     :                                                                       */
/*  <<Ver No>>        <<Modified By>>    <<Modified Date>>    << Details >>                       */
/*      1.1           Benjamine S          03-Nov-2007        Business Logic added                */
/*------------------------------------------------------------------------------------------------*/
/*      1.2           Kalimuthu            06-Dec-2007     Modified to solve the following issues */
/*                             a) Partner Role map code is fetched for role id 1                  */
/*                             b) Activation Date is included in the main cursor                  */
/*                             c) refin_meiten attributes should come before closing the tag      */
/*                             d) txs_refi_data header is added in refin structure                */
/*------------------------------------------------------------------------------------------------*/
/*      1.3           Kalimuthu         27-Dec-2007        Modified to solve the following issues */
/*                   1) Residual Value population is wrong for contract split contract            */
/*                   2) End of accrual of MSZ before start of accrual  for extended contract      */
/*                   3) The population logic for field aufloesungsart is wrong.                   */
/*             If refityp = 'DARLEHEN',then this field should be populated as 'FINANZMATHEMATISCH'*/
/*------------------------------------------------------------------------------------------------*/
/*      1.4           Benjamine         28-Dec-2007        FTP the generated xml file to TLL location*/
/*------------------------------------------------------------------------------------------------*/
/*------------------------------------------------------------------------------------------------*/
/*      1.5           Kali              02-Jan-2008        Fix for the sit defect 8184,8185,8190,8195,8196*/
/*------------------------------------------------------------------------------------------------*/
/*------------------------------------------------------------------------------------------------*/
/*      1.6           Kali              04-Jan-2008       Fix for risk percentage calculation     */
/*      1.7           Kali              10-Jan-2008       Fix for refi_mieten aufloesung_beginn for 599 */
/*------------------------------------------------------------------------------------------------*/
/*------------------------------------------------------------------------------------------------*/
/*      1.8           Benjamine         14-Jan-2008       Vertragtyp Value calculation  method      */
/*                                                        changed with related screen CC367 changes */
/*---------------------------------------------------------------------------------------------------*/
/*      1.9           Kalimuthu         29.Jan.2008       Fix for invalid file id for file list pointer*/
/*--------------------------------------------------------------------------------------------------*/
/*      2.0           Kalimuthu         30-Jan-2008                                                 */
/*                                  1) Fix for defects 177769 and 177768 pick up logic for          */
/*                                     distribution channel and bus seg code                        */ 
/*                                     for level2      (Direct *)                                   */
/*                                  2) Txs Reference id is not required for company 05,83 and 599   */
/*                                     if lgs refin type is 'C'                                     */
/*                                  3) Temporary Table for accural objects to improve  performenance*/
/*                                  4) Fix for 17770 - refin interest rate                          */
/*                                  5) TXS REF ID in refin xml is assigned as vname                 */
/*                                  6) sparte is added for populate securtiy class method - rajagobal*/
/*                                  7) uc_price_profing_ms table is removed from main curosr        */
/*      2.1           Kalimuthu         14-Feb-2008                                                 
/*                                  1) Fix for defects 17984 restwert/@faelligkeit                  
/*                                     removed lease end dt +1. New Rule: lease end dt                  
/*                                  2) Fix for defects 17985 for company 599                        
/*                                      a) <refi_mieten_rw> for all contracts with a "Schlusszahlung", 
/*                                         which are running in the base period (residual value = "Schlusszahlung")
/*
/*                                      b) <refi_mieten> for all contracts with a "Schlusszahlung", 
/*                                      which are running in the extension period 
/*                                  2) Fix for defects 17982 and 18010
/*      2.2           Kalimuthu         21-Feb-2008                                                 
/*                                      To Handle Multiple object package number
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/

/*-----------------------------------------------------------*/
/*  Whenever source is updated ,                             */
/*  update the version number in following variable.         */
/*-----------------------------------------------------------*/
g_src_version   VARCHAR2(4) := '2.1';

/*-----------------------------------*/
/*  Global Record Type Declaration   */
/*-----------------------------------*/
  
  -- To Store company number 001 32 bit code for refi interest rate calculation
   v_comp_prtnr_id_01   UC_COMPANY_MS.PRTNR_ID%TYPE; 

   TYPE vertragsheader_typ IS RECORD (
        vname                                              VARCHAR2(32),
        gesellschaft                                       VARCHAR2(3),
        geschaeftsstelle                                   VARCHAR2(3),
        plz                                                UC_ADDRESS_INFO_TX.ZIP_CD%TYPE,
        branche                                            VARCHAR2(3),
        geschaeftsbereich                                  VARCHAR2(15),
        rating                                             VARCHAR2(2),
        objektart                                          VARCHAR2(3),
        vertriebsweg                                       VARCHAR2(15),
        ratenstruktur                                      VARCHAR2(15),
        vbeginn                                            date,
        vbeginn1                                           date,
        vende_grundlaufzeit                                date,
        vende_verlaengerung                                date,
        naechste_sollstellung                              date,
        zugangsdatum                                       date,
        vertragstyp                                        VARCHAR2(35),
        vertragstyp_erweitert                              uc_trgns_pdt_map_ms.elmntry_pdt_name%TYPE,
        vertragsart                                        VARCHAR2(6),
        intern_kalkuzins                                   uc_refin_ms.refin_int_rate%TYPE,
        refi_kalkuzins                                     uc_sub_segment_ms.refin_int_rate%TYPE,
        geschaeftsfeld                                     VARCHAR2(50),
        zahlungsweise                                      VARCHAR2(50),
        mahnstufe                                          NUMBER,
        rechenart_mk                                       VARCHAR2(50),
        status                                             VARCHAR2(15),
        anschaffungswert                                   uc_pricing_ms.acqstn_value%TYPE
   );
   TYPE mietkaufvermogen_typ IS RECORD
   (
      createMietkaufvermogen       BOOLEAN,
      restbuchwert_betrag          UC_ACCRL_COLTR_MS.LINEAR_ACCRL_AMT%TYPE
   );

   TYPE msz_typ IS RECORD (
      createMSZ               BOOLEAN,
      faelligkeit             DATE,
      aufloesung_beginn       DATE,
      aufloesung_ende         DATE,
      ende_aufloesungszeit    DATE,
      msz_betrag              uc_pricing_ms.acqstn_value%TYPE,
      msz_rap_betrag          uc_pricing_ms.acqstn_value%TYPE
   );
   
   TYPE   nachgeschaeft_typ IS RECORD 
   (
      createRestwert       BOOLEAN,
      faelligkeit        DATE,
      betrag            UC_PAYMENT_MS.RSDL_VALUE%TYPE
   );
   
 

   TYPE rate_explizit_typ is RECORD
   (
      betrag            uc_lease_rntl_tx.end_rate_amt%type,
      faellig_ab        date,
      gueltig_bis       date,
      ratenabstand      varchar2(2)
   );
   
   TYPE rate_explizit_tab IS TABLE OF rate_explizit_typ INDEX BY BINARY_INTEGER;

   TYPE zlg_typ is RECORD
   (
      ratengueltigkeit  VARCHAR2(30),
      betrag            uc_lease_rntl_tx.end_rate_amt%type,
      termin            datE
   );

   TYPE nutzungsentgelt_typ is RECORD
   (
      createNutzungsentgelt      BOOLEAN,
      betrag                     uc_lease_rntl_tx.end_rate_amt%type,
      faelligkeit                date
   );

  TYPE   zahlungsplan_typ IS RECORD 
   ( 
      createZahlungpalan      BOOLEAN,
      ratentyp                VARCHAR2(10),
      linearisierungsart      VARCHAR2(30), 
      zlg                     zlg_typ,
      rate_explizit           rate_explizit_tab
   );


   TYPE restwert_typ IS RECORD
   (
      createRestwert       BOOLEAN,
      faelligkeit        DATE,
      rw_betrag          uc_payment_ms.rsdl_value%TYPE,
      rw_betrag_vor_verl uc_payment_ms.rsdl_value%TYPE
   );

   TYPE  verwaltungskosten_typ IS RECORD 
   (
      createRestwert       BOOLEAN,
      anfang_betrag        NUMBER (17, 4),
      laufend_betrag        NUMBER (17,4),
      ende_betrag        NUMBER (17, 4)
   );
 
  TYPE  risikovorsorge_typ IS RECORD 
   (
      createRestwert       BOOLEAN,
      prozent              NUMBER (7,4),
      bezugszeitraum       VARCHAR2(10)
   );
  
   TYPE  refi_mieten_typ IS RECORD 
   (
      createRefinMeiten             BOOLEAN,
      barwert_betrag                uc_refin_ms.stlmnt_sales_price%type,
      rap_hgb_betrag                uc_accrl_coltr_ms.linear_outstdng_prncpl_amt%type,
      aufloesung_beginn             DATE,
      aufloesung_ende               DATE,
      zins                          uc_refin_ms.stlmnt_int_rate%type,
      ende_aufloesungszeit          DATE,
      aufloesung_prap_auf_null      VARCHAR2(3),
      faelligkeit_barwert           DATE,
      aufloesungsart                VARCHAR2(30),
      refityp                       VARCHAR2(30),
      rechenart                     VARCHAR2(30),
      zlg                           zlg_typ,
      rate_explizit                 rate_explizit_tab,
      --for refin_mieten_rw
      restwert_refi_betrag          uc_accrl_coltr_ms.linear_outstdng_prncpl_amt%type
   );

  
   TYPE n_tabtype IS TABLE OF VARCHAR2 (100)  INDEX BY BINARY_INTEGER;

   TYPE v_typ_linear_amt IS TABLE OF UC_ACCRL_COLTR_MS.LINEAR_OUTSTDNG_PRNCPL_AMT%TYPE INDEX BY BINARY_INTEGER;

	TYPE v_typ_accrl_obj IS TABLE OF UC_ACCRL_COLTR_MS.ACCRL_OBJ%TYPE INDEX BY BINARY_INTEGER;
	TYPE v_typ_accrl_durtn IS TABLE OF UC_ACCRL_COLTR_MS.ACCRL_DURTN%TYPE INDEX BY BINARY_INTEGER;
   
   /************* Start Calculation Package Types  */
   TYPE rec_riskvalues IS RECORD (
      val   NUMBER
   );

   TYPE rec_riskngevalues IS RECORD (
      val   NUMBER
   );

   TYPE rec_security_typ_bonitat IS RECORD (
      secu_typ_cd     uc_security_type_dn.secu_typ_cd%TYPE,
      bonitat         uc_partner_ms.cr_worth%TYPE,
      secu_provider   uc_partner_ms.prtnr_id%TYPE
   );

   TYPE rec_security_class IS RECORD (
      secu_calcn_order   uc_security_type_dn.calcn_order%TYPE,
      secu_desc          uc_security_type_dn.secu_desc%TYPE,
      secu_bonitat       uc_partner_ms.cr_worth%TYPE,
      secu_typ_cd        uc_security_type_dn.secu_typ_cd%TYPE,
      secu_grp           uc_security_type_dn.secu_grp%TYPE,
      secu_provider      uc_partner_ms.prtnr_id%TYPE,
      secu_risk_pct      NUMBER
   );

   TYPE tab_security_class IS TABLE OF rec_security_class
      INDEX BY BINARY_INTEGER;

   p_tab_security_class          tab_security_class;
   p_tab_security_class_new      tab_security_class;

   TYPE tab_security_typ_bonitat IS TABLE OF rec_security_typ_bonitat
      INDEX BY BINARY_INTEGER;

   p_tab_security_typ_bonitat    tab_security_typ_bonitat;

   TYPE arrriskvalues IS TABLE OF rec_riskvalues
      INDEX BY BINARY_INTEGER;

   TYPE arrriskngevalues IS TABLE OF rec_riskngevalues
      INDEX BY BINARY_INTEGER;


   -- p_supl_id and p_confirm_flg were added by Rajagopal on 20-11-2007 and 03-12-2007 respectively for CEAnF implementation
   -- p_sparte was added by Rajagopal on 05-01-2008 for identify the distribution channel of the contract.

   PROCEDURE POPULATE_SECURITY_CLASS (
           v_distrib_chnl_cd UC_DISTRIB_CHNL_MS.DISTRIB_CHNL_CD%TYPE,
           v_bus_seg_cd   UC_BUS_SEG_MS.BUS_SEG_CD%TYPE,
           v_refin_typ_cd UC_SUB_SEGMENT_MS.REFIN_TYP%TYPE,
           v_cr_worth     UC_PARTNER_MS.CR_WORTH%TYPE,
           p_subseg_cd    UC_SUB_SEGMENT_MS.SUBSEG_CD%TYPE,
           p_supl_id	UC_OBJECT_PACKAGE_MS.SUPL_ID%TYPE,
           p_confirm_flg VARCHAR2,
           p_lgs_flg VARCHAR2, 
           p_sparte VARCHAR2
   );


   PROCEDURE proc_order_security_class;


    PROCEDURE  PROC_GEN_SECU_CLASS_ARR (p_tab_security_class IN tab_security_class,
                                     vSecurityClass OUT VARCHAR2,
                                     vBonitat OUT VARCHAR2, 
                                     vSuppliers OUT VARCHAR2);

   /************* End of Calculation Package Types  */
   PROCEDURE main_proc (
      stichtag_date               IN       DATE,
      inp_calc_fact_book_dt_flg   IN       VARCHAR2,
      inp_calc_fact_dt            IN       DATE,
      inp_version                 IN       VARCHAR2,
      inp_extn_period             IN       VARCHAR2,
      inp_extn_period_lsva_jz     IN       VARCHAR2,
      inp_extn_period_lsva_hz     IN       VARCHAR2,
      inp_extn_period_lsva_qz     IN       VARCHAR2,
      inp_extn_period_lsva_mz     IN       VARCHAR2,
      inp_extn_period_lsta_jz     IN       VARCHAR2,
      inp_extn_period_lsta_hz     IN       VARCHAR2,
      inp_extn_period_lsta_qz     IN       VARCHAR2,
      inp_extn_period_lsta_mz     IN       VARCHAR2,
      inp_extn_period_dlva_jz     IN       VARCHAR2,
      inp_extn_period_dlva_hz     IN       VARCHAR2,
      inp_extn_period_dlva_qz     IN       VARCHAR2,
      inp_extn_period_dlva_mz     IN       VARCHAR2,
      inp_extn_period_dlta_jz     IN       VARCHAR2,
      inp_extn_period_dlta_hz     IN       VARCHAR2,
      inp_extn_period_dlta_qz     IN       VARCHAR2,
      inp_extn_period_dlta_mz     IN       VARCHAR2,
      v_return_code               OUT      NUMBER
   );

END PKG_TRIGONIS_UCS_XML;
/
CREATE OR REPLACE PACKAGE BODY PKG_TRIGONIS_UCS_XML
AS
   v_pkg_id              VARCHAR2 (30)      := 'TRIGONIS_UCS_XML';
   v_pdt_typ             VARCHAR2 (30)      := 'TRIGONIS_MISSING_PDT';
                                                              -- Defect 15009 
   lf_file_handle        UTL_FILE.file_type;
   lv_file_handle        UTL_FILE.file_type;
   lf_pdt_file_handle    UTL_FILE.file_type;
   v_refin_id            VARCHAR2 (30)      := 'UCS_REFINANCE_XML';
   v_refin_filename      VARCHAR2 (50);
   v_refin_output        UTL_FILE.file_type;
   lf_refinfile_handle   UTL_FILE.file_type;
   v_new_comp            BOOLEAN := TRUE;
   refin_result          VARCHAR2(8000);
   v_refin_cmp_no        NUMBER (4)         := 0;
   v_file_open_err       EXCEPTION;
   v_deleting_err        EXCEPTION;
   v_skip_record         EXCEPTION;
   v_proc_err            EXCEPTION;
   v_fatal_excp          EXCEPTION;
   v_contract_filenames                n_tabtype;
   v_contract_filecnt                  NUMBER(5) := 0;
   v_refin_filenames                   n_tabtype;
   v_refin_filecnt                     NUMBER(5) := 0;
   v_no_of_refin_cnt                   NUMBER(5) := 0;
   v_bulk_fetch_cnt                CONSTANT NUMBER(6) := 10000;   
   v_stichtag_date                      Date;
   g_inp_calc_fact_book_dt_flg          VARCHAR2(1);
   g_inp_calc_fact_dt                   DATE;
   g_inp_version                        VARCHAR2(10);
   g_inp_extn_period                    VARCHAR2(10);
   g_inp_extn_period_lsva_jz            VARCHAR2(10);
   g_inp_extn_period_lsva_hz            VARCHAR2(10);
   g_inp_extn_period_lsva_qz            VARCHAR2(10);
   g_inp_extn_period_lsva_mz            VARCHAR2(10);
   g_inp_extn_period_lsta_jz            VARCHAR2(10);
   g_inp_extn_period_lsta_hz            VARCHAR2(10);
   g_inp_extn_period_lsta_qz            VARCHAR2(10);
   g_inp_extn_period_lsta_mz            VARCHAR2(10);
   g_inp_extn_period_dlva_jz            VARCHAR2(10);
   g_inp_extn_period_dlva_hz            VARCHAR2(10);
   g_inp_extn_period_dlva_qz            VARCHAR2(10);
   g_inp_extn_period_dlva_mz            VARCHAR2(10);
   g_inp_extn_period_dlta_jz            VARCHAR2(10);
   g_inp_extn_period_dlta_hz            VARCHAR2(10);
   g_inp_extn_period_dlta_qz            VARCHAR2(10);
   g_inp_extn_period_dlta_mz            VARCHAR2(10);

   v_curr_comp_no                       uc_company_ms.comp_num%type;
   v_curr_contract_file                 VARCHAR2(50);
   v_curr_refin_file                    VARCHAR2(50);
   v_contract_fp                        UTL_FILE.FILE_TYPE;
   v_refin_fp                           UTL_FILE.FILE_TYPE;
   v_filelist_fp                        UTL_FILE.FILE_TYPE;
   v_missing_pdt                        NUMBER(10) := 0 ;
   v_skip_cnt                           NUMBER(20) := 0 ;
   v_obj_pkg                            VARCHAR2 (2000)                      := NULL;  
   TYPE contract_other_info_typ IS RECORD
   (
      acqstn_value                uc_pricing_ms.acqstn_value%TYPE,
      down_pymt                   uc_payment_ms.down_pymt%TYPE,
      pkt_cd                      uc_refin_ms.pkt_cd%TYPE,
      rsdl_value                  uc_payment_ms.rsdl_value%TYPE,
      rsdl_value_org              uc_payment_ms.rsdl_value%TYPE,
      cr_worth                    uc_partner_ms.cr_worth%TYPE,
      first_instlmnt_dt           uc_payment_ms.lease_bill_pay_dt%TYPE,
      segcd_sh_nm                uc_bus_seg_ms.name%type,
      bus_seg_cd_sh_nm           uc_bus_seg_ms.short_name%type,
      districhnl_sh_nm            uc_distrib_chnl_ms.short_name%type := null,
      districhnl_name             uc_distrib_chnl_ms.NAME%type,
      incrse_first_instlmnt_pct   uc_payment_ms.incrse_first_instlmnt_pct%TYPE,
      spl_post_bus_expct_pct      uc_payment_ms.expct_post_sale_pft_pct%TYPE,
      pymt_cd                     uc_payment_ms.pymt_cd%TYPE,
      spl_rate                    uc_payment_ms.utlztn_charge%TYPE,
      rv_redn_fact                uc_payment_ms.rv_redn_fact%TYPE,
      pymt_rntl_typ_codes_cd      uc_payment_ms.rntl_typ_codes_cd%TYPE,
      pymt_prmsbl_pymt_modes      uc_payment_ms.prmsbl_pymt_modes%TYPE,
      vat_cd                      uc_payment_ms.vat_cd%TYPE,
      rntl_typ_codes_cd           uc_rntl_typ_ms.rntl_typ_codes_cd%TYPE,
      rntl_typ_codes_desc         uc_rntl_typ_ms.cd_desc%TYPE,
      prmsbl_pymt_modes           uc_cntrct_codes_ms.cd_desc%TYPE,
      prmsbl_pymt_modes_cd        uc_cntrct_codes_ms.codes_cd%TYPE,                                                  --{ 
      utlztn_charge               uc_payment_ms.utlztn_charge%TYPE,
      utlztn_frm                  uc_payment_ms.utlztn_frm%TYPE,
      refin_cd                    uc_refin_codes_ms.refin_cd%TYPE,
      prchse_comp_cd              uc_refin_ms.prchse_comp_cd%TYPE,
      refin_typ                   uc_refin_ms.refin_typ%TYPE,
      stlmnt_int_rate             uc_refin_ms.stlmnt_int_rate%TYPE,
      refin_int_rate              uc_refin_ms.refin_int_rate%TYPE,
      stlmnt_sales_price          uc_refin_ms.stlmnt_sales_price%TYPE,
      sale_dt                     uc_refin_ms.sale_dt%TYPE,
      refin_start_dt              uc_refin_ms.sale_dt%TYPE,
      num_of_sold_mon             uc_refin_ms.num_of_sold_mon%TYPE,
      trnsfr_num                  uc_refin_ms.trnsfr_num%TYPE,
      prchse_comp_num             uc_company_ms.comp_num%TYPE,
      refin_prtnr_num             uc_partner_ms.prtnr_num%TYPE,
      berites                     VARCHAR2(1) := 'N',
      ende_grundlaufzeit          DATE,
      ende_verlaengerung          DATE,
      supplier                    UC_OBJECT_PACKAGE_MS.supl_id%TYPE,
      fincl_accrl_amt             UC_ACCRL_COLTR_MS.FINCL_ACCRL_AMT%TYPE,
      linear_accrl_amt            UC_ACCRL_COLTR_MS.FINCL_ACCRL_AMT%TYPE,
      fincl_accrl_amt_npo         UC_ACCRL_COLTR_MS.FINCL_ACCRL_AMT%TYPE,
      linear_accrl_amt_npo        UC_ACCRL_COLTR_MS.FINCL_ACCRL_AMT%TYPE,
      accr_max_cntrct_durtn       UC_SUB_SEGMENT_MS.MAX_CNTRCT_DURTN%TYPE,
      ende_aufloesungszeit        DATE,
      old_cntrct_stat_num         UC_CONTRACT_MS.cntrct_stat_num%TYPE,
      lgs_refin_typ_desc          uc_refin_codes_ms.refin_cd%TYPE,
      sparte                      VARCHAR2(200),
      repymt_start_dt             date
   );

   v_vertragsheader_rec                 vertragsheader_typ;
   v_msz_rec                            msz_typ;
   v_mietkaufvermogen_rec               mietkaufvermogen_typ;
   v_nachgeschaeft_rec                  nachgeschaeft_typ ;
   v_restwert_rec                       restwert_typ;
   v_verwaltungskosten_rec              verwaltungskosten_typ ;
   v_risikovorsorge_rec                 risikovorsorge_typ ;
   v_zahlungsplan_rec                   zahlungsplan_typ;   
   v_nutzungsentgelt_rec                nutzungsentgelt_typ;
   v_refi_mieten_rec                    refi_mieten_typ;
   v_refi_mieten_rw_rec                 refi_mieten_typ;
   v_refi_rw_rec                        refi_mieten_typ;


   v_cntr_other_info                    contract_other_info_typ;

   v_fn_ret                      VARCHAR2(2);

   RESULT                          varchar2(8000);
-------------------------------
   CURSOR contract_dtl_cursor IS
--   SELECT   /*+ FIRST_ROWS INDEX(a UK_SUBSEG_SEGCD_SUBSEG_CD) */
   SELECT   
          cmp.comp_num           comp_num, 
          prt.prtnr_num          prtnr_num,
          cnt.cntrct_num         cntrct_num, 
          seg.seg_num            seg_num,
          sseg.subseg_num        subseg_num, 
          sseg.subseg_cd         subseg_cd,
          seg.seg_cd             seg_cd, 
          cnt.cntrct_end_dt      cntrct_end_dt,
          cnt.cntrct_way         cntrct_way,
          sseg.cntrct_stat_num   cntrct_stat_num,
          sseg.lease_bgn_dt      lease_bgn_dt,
          sseg.open_instlmnt     open_instlmnt,
          sseg.actv_dt              actv_dt,
          cnt.comp_prtnr_id      comp_prtnr_id,
          cnt.bank_coll_flg      bank_coll_flg, 
          cnt.appln_dt           appln_dt,
          seg.elmntry_pdt_cd     elmntry_pdt_cd, 
          prt.dub_flg            dub_flg,
          cnt.distrib_chnl_cd    distrib_chnl_cd, 
          prt.prtnr_id           prtnr_id,
          prt.cr_worth           prtnr_cr_worth,
          cnt.cr_worth           cr_worth,
          sseg.refin_int_rate    refin_int_rate,
          sseg.cntrct_durtn      cntrct_durtn,
          sseg.lease_end_dt      lease_end_dt,
          sseg.min_fnl_pymt      min_fnl_pymt,
          sseg.max_cntrct_durtn  max_cntrct_durtn,
          sseg.min_cntrct_durtn  min_cntrct_durtn,
          sseg.refin_typ         refin_typ, 
          sseg.intrnl_rate_rtn  intrnl_rate_rtn,
          sseg.prtnr_infn_dt     prtnr_infn_dt,
          nvl(sseg.own_comp,'X') own_comp,
          cnt.cntrct_cd          cntrct_cd, 
          nvl(sseg.old_subseg_cd,'X')    old_subseg_cd,
          sseg.lgs_refin_typ     lgs_refin_typ,
          cntrct_start_dt        cntrct_start_dt, 
          cnt.bus_seg_cd         bus_seg_cd,
          seg.dplstk_elmntry_pdt_cd dplstk_elmntry_pdt_cd,
          sseg.amrtzatn_durtn       amrtzatn_durtn,
          elm.elmntry_pdt_name      elmntry_pdt_name, 
          elm.rv_flg                rv_flg,
          mp.ms_pdt_id              ms_pdt_id, 
          mp.ms_pdt_name            ms_pdt_name,
          mp.pdt_grp_id             pdt_grp_id
     FROM uc_contract_ms cnt,
          uc_segment_ms seg,
          uc_sub_segment_ms sseg,
          uc_company_ms cmp,
          uc_partner_ms prt,
          uc_elmntry_product_ms elm,
          uc_master_product_ms mp
    WHERE sseg.cntrct_stat_num = 400
      AND elm.elmntry_pdt_typ_flg = 'F'
      AND cnt.cntrct_cd = seg.cntrct_cd
      AND sseg.seg_cd = seg.seg_cd
      AND cmp.prtnr_id = cnt.comp_prtnr_id
      AND prt.prtnr_id = cnt.prtnr_id
      AND elm.elmntry_pdt_id = seg.elmntry_pdt_cd
      AND mp.ms_pdt_id = elm.ms_pdt_id
      ORDER BY cmp.comp_num;
   
   CURSOR LESSEE_CUR(v_subseg_cd in UC_SUB_SEGMENT_MS.SUBSEG_CD%TYPE) IS 
   SELECT  sseg.LESSEE_CHNG_DT,subseg_cd,old_subseg_cd,sseg.cntrct_stat_num
   FROM uc_sub_segment_ms  sseg
   START WITH SUBSEG_CD = v_subseg_cd
   CONNECT BY PRIOR OLD_SUBSEG_CD = SUBSEG_CD
   order by sseg.LESSEE_CHNG_DT;

   CURSOR cur_obj_pkg (obj_subseg_cd uc_sub_segment_ms.subseg_cd%TYPE)
   IS
   SELECT DISTINCT obj_pack.obj_pkg_num
   FROM uc_object_package_ms obj_pack, uc_subseg_obj_pkg_tx sseg_obj
   WHERE obj_pack.obj_pkg_id = sseg_obj.obj_pkg_cd
   AND sseg_obj.subseg_cd = obj_subseg_cd
   AND sseg_obj.valid_frm_dt <= v_stichtag_date --Defect 14292
   AND sseg_obj.valid_till_dt >= v_stichtag_date --Defect 14292
   AND del_flg = 'N';

   CURSOR lease_rntl_cur (p_pymt_cd in uc_lease_rntl_tx.pymt_cd%type) IS 
   SELECT DISTINCT
           frm_dt,
           nvl(a.lease_rate_amt,0) lease_rate_amt,
           to_dt,
           redmtn_amt,
           a.end_rate_amt end_rate_amt,
           lease_recd_id_flg,
            DECODE (UPPER (c.codes_cd),
                     'YRLY', 12,
                     'HALF', 6,
                     'QUAR', 3,
                     'MON', 1,
                     1
                    ) pymt_md
   FROM	uc_lease_rntl_tx a,uc_cntrct_codes_ms c
   WHERE a.pymt_cd = p_pymt_cd
   and a.LEASE_RECD_ID_FLG = 'M'-- Added new condition to avoid picking up vat record --defect 13686
   AND a.prmsbl_pymt_modes = c.cntrct_codes_cd
   ORDER BY FRM_DT,TO_DT;

/*--$$$$       AND l.lease_recd_id_flg != 'Z'
         AND l.to_dt <= pv_lease_end_dt;
*/
   --LEASE_RNTL_CD is unique for these records 



   CURSOR cur_old_sub_seg_cd (v_subseg_cd uc_sub_segment_ms.subseg_cd%TYPE)
   IS
   SELECT     subseg_cd
      FROM uc_sub_segment_ms
   START WITH subseg_cd = v_subseg_cd
   CONNECT BY PRIOR old_subseg_cd = subseg_cd
   ORDER BY subseg_cd DESC;

   TYPE cur_contract_tab IS TABLE OF contract_dtl_cursor%ROWTYPE INDEX BY BINARY_INTEGER;
   TYPE cur_lease_rntl_tab IS TABLE OF lease_rntl_cur%ROWTYPE INDEX BY BINARY_INTEGER;

   v_curr_contract_rec                      contract_dtl_cursor%ROWTYPE;
   v_cur_contract_tab                       cur_contract_tab;
   v_cur_lease_rntl_tab                     cur_lease_rntl_tab;
   g_next_installement_dt                   DATE;


   PROCEDURE PROC_FETCH_LEASE_RNTL_DTL (p_pymt_cd in uc_lease_rntl_tx.pymt_cd%type)
   IS
   v_multi_fact   NUMBER(3);
   BEGIN
          OPEN  lease_rntl_cur (p_pymt_cd);
          BEGIN
                  v_cur_lease_rntl_tab.DELETE;
          EXCEPTION
          WHEN OTHERS
          THEN
                  NULL;
          END;
          FETCH lease_rntl_cur BULK COLLECT INTO v_cur_lease_rntl_tab;

          CLOSE lease_rntl_cur;
         -- To find nachstesollstellung
         ---Added the following rules to determine next installment date.-Defect 13890
         IF(v_curr_contract_rec.comp_num NOT IN(599, 596, 597))
         THEN
            IF(v_cur_lease_rntl_tab.COUNT > 0)
            THEN
              FOR J IN v_cur_lease_rntl_tab.FIRST..v_cur_lease_rntl_tab.LAST
              LOOP
                  IF((v_cur_lease_rntl_tab(J).FRM_DT <= v_stichtag_date AND v_cur_lease_rntl_tab(J).TO_DT >= v_stichtag_date) )
                  THEN
                          v_multi_fact := v_cur_lease_rntl_tab(J).pymt_md;

                          SELECT add_months (v_cur_lease_rntl_tab(J).FRM_DT, floor((months_between(v_stichtag_date,v_cur_lease_rntl_tab(J).FRM_DT)/v_multi_fact)+1)*v_multi_fact)
                          INTO g_next_installement_dt
                          FROM DUAL;
                   END IF;
               END LOOP;
            END IF;
         END IF;
   END PROC_FETCH_LEASE_RNTL_DTL;

   PROCEDURE PROC_BUILD_ACCR_OBJECTS IS
   BEGIN
         pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','Start Time to build UC_ACCRUAL_RPT_TRGNS_TP   '||to_char(sysdate,'dd-mm.yyyyhh24mi:ss'),'','');
         pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','Deleting records in UC_ACCRUAL_RPT_TRGNS_TP Date = ','',v_stichtag_date);

         DELETE FROM UC_ACCRUAL_RPT_TRGNS_TP;

         COMMIT;

         pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','Inserting <MK Accural Object> records in UC_ACCRUAL_RPT_TRGNS_TP Date = ','',v_stichtag_date);
         --MK Object
         INSERT INTO UC_ACCRUAL_RPT_TRGNS_TP
         (
             accrl_key ,
             accrl_obj ,
             last_accr_relse_dt 
         )
         SELECT accr_ms_1.SUBSEG_CD,'MKMAX', MAX(relse_frm_dt) last_accr_relse_dt 
         FROM UC_ACCRL_COLTR_MS accr_ms_1,UC_SUB_SEGMENT_MS SSEG
         WHERE  accr_ms_1.SUBSEG_CD = sseg.subseg_cd
         AND ACCRL_OBJ = 'MK' 
         AND TRNSCTN_TYP = 200
         AND SSEG.CNTRCT_STAT_NUM = '400'
         GROUP BY accr_ms_1.SUBSEG_CD;
                   

         INSERT INTO UC_ACCRUAL_RPT_TRGNS_TP
         (
            accrl_key ,
            accrl_obj ,
            linear_accrl_amt ,
            fincl_accrl_amt  ,
            LINEAR_OUTSTDNG_PRNCPL_AMT,
            FINCL_OUTSTDNG_PRNCPL_AMT ,
            accrl_durtn ,
            first_accr_relse_dt,
            last_accr_relse_dt 
         )
         SELECT ACCR_MS.subseg_cd,accr_ms.ACCRL_OBJ,accr_ms.LINEAR_ACCRL_AMT,accr_ms.FINCL_ACCRL_AMT,0,0,accr_ms.ACCRL_DURTN,null,null
         FROM UC_ACCRUAL_RPT_TRGNS_TP accrl_rpt,UC_ACCRL_COLTR_MS ACCR_MS 
         WHERE accrl_rpt.accrl_key = accr_ms.SUBSEG_CD 
         AND accrl_rpt.accrl_obj = 'MKMAX' 
         AND accr_ms.ACCRL_OBJ = 'MK' 
         AND accr_ms.TRNSCTN_TYP = 200 
         AND accr_ms.RELSE_FRM_DT = v_stichtag_date
         AND accr_ms.CANCL_FLG is NULL;

         COMMIT;


         pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','Inserting <PRAP Accural Object> records in UC_ACCRUAL_RPT_TRGNS_TP Date = ','',v_stichtag_date);

          --PRAP_FVK
         INSERT INTO UC_ACCRUAL_RPT_TRGNS_TP
         (
            accrl_key ,
            accrl_obj ,
            accrl_durtn ,
            first_accr_relse_dt,
            last_accr_relse_dt 
         )			   
         SELECT PKT_CD,ACCRL_OBJ||'MAX', max(accrl_durtn),min(relse_frm_dt),MAX(relse_frm_dt) last_accr_relse_dt
         FROM uc_accrl_coltr_ms  accr_ms_1
         where (accrl_obj = 'MK_Verwk'
         or accrl_obj = 'PRAP_FVK')
         AND exists 
         (
            SELECT refin.pkt_cd
            FROM uc_sub_segment_ms sseg, uc_refin_ms refin
            WHERE refin.subseg_cd = sseg.subseg_cd
            AND sseg.cntrct_stat_num = '400'
            AND accr_ms_1.pkt_cd = refin.pkt_cd
         )
         group by pkt_cd,ACCRL_OBJ;

         INSERT INTO UC_ACCRUAL_RPT_TRGNS_TP
         (
            accrl_key ,
            accrl_obj ,
            linear_accrl_amt ,
            fincl_accrl_amt  ,
            LINEAR_OUTSTDNG_PRNCPL_AMT,
            FINCL_OUTSTDNG_PRNCPL_AMT ,
            accrl_durtn ,
            first_accr_relse_dt,
            last_accr_relse_dt 
         )
         SELECT 
            accr_ms.pkt_cd, accr_ms.accrl_obj, accr_ms.linear_accrl_amt, accr_ms.fincl_accrl_amt,
            accr_ms.linear_outstdng_prncpl_amt, accr_ms.fincl_outstdng_prncpl_amt, accr_ms.accrl_durtn,
            null, null
         FROM UC_ACCRUAL_RPT_TRGNS_TP accr_rpt,uc_accrl_coltr_ms accr_ms
         WHERE accr_rpt.accrl_key = accr_ms.pkt_cd
         and accr_rpt.accrl_obj IN('PRAP_FVKMAX','MK_VerwkMAX')
         AND accr_ms.relse_frm_dt = v_stichtag_date
         AND (accr_ms.accrl_obj = 'PRAP_FVK' OR accr_ms.accrl_obj = 'RAP_Zi'
         OR accr_ms.accrl_obj = 'RAP_NPO'  or accr_ms.accrl_obj = 'MK_Verwk'
         )
         AND accr_ms.trnsctn_typ = '200'
         AND accr_ms.cancl_flg IS NULL;

         commit;
         pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','Inserting <MSZ Accural Object> records in UC_ACCRUAL_RPT_TRGNS_TP Date = ','',v_stichtag_date);

         INSERT INTO UC_ACCRUAL_RPT_TRGNS_TP
         (
               accrl_key ,
               accrl_obj ,
               linear_accrl_amt ,
               fincl_accrl_amt  ,
               first_accr_relse_dt,
               last_accr_relse_dt
         )SELECT
               sseg.SUBSEG_CD,ACCRL_OBJ,
               SUM
               (
                       CASE WHEN  RELSE_FRM_DT  > v_stichtag_date  AND accr_ms.cancl_flg is null
                       THEN
                               NVL(LINEAR_ACCRL_AMT,0)
                       ELSE    0
                       END
               ),
               SUM
               (
                       CASE WHEN  RELSE_FRM_DT  > v_stichtag_date AND accr_ms.cancl_flg is null
                       THEN
                               NVL(FINCL_ACCRL_AMT,0)
                       ELSE    0
                       END
               ),
               MIN(accr_ms.RELSE_FRM_DT),
               MAX(accr_ms.RELSE_FRM_DT)
         FROM UC_ACCRL_COLTR_MS accr_ms,UC_SUB_SEGMENT_MS sseg
         WHERE TRNSCTN_TYP =  200
         AND ACCRL_OBJ = 'MSZ'
         AND accr_ms.SUBSEG_CD = sseg.subseg_cd
         AND sseg.cntrct_stat_num = '400'
         GROUP BY sseg.subseg_cd,accrl_obj;

         COMMIT;
         pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','End Time to build UC_ACCRUAL_RPT_TRGNS_TP   '||to_char(sysdate,'dd-mm.yyyyhh24mi:ss'),'','');
   EXCEPTION
   WHEN OTHERS
   THEN
      pkg_batch_logger.proc_log (lf_file_handle,'INFO','Error while inserting into table UC_ACCRUAL_RPT_TRGNS_TP ','',SQLERRM);
      raise v_proc_err;
   END PROC_BUILD_ACCR_OBJECTS;

  PROCEDURE PROC_VALIDATE_PARAMS ( 
      stichtag_date               IN       DATE,
      inp_calc_fact_book_dt_flg   IN       VARCHAR2,
      inp_calc_fact_dt            IN       DATE,
      inp_version                 IN       VARCHAR2,
      inp_extn_period             IN       VARCHAR2,
      inp_extn_period_lsva_jz     IN       VARCHAR2,
      inp_extn_period_lsva_hz     IN       VARCHAR2,
      inp_extn_period_lsva_qz     IN       VARCHAR2,
      inp_extn_period_lsva_mz     IN       VARCHAR2,
      inp_extn_period_lsta_jz     IN       VARCHAR2,
      inp_extn_period_lsta_hz     IN       VARCHAR2,
      inp_extn_period_lsta_qz     IN       VARCHAR2,
      inp_extn_period_lsta_mz     IN       VARCHAR2,
      inp_extn_period_dlva_jz     IN       VARCHAR2,
      inp_extn_period_dlva_hz     IN       VARCHAR2,
      inp_extn_period_dlva_qz     IN       VARCHAR2,
      inp_extn_period_dlva_mz     IN       VARCHAR2,
      inp_extn_period_dlta_jz     IN       VARCHAR2,
      inp_extn_period_dlta_hz     IN       VARCHAR2,
      inp_extn_period_dlta_qz     IN       VARCHAR2,
      inp_extn_period_dlta_mz     IN       VARCHAR2,
      v_return_code               OUT      NUMBER
    ) 
    IS
    
    l_pdt_missing_filenm VARCHAR2(100) := v_pdt_typ ||'_'||to_char(stichtag_date,'yyyymmdd');

    BEGIN
      l_pdt_missing_filenm := v_pdt_typ ||'_'||to_char(stichtag_date,'yyyymmdd');

      BEGIN                                                               --{
         lf_file_handle := pkg_batch_logger.func_open_log (v_pkg_id);
         lv_file_handle := pkg_batch_logger.func_open_log (v_pkg_id);
      EXCEPTION
      WHEN OTHERS
      THEN
            pkg_batch_logger.proc_log (lf_file_handle,'INFO','*filehandle1*','',SQLERRM);
            RAISE v_file_open_err;
      END;                                                                 --}

      BEGIN                                                                --3
         lf_pdt_file_handle := UTL_FILE.fopen ('SPOOL_DIR', l_pdt_missing_filenm, 'W');
      EXCEPTION
         WHEN OTHERS
         THEN
            pkg_batch_logger.proc_log (lf_file_handle,'INFO','*filehandle2*','',SQLERRM);
            RAISE v_file_open_err;
      END;   
      
      BEGIN                                                                --3
         v_filelist_fp := UTL_FILE.fopen ('OUTGOING_DIR','TRIGONIS_UCS_XML.ftp.list', 'W');
      EXCEPTION
         WHEN OTHERS
         THEN
            pkg_batch_logger.proc_log (lf_file_handle,'INFO','*ftpfilelist*','',SQLERRM);
            RAISE v_file_open_err;
      END;                                                                       --}

      pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','--------------------------------','','');
      pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','--------------------------------','','');
      pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','TRIGONIS UCS Source Version ='||g_src_version,'','');
      pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','List of Input Parameters :-','','');
      pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','Input Due Date		 = ','',stichtag_date);
      pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','Input CalculationFactorFlag   = ','',NVL (inp_calc_fact_book_dt_flg, 'N'));
      pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','Input CalculationFactorDate   = ','',NVL (inp_calc_fact_dt, stichtag_date));
      pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','Input Version		 = ','',NVL (inp_version, 'A'));
      pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','Input Extension Period	 = ','',NVL (inp_extn_period, '12'));
      pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','Input ExtensionPeriod LS VAJZ = ','',NVL (inp_extn_period_lsva_jz, '24'));
      pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','Input ExtensionPeriod LS VAHZ = ','',NVL (inp_extn_period_lsva_hz, '24'));
      pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','Input ExtensionPeriod LS VAQZ = ','',NVL (inp_extn_period_lsva_qz, '24'));
      pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','Input ExtensionPeriod LS VAMZ = ','',NVL (inp_extn_period_lsva_mz, '24'));
      pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','Input ExtensionPeriod LS TAJZ = ','',NVL (inp_extn_period_lsta_jz, '24'));
      pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','Input ExtensionPeriod LS TAHZ = ','',NVL (inp_extn_period_lsta_hz, '24'));
      pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','Input ExtensionPeriod LS TAQZ = ','',NVL (inp_extn_period_lsta_qz, '24'));
      pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','Input ExtensionPeriod LS TAMZ = ','',NVL (inp_extn_period_lsta_mz, '24'));
      pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','Input ExtensionPeriod DL VAJZ = ','',NVL (inp_extn_period_dlva_jz, '24'));
      pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','Input ExtensionPeriod DL VAHZ = ','',NVL (inp_extn_period_dlva_hz, '24'));
      pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','Input ExtensionPeriod DL VAQZ = ','',NVL (inp_extn_period_dlva_qz, '18'));
      pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','Input ExtensionPeriod DL VAMZ = ','',NVL (inp_extn_period_dlva_mz, '18'));
      pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','Input ExtensionPeriod DL TAJZ = ','',NVL (inp_extn_period_dlta_jz, '12'));
      pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','Input ExtensionPeriod DL TAHZ = ','',NVL (inp_extn_period_dlta_hz, '12'));
      pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','Input ExtensionPeriod DL TAQZ = ','',NVL (inp_extn_period_dlta_qz, '15'));
      pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','Input ExtensionPeriod DL TAMZ = ','',NVL (inp_extn_period_dlta_mz, '15'));
      pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','--------------------------------','','');
      pkg_batch_logger.proc_log (lf_file_handle,'DEBUG','--------------------------------','','');
      IF stichtag_date IS NULL
      THEN                                                                 --{
         pkg_batch_logger.proc_log(lf_file_handle,'DEBUG','Input Parameter:STICHTAG IST FEHLERHAFT ',' ',stichtag_date);
         pkg_batch_logger.proc_log_status (lf_file_handle, 'B');
         v_return_code := 0;
         RETURN;
      END IF;                                                              --}

      IF inp_calc_fact_dt IS NULL
      THEN                                                                 --{
         pkg_batch_logger.proc_log(lf_file_handle,'DEBUG','Input Parameter:KOSTENDATUM IST FEHLERHAFT ',' ',inp_calc_fact_dt);
         pkg_batch_logger.proc_log_status (lf_file_handle, 'B');
         v_return_code := 0;
         RETURN;
      END IF;                                                              --}
      IF (NVL (inp_calc_fact_book_dt_flg, 'N') NOT IN ('N', 'J'))
      THEN                                                                 --{
         pkg_batch_logger.proc_log(lf_file_handle,'DEBUG','Input Parameter:BUZUG-KOSTENDATUM IST FEHLERHAFT ',' ',inp_calc_fact_book_dt_flg);
         pkg_batch_logger.proc_log_status (lf_file_handle, 'B');
         v_return_code := 0;
         RETURN;
      END IF;                                                              --}
      IF (NVL (inp_version, 'A') NOT IN ('N', 'A'))
      THEN                                                                 --{
         pkg_batch_logger.proc_log(lf_file_handle,'DEBUG','Input Parameter:VERSION IST FEHLERHAFT ',' ',inp_version);
         pkg_batch_logger.proc_log_status (lf_file_handle, 'B');
         v_return_code := 0;
         RETURN;
      END IF;                                                              --}
   END PROC_VALIDATE_PARAMS;   

   ---------------------------------------------------------------------------------------------------------
	-- Bharath 23-Mar-2006
	-- Following procedure PRC_GET_EXPO_GUARANT_FLG is developed to get the expo guarant flag, which will be
	-- used to arrived at the vertragstyp (TRGNS_PDT_TYP) for TA / TA contracts.
	---------------------------------------------------------------------------------------------------------

	PROCEDURE PRC_GET_EXPO_GUARANT_FLG( lf_file_handle UTL_FILE.file_type,
                                       v_subseg_cd IN UC_SUB_SEGMENT_MS.SUBSEG_CD%TYPE,
                                       v_ret_expo_guarant_flg OUT VARCHAR2,
                                       v_err_cd OUT NUMBER,
                                       v_err_txt OUT VARCHAR2 ) AS 
		v_data_avail_flg NUMBER;

		TYPE tab_subseg_obj_pkg_cd IS TABLE OF UC_SUBSEG_OBJ_PKG_TX.SUBSEG_OBJ_PKG_CD%TYPE INDEX BY PLS_INTEGER;
		TYPE tab_subseg_objpkg_obj_cd IS TABLE OF UC_SUBSEG_OBJPKG_OBJ_TX.SUBSEG_OBJPKG_OBJ_CD%TYPE INDEX BY PLS_INTEGER;

		v_subseg_obj_pkg_cd tab_subseg_obj_pkg_cd;
		v_subseg_objpkg_obj_cd tab_subseg_objpkg_obj_cd ;

	BEGIN

		v_err_cd := 0;
		v_err_txt := NULL;
		v_ret_expo_guarant_flg := 'N';
		v_data_avail_flg := 0;
		v_subseg_obj_pkg_cd.DELETE;
		v_subseg_objpkg_obj_cd.DELETE;

		-- Check for expo guarant flg at sub segment level
			BEGIN
			SELECT c.EXPO_GARNTR_FLG
			INTO v_ret_expo_guarant_flg
			FROM UC_SECU_PRVDR_TX a, UC_SECURITY_PARTNER_MS c
			WHERE OWNER_ID = v_subseg_cd AND a.OWNER_TYP = 'SUBSEG'
			AND a.prtnr_id = c.prtnr_id;

			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					v_data_avail_flg := 1;
				WHEN OTHERS THEN 
					v_err_cd := 1;
					v_err_txt := 'EXPO_GUARANT_FLG - SUBSEG_CD - '||SQLERRM;
					RETURN;			
		END;

		IF ( v_data_avail_flg = 0 ) --Expo Guarant with 'J' for subsegment found
		THEN
			RETURN;
		END IF;

		-- Get the object package id for the subsegment

		BEGIN
			SELECT SUBSEG_OBJ_PKG_CD
			BULK COLLECT INTO v_subseg_obj_pkg_cd
			FROM UC_SUBSEG_OBJ_PKG_TX
			WHERE SUBSEG_CD = v_subseg_cd;

			EXCEPTION
				WHEN NO_DATA_FOUND THEN 
						NULL;
				WHEN OTHERS THEN 
					v_err_cd := 2;
					v_err_txt := 'SUBSEG_OBJ_PKG_CD - '||SQLERRM;
					RETURN;
		END;
		-- Get the object id for the object package id selected above
		IF ( v_subseg_obj_pkg_cd.COUNT > 0 ) THEN 
			FOR objpkg_cntr IN 1..v_subseg_obj_pkg_cd.COUNT
			LOOP
				v_data_avail_flg := 0;
				BEGIN 
						SELECT c.EXPO_GARNTR_FLG
						INTO v_ret_expo_guarant_flg
						FROM UC_SECU_PRVDR_TX a, UC_SECURITY_PARTNER_MS c
						WHERE OWNER_ID = v_subseg_obj_pkg_cd( objpkg_cntr ) 
						AND a.OWNER_TYP = 'OBJPAK'
						AND a.prtnr_id = c.prtnr_id;			
					
						EXCEPTION
							WHEN NO_DATA_FOUND THEN
								v_data_avail_flg := 1;
							WHEN OTHERS THEN 
								v_err_cd := 3;
								v_err_txt := 'EXPO_GUARANT_FLG - SUBSEG_OBJK_PKG_CD - '||SQLERRM;
								RETURN;
				END;
				IF ( v_data_avail_flg = 0 ) --Expo Guarant with 'J' for subseg_obj_pkg_cd found
				THEN
					EXIT;
				END IF;
				IF ( v_data_avail_flg = 1 ) --Expo Guarant with 'J' for subseg_obj_pkg_cd not available
				THEN 
					BEGIN
							SELECT SUBSEG_OBJPKG_OBJ_CD
							BULK COLLECT INTO v_subseg_objpkg_obj_cd
							FROM UC_SUBSEG_OBJPKG_OBJ_TX
							WHERE SUBSEG_OBJ_PKG_CD = v_subseg_obj_pkg_cd ( objpkg_cntr );

							EXCEPTION
								WHEN NO_DATA_FOUND THEN 
									NULL;
								WHEN OTHERS THEN 
									v_err_cd := 4;
									v_err_txt := 'SUBSEG_OBJPKG_OBJ_CD - '||SQLERRM;
									RETURN;
					END;

					IF ( v_subseg_objpkg_obj_cd.COUNT > 0 )
					THEN 

							--Pkg_Batch_Logger.proc_log(lf_file_handle,'DEBUG','Before check Expo at object level <'||v_data_avail_flg||'>','','');

							FOR objpkg_obj_cntr IN 1..v_subseg_objpkg_obj_cd.COUNT
							LOOP 
									v_data_avail_flg := 0;

									BEGIN 
											SELECT c.EXPO_GARNTR_FLG
											INTO v_ret_expo_guarant_flg
											FROM UC_SECU_PRVDR_TX a, UC_SECURITY_PARTNER_MS c
											WHERE OWNER_ID = v_subseg_objpkg_obj_cd( objpkg_obj_cntr ) 
											AND a.OWNER_TYP = 'OBJECT'
											AND a.prtnr_id = c.prtnr_id;		
										
											EXCEPTION
												WHEN NO_DATA_FOUND THEN
													v_data_avail_flg := 1;
												WHEN OTHERS THEN 
													v_err_cd := 5;
													v_err_txt := 'EXPO_GUARANT_FLG - SUBSEG_OBJK_PKG_OBJ_CD - '||SQLERRM;
													RETURN;
									END;

									IF ( v_data_avail_flg = 0 )
									THEN 
										--Pkg_Batch_Logger.proc_log(lf_file_handle,'DEBUG','Expo Guarant found at object level <'||v_data_avail_flg||'>','','');
										EXIT;
									END IF;
							END LOOP;
					END IF;
				END IF;

				IF ( v_data_avail_flg = 0 )
				THEN 
					EXIT; --Record with expo guarant flg as 'J' found at object level
				END IF;
			
			END LOOP;

		END IF;
	END PRC_GET_EXPO_GUARANT_FLG;
                                                        --}
   FUNCTION FN_GET_TRIGONIS_PDF_TYP(p_comp_num in NUMBER,p_ms_pdt_name IN VARCHAR2,p_elmntry_pdt_name IN VARCHAR2) 
   RETURN VARCHAR2 AS
      v_expo_err_cd        NUMBER;
      v_expo_err_txt       VARCHAR2(500);
      v_expo_guarant_flg   VARCHAR2(1);
      v_trig_pdt_typ       VARCHAR2(50);   
      v_vertragstyp        VARCHAR2(32);
   BEGIN
         IF ( p_ms_pdt_name = 'TA' ) AND ( p_elmntry_pdt_name = 'TA' )
			THEN
					v_expo_err_cd := 0;
					v_expo_err_txt := '';
					BEGIN
						SELECT TRGNS_PDT_TYP
						INTO v_trig_pdt_typ
						FROM UC_TRGNS_PDT_MAP_MS
						WHERE COMP_NUM = p_comp_num
						AND MS_PDT_NAME = p_ms_pdt_name
						AND ELMNTRY_PDT_NAME = p_elmntry_pdt_name;
					EXCEPTION
					WHEN NO_DATA_FOUND 
               THEN
							Pkg_Batch_Logger.proc_log(lf_file_handle,'ERROR','BAT_I_0016', 'TA <COMP_NUM  MS_PDT_NAME  ELMNTRY_PDT_NAME>,UC_TRGNS_PDT_MAP_MS' ,'CNTRCT_NUM - '||v_curr_contract_rec.cntrct_num);
							Pkg_Batch_Logger.proc_log(lf_file_handle,'DEBUG','<'||p_comp_num||'> <'||p_ms_pdt_name||'> <'||p_elmntry_pdt_name||'>','',' - Contract Not Processed');
                     -- Following is fix for the Defect 15009
                     Pkg_Batch_Logger.proc_log(lf_pdt_file_handle,'DEBUG',
                                                                p_comp_num
                                                                ||'-'||v_curr_contract_rec.prtnr_num
                                                                ||'-'||v_curr_contract_rec.cntrct_num
                                                                ||'-'||v_curr_contract_rec.seg_num
                                                                ||'-'||v_curr_contract_rec.subseg_num
                                                                ||'     '||p_ms_pdt_name
                                                                ||'     '||p_elmntry_pdt_name,
                                                                '','Trigonis Contract Type missing');
                            v_missing_pdt := v_missing_pdt + 1 ;
                     RAISE v_skip_record;
               WHEN TOO_MANY_ROWS 
               THEN
                     v_expo_err_cd := 1; --Too many rows mean derive the vertragtyp manualy
               WHEN OTHERS 
               THEN
                     Pkg_Batch_Logger.proc_log(lf_file_handle,'FATAL','BAT_F_9999',SQLERRM,'TA - TRIG_PDT_TYP');
                     Pkg_Batch_Logger.proc_log(lf_file_handle,'DEBUG','<'||v_curr_contract_rec.comp_num||'> <'||p_ms_pdt_name||'> <'||p_elmntry_pdt_name||'>','','');
                     -- Following is fix for the Defect 15009
                     Pkg_Batch_Logger.proc_log(lf_pdt_file_handle,'DEBUG',
                                                                v_curr_contract_rec.comp_num
                                                                ||'-'||v_curr_contract_rec.prtnr_num
                                                                ||'-'||v_curr_contract_rec.cntrct_num
                                                                ||'-'||v_curr_contract_rec.seg_num
                                                                ||'-'||v_curr_contract_rec.subseg_num
                                                                ||'     '||P_MS_PDT_NAME
                                                                ||'     '||P_ELMNTRY_PDT_NAME,
                                                                '','Error Occured '||sqlcode);
                     v_missing_pdt := v_missing_pdt + 1 ;
                     RAISE v_skip_record;
               END;

               -- Following is done when there are more than one record for the TA product in the 
               -- UC_TRGNS_PDT_MAP_MS table. Then vertragstyp is derived using the procedure given below

               IF ( v_expo_err_cd = 1 )
               THEN 
                     v_expo_err_cd := 0;
                     v_expo_guarant_flg := NULL;

                     PRC_GET_EXPO_GUARANT_FLG( lf_file_handle,v_curr_contract_rec.subseg_cd,v_expo_guarant_flg,v_expo_err_cd,v_expo_err_txt);

                     IF (v_expo_err_cd != 0)
                     THEN 
                        Pkg_Batch_Logger.proc_log(lf_file_handle,'DEBUG','Error while executing PRC_GET_EXPO_GUARANT_FLG - '||v_curr_contract_rec.subseg_cd,'','');					
                        Pkg_Batch_Logger.proc_log(lf_file_handle,'DEBUG',v_expo_err_cd||' - '||v_expo_err_txt,'','');
                        RAISE v_skip_record;
                     END IF;

                     --Pkg_Batch_Logger.proc_log(lf_file_handle,'DEBUG','Expo Guarant Flag after PRC_GET_EXPO_GUARANT_FLG <'||v_expo_guarant_flg||'>','','');					
                     IF ( v_expo_guarant_flg = 'N' )
                     THEN 
                        v_trig_pdt_typ := 'TA_OHNE_RW_RISK';      --- 1 is changed to TA_OHNE_RW_RISK ;
                     ELSE 
                        v_trig_pdt_typ := 'TA_MIT_RW_RISK';    --- 2 is changed to TA_MIT_RW_RISK ;
                     END IF;
               END IF;
         ELSE -- if the P_MS_PDT_NAME is not 'TA'
               v_trig_pdt_typ := NULL;

               BEGIN
                  SELECT TRGNS_PDT_TYP
                  INTO v_trig_pdt_typ
                  FROM UC_TRGNS_PDT_MAP_MS
                  WHERE COMP_NUM = v_curr_contract_rec.comp_num
                  AND MS_PDT_NAME = P_MS_PDT_NAME
                  AND ELMNTRY_PDT_NAME = P_ELMNTRY_PDT_NAME;
               EXCEPTION
                  WHEN NO_DATA_FOUND 
                  THEN
                     Pkg_Batch_Logger.proc_log(lf_file_handle,'ERROR','BAT_I_0016', '<COMP_NUM  MS_PDT_NAME  ELMNTRY_PDT_NAME>,UC_TRGNS_PDT_MAP_MS' ,'CNTRCT_NUM - '||v_curr_contract_rec.cntrct_num);
                     Pkg_Batch_Logger.proc_log(lf_file_handle,'DEBUG','<'||v_curr_contract_rec.comp_num||'> <'||P_MS_PDT_NAME||'> <'||P_ELMNTRY_PDT_NAME||'>','',' - Contract Not Processed');
                     -- Following is fix for the Defect 15009
                    Pkg_Batch_Logger.proc_log(lf_pdt_file_handle,'DEBUG',
                            v_curr_contract_rec.comp_num
                            ||'-'||v_curr_contract_rec.prtnr_num
                            ||'-'||v_curr_contract_rec.cntrct_num
                            ||'-'||v_curr_contract_rec.seg_num
                            ||'-'||v_curr_contract_rec.subseg_num
                            ||'     '||P_MS_PDT_NAME
                            ||'     '||P_ELMNTRY_PDT_NAME,
                            '','Trigonis Contract Type missing');
                            v_missing_pdt := v_missing_pdt + 1 ;
                     RAISE v_skip_record;
                  WHEN TOO_MANY_ROWS THEN
                     Pkg_Batch_Logger.proc_log(lf_file_handle,'ERROR','BAT_E_0091',v_curr_contract_rec.old_subseg_cd,'TRIG_PDT_TYP');
                     Pkg_Batch_Logger.proc_log(lf_file_handle,'DEBUG','<'||v_curr_contract_rec.comp_num||'> <'||P_MS_PDT_NAME||'> <'||P_ELMNTRY_PDT_NAME||'>','','');

                                                        -- Following is fix for the Defect 15009

                                                        Pkg_Batch_Logger.proc_log(lf_pdt_file_handle,'DEBUG',
                                                                v_curr_contract_rec.comp_num
                                                                ||'-'||v_curr_contract_rec.prtnr_num
                                                                ||'-'||v_curr_contract_rec.cntrct_num
                                                                ||'-'||v_curr_contract_rec.seg_num
                                                                ||'-'||v_curr_contract_rec.subseg_num
                                                                ||'     '||P_MS_PDT_NAME
                                                                ||'     '||P_ELMNTRY_PDT_NAME,
                                                                '','Many Mappings Found');
                           v_missing_pdt := v_missing_pdt + 1 ;
                     RAISE v_skip_record;
                  WHEN OTHERS THEN
                     Pkg_Batch_Logger.proc_log(lf_file_handle,'FATAL','BAT_F_9999',SQLERRM,'TRIG_PDT_TYP');
                     Pkg_Batch_Logger.proc_log(lf_file_handle,'DEBUG','<'||v_curr_contract_rec.comp_num||'> <'||P_MS_PDT_NAME||'> <'||P_ELMNTRY_PDT_NAME||'>','','');

                                                        -- Following is fix for the Defect 15009

                                                        Pkg_Batch_Logger.proc_log(lf_pdt_file_handle,'DEBUG',
                                                                v_curr_contract_rec.comp_num
                                                                ||'-'||v_curr_contract_rec.prtnr_num
                                                                ||'-'||v_curr_contract_rec.cntrct_num
                                                                ||'-'||v_curr_contract_rec.seg_num
                                                                ||'-'||v_curr_contract_rec.subseg_num
                                                                ||'     '||P_MS_PDT_NAME
                                                                ||'     '||P_ELMNTRY_PDT_NAME,
                                                                '','Error Occured '||sqlcode);
                            v_missing_pdt := v_missing_pdt + 1 ;
                     RAISE v_skip_record;
               END;
         END IF;
         /*---------------------------------------------*/
/* Geting value for v_vertragstyp              */
/*---------------------------------------------*/
      --$$$$
         v_vertragstyp := v_trig_pdt_typ;

--         IF v_trig_pdt_typ = 0 
--         THEN
--              v_vertragstyp := 'VA';
--         ELSIF    v_trig_pdt_typ = 1
--         THEN 
--              v_vertragstyp := 'TA_MIT_RW_RISK';
--         ELSIF    v_trig_pdt_typ = 2
--         THEN 
--              v_vertragstyp := 'TA_OHNE_RW_RISK';  
--         ELSIF    v_trig_pdt_typ = 3
--         THEN 
--              v_vertragstyp := 'KUENDBAR';
--         ELSIF    v_trig_pdt_typ = 4
--         THEN 
--              v_vertragstyp := 'MIETKAUF';
--         ELSIF    v_trig_pdt_typ = 5
--         THEN 
--              v_vertragstyp := 'MIETVERTRAG';                            
--         ELSE
--             v_vertragstyp := 'SOFTWARE';
--         END IF;                      
         RETURN v_vertragstyp;
   END FN_GET_TRIGONIS_PDF_TYP;

   FUNCTION FN_GET_BONITAET_NOTE 
   RETURN  VARCHAR2
   
   AS
   v_codes_cd     uc_cntrct_codes_ms.codes_cd%type;
   v_rating_cd      VARCHAR2(2) := '00';
   v_num          NUMBER(2);

   BEGIN
      IF (v_curr_contract_rec.prtnr_cr_worth IS NOT NULL)
      THEN
            BEGIN
               SELECT codes_cd
                 INTO v_codes_cd
                 FROM uc_cntrct_codes_ms
                WHERE cntrct_codes_cd = v_curr_contract_rec.prtnr_cr_worth;
            EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                  return '00';
            END;

            IF    v_codes_cd = '0'
            THEN   
                    v_rating_cd :='0';
            ELSIF v_codes_cd = 'A'
            THEN
                    v_rating_cd :='1';
            ELSIF v_codes_cd = 'A-'
            THEN
                    v_rating_cd :='2';
            ELSIF v_codes_cd = 'B+'
            THEN
                    v_rating_cd :='3';
            ELSIF v_codes_cd = 'B'
            THEN
                    v_rating_cd :='4';
            ELSIF v_codes_cd = 'B-'
            THEN
                    v_rating_cd :='5';
            ELSIF v_codes_cd = 'C+'
            THEN
                    v_rating_cd :='6';
            ELSIF v_codes_cd = 'C'
            THEN
                    v_rating_cd :='7';
            ELSIF v_codes_cd = 'C-'
            THEN
                    v_rating_cd :='8';
            ELSIF v_codes_cd = 'D'
            THEN
                    v_rating_cd :='9';
            ELSE  
               BEGIN
                  v_num := to_number(v_rating_cd);
               EXCEPTION
               WHEN OTHERS
               THEN
                  v_num := 0;
               END;
               IF(v_num >= 0 and v_num <= 16)
               THEN
                 v_rating_cd := v_num;
               ELSE
                 v_rating_cd := 0;
               END IF;
            END IF;
      END IF;
      return v_rating_cd;
   END FN_GET_BONITAET_NOTE;


   FUNCTION FN_CALC_REST_EXT_DURATION (p_berites in VARCHAR2,
                                       p_prmsbl_pymt_modes_cd     IN    VARCHAR2,
                                       p_first_instlmnt_dt        IN    DATE,
                                       p_ende_grundlaufzeit       OUT   DATE,
                                       p_ende_verlaengerung       OUT   DATE
   )
   RETURN VARCHAR2 
   
   AS 
   v_extension_duration          NUMBER(5) := 0;
   v_lease_rec                   lease_rntl_cur%ROWTYPE;
   v_UMZ			                  NUMBER(5) := 0;
	v_diff_mon		               NUMBER(5);
	v_rec_count		               NUMBER := 0;
	v_vmz_filled		            BOOLEAN := FALSE;
	v_888_filled		            BOOLEAN := FALSE;
	v_vmz_period		            BOOLEAN := FALSE;
	v_888_period		            BOOLEAN := FALSE;
	v_prd_ext_per		            NUMBER;
	v_pymt_mode_dur		         NUMBER;
	v_vmz_durtn		               NUMBER;
	v_prmy_cntr_enddt	            DATE;

   BEGIN
      IF (p_prmsbl_pymt_modes_cd = 'MON')
      THEN
         v_pymt_mode_dur := 1;
      ELSIF (p_prmsbl_pymt_modes_cd = 'QUAR')
      THEN
         v_pymt_mode_dur := 3;
      ELSIF (p_prmsbl_pymt_modes_cd = 'HALF')
      THEN
         v_pymt_mode_dur := 6;
      ELSIF (p_prmsbl_pymt_modes_cd = 'YRLY')
      THEN
         v_pymt_mode_dur := 12;
      END IF;

      IF(v_curr_contract_rec.COMP_NUM = '599')
      THEN  
            IF(p_berites != 'J')
            THEN
               v_extension_duration := 0;
            ELSE
               IF ( v_cur_lease_rntl_tab.COUNT > 0 ) 
               THEN --{
                    FOR I IN v_cur_lease_rntl_tab.FIRST..v_cur_lease_rntl_tab.LAST
                    LOOP 
                     v_lease_rec := v_cur_lease_rntl_tab(I);
                     v_rec_count := v_rec_count + 1;
                     v_diff_mon := MONTHS_BETWEEN(v_lease_rec.to_dt,v_lease_rec.frm_dt);
                     IF(v_lease_rec.frm_dt <= v_stichtag_date AND v_lease_rec.to_dt >= v_stichtag_date)
                     THEN
                        IF(v_lease_rec.to_dt = v_stichtag_date or v_rec_count = 1 )
                        THEN
                           IF(v_rec_count = 1)
                           THEN
                              v_extension_duration := 1;
                           ELSE	
                              v_extension_duration := v_diff_mon + 1;
                           END IF;
                        ELSE
                           IF (v_diff_mon > 800)
                           THEN
                              v_extension_duration := v_UMZ + MONTHS_BETWEEN(v_stichtag_date,v_lease_rec.frm_dt) + 1;
                           ELSE
                              v_extension_duration := v_diff_mon;
                           END IF;
                       END IF; 
                     ELSE
                        IF(v_rec_count = 1)
                        THEN
                           v_UMZ := 0;
                           v_extension_duration := 1;
                        ELSIF(v_diff_mon > 800)
                        THEN
                           null;
                        ELSE
                           v_UMZ := v_diff_mon;						
                           v_extension_duration := v_diff_mon;
                        END IF;
                     END IF;
                  END LOOP;
               END IF;
         END IF;
      ELSIF (v_curr_contract_rec.COMP_NUM = '5' AND  v_curr_contract_rec.COMP_NUM = '83')/* Other than 599 */
      THEN
            IF(p_berites != 'J')
            THEN
               v_extension_duration := 0;
            ELSE
               v_rec_count := 0;
               IF (v_curr_contract_rec.ms_pdt_name = 'KV')
               THEN
                  v_prd_ext_per := g_inp_extn_period   ;
               ELSE
                  v_prd_ext_per := 0  ;
               END IF;

               IF(p_prmsbl_pymt_modes_cd = 'MON')
               THEN
                  v_pymt_mode_dur := 1;
                  IF (v_curr_contract_rec.ms_pdt_name = 'VA')
                  THEN
                     v_prd_ext_per := g_inp_extn_period_LSVA_MZ ; 
                  ELSIF (v_curr_contract_rec.ms_pdt_name = 'TA')
                  THEN
                     v_prd_ext_per := g_inp_extn_period_LSTA_MZ ;
                  END IF;
               ELSIF(p_prmsbl_pymt_modes_cd = 'QUAR')
               THEN
                  v_pymt_mode_dur := 3;
                  IF (v_curr_contract_rec.ms_pdt_name = 'VA')
                  THEN
                     v_prd_ext_per := g_inp_extn_period_LSVA_QZ ; 
                  ELSIF (v_curr_contract_rec.ms_pdt_name = 'TA')
                  THEN
                     v_prd_ext_per := g_inp_extn_period_LSTA_QZ ; 
                  END IF;
               ELSIF(p_prmsbl_pymt_modes_cd = 'HALF')
               THEN
                  v_pymt_mode_dur := 6;
                  IF (v_curr_contract_rec.ms_pdt_name = 'VA')
                  THEN
                     v_prd_ext_per := g_inp_extn_period_LSVA_HZ ; 
                  ELSIF (v_curr_contract_rec.ms_pdt_name = 'TA')
                  THEN
                     v_prd_ext_per := g_inp_extn_period_LSTA_HZ ; 
                  END IF;
               ELSIF(p_prmsbl_pymt_modes_cd = 'YRLY')
               THEN
                  v_pymt_mode_dur := 12;
                  IF (v_curr_contract_rec.ms_pdt_name = 'VA')
                  THEN
                     v_prd_ext_per := g_inp_extn_period_LSVA_JZ ; 
                  ELSIF (v_curr_contract_rec.ms_pdt_name = 'TA')
                  THEN
                     v_prd_ext_per := g_inp_extn_period_LSTA_JZ ; 
                  END IF;
               END IF;

               v_vmz_filled := FALSE;
               v_888_filled := FALSE;
               v_vmz_period := FALSE;
               v_888_period := FALSE;
               v_vmz_durtn  := 0;
               v_rec_count := 0;

               IF ( v_cur_lease_rntl_tab.COUNT > 0 ) --Condition Included by Bharath to avoid Fatal Error (30-Mar-2006)
               THEN --{
                     FOR I IN v_cur_lease_rntl_tab.FIRST..v_cur_lease_rntl_tab.LAST
                     LOOP --{
                        v_rec_count := v_rec_count + 1;
                        v_lease_rec := v_cur_lease_rntl_tab(I);
                        v_diff_mon := MONTHS_BETWEEN(v_lease_rec.to_dt,v_lease_rec.frm_dt);

                        IF(v_rec_count = 1)
                        THEN
                           v_prmy_cntr_enddt := add_months(v_lease_rec.frm_dt-1,v_curr_contract_rec.cntrct_durtn); 
                        END IF;

                        IF (v_lease_rec.frm_dt > v_prmy_cntr_enddt AND v_diff_mon < 888)
                        THEN
                           v_vmz_filled := TRUE;
                           v_vmz_durtn  := v_vmz_durtn + v_diff_mon ;
                        ELSIF(v_diff_mon > 888 )
                        THEN	
                           v_888_filled := TRUE;
                        END IF;

                        IF(v_lease_rec.frm_dt <= v_stichtag_date AND v_lease_rec.to_dt >= v_stichtag_date)
                        THEN
                           IF(v_lease_rec.frm_dt > v_prmy_cntr_enddt )
                           THEN
                              IF(v_diff_mon < 888)
                              THEN
                                 v_vmz_period := TRUE;
                              ELSE
                                 v_888_period := TRUE;
                              END IF;
                           END IF;
                        END IF;
                     END LOOP;
               END IF;
               --- VMZ Segment is filled
               IF(v_vmz_filled = TRUE )
               THEN
                  IF(v_vmz_period = TRUE)/*** Contract in VMZ Period ***/
                  THEN
                     v_extension_duration := v_vmz_durtn;
                  ELSIF(v_888_period  = TRUE)
                  THEN
                     v_extension_duration := v_vmz_durtn+v_prd_ext_per;
                  ELSE
                     v_extension_duration := v_prd_ext_per;
                  END IF;
               ELSIF(v_888_period = TRUE ) -- Contract in 888 Period
               THEN
                  v_extension_duration := v_prd_ext_per;
               ELSE
                  v_extension_duration := v_prd_ext_per;
               END IF;
            END IF; /** End Of Berites */
      ELSE  /* CEANF */
            v_888_period := false;
            IF ( v_cur_lease_rntl_tab.COUNT > 0 ) 
            THEN --{
                  FOR I IN v_cur_lease_rntl_tab.FIRST..v_cur_lease_rntl_tab.LAST
                  LOOP 
                     v_lease_rec := v_cur_lease_rntl_tab(I);
                     v_diff_mon := MONTHS_BETWEEN(v_lease_rec.to_dt,v_lease_rec.frm_dt);
                     IF(v_lease_rec.frm_dt <= v_stichtag_date AND v_lease_rec.to_dt >= v_stichtag_date)
                     THEN
                              IF(v_diff_mon > 800)
                              THEN
                                 v_888_period := TRUE;
                              END IF;
                     END IF;
                  END LOOP;
            END IF;
            IF ((p_berites != 'J')            OR 
             ((v_curr_contract_rec.elmntry_pdt_name = 'AK') and (v_888_period = false)) OR
             ((v_curr_contract_rec.elmntry_pdt_name = 'AT')))
            THEN
             --contract NOT in extension
             v_extension_duration := 0;
            ELSE 
             --contract is in extension
             v_prd_ext_per := 0;

             IF ((v_curr_contract_rec.elmntry_pdt_name = 'AK') OR (v_curr_contract_rec.elmntry_pdt_name = 'AF')) 
             THEN
                 --contract is extended through a "AK" or "AF" contract for endless duration
                 v_prd_ext_per := g_inp_extn_period;
             ELSE 
                 v_prd_ext_per := g_inp_extn_period;
             END IF;
            END IF;
      END IF;/** End Of Company */

      --v_beginn = v_curr_contract_rec.lease_bgn_dt; --//from dialog "CC009"
      p_ende_grundlaufzeit := v_curr_contract_rec.lease_end_dt; --//from dialog "CC009"
      p_ende_verlaengerung := ADD_MONTHS(p_ende_grundlaufzeit,v_extension_duration);

      WHILE (p_ende_verlaengerung < v_stichtag_date) 
      LOOP
         v_extension_duration := v_extension_duration +  v_pymt_mode_dur; --//contract.getPaymentMode().getIntValue()  => 1,3,6 or 12
         p_ende_verlaengerung := ADD_MONTHS(p_ende_grundlaufzeit,v_extension_duration);
      END LOOP;

      RETURN '0';
   END FN_CALC_REST_EXT_DURATION;

   PROCEDURE FN_SET_STR_ATTRIBUTE(p_result IN  varchar2,p_name IN VARCHAR2,p_value IN VARCHAR2) IS

   BEGIN
         IF(TRIM(p_value) IS NOT NULL)
         THEN
                IF(p_result = 'R')
                THEN
                        refin_result := refin_result ||' '|| p_name || '="'|| p_value || '" ';
                ELSE
                        result := result ||' '|| p_name || '="'|| p_value || '" ';
                END IF;
        END IF;
   END FN_SET_STR_ATTRIBUTE;

   PROCEDURE FN_SET_INT_ATTRIBUTE(p_result IN  varchar2,p_name IN VARCHAR2,p_value IN NUMBER) IS

   BEGIN
        IF(TRIM(p_value) IS NOT NULL)
         THEN
                IF(p_result = 'R')
                THEN
                        refin_result := refin_result ||' '|| p_name || '="'|| p_value || '" ';
                ELSE
                        result := result ||' '|| p_name || '="'|| p_value || '" ';
                END IF;
        END IF;
   END FN_SET_INT_ATTRIBUTE;

   PROCEDURE FN_SET_PERCENT_ATTRIBUTE(p_result IN  varchar2,p_name IN VARCHAR2,p_value IN NUMBER) IS

   BEGIN
       IF(TRIM(p_value) IS NOT NULL)
       THEN
                IF(p_result = 'R')
                THEN
                        refin_result := refin_result ||' '|| p_name || '="' ||TO_CHAR(p_value,'9999999999999999990D999999','NLS_NUMERIC_CHARACTERS=.,') || '" ';
                ELSE
                        result := result ||' '|| p_name || '="' ||TO_CHAR(p_value,'9999999999999999990D999999','NLS_NUMERIC_CHARACTERS=.,') || '" ';
                END IF;
       END IF;
   END FN_SET_PERCENT_ATTRIBUTE;
  
   PROCEDURE FN_SET_DATE_ATTRIBUTE(p_result IN  varchar2,p_name IN VARCHAR2,p_value IN DATE) IS

   BEGIN
        IF(TRIM(p_value) IS NOT NULL)
       THEN
                IF(p_result = 'R')
                THEN
                        refin_result := refin_result ||' '|| p_name || '="' ||TO_CHAR(p_value,'DD.MM.YYYY') || '" ';
                ELSE
                        result := result ||' '|| p_name || '="' ||TO_CHAR(p_value,'DD.MM.YYYY') || '" ';
                END IF;
       END IF;
   END FN_SET_DATE_ATTRIBUTE;

   PROCEDURE FN_SET_MONEY_ATTRIBUTE(p_result IN  varchar2,p_name IN VARCHAR2,p_value IN NUMBER) IS

   BEGIN
        IF(TRIM(p_value) IS NOT NULL)
       THEN
                IF(p_result = 'R')
                THEN
                        refin_result := refin_result ||' '|| p_name || '="' ||TO_CHAR(p_value,'9999999999999999990D99','NLS_NUMERIC_CHARACTERS=.,') || '" ';
                ELSE
                        result := result ||' '|| p_name || '="' ||TO_CHAR(p_value,'9999999999999999990D99','NLS_NUMERIC_CHARACTERS=.,') || '" ';
                END IF;
       END IF;
   END FN_SET_MONEY_ATTRIBUTE;

   PROCEDURE PROC_CREATE_REFI_XML(p_new_company_flag IN OUT BOOLEAN)   IS
   v_txs_ref_id VARCHAR2(40) := 40; 
   BEGIN
      refin_result := null;

      IF(v_refi_mieten_rec.createRefinMeiten = TRUE
      OR v_refi_mieten_rw_rec.createRefinMeiten = TRUE 
      OR v_refi_rw_rec.createRefinMeiten = TRUE)
      THEN
         v_no_of_refin_cnt := v_no_of_refin_cnt + 1;
         IF(p_new_company_flag = TRUE)
         THEN
               v_no_of_refin_cnt := 0;
               v_refin_filename :='UCS2TLL_REFIDATA' || LPAD (v_curr_contract_rec.comp_num, 3, 0)|| '_'|| TO_CHAR(v_stichtag_date,'yyyymmdd') ||'.xml';
             
               IF UTL_FILE.is_open (v_refin_fp)
               THEN
                  refin_result := '</txs_refi_data>';
                  UTL_FILE.put_line (v_refin_fp, refin_result);                     
                  UTL_FILE.fclose (v_refin_fp);
               END IF;

               v_refin_fp := UTL_FILE.fopen ('OUTGOING_DIR',
                                  v_refin_filename,
                                  'W',
                                  32767
                                 );
               refin_result :='<?xml version="1.0" encoding="utf-8"?>'
                           ||'<txs_refi_data xsi:noNamespaceSchemaLocation="TLL_refi_request_response.xsd" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" sim_date="'
                           || TO_CHAR(v_stichtag_date,'dd.mm.yyyy')
                           || '"'
                           || ' type="RESPONSE">';
            v_refin_filecnt   := v_refin_filecnt + 1;
            v_refin_filenames(v_refin_filecnt) := v_refin_filename;
	    UTL_FILE.put_line (v_filelist_fp, v_refin_filename,TRUE);               
            p_new_company_flag := FALSE;
         END IF;
        /*---------------------------------------------*/
        /* Geting value for v_txs_ref_id               */
        /*---------------------------------------------*/


         /*   v_txs_ref_id :=v_curr_contract_rec.comp_num|| '-'
                           || v_curr_contract_rec.prtnr_num
                           || '-'
                           || v_curr_contract_rec.cntrct_num
                           || '-'
                           || v_curr_contract_rec.seg_num               
                           || '-'               
                           || v_curr_contract_rec.subseg_num;
         */
        
        /* Note: UCS Refinancing information ref id is changed as vname inorder */

         v_txs_ref_id := v_vertragsheader_rec.vname;

         refin_result:= refin_result || '<refi_contract ' ;
         FN_SET_STR_ATTRIBUTE('R','asset_id',  v_txs_ref_id );      
         FN_SET_STR_ATTRIBUTE('R','comp_no',  LPAD(v_curr_contract_rec.comp_num,3,'0') );      
         refin_result:= refin_result || '> ' ;

         IF(v_refi_mieten_rec.createRefinMeiten = TRUE)
         THEN
           
            refin_result:= refin_result || '<refi_mieten ' ;
            FN_SET_DATE_ATTRIBUTE('R','aufloesung_beginn', v_refi_mieten_rec.aufloesung_beginn );             
            FN_SET_DATE_ATTRIBUTE('R','aufloesung_ende', v_refi_mieten_rec.aufloesung_ende );  
            FN_SET_DATE_ATTRIBUTE('R','ende_aufloesungszeit', v_refi_mieten_rec.ende_aufloesungszeit );             
            FN_SET_STR_ATTRIBUTE('R','aufloesung_prap_auf_null', v_refi_mieten_rec.aufloesung_prap_auf_null );             
            FN_SET_PERCENT_ATTRIBUTE('R','zins', v_refi_mieten_rec.zins );             
            FN_SET_DATE_ATTRIBUTE('R','faelligkeit_barwert', v_refi_mieten_rec.faelligkeit_barwert );             
            FN_SET_STR_ATTRIBUTE('R','aufloesungsart', v_refi_mieten_rec.aufloesungsart );             
            FN_SET_STR_ATTRIBUTE('R','refityp', v_refi_mieten_rec.refityp );             
            FN_SET_STR_ATTRIBUTE('R','rechenart', v_refi_mieten_rec.rechenart );   
            refin_result:= refin_result || '> ' ;

            IF(v_refi_mieten_rec.barwert_betrag is not null)
            THEN
               refin_result:= refin_result || ' <barwert ' ;
               FN_SET_MONEY_ATTRIBUTE('R','betrag', v_refi_mieten_rec.barwert_betrag );          
               refin_result:= refin_result || '/> ' ;
            END IF;
         
            IF(v_refi_mieten_rec.rap_hgb_betrag is not null)
            THEN
               refin_result:= refin_result || ' <rap_hgb ' ;
               FN_SET_MONEY_ATTRIBUTE('R','betrag', v_refi_mieten_rec.rap_hgb_betrag );          
               refin_result:= refin_result || '/> ' ;
            END IF;
           
            IF(v_refi_mieten_rec.rate_explizit.COUNT > 0)
            THEN
                  refin_result:= refin_result || ' <ratenplan_explizit ratengueltigkeit="FOLGEPERIODE"> ' ;
                  FOR I IN v_refi_mieten_rec.rate_explizit.FIRST..v_refi_mieten_rec.rate_explizit.LAST 
                  LOOP
                         refin_result := refin_result || '<rate_explizit  ';
                         FN_SET_MONEY_ATTRIBUTE('R','betrag',  v_refi_mieten_rec.rate_explizit(I).betrag);
                         FN_SET_DATE_ATTRIBUTE('R','faellig_ab', v_refi_mieten_rec.rate_explizit(I).faellig_ab);
                         FN_SET_DATE_ATTRIBUTE('R','gueltig_bis', v_refi_mieten_rec.rate_explizit(I).gueltig_bis);
                         FN_SET_STR_ATTRIBUTE('R','ratenabstand', v_refi_mieten_rec.rate_explizit(I).ratenabstand);         
                         refin_result := refin_result || '/>';
                  END LOOP;
            END IF;
            refin_result := refin_result || '</ratenplan_explizit> </refi_mieten>' || CHR(10);
        END IF;
         IF(v_refi_mieten_rw_rec.createRefinMeiten = TRUE )
         THEN
                  refin_result:= refin_result || '<refi_mieten_rw ' ;
                  FN_SET_DATE_ATTRIBUTE('R','aufloesung_beginn', v_refi_mieten_rw_rec.aufloesung_beginn );             
                  FN_SET_DATE_ATTRIBUTE('R','aufloesung_ende', v_refi_mieten_rw_rec.aufloesung_ende );  
                  FN_SET_DATE_ATTRIBUTE('R','ende_aufloesungszeit', v_refi_mieten_rw_rec.ende_aufloesungszeit );             
                  FN_SET_STR_ATTRIBUTE('R','aufloesung_prap_auf_null', v_refi_mieten_rw_rec.aufloesung_prap_auf_null );             
                  FN_SET_PERCENT_ATTRIBUTE('R','zins', v_refi_mieten_rw_rec.zins );             
                  FN_SET_DATE_ATTRIBUTE('R','faelligkeit_barwert', v_refi_mieten_rw_rec.faelligkeit_barwert );             
                  FN_SET_STR_ATTRIBUTE('R','aufloesungsart', v_refi_mieten_rw_rec.aufloesungsart );             
                  FN_SET_STR_ATTRIBUTE('R','refityp', v_refi_mieten_rw_rec.refityp );             
                  FN_SET_STR_ATTRIBUTE('R','rechenart', v_refi_mieten_rw_rec.rechenart );   
                  refin_result:= refin_result || '> ' ;
                  IF(v_refi_mieten_rw_rec.restwert_refi_betrag IS NOT NULL)
                  THEN
                     refin_result:= refin_result || ' <restwert_refi ' ;
                     FN_SET_MONEY_ATTRIBUTE('R','betrag', v_refi_mieten_rw_rec.restwert_refi_betrag );          
                     refin_result:= refin_result || '/> ' ;
                  END IF;
                  IF(v_refi_mieten_rw_rec.barwert_betrag is not null)
                  THEN
                     refin_result:= refin_result || ' <barwert ' ;
                     FN_SET_MONEY_ATTRIBUTE('R','betrag', v_refi_mieten_rw_rec.barwert_betrag );          
                     refin_result:= refin_result || '/> ' ;
                  END IF;

                  IF(v_refi_mieten_rw_rec.rap_hgb_betrag is not null)
                  THEN
                     refin_result:= refin_result || ' <rap_hgb ' ;
                     FN_SET_MONEY_ATTRIBUTE('R','betrag', v_refi_mieten_rw_rec.rap_hgb_betrag );          
                     refin_result:= refin_result || '/> ' ;
                  END IF;
                 
                  IF(v_refi_mieten_rw_rec.rate_explizit.COUNT > 0)
                  THEN
                        refin_result:= refin_result || ' <ratenplan_explizit ratengueltigkeit="FOLGEPERIODE"> ' ;
                        FOR I IN v_refi_mieten_rw_rec.rate_explizit.FIRST..v_refi_mieten_rw_rec.rate_explizit.LAST 
                        LOOP
                               refin_result := refin_result || '<rate_explizit  ';
                               FN_SET_MONEY_ATTRIBUTE('R','betrag',  v_refi_mieten_rw_rec.rate_explizit(I).betrag);
                               FN_SET_DATE_ATTRIBUTE('R','faellig_ab', v_refi_mieten_rw_rec.rate_explizit(I).faellig_ab);
                               FN_SET_DATE_ATTRIBUTE('R','gueltig_bis', v_refi_mieten_rw_rec.rate_explizit(I).gueltig_bis);
                               FN_SET_STR_ATTRIBUTE('R','ratenabstand', v_refi_mieten_rw_rec.rate_explizit(I).ratenabstand);         
                               refin_result := refin_result || '/>';
                        END LOOP;
                  END IF;
                  refin_result := refin_result || '</ratenplan_explizit> </refi_mieten_rw>' || CHR(10);
         END IF;
         IF(v_refi_rw_rec.createRefinMeiten = TRUE)
         THEN
                  refin_result:= refin_result || '<refi_rw ' ;
                  FN_SET_DATE_ATTRIBUTE('R','aufloesung_beginn', v_refi_rw_rec.aufloesung_beginn );             
                  FN_SET_DATE_ATTRIBUTE('R','aufloesung_ende', v_refi_rw_rec.aufloesung_ende );  
                  FN_SET_DATE_ATTRIBUTE('R','ende_aufloesungszeit', v_refi_rw_rec.ende_aufloesungszeit );             
                  FN_SET_STR_ATTRIBUTE('R','aufloesung_prap_auf_null', v_refi_rw_rec.aufloesung_prap_auf_null );             
                  FN_SET_PERCENT_ATTRIBUTE('R','zins', v_refi_rw_rec.zins );             
                  FN_SET_DATE_ATTRIBUTE('R','faelligkeit_barwert', v_refi_rw_rec.faelligkeit_barwert );             
                  FN_SET_STR_ATTRIBUTE('R','aufloesungsart', v_refi_rw_rec.aufloesungsart );             
                  FN_SET_STR_ATTRIBUTE('R','refityp', v_refi_rw_rec.refityp );             
                  FN_SET_STR_ATTRIBUTE('R','rechenart', v_refi_rw_rec.rechenart );   
                  refin_result:= refin_result || '> ' ;
              
                  IF(v_refi_rw_rec.restwert_refi_betrag IS NOT NULL)
                  THEN
                     refin_result:= refin_result || ' <restwert_refi ' ;
                     FN_SET_MONEY_ATTRIBUTE('R','betrag', v_refi_rw_rec.restwert_refi_betrag );          
                     refin_result:= refin_result || '/> ' ;
                  END IF;

                  IF(v_refi_rw_rec.barwert_betrag is not null)
                  THEN
                     refin_result:= refin_result || ' <barwert ' ;
                     FN_SET_MONEY_ATTRIBUTE('R','betrag', v_refi_rw_rec.barwert_betrag );          
                     refin_result:= refin_result || '/> ' ;
                  END IF;

                  IF(v_refi_rw_rec.rap_hgb_betrag is not null)
                  THEN
                     refin_result:= refin_result || ' <rap_hgb ' ;
                     FN_SET_MONEY_ATTRIBUTE('R','betrag', v_refi_rw_rec.rap_hgb_betrag );          
                     refin_result:= refin_result || '/> ' ;
                  END IF;
                  
                  refin_result := refin_result || ' </refi_rw>' || CHR(10) ;
         END IF;
         refin_result := refin_result ||' </refi_contract>';
         UTL_FILE.put_line (v_refin_fp, refin_result);
         UTL_FILE.fflush (v_refin_fp);
      END IF;
   END PROC_CREATE_REFI_XML;  

   PROCEDURE PROC_CREATE_CONTR_FINAL_XML IS

   v_txs_ref_id VARCHAR2(40) := 40; 
   
   BEGIN
            /*-----------------------------------------------------*/
            /* Creating Final XML                                  */
            /*-----------------------------------------------------*/
        --    Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Fianl xml  ==>'||RESULT,'', '');                

            RESULT :=
                  '<?xml version="1.0"?>'
               || ' <bestand xsi:noNamespaceSchemaLocation="TLL_Bestand.xsd" '
               || 'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
               || 'sim_stichtag="'
               || TO_CHAR (v_stichtag_date, 'dd.mm.yyyy')
               || '" '
               || ' bestandstyp="BESTAND"> '
               || ' <vorgang vname="'
               || v_vertragsheader_rec.vname
               || '"> '
               || '<direktvertrag> '
               || '<vertrag> '
               ||CHR (10)
               ||'<vertragsheader ';
               
     --          Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Fianl xml  ==>'||RESULT,'', '');                
              
               FN_SET_STR_ATTRIBUTE('C','gesellschaft',           lpad(v_vertragsheader_rec.gesellschaft,3,'0'));  
               FN_SET_STR_ATTRIBUTE('C','geschaeftsstelle',       v_vertragsheader_rec.geschaeftsstelle);            
               FN_SET_STR_ATTRIBUTE('C','plz',                    v_vertragsheader_rec.plz);                         
               FN_SET_STR_ATTRIBUTE('C','branche',                v_vertragsheader_rec.branche );                    
               FN_SET_STR_ATTRIBUTE('C','geschaeftsbereich',      v_vertragsheader_rec.geschaeftsbereich );          
               FN_SET_STR_ATTRIBUTE('C','rating',                 v_vertragsheader_rec.rating     );                 
               FN_SET_STR_ATTRIBUTE('C','objektart',              v_vertragsheader_rec.objektart       );            
               FN_SET_STR_ATTRIBUTE('C','vertriebsweg',           v_vertragsheader_rec.vertriebsweg  );              
               FN_SET_STR_ATTRIBUTE('C','ratenstruktur',          v_vertragsheader_rec.ratenstruktur );              
               
               FN_SET_DATE_ATTRIBUTE('C','vbeginn',                v_vertragsheader_rec.vbeginn   );                  
               FN_SET_DATE_ATTRIBUTE('C','vende_grundlaufzeit',    v_vertragsheader_rec.vende_grundlaufzeit );        
               FN_SET_DATE_ATTRIBUTE('C','vende_verlaengerung',    v_vertragsheader_rec.vende_verlaengerung );        
               FN_SET_DATE_ATTRIBUTE('C','naechste_sollstellung',  v_vertragsheader_rec.naechste_sollstellung  );     
               FN_SET_DATE_ATTRIBUTE('C','zugangsdatum',           v_vertragsheader_rec.zugangsdatum   );             
              
               FN_SET_STR_ATTRIBUTE('C','vertragstyp',            v_vertragsheader_rec.vertragstyp  );               
               FN_SET_STR_ATTRIBUTE('C','vertragstyp_erweitert',  v_vertragsheader_rec.vertragstyp_erweitert );      
               FN_SET_STR_ATTRIBUTE('C','vertragsart',            v_vertragsheader_rec.vertragsart      );           
               
               FN_SET_PERCENT_ATTRIBUTE('C','intern_kalkuzins',       v_vertragsheader_rec.intern_kalkuzins );           
               FN_SET_PERCENT_ATTRIBUTE('C','refi_kalkuzins',  v_vertragsheader_rec.refi_kalkuzins   );           

               FN_SET_STR_ATTRIBUTE('C','geschaeftsfeld',         v_vertragsheader_rec.geschaeftsfeld   );           
               FN_SET_STR_ATTRIBUTE('C','zahlungsweise',          v_vertragsheader_rec.zahlungsweise   );            
               FN_SET_INT_ATTRIBUTE('C','mahnstufe',              v_vertragsheader_rec.mahnstufe      );             
               FN_SET_STR_ATTRIBUTE('C','rechenart_mk',           v_vertragsheader_rec.rechenart_mk   );             
               FN_SET_STR_ATTRIBUTE('C','status',                 v_vertragsheader_rec.status         );             
               
               
               RESULT := RESULT ||'> <anschaffungswert ';
               FN_SET_MONEY_ATTRIBUTE('C','betrag',v_vertragsheader_rec.anschaffungswert);
               RESULT := RESULT ||'/></vertragsheader>';
               
               /****************************************************/
               /*       CREATE mietkaufvermogen XML SEGMENTS       */
               /****************************************************/
               IF(v_mietkaufvermogen_rec.createMietkaufvermogen = TRUE)
               THEN
                  RESULT := RESULT || '<mietkaufvermoegen> <restbuchwert ';
                  FN_SET_MONEY_ATTRIBUTE('C','betrag',  v_mietkaufvermogen_rec.restbuchwert_betrag);     
                  RESULT := RESULT || '/> </mietkaufvermoegen> ';
               END IF;

               /****************************************************/
               /*       CREATE MSZ XML SEGMENTS                    */
               /****************************************************/
               IF(v_msz_rec.createMSZ = TRUE)
               THEN
                  RESULT := RESULT || '<msz ';
                  
                  FN_SET_DATE_ATTRIBUTE('C','faelligkeit', v_msz_rec.faelligkeit);
                  FN_SET_DATE_ATTRIBUTE('C','aufloesung_beginn', v_msz_rec.aufloesung_beginn);
                  FN_SET_DATE_ATTRIBUTE('C','aufloesung_ende', v_msz_rec.aufloesung_ende);
                  FN_SET_DATE_ATTRIBUTE('C','ende_aufloesungszeit', v_msz_rec.ende_aufloesungszeit );
                  RESULT := RESULT || '> <msz_betrag ';
                  FN_SET_MONEY_ATTRIBUTE('C','betrag',  v_msz_rec.msz_betrag   );           
                  RESULT := RESULT || ' /> ';
                  
                  IF(v_msz_rec.msz_rap_betrag IS NOT NULL)
                  THEN
                     RESULT := RESULT || '<msz_rap ';
                     FN_SET_MONEY_ATTRIBUTE('C','betrag',  v_msz_rec.msz_rap_betrag   );      
                     RESULT := RESULT || '/>';
                  END IF;

                  RESULT := RESULT || '</msz> ';

               END IF;


               /****************************************************/
               /*       CREATE nachgeschaeft XML SEGMENT           */
               /****************************************************/

               IF(v_nachgeschaeft_rec.createRestwert  = TRUE)
               THEN  
                  RESULT := RESULT || '<nachgeschaeft ';
              
                  FN_SET_DATE_ATTRIBUTE('C','faelligkeit', v_nachgeschaeft_rec.faelligkeit);
                  FN_SET_MONEY_ATTRIBUTE('C','betrag',  v_nachgeschaeft_rec.betrag   );      
                  RESULT := RESULT || '/>';
               END IF;


               /****************************************************/
               /*       CREATE Restwert XML SEGMENT                */
               /****************************************************/

               IF(v_restwert_rec.createRestwert  = TRUE)
               THEN  
                     RESULT := RESULT || '<restwert ';
                     FN_SET_DATE_ATTRIBUTE('C','faelligkeit', v_restwert_rec.faelligkeit);
                     RESULT := RESULT || '><rw_betrag  ';
                     FN_SET_MONEY_ATTRIBUTE('C','betrag',  v_restwert_rec.rw_betrag  );           
                   
                     RESULT := RESULT || '/> <rw_betrag_vor_verl ';
                     FN_SET_MONEY_ATTRIBUTE('C','betrag',  v_restwert_rec.rw_betrag_vor_verl  );         
                     RESULT := RESULT || '/> </restwert> ';
               END IF;

             --Defect id 17982
            /****************************************************/
            /*       CREATE nutzungsentgelt XML SEGMENT         */ 
            /****************************************************/
            IF(v_nutzungsentgelt_rec.createNutzungsentgelt    = TRUE)
            THEN
               IF(v_nutzungsentgelt_rec.betrag > 0)
               THEN
                   RESULT := RESULT || '<nutzungsentgelt ';
                   FN_SET_DATE_ATTRIBUTE('C','faelligkeit', v_nutzungsentgelt_rec.faelligkeit);
                   FN_SET_MONEY_ATTRIBUTE('C','betrag',  v_nutzungsentgelt_rec.betrag);
                   RESULT := RESULT || '/>';
               END IF;
            END IF;

            /****************************************************/
            /*       CREATE ZAHUL XML SEGMENT                */ 
            /****************************************************/

           IF(v_zahlungsplan_rec.createZahlungpalan    = TRUE)
           THEN
               RESULT := RESULT || '<zahlungsplan  ';
               FN_SET_STR_ATTRIBUTE('C','ratentyp', v_zahlungsplan_rec.ratentyp );           
               FN_SET_STR_ATTRIBUTE('C','linearisierungsart', v_zahlungsplan_rec.linearisierungsart);           
               RESULT := RESULT || '> <ratenplan_explizit ratengueltigkeit="FOLGEPERIODE"> ';
               IF(v_zahlungsplan_rec.zlg.betrag > 0)
               THEN
                   RESULT := RESULT || '<zlg ';
                   FN_SET_DATE_ATTRIBUTE('C','termin', v_zahlungsplan_rec.zlg.termin);
                   FN_SET_MONEY_ATTRIBUTE('C','betrag',  v_zahlungsplan_rec.zlg.betrag);
                   RESULT := RESULT || '/>';
               END IF;
              
               IF(v_zahlungsplan_rec.rate_explizit.COUNT > 0)
               THEN
                  FOR I IN v_zahlungsplan_rec.rate_explizit.FIRST..v_zahlungsplan_rec.rate_explizit.LAST 
                  LOOP
                         RESULT := RESULT || '<rate_explizit  ';
                         FN_SET_MONEY_ATTRIBUTE('C','betrag',  v_zahlungsplan_rec.rate_explizit(I).betrag);
                         FN_SET_DATE_ATTRIBUTE('C','faellig_ab', v_zahlungsplan_rec.rate_explizit(I).faellig_ab);
                         FN_SET_DATE_ATTRIBUTE('C','gueltig_bis', v_zahlungsplan_rec.rate_explizit(I).gueltig_bis);
                         FN_SET_STR_ATTRIBUTE('C','ratenabstand', v_zahlungsplan_rec.rate_explizit(I).ratenabstand);         
                         RESULT := RESULT || '/>';
                  END LOOP;
               END IF;
               RESULT := RESULT || '</ratenplan_explizit> </zahlungsplan>';
            END IF;


               /****************************************************/
               /*       CREATE verwaltungskosten XML SEGMENT           */
               /****************************************************/

               IF(v_verwaltungskosten_rec.createRestwert  = TRUE)
               THEN  
                  RESULT := RESULT || '<verwaltungskosten> <anfang ';
             
                  FN_SET_MONEY_ATTRIBUTE('C','betrag', v_verwaltungskosten_rec.anfang_betrag);
                  RESULT := RESULT || '/> <laufend ';
                  FN_SET_MONEY_ATTRIBUTE('C','betrag', v_verwaltungskosten_rec.laufend_betrag);

                  RESULT := RESULT || '/> <ende ';
                  FN_SET_MONEY_ATTRIBUTE('C','betrag', v_verwaltungskosten_rec.ende_betrag);
                  RESULT := RESULT || '/> </verwaltungskosten>';
               END IF;
               /****************************************************/
               /*       CREATE risikovorsorge  XML SEGMENT         */
               /****************************************************/
               IF(v_risikovorsorge_rec.createRestwert  = TRUE)
               THEN  
                    RESULT := RESULT || '<risikovorsorge ';
                    FN_SET_MONEY_ATTRIBUTE('C','prozent', v_risikovorsorge_rec.prozent); 
                    FN_SET_STR_ATTRIBUTE('C','bezugszeitraum',v_risikovorsorge_rec.bezugszeitraum);            
                    RESULT := RESULT || '/>';
               END IF;

                /*--------------------------------------------------*/
                /* Geting value for v_object_pkg_num                */
                /*--------------------------------------------------*/
                    BEGIN
                       v_obj_pkg := NULL;

                       FOR cur_objpkg IN cur_obj_pkg (v_curr_contract_rec.subseg_cd)
                       LOOP
                          v_obj_pkg := v_obj_pkg||'<anlagevermoegen';
                          v_obj_pkg :=
                                v_obj_pkg
                             || ' asset_num="'
                             || cur_objpkg.obj_pkg_num
                             || '" />'
                             || CHR (10);
                       END LOOP;
                       RESULT := RESULT || v_obj_pkg ;
                    EXCEPTION
                       WHEN OTHERS
                       THEN
                          pkg_batch_logger.proc_log (lf_file_handle,
                                                     'FATAL',
                                                     'BAT_F_9999',
                                                     'v_obj_pkg' || ',' || v_curr_contract_rec.subseg_cd,
                                                     SQLERRM
                                                    );
                    END;

            /*---------------------------------------------*/
            /* Geting value for v_txs_ref_id               */
            /*---------------------------------------------*/
             v_txs_ref_id :=v_curr_contract_rec.comp_num|| '-'
                           || v_curr_contract_rec.prtnr_num
                           || '-'
                           || v_curr_contract_rec.cntrct_num
                           || '-'
                           || v_curr_contract_rec.seg_num               
                           || '-'               
                           || v_curr_contract_rec.subseg_num;

            IF(v_curr_contract_rec.comp_num  = '599')
            THEN
                v_txs_ref_id := null;
            ELSIF(v_curr_contract_rec.comp_num IN(5,83) )
            THEN
                IF(v_cntr_other_info.lgs_refin_typ_desc !='C')
                THEN
                        v_txs_ref_id := null;
                END IF;
            END IF;
            IF(v_txs_ref_id is not null)
            THEN
                    RESULT := RESULT ||  ' <txs_reference txs_ref_id="'|| v_txs_ref_id || '" />';
            END IF;

            RESULT := RESULT || '  </vertrag> </direktvertrag> </vorgang> </bestand>';
               --Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Fianl xml2  ==>'||RESULT,'', '');                
   END PROC_CREATE_CONTR_FINAL_XML;

   PROCEDURE PROC_CREATE_XML IS

     /* v_doc             xmldom.DOMDocument;
      v_main_node       xmldom.DOMNode;
      v_root_node       xmldom.DOMNode;
      v_tmp_node         xmldom.DOMNode;
      v_vetrag_node         xmldom.DOMNode;
      v_item_node         xmldom.DOMNode;
      v_root_elmt         xmldom.DOMElement;
      v_item_elmt         xmldom.DOMElement;
      v_tmp_elmt          xmldom.DOMNode;
      v_vetrag_elmt         xmldom.DOMElement;

      v_item_text         xmldom.DOMText;
     */
   BEGIN
  /*        -- get document
      v_doc := xmldom.newDOMDocument;
      
      -- create root element
      v_main_node := xmldom.makeNode(v_doc);
      v_root_elmt := xmldom.createElement(v_doc, 'bestand'  );

--      xmldom.setAttribute(v_root_elmt, 'xmlns', 'http://www.akadia.com/xml/soug/xmldom');
      xmldom.setAttribute(v_root_elmt, 'xmlns:xsi', 'http://www.w3.org/2001/XMLSchema-instance');
      xmldom.setAttribute(v_root_elmt, 'xsi:noNamespaceSchemaLocation', 'TLL_Bestand.xsd');
      xmldom.setAttribute(v_root_elmt, 'sim_stichtag',to_char(v_stichtag_date,'dd.mm.yyyy'));
      xmldom.setAttribute(v_root_elmt, 'bestandstyp','BESTAND');
      v_root_node := xmldom.appendChild(v_main_node, xmldom.makeNode(v_root_elmt) );

      
      v_item_elmt := xmldom.createElement(v_doc,'vorgang');
      xmldom.setAttribute(v_item_elmt, 'vname', v_curr_contract_rec.vname);
      v_tmp_node := xmldom.appendChild(v_root_node, xmldom.makeNode(v_item_elmt));

      v_item_elmt := xmldom.createElement(v_doc,'direktvertrag');
      v_tmp_node := xmldom.appendChild(v_tmp_node, xmldom.makeNode(v_item_elmt));

      v_item_elmt := xmldom.createElement(v_doc,'vertrag');
      v_vetrag_node := xmldom.appendChild(v_tmp_node, xmldom.makeNode(v_item_elmt));
      
      -- create vetrag header 
      v_item_elmt := xmldom.createElement(v_doc,'vertragsheader');
      
      FN_SET_STR_ATTRIBUTE(v_item_elmt, 'gesellschaft',           lpad(v_curr_contract_rec.gesellschaft,3,'0'));  
      FN_SET_STR_ATTRIBUTE(v_item_elmt, 'geschaeftsstelle',       v_curr_contract_rec.geschaeftsstelle);            
      FN_SET_STR_ATTRIBUTE(v_item_elmt, 'plz',                    v_curr_contract_rec.plz);                         
      FN_SET_STR_ATTRIBUTE(v_item_elmt, 'branche',                v_curr_contract_rec.branche );                    
      FN_SET_STR_ATTRIBUTE(v_item_elmt, 'geschaeftsbereich',      v_curr_contract_rec.geschaeftsbereich );          
      FN_SET_STR_ATTRIBUTE(v_item_elmt, 'rating',                 v_curr_contract_rec.rating     );                 
      FN_SET_STR_ATTRIBUTE(v_item_elmt, 'objektart',              v_curr_contract_rec.objektart       );            
      FN_SET_STR_ATTRIBUTE(v_item_elmt, 'vertriebsweg',           v_curr_contract_rec.vertriebsweg  );              
      FN_SET_STR_ATTRIBUTE(v_item_elmt, 'ratenstruktur',          v_curr_contract_rec.ratenstruktur );              
      
      FN_SET_DATE_ATTRIBUTE(v_item_elmt, 'vbeginn',                v_curr_contract_rec.vbeginn   );                  
      FN_SET_DATE_ATTRIBUTE(v_item_elmt, 'vende_grundlaufzeit',    v_curr_contract_rec.vende_grundlaufzeit );        
      FN_SET_DATE_ATTRIBUTE(v_item_elmt, 'vende_verlaengerung',    v_curr_contract_rec.vende_verlaengerung );        
      FN_SET_DATE_ATTRIBUTE(v_item_elmt, 'naechste_sollstellung',  v_curr_contract_rec.naechste_sollstellung  );     
      FN_SET_DATE_ATTRIBUTE(v_item_elmt, 'zugangsdatum',           v_curr_contract_rec.zugangsdatum   );             
     
      FN_SET_STR_ATTRIBUTE(v_item_elmt, 'vertragstyp',            v_curr_contract_rec.vertragstyp  );               
      FN_SET_STR_ATTRIBUTE(v_item_elmt, 'vertragstyp_erweitert',  v_curr_contract_rec.vertragstyp_erweitert );      
      FN_SET_STR_ATTRIBUTE(v_item_elmt, 'vertragsart',            v_curr_contract_rec.vertragsart      );           
      
      FN_SET_PERCENT_ATTRIBUTE(v_item_elmt, 'intern_kalkuzins',       v_curr_contract_rec.intern_kalkuzins );           
      FN_SET_PERCENT_ATTRIBUTE(v_item_elmt, 'refi_kalkuzins',         v_curr_contract_rec.refi_kalkuzins   );           

      FN_SET_STR_ATTRIBUTE(v_item_elmt, 'geschaeftsfeld',         v_curr_contract_rec.geschaeftsfeld   );           
      FN_SET_STR_ATTRIBUTE(v_item_elmt, 'zahlungsweise',          v_curr_contract_rec.zahlungsweise   );            
      FN_SET_INT_ATTRIBUTE(v_item_elmt, 'mahnstufe',              v_curr_contract_rec.mahnstufe      );             
      FN_SET_STR_ATTRIBUTE(v_item_elmt, 'rechenart_mk',           v_curr_contract_rec.rechenart_mk   );             
      FN_SET_STR_ATTRIBUTE(v_item_elmt, 'status',                 v_curr_contract_rec.status         );             

      v_item_node := xmldom.appendChild(v_vetrag_node, xmldom.makeNode(v_item_elmt));

      v_item_elmt := xmldom.createElement(v_doc,'anschaffungswert');
      FN_SET_MONEY_ATTRIBUTE(RESULT,v_item_elmt, 'betrag',v_curr_contract_rec.anschaffungswert )

      v_item_node := xmldom.appendChild(v_item_node, xmldom.makeNode(v_item_elmt));*/
      dbms_output.put_line('test');
    
   END PROC_CREATE_XML;

   PROCEDURE PROC_CREATE_MSZ 
   IS
      l_sixpct_acqstn_val        uc_pricing_ms.acqstn_value%TYPE;
      l_msz_linear_accrl_amt     UC_ACCRL_COLTR_MS.LINEAR_ACCRL_AMT%TYPE;
      l_msz_fincl_accrl_amt      UC_ACCRL_COLTR_MS.FINCL_ACCRL_AMT%TYPE;
      l_msz_first_relase_dt      DATE;
      l_msz_last_relase_dt       DATE;
      l_no_acc_rec               NUMBER := 0;
      l_msz_linear_accrl_amt_100 UC_ACCRL_COLTR_MS.FINCL_ACCRL_AMT%TYPE;
      PROCEDURE PROC_CALC_MSZ_RAP_REST_AMOUNT IS
      BEGIN
            -- Retrieve the PRAP MSZ REST AMT
            BEGIN --{
                   SELECT 
                        linear_accrl_amt ,
                        fincl_accrl_amt  ,
                        first_accr_relse_dt,
                        last_accr_relse_dt ,
                        rownum
                   INTO l_msz_linear_accrl_amt,
                        l_msz_fincl_accrl_amt,
                        l_msz_first_relase_dt,
                        l_msz_last_relase_dt,
                        l_no_acc_rec
                   FROM UC_ACCRUAL_RPT_TRGNS_TP accr_ms
                   WHERE ACCRL_OBJ = 'MSZ'
                   AND ACCRL_KEY = v_curr_contract_rec.subseg_cd ;
            EXCEPTION
            WHEN NO_DATA_FOUND 
            THEN
                  l_msz_linear_accrl_amt := 0;
                  l_msz_fincl_accrl_amt  := 0;
                  l_no_acc_rec := 0;
            WHEN OTHERS 
            THEN
                  Pkg_Batch_Logger.proc_log (lv_file_handle,'FATAL','BAT_F_9999','UC_ACCRL_COLTR_MS FOR SUBSEG_CD'|| v_curr_contract_rec.subseg_cd, SQLERRM);
                  raise v_skip_record;
            END; --}

            --Added for the defect 12387
            IF( nvl(l_no_acc_rec,0) = 0)
            THEN
               ---Check for lessee Change.
               FOR Less_Rec IN LESSEE_CUR(v_curr_contract_rec.subseg_cd)
               LOOP
                  l_msz_linear_accrl_amt := 0;
                  l_msz_fincl_accrl_amt  := 0;
                  l_no_acc_rec := 0;

                  IF(Less_Rec.cntrct_stat_num != '400')
                  THEN
                     BEGIN --{
                        SELECT 
                                SUM
                                (
                                        CASE WHEN  RELSE_FRM_DT  > v_stichtag_date  AND accr_ms.cancl_flg is null 
                                        THEN 
                                                NVL(LINEAR_ACCRL_AMT,0)
                                        ELSE    0 
                                        END
                                ),
                                SUM
                                (
                                        CASE WHEN  RELSE_FRM_DT  > v_stichtag_date  AND accr_ms.cancl_flg is null 
                                THEN 
                                        NVL(FINCL_ACCRL_AMT,0)
                                ELSE    0 
                                END
                                ),
                                MIN(accr_ms.RELSE_FRM_DT),
                                MAX(accr_ms.RELSE_FRM_DT),
                                COUNT(1)
                       INTO l_msz_linear_accrl_amt,
                       l_msz_fincl_accrl_amt,
                       l_msz_first_relase_dt,
                       l_msz_last_relase_dt,
                       l_no_acc_rec
                      FROM UC_ACCRL_COLTR_MS accr_ms,uc_segment_ms seg,uc_sub_segment_ms sseg
                      WHERE TRNSCTN_TYP =  200
                      AND ACCRL_OBJ = 'MSZ'
                      AND sseg.subseg_cd = Less_Rec.subseg_cd 		
                      AND seg.seg_cd = sseg.seg_cd
                      AND accr_ms.subseg_cd = sseg.subseg_cd
                      AND accr_ms.seg_cd = seg.seg_cd
                      AND accr_ms.cntrct_cd = seg.cntrct_cd
                      AND accr_ms.comp_num = v_curr_contract_rec.comp_num;
                     -- AND accr_ms.cancl_flg is null;

                      IF ( nvl(l_no_acc_rec,0) > 0)
                      THEN
                        EXIT;
                      END IF;

                  EXCEPTION
                  WHEN NO_DATA_FOUND 
                  THEN
                        l_msz_linear_accrl_amt := 0;
                        l_msz_fincl_accrl_amt  := 0;
                        l_msz_linear_accrl_amt_100 := 0;
                        l_no_acc_rec := 0;
                  WHEN OTHERS 
                  THEN
                        Pkg_Batch_Logger.proc_log (lv_file_handle,'FATAL','BAT_F_9999','UC_ACCRL_COLTR_MS FOR SUBSEG_CD'|| v_curr_contract_rec.subseg_cd, SQLERRM);
                        raise v_fatal_excp;
                  END; --}
                END IF;
              END LOOP;
            END IF;
      END PROC_CALC_MSZ_RAP_REST_AMOUNT;
   BEGIN
        v_msz_rec := NULL;
        v_msz_rec.faelligkeit := null;
        v_msz_rec.aufloesung_beginn := null;
        v_msz_rec.faelligkeit := null;
        v_msz_rec.aufloesung_ende := null;
        v_msz_rec.ende_aufloesungszeit := null;
        v_msz_rec.msz_betrag := null;
        v_msz_rec.msz_rap_betrag := null;

        IF(v_cntr_other_info.down_pymt > 0 and v_vertragsheader_rec.vertragstyp != 'MIETKAUF')
        THEN
            v_msz_rec.createMSZ         := true;
            l_sixpct_acqstn_val := v_cntr_other_info.acqstn_value * 6/100;
            v_msz_rec.faelligkeit             := nvl(v_curr_contract_rec.lease_bgn_dt,v_vertragsheader_rec.vbeginn1);
            v_msz_rec.msz_betrag    := v_cntr_other_info.down_pymt;
            IF(v_cntr_other_info.down_pymt > l_sixpct_acqstn_val )
            THEN
               IF(v_curr_contract_rec.cntrct_start_dt < v_stichtag_date)
               THEN
                  PROC_CALC_MSZ_RAP_REST_AMOUNT;
                  v_msz_rec.msz_rap_betrag          := nvl(l_msz_linear_accrl_amt,0);
                  v_msz_rec.aufloesung_beginn       := TRUNC(nvl(l_msz_first_relase_dt ,v_vertragsheader_rec.vbeginn1),'MM');
                  v_msz_rec.aufloesung_ende         := v_curr_contract_rec.lease_end_dt;
                  v_msz_rec.ende_aufloesungszeit    := l_msz_last_relase_dt;
               ELSE
                  PROC_CALC_MSZ_RAP_REST_AMOUNT;
                  v_msz_rec.aufloesung_beginn       := TRUNC(nvl(l_msz_first_relase_dt ,v_vertragsheader_rec.vbeginn1),'MM');
                  v_msz_rec.aufloesung_ende         := v_curr_contract_rec.lease_end_dt;
                  v_msz_rec.ende_aufloesungszeit    := l_msz_last_relase_dt;
               END IF;
               IF(v_curr_contract_rec.comp_num = '599')--$$$ Lesee Change
               THEN
                  IF(v_msz_rec.aufloesung_beginn >= v_msz_rec.aufloesung_ende)
                  THEN
                        v_msz_rec.aufloesung_beginn   := TRUNC(nvl(v_cntr_other_info.first_instlmnt_dt,v_vertragsheader_rec.vbeginn1),'MM');
                  END IF;
               END IF;
            ELSE  
               IF(v_curr_contract_rec.cntrct_start_dt < v_stichtag_date)
               THEN
                  v_msz_rec.msz_rap_betrag := 0;
               END IF;
            END IF;
        ELSE
            v_msz_rec.createMSZ := false;
        END IF;
   EXCEPTION
   WHEN OTHERS 
   THEN
      Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999','PROC_CREATE_MSZ:SUBSEG_CD'||v_curr_contract_rec.subseg_cd, SQLERRM);
      RAISE v_fatal_excp;
   END PROC_CREATE_MSZ;

   PROCEDURE PROC_CREATE_MIETKAUFVERMOGEN IS
   BEGIN
            v_mietkaufvermogen_rec := null;
            v_mietkaufvermogen_rec.createMietkaufvermogen :=  FALSE;
            IF(v_vertragsheader_rec.vertragstyp != 'MIETKAUF')
            THEN
               v_mietkaufvermogen_rec.createMietkaufvermogen :=  false;
            ELSE
                  v_mietkaufvermogen_rec.createMietkaufvermogen :=  true;
                  BEGIN
                        SELECT fincl_accrl_amt 
                        INTO v_mietkaufvermogen_rec.restbuchwert_betrag
                        FROM UC_ACCRUAL_RPT_TRGNS_TP
                        WHERE accrl_key = v_curr_contract_rec.subseg_cd
                        AND ACCRL_OBJ = 'MK' ;  -- Changes for TritAnStelle implemented
                  EXCEPTION
                  WHEN OTHERS THEN
                       v_mietkaufvermogen_rec.restbuchwert_betrag := null;
                  END;
         
                  /* Start of Fix for Defect 16619 - Source Version 1.14 */
                  IF nvl(v_mietkaufvermogen_rec.restbuchwert_betrag,0) = 0
                  THEN
                      IF v_cntr_other_info.pkt_cd IS NOT NULL
                      THEN
                              BEGIN
                                 SELECT   linear_outstdng_prncpl_amt 
                                 INTO     v_mietkaufvermogen_rec.restbuchwert_betrag
                                 FROM     UC_ACCRL_COLTR_MS
                                 WHERE    PKT_CD = v_cntr_other_info.pkt_cd
                                 AND      ACCRL_OBJ = 'MK_Verwk' 
                                 AND      TRNSCTN_TYP = 200 
                                 AND      RELSE_FRM_DT = v_stichtag_date
                                 AND      CANCL_FLG is NULL;
                              EXCEPTION
                              WHEN OTHERS THEN
                                 Pkg_Batch_Logger.proc_log(lf_file_handle,'DEBUG','Error while fetching MK Verwk details for Packet Code : '||sqlerrm,'',v_cntr_other_info.pkt_cd);
                                 v_mietkaufvermogen_rec.restbuchwert_betrag := NULL ;
                              END ;
                      END IF;
                  END IF;
            END IF;
            IF v_mietkaufvermogen_rec.restbuchwert_betrag IS NULL
            THEN
                  v_mietkaufvermogen_rec.createMietkaufvermogen :=  false;
            END IF;
   EXCEPTION
   WHEN OTHERS 
   THEN
         Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999','HEADER_6', SQLERRM);
         RAISE v_fatal_excp;
   END PROC_CREATE_MIETKAUFVERMOGEN;
   
   PROCEDURE PROC_CREATE_NACHGESCHAEFT  IS
   BEGIN
                dbms_output.put_line('test');
   END PROC_CREATE_NACHGESCHAEFT;

-- UC_OBJECT_PACKAGE_MS.SUPL_ID%TYPE was added by Rajagopal on 20-11-2007 for CEAnF implementation
-- SECU_PROVIDER column in each union query was added by Rajagopal on 20-11-2007 for CEAnF implementation
-- p_confirm_flg was added by Rajagopal on 03-12-2007 for CEAnF implementation
-- p_sparte was added by Rajagopal on 05-01-2008 to identify the distribution channel of the contract

PROCEDURE POPULATE_SECURITY_CLASS (v_distrib_chnl_cd UC_DISTRIB_CHNL_MS.DISTRIB_CHNL_CD%TYPE,
                                   v_bus_seg_cd   UC_BUS_SEG_MS.BUS_SEG_CD%TYPE,
                                   v_refin_typ_cd UC_SUB_SEGMENT_MS.REFIN_TYP%TYPE,
                                   v_cr_worth     UC_PARTNER_MS.CR_WORTH%TYPE,
                                   p_subseg_cd    UC_SUB_SEGMENT_MS.SUBSEG_CD%TYPE,
                                   p_supl_id		  UC_OBJECT_PACKAGE_MS.SUPL_ID%TYPE,
                                   p_confirm_flg	VARCHAR2,
                                   p_lgs_flg  VARCHAR2,
                                   p_sparte VARCHAR2)
AS

-- The IF..ELSE block was added by Rajagopal on 22-11-2007 and 03-12-2007 for CEAnF implementation


      CURSOR cur_security_class1 IS
         SELECT SECU_TYP_CD, SECU_DESC, CALCN_ORDER, SECU_GRP, RISK_CVRG, CR_WORTH, SECU_PROVIDER
        FROM  (
             SELECT A.SECU_TYP_CD SECU_TYP_CD, A.SECU_DESC SECU_DESC, A.CALCN_ORDER CALCN_ORDER,
                   A.SECU_GRP SECU_GRP, 100 RISK_CVRG, NULL CR_WORTH, NULL SECU_PROVIDER
            FROM   UC_SECURITY_TYPE_DN A,
                   UC_REFIN_CODES_MS  B,
                  UC_SUB_SEGMENT_MS c
            WHERE  A.SECU_DESC = B.CD_DESC
            AND    B.REFIN_CODES_CD = NVL(REFIN_TYP,LGS_REFIN_TYP)
            AND    C.SUBSEG_CD = p_subseg_cd
            UNION
               SELECT A.SECU_TYP_CD SECU_TYP_CD, A.SECU_DESC SECU_DESC, A.CALCN_ORDER CALCN_ORDER, 
                      A.SECU_GRP SECU_GRP, B.RISK_CVRG, DECODE(A.GARNTR_CR_FLG, 'J', B.CR_WORTH, V_CR_WORTH) CR_WORTH, NVL(B.PRTNR_ID, P_SUPL_ID) SECU_PROVIDER 
                  FROM UC_SECURITY_TYPE_DN    A, 
                       UC_SECU_PRVDR_TX  B, 
                       UC_SUB_SEGMENT_MS C
                  WHERE B.OWNER_ID = C.SUBSEG_CD
                        AND A.SECU_TYP_CD = B.SECU_TYP_CD
                        AND B.DEL_FLG = 'N'
                        AND B.RISK_RLVNCE = 'Y'
                        AND C.SUBSEG_CD = p_subseg_cd
            UNION 
               SELECT A.SECU_TYP_CD SECU_TYP_CD, A.SECU_DESC SECU_DESC, A.CALCN_ORDER CALCN_ORDER, 
                      A.SECU_GRP SECU_GRP, B.RISK_CVRG, DECODE(A.GARNTR_CR_FLG, 'J', B.CR_WORTH, V_CR_WORTH) CR_WORTH, NVL(B.PRTNR_ID, E.SUPL_ID) SECU_PROVIDER
                  FROM UC_SECURITY_TYPE_DN    A, 
                       UC_SECU_PRVDR_TX  B, 
                      UC_SUB_SEGMENT_MS C,
                      UC_SUBSEG_OBJ_PKG_TX D,
                      UC_OBJECT_PACKAGE_MS E,
                      UC_OBJECT_MS F,
                      UC_SUBSEG_OBJPKG_OBJ_TX G
                  WHERE (B.OWNER_ID = G.SUBSEG_OBJPKG_OBJ_CD OR B.OWNER_ID = D.SUBSEG_OBJ_PKG_CD)
                       AND A.SECU_TYP_CD = B.SECU_TYP_CD
                       AND B.DEL_FLG = 'N'
                       AND B.RISK_RLVNCE = 'Y'
                       AND C.SUBSEG_CD = D.SUBSEG_CD
                       aND D.OBJ_PKG_CD = E.OBJ_PKG_ID
                       AND D.SUBSEG_OBJ_PKG_CD = G.SUBSEG_OBJ_PKG_CD
                       AND G.OBJ_ID = F.OBJ_ID
                       AND C.SUBSEG_CD = p_subseg_cd
            UNION
            SELECT std.SECU_TYP_CD SECU_TYP_CD, std.SECU_DESC SECU_DESC, std.CALCN_ORDER CALCN_ORDER,
                   std.SECU_GRP SECU_GRP, ((opm.INTRNL_BGL/PM.ACQSTN_VALUE)*100) RISK_CVRG, 
                   V_CR_WORTH CR_WORTH, opm.SUPL_ID SECU_PROVIDER
             FROM   UC_SUBSEG_OBJ_PKG_TX sopt,
                    UC_OBJECT_PACKAGE_MS opm,
                   UC_OBJECT_HIERARCHY_MS ohm,
                   UC_SECURITY_TYPE_DN std,
                   UC_PRICING_MS PM
             WHERE  opm.HRCHY_ID    = ohm.hrchy_id
             AND    sopt.obj_pkg_CD = opm.OBJ_PKG_ID
             AND    std.SECU_TYP_CD = ohm.SECU_TYP_CD
             AND    SOPT.SUBSEG_CD  = PM.SUBSEG_CD
             AND    sopt.subseg_cd  = p_subseg_cd )  SECURITY_INFO
         ORDER BY CALCN_ORDER;

      CURSOR cur_security_class2 IS
         SELECT SECU_TYP_CD, SECU_DESC, CALCN_ORDER, SECU_GRP, RISK_CVRG, CR_WORTH, SECU_PROVIDER
        FROM  (
             SELECT A.SECU_TYP_CD SECU_TYP_CD, A.SECU_DESC SECU_DESC, A.CALCN_ORDER CALCN_ORDER,
                   A.SECU_GRP SECU_GRP, 100 RISK_CVRG, NULL CR_WORTH, NULL SECU_PROVIDER
            FROM   UC_SECURITY_TYPE_DN A,
                   UC_REFIN_CODES_MS  B,
                  UC_SUB_SEGMENT_MS c
            WHERE  A.SECU_DESC = B.CD_DESC
            AND    B.REFIN_CODES_CD = NVL(REFIN_TYP,LGS_REFIN_TYP)
            AND    C.SUBSEG_CD = p_subseg_cd
         UNION
            SELECT A.SECU_TYP_CD SECU_TYP_CD, A.SECU_DESC SECU_DESC, A.CALCN_ORDER CALCN_ORDER, 
                  A.SECU_GRP SECU_GRP, B.RISK_CVRG, DECODE(A.GARNTR_CR_FLG, 'J', D.CR_WORTH, V_CR_WORTH) CR_WORTH, B.PRTNR_ID SECU_PROVIDER 
               FROM UC_SECURITY_TYPE_DN    A,
                    UC_SECU_PRVDR_TX  B,
                    UC_SUB_SEGMENT_MS C,
                    UC_PARTNER_MS D
               WHERE B.OWNER_ID = C.SUBSEG_CD
               AND   A.SECU_TYP_CD = B.SECU_TYP_CD
               AND   D.PRTNR_ID = B.PRTNR_ID
               AND B.DEL_FLG = 'N'
               AND B.RISK_RLVNCE = 'Y'
               AND C.SUBSEG_CD = p_subseg_cd
            UNION
            SELECT A.SECU_TYP_CD SECU_TYP_CD, A.SECU_DESC SECU_DESC, A.CALCN_ORDER CALCN_ORDER, 
                  A.SECU_GRP SECU_GRP, B.RISK_CVRG, V_CR_WORTH CR_WORTH, P_SUPL_ID SECU_PROVIDER 
               FROM UC_SECURITY_TYPE_DN    A,
                    UC_SECU_PRVDR_TX  B,
                    UC_SUB_SEGMENT_MS C
               WHERE B.OWNER_ID = C.SUBSEG_CD
               AND   A.SECU_TYP_CD = B.SECU_TYP_CD
                AND B.DEL_FLG = 'N'
               AND B.RISK_RLVNCE = 'Y'
               AND B.PRTNR_ID IS NULL
               AND C.SUBSEG_CD = p_subseg_cd
            UNION 
            SELECT A.SECU_TYP_CD SECU_TYP_CD, A.SECU_DESC SECU_DESC, A.CALCN_ORDER CALCN_ORDER, 
                  A.SECU_GRP SECU_GRP, B.RISK_CVRG, DECODE(A.GARNTR_CR_FLG, 'J', H.CR_WORTH, V_CR_WORTH) CR_WORTH, NVL(B.PRTNR_ID, E.SUPL_ID) SECU_PROVIDER
               FROM UC_SECURITY_TYPE_DN    A, 
                    UC_SECU_PRVDR_TX  B, 
                   UC_SUB_SEGMENT_MS C,
                   UC_SUBSEG_OBJ_PKG_TX D,
                   UC_OBJECT_PACKAGE_MS E,
                   UC_OBJECT_MS F,
                   UC_SUBSEG_OBJPKG_OBJ_TX G,
                   UC_PARTNER_MS H
               WHERE (B.OWNER_ID = G.SUBSEG_OBJPKG_OBJ_CD OR B.OWNER_ID = D.SUBSEG_OBJ_PKG_CD)
                    AND A.SECU_TYP_CD = B.SECU_TYP_CD
                    AND B.DEL_FLG = 'N'
                     AND B.RISK_RLVNCE = 'Y'
                    AND C.SUBSEG_CD = D.SUBSEG_CD
                    aND D.OBJ_PKG_CD = E.OBJ_PKG_ID
                    AND D.SUBSEG_OBJ_PKG_CD = G.SUBSEG_OBJ_PKG_CD
                    AND G.OBJ_ID = F.OBJ_ID
                    AND H.PRTNR_ID = B.PRTNR_ID
                     AND C.SUBSEG_CD = p_subseg_cd
            UNION 
            SELECT A.SECU_TYP_CD SECU_TYP_CD, A.SECU_DESC SECU_DESC, A.CALCN_ORDER CALCN_ORDER, 
                  A.SECU_GRP SECU_GRP, B.RISK_CVRG, V_CR_WORTH CR_WORTH, E.SUPL_ID SECU_PROVIDER
               FROM UC_SECURITY_TYPE_DN    A, 
                    UC_SECU_PRVDR_TX  B, 
                   UC_SUB_SEGMENT_MS C,
                   UC_SUBSEG_OBJ_PKG_TX D,
                   UC_OBJECT_PACKAGE_MS E,
                   UC_OBJECT_MS F,
                   UC_SUBSEG_OBJPKG_OBJ_TX G
               WHERE (B.OWNER_ID = G.SUBSEG_OBJPKG_OBJ_CD OR B.OWNER_ID = D.SUBSEG_OBJ_PKG_CD)
                    AND A.SECU_TYP_CD = B.SECU_TYP_CD
                    AND B.DEL_FLG = 'N'
                    AND B.RISK_RLVNCE = 'Y'
                    AND B.PRTNR_ID IS NULL
                    AND C.SUBSEG_CD = D.SUBSEG_CD
                    aND D.OBJ_PKG_CD = E.OBJ_PKG_ID
                    AND D.SUBSEG_OBJ_PKG_CD = G.SUBSEG_OBJ_PKG_CD
                    AND G.OBJ_ID = F.OBJ_ID
                    AND C.SUBSEG_CD = p_subseg_cd
            UNION
            SELECT std.SECU_TYP_CD SECU_TYP_CD, std.SECU_DESC SECU_DESC, std.CALCN_ORDER CALCN_ORDER,
                   std.SECU_GRP SECU_GRP, ((opm.INTRNL_BGL/PM.ACQSTN_VALUE)*100) RISK_CVRG, 
                   V_CR_WORTH CR_WORTH, opm.SUPL_ID SECU_PROVIDER
             FROM   UC_SUBSEG_OBJ_PKG_TX sopt,
                    UC_OBJECT_PACKAGE_MS opm,
                   UC_OBJECT_HIERARCHY_MS ohm,
                   UC_SECURITY_TYPE_DN std,
                   UC_PRICING_MS PM
             WHERE  opm.HRCHY_ID    = ohm.hrchy_id
             AND    sopt.obj_pkg_CD = opm.OBJ_PKG_ID
             AND    std.SECU_TYP_CD = ohm.SECU_TYP_CD
             AND    SOPT.SUBSEG_CD  = PM.SUBSEG_CD
             AND    sopt.subseg_cd  = p_subseg_cd )  SECURITY_INFO
         ORDER BY CALCN_ORDER;

   CURSOR cur_security_class3 IS
         SELECT SECU_TYP_CD, SECU_DESC, CALCN_ORDER, SECU_GRP, RISK_CVRG, CR_WORTH, SECU_PROVIDER
        FROM  (		
         SELECT A.SECU_TYP_CD SECU_TYP_CD, A.SECU_DESC SECU_DESC, A.CALCN_ORDER CALCN_ORDER, 
               A.SECU_GRP SECU_GRP, B.RISK_CVRG, DECODE(A.GARNTR_CR_FLG, 'J', B.CR_WORTH, V_CR_WORTH) CR_WORTH, NVL(B.PRTNR_ID, P_SUPL_ID) SECU_PROVIDER 
            FROM UC_SECURITY_TYPE_DN    A, 
                 UC_SECU_PRVDR_TX  B, 
                 UC_SUB_SEGMENT_MS C
            WHERE B.OWNER_ID = C.SUBSEG_CD
                 AND A.SECU_TYP_CD = B.SECU_TYP_CD
                 AND B.DEL_FLG = 'N'
                 AND B.RISK_RLVNCE = 'Y'		  
                 AND C.SUBSEG_CD = p_subseg_cd
         UNION 
         SELECT A.SECU_TYP_CD SECU_TYP_CD, A.SECU_DESC SECU_DESC, A.CALCN_ORDER CALCN_ORDER, 
                A.SECU_GRP SECU_GRP, B.RISK_CVRG, DECODE(A.GARNTR_CR_FLG, 'J', B.CR_WORTH, V_CR_WORTH) CR_WORTH, NVL(B.PRTNR_ID, E.SUPL_ID) SECU_PROVIDER
            FROM UC_SECURITY_TYPE_DN    A, 
                UC_SECU_PRVDR_TX  B, 
                UC_SUB_SEGMENT_MS C,
                UC_SUBSEG_OBJ_PKG_TX d,
                UC_OBJECT_PACKAGE_MS e,
                UC_OBJECT_MS f,
                UC_SUBSEG_OBJPKG_OBJ_TX g
            WHERE (B.OWNER_ID = G.SUBSEG_OBJPKG_OBJ_CD OR B.OWNER_ID = D.SUBSEG_OBJ_PKG_CD)
                 AND A.SECU_TYP_CD = B.SECU_TYP_CD
                 AND B.DEL_FLG = 'N'
                 AND B.RISK_RLVNCE = 'Y'		  	  
                 AND C.SUBSEG_CD = D.SUBSEG_CD
                 aND D.OBJ_PKG_CD = E.OBJ_PKG_ID
                 AND D.SUBSEG_OBJ_PKG_CD = G.SUBSEG_OBJ_PKG_CD
                 AND G.OBJ_ID = F.OBJ_ID
                 AND C.SUBSEG_CD = p_subseg_cd
            UNION
            SELECT std.SECU_TYP_CD SECU_TYP_CD, std.SECU_DESC SECU_DESC, std.CALCN_ORDER CALCN_ORDER,
                   std.SECU_GRP SECU_GRP, ((opm.INTRNL_BGL/PM.ACQSTN_VALUE)*100) RISK_CVRG, 
                   V_CR_WORTH CR_WORTH, opm.SUPL_ID SECU_PROVIDER
             FROM   UC_SUBSEG_OBJ_PKG_TX sopt,
                    UC_OBJECT_PACKAGE_MS opm,
                   UC_OBJECT_HIERARCHY_MS ohm,
                   UC_SECURITY_TYPE_DN std,
                   UC_PRICING_MS PM
             WHERE  opm.HRCHY_ID    = ohm.hrchy_id
             AND    sopt.obj_pkg_CD = opm.OBJ_PKG_ID
             AND    std.SECU_TYP_CD = ohm.SECU_TYP_CD
             AND    SOPT.SUBSEG_CD  = PM.SUBSEG_CD
             AND    sopt.subseg_cd  = p_subseg_cd)  SECURITY_INFO
         ORDER BY CALCN_ORDER;

      CURSOR cur_security_class4 IS
         SELECT SECU_TYP_CD, SECU_DESC, CALCN_ORDER, SECU_GRP, RISK_CVRG, CR_WORTH, SECU_PROVIDER
        FROM  (				
         SELECT A.SECU_TYP_CD SECU_TYP_CD, A.SECU_DESC SECU_DESC, A.CALCN_ORDER CALCN_ORDER, 
                A.SECU_GRP SECU_GRP, B.RISK_CVRG, DECODE(A.GARNTR_CR_FLG, 'J', D.CR_WORTH, V_CR_WORTH) CR_WORTH, B.PRTNR_ID SECU_PROVIDER 
            FROM UC_SECURITY_TYPE_DN    A,
                 UC_SECU_PRVDR_TX  B,
                 UC_SUB_SEGMENT_MS C,
                 UC_PARTNER_MS D
            WHERE B.OWNER_ID = C.SUBSEG_CD
              AND A.SECU_TYP_CD = B.SECU_TYP_CD
              AND D.PRTNR_ID = B.PRTNR_ID
              AND B.DEL_FLG = 'N'
              AND B.RISK_RLVNCE = 'Y'
              AND C.SUBSEG_CD = p_subseg_cd
         UNION
         SELECT A.SECU_TYP_CD SECU_TYP_CD, A.SECU_DESC SECU_DESC, A.CALCN_ORDER CALCN_ORDER, 
                A.SECU_GRP SECU_GRP, B.RISK_CVRG, V_CR_WORTH CR_WORTH, P_SUPL_ID SECU_PROVIDER 
            FROM UC_SECURITY_TYPE_DN    A,
                 UC_SECU_PRVDR_TX  B,
                 UC_SUB_SEGMENT_MS C
            WHERE B.OWNER_ID = C.SUBSEG_CD
              AND A.SECU_TYP_CD = B.SECU_TYP_CD
              AND B.DEL_FLG = 'N'
              AND B.RISK_RLVNCE = 'Y'
              AND B.PRTNR_ID IS NULL
              AND C.SUBSEG_CD = p_subseg_cd
         UNION 
         SELECT A.SECU_TYP_CD SECU_TYP_CD, A.SECU_DESC SECU_DESC, A.CALCN_ORDER CALCN_ORDER, 
                A.SECU_GRP SECU_GRP, B.RISK_CVRG, DECODE(A.GARNTR_CR_FLG, 'J', H.CR_WORTH, V_CR_WORTH) CR_WORTH, NVL(B.PRTNR_ID, E.SUPL_ID) SECU_PROVIDER
            FROM UC_SECURITY_TYPE_DN    A, 
                 UC_SECU_PRVDR_TX  B, 
                 UC_SUB_SEGMENT_MS C,
                 UC_SUBSEG_OBJ_PKG_TX D,
                 UC_OBJECT_PACKAGE_MS E,
                 UC_OBJECT_MS F,
                 UC_SUBSEG_OBJPKG_OBJ_TX G,
                 UC_PARTNER_MS H
            WHERE (B.OWNER_ID = G.SUBSEG_OBJPKG_OBJ_CD OR B.OWNER_ID = D.SUBSEG_OBJ_PKG_CD)
              AND A.SECU_TYP_CD = B.SECU_TYP_CD
              AND B.DEL_FLG = 'N'
              AND B.RISK_RLVNCE = 'Y'
              AND C.SUBSEG_CD = D.SUBSEG_CD
              AND D.OBJ_PKG_CD = E.OBJ_PKG_ID
              AND D.SUBSEG_OBJ_PKG_CD = G.SUBSEG_OBJ_PKG_CD
              AND G.OBJ_ID = F.OBJ_ID
              AND H.PRTNR_ID = B.PRTNR_ID
              AND C.SUBSEG_CD = p_subseg_cd
         UNION 
         SELECT A.SECU_TYP_CD SECU_TYP_CD, A.SECU_DESC SECU_DESC, A.CALCN_ORDER CALCN_ORDER, 
                A.SECU_GRP SECU_GRP, B.RISK_CVRG, V_CR_WORTH CR_WORTH, E.SUPL_ID SECU_PROVIDER
            FROM UC_SECURITY_TYPE_DN    A, 
                 UC_SECU_PRVDR_TX  B, 
                 UC_SUB_SEGMENT_MS C,
                 UC_SUBSEG_OBJ_PKG_TX D,
                 UC_OBJECT_PACKAGE_MS E,
                 UC_OBJECT_MS F,
                 UC_SUBSEG_OBJPKG_OBJ_TX G
            WHERE (B.OWNER_ID = G.SUBSEG_OBJPKG_OBJ_CD OR B.OWNER_ID = D.SUBSEG_OBJ_PKG_CD)
              AND A.SECU_TYP_CD = B.SECU_TYP_CD
              AND B.DEL_FLG = 'N'
              AND B.RISK_RLVNCE = 'Y'
              AND B.PRTNR_ID IS NULL
              AND C.SUBSEG_CD = D.SUBSEG_CD
              AND D.OBJ_PKG_CD = E.OBJ_PKG_ID
              AND D.SUBSEG_OBJ_PKG_CD = G.SUBSEG_OBJ_PKG_CD
              AND G.OBJ_ID = F.OBJ_ID
              AND C.SUBSEG_CD = p_subseg_cd
            UNION
            SELECT std.SECU_TYP_CD SECU_TYP_CD, std.SECU_DESC SECU_DESC, std.CALCN_ORDER CALCN_ORDER,
                   std.SECU_GRP SECU_GRP, ((opm.INTRNL_BGL/PM.ACQSTN_VALUE)*100) RISK_CVRG, 
                   V_CR_WORTH CR_WORTH, opm.SUPL_ID SECU_PROVIDER
             FROM   UC_SUBSEG_OBJ_PKG_TX sopt,
                    UC_OBJECT_PACKAGE_MS opm,
                   UC_OBJECT_HIERARCHY_MS ohm,
                   UC_SECURITY_TYPE_DN std,
                   UC_PRICING_MS PM
             WHERE  opm.HRCHY_ID    = ohm.hrchy_id
             AND    sopt.obj_pkg_CD = opm.OBJ_PKG_ID
             AND    std.SECU_TYP_CD = ohm.SECU_TYP_CD
             AND    SOPT.SUBSEG_CD  = PM.SUBSEG_CD
             AND    sopt.subseg_cd  = p_subseg_cd )  SECURITY_INFO
         ORDER BY CALCN_ORDER;
         
      v_counter NUMBER := 0;
      v_secu_typ_cd UC_SECURITY_TYPE_DN.SECU_TYP_CD%TYPE;
      v_secu_desc   UC_SECURITY_TYPE_DN.SECU_DESC%TYPE;
      v_calcn_order UC_SECURITY_TYPE_DN.CALCN_ORDER%TYPE;
      v_secu_grp    UC_SECURITY_TYPE_DN.SECU_GRP%TYPE;
      v_risk_cvrg   NUMBER;
      v_cred_worth  UC_PARTNER_MS.CR_WORTH%TYPE;
      v_secu_provider UC_OBJECT_PACKAGE_MS.SUPL_ID%TYPE;  -- v_secu_provider was added by Rajagopal on 20-11-2007 for CEAnF implementation

BEGIN

   p_tab_security_class.DELETE();

   IF (p_lgs_flg = 'Y') AND (UPPER(p_sparte) != UPPER('Sparkasse/DL-Direkt')) THEN ----1  
          IF p_confirm_flg = 'Y' THEN ---2
                FOR I1 IN CUR_SECURITY_CLASS1
                LOOP
                     v_counter := v_counter+1;
                     p_tab_security_class(v_counter).secu_typ_cd := i1.SECU_TYP_CD;
                     p_tab_security_class(v_counter).secu_desc := i1.SECU_DESC;
                     p_tab_security_class(v_counter).secu_calcn_order := i1.CALCN_ORDER;
                     p_tab_security_class(v_counter).secu_grp := i1.SECU_GRP;
                     p_tab_security_class(v_counter).secu_risk_pct := i1.RISK_CVRG;
                     p_tab_security_class(v_counter).secu_bonitat := i1.CR_WORTH;
                     p_tab_security_class(v_counter).secu_provider := i1.SECU_PROVIDER;  -- Added by Rajagopal on 20-11-2007 for CEAnF implementation
                END LOOP;
          ELSE---2 
            FOR I2 IN CUR_SECURITY_CLASS2
               LOOP
                  v_counter := v_counter+1;
                  p_tab_security_class(v_counter).secu_typ_cd := i2.SECU_TYP_CD;
                  p_tab_security_class(v_counter).secu_desc := i2.SECU_DESC;
                  p_tab_security_class(v_counter).secu_calcn_order := i2.CALCN_ORDER;
                  p_tab_security_class(v_counter).secu_grp := i2.SECU_GRP;
                  p_tab_security_class(v_counter).secu_risk_pct := i2.RISK_CVRG;
                  p_tab_security_class(v_counter).secu_bonitat := i2.CR_WORTH;
                  p_tab_security_class(v_counter).secu_provider := i2.SECU_PROVIDER;  -- Added by Rajagopal on 20-11-2007 for CEAnF implementation
               END LOOP; 
          END IF;----2 
   ELSE ---1
       IF p_confirm_flg = 'Y' THEN ---3  
             FOR I3 IN CUR_SECURITY_CLASS3
                LOOP
                  v_counter := v_counter+1;
                  p_tab_security_class(v_counter).secu_typ_cd := i3.SECU_TYP_CD;
                  p_tab_security_class(v_counter).secu_desc := i3.SECU_DESC;
                  p_tab_security_class(v_counter).secu_calcn_order := i3.CALCN_ORDER;
                  p_tab_security_class(v_counter).secu_grp := i3.SECU_GRP;
                  p_tab_security_class(v_counter).secu_risk_pct := i3.RISK_CVRG;
                  p_tab_security_class(v_counter).secu_bonitat := i3.CR_WORTH;
                  p_tab_security_class(v_counter).secu_provider := i3.SECU_PROVIDER;  -- Added by Rajagopal on 20-11-2007 for CEAnF implementation
                END LOOP;
       ELSE---3 
            FOR I4 IN CUR_SECURITY_CLASS4
               LOOP
                  v_counter := v_counter+1;
                  p_tab_security_class(v_counter).secu_typ_cd := i4.SECU_TYP_CD;
                  p_tab_security_class(v_counter).secu_desc := i4.SECU_DESC;
                  p_tab_security_class(v_counter).secu_calcn_order := i4.CALCN_ORDER;
                  p_tab_security_class(v_counter).secu_grp := i4.SECU_GRP;
                  p_tab_security_class(v_counter).secu_risk_pct := i4.RISK_CVRG;
                  p_tab_security_class(v_counter).secu_bonitat := i4.CR_WORTH;
                  p_tab_security_class(v_counter).secu_provider := i4.SECU_PROVIDER;  -- Added by Rajagopal on 20-11-2007 for CEAnF implementation
               END LOOP; 
          END IF;----3 

   END IF;---1	

   IF (p_lgs_flg = 'Y') AND (UPPER(p_sparte) != UPPER('Sparkasse/DL-Direkt')) THEN
   -- SECU_PROVIDER column was added by Rajagopal on 20-11-2007 for CEAnF implementation
      BEGIN
           SELECT A.SECU_TYP_CD SECU_TYP_CD, A.SECU_DESC SECU_DESC, A.CALCN_ORDER CALCN_ORDER,
                   A.SECU_GRP SECU_GRP, 100 RISK_CVRG, NULL CR_WORTH
         INTO   v_secu_typ_cd, v_secu_desc, v_calcn_order,
                v_secu_grp, v_risk_cvrg, v_cred_worth
         FROM   UC_SECURITY_TYPE_DN A,
               UC_BUS_SEG_MS  B
          WHERE  A.SECU_DESC = B.SHORT_NAME||' '||B.NAME
         AND    B.BUS_SEG_CD = v_bus_Seg_cd;

         v_counter := v_counter+1;
         p_tab_security_class(v_counter).secu_typ_cd := V_SECU_TYP_CD;
         p_tab_security_class(v_counter).secu_desc := V_SECU_DESC;
         p_tab_security_class(v_counter).secu_calcn_order := V_CALCN_ORDER;
         p_tab_security_class(v_counter).secu_grp := V_SECU_GRP;
         p_tab_security_class(v_counter).secu_risk_pct := V_RISK_CVRG;
         p_tab_security_class(v_counter).secu_bonitat := V_CRED_WORTH;
         p_tab_security_class(v_counter).secu_provider := NULL ;  -- Added by Rajagopal on 20-11-2007 for CEAnF implementation

      EXCEPTION
           WHEN NO_DATA_FOUND THEN
            BEGIN
                 SELECT A.SECU_TYP_CD SECU_TYP_CD, A.SECU_DESC SECU_DESC, A.CALCN_ORDER CALCN_ORDER,
                         A.SECU_GRP SECU_GRP, 100 RISK_CVRG, NULL CR_WORTH 
               INTO   v_secu_typ_cd, v_secu_desc, v_calcn_order,
                      v_secu_grp, v_risk_cvrg, v_cred_worth
               FROM   UC_SECURITY_TYPE_DN A,
                     UC_BUS_SEG_MS  B
                WHERE  A.SECU_DESC LIKE B.SHORT_NAME||'%'
               AND    B.BUS_SEG_CD = v_bus_Seg_cd
               AND    ROWNUM < 2;

                  v_counter := v_counter+1;
                  p_tab_security_class(v_counter).secu_typ_cd := V_SECU_TYP_CD;
                  p_tab_security_class(v_counter).secu_desc := V_SECU_DESC;
                  p_tab_security_class(v_counter).secu_calcn_order := V_CALCN_ORDER;
                  p_tab_security_class(v_counter).secu_grp := V_SECU_GRP;
                  p_tab_security_class(v_counter).secu_risk_pct := V_RISK_CVRG;
                  p_tab_security_class(v_counter).secu_bonitat := V_CRED_WORTH;
                  p_tab_security_class(v_counter).secu_provider := NULL;  -- Added by Rajagopal on 20-11-2007 for CEAnF implementation

            EXCEPTION
               WHEN OTHERS THEN
                  NULL;
            END;
      END;

   -- SECU_PROVIDER column was added by Rajagopal on 20-11-2007 for CEAnF implementation
      BEGIN
           SELECT A.SECU_TYP_CD SECU_TYP_CD, A.SECU_DESC SECU_DESC, A.CALCN_ORDER CALCN_ORDER,
                   A.SECU_GRP SECU_GRP, 100 RISK_CVRG, NULL CR_WORTH 
         INTO   v_secu_typ_cd, v_secu_desc, v_calcn_order,
                v_secu_grp, v_risk_cvrg, v_cred_worth
         FROM   UC_SECURITY_TYPE_DN A,
               UC_DISTRIB_CHNL_MS  B
          WHERE  A.SECU_DESC = B.SHORT_NAME||' '||B.NAME
         AND    B.DISTRIB_CHNL_CD = v_distrib_chnl_cd;

         v_counter := v_counter+1;
         p_tab_security_class(v_counter).secu_typ_cd := V_SECU_TYP_CD;
         p_tab_security_class(v_counter).secu_desc := V_SECU_DESC;
         p_tab_security_class(v_counter).secu_calcn_order := V_CALCN_ORDER;
         p_tab_security_class(v_counter).secu_grp := V_SECU_GRP;
         p_tab_security_class(v_counter).secu_risk_pct := V_RISK_CVRG;
         p_tab_security_class(v_counter).secu_bonitat := V_CRED_WORTH;
         p_tab_security_class(v_counter).secu_provider := NULL;  -- Added by Rajagopal on 20-11-2007 for CEAnF implementation

      EXCEPTION
           WHEN NO_DATA_FOUND THEN
            BEGIN
                 SELECT A.SECU_TYP_CD SECU_TYP_CD, A.SECU_DESC SECU_DESC, A.CALCN_ORDER CALCN_ORDER,
                         A.SECU_GRP SECU_GRP, 100 RISK_CVRG, NULL CR_WORTH 
               INTO   v_secu_typ_cd, v_secu_desc, v_calcn_order,
                      v_secu_grp, v_risk_cvrg, v_cred_worth
               FROM   UC_SECURITY_TYPE_DN A,
                     UC_DISTRIB_CHNL_MS  B
                WHERE  A.SECU_DESC LIKE B.SHORT_NAME||'%'
               AND    B.DISTRIB_CHNL_CD = v_distrib_chnl_cd
               AND    ROWNUM < 2;

                  v_counter := v_counter+1;
                  p_tab_security_class(v_counter).secu_typ_cd := V_SECU_TYP_CD;
                  p_tab_security_class(v_counter).secu_desc := V_SECU_DESC;
                  p_tab_security_class(v_counter).secu_calcn_order := V_CALCN_ORDER;
                  p_tab_security_class(v_counter).secu_grp := V_SECU_GRP;
                  p_tab_security_class(v_counter).secu_risk_pct := V_RISK_CVRG;
                  p_tab_security_class(v_counter).secu_bonitat := V_CRED_WORTH;
                  p_tab_security_class(v_counter).secu_provider := NULL;  -- Added by Rajagopal on 20-11-2007 for CEAnF implementation

            EXCEPTION
               WHEN OTHERS THEN
                  NULL;
            END;
      END;
   END IF;

   PROC_ORDER_SECURITY_CLASS;

   END POPULATE_SECURITY_CLASS;

-- vSuppliers was added by Rajagopal on 23-10-2007 for CEAnF implementation

 PROCEDURE  PROC_GEN_SECU_CLASS_ARR (p_tab_security_class IN tab_security_class,
                                     vSecurityClass OUT VARCHAR2,
                                     vBonitat OUT VARCHAR2, vSuppliers OUT VARCHAR2)
 AS
    l_secu_bonitat_tab_count NUMBER := 0;
    lsSecclass VARCHAR2(4000);
    lsBonitat  VARCHAR2(4000);
	 lsSuppliers VARCHAR2(4000);	-- Added by Rajagopal for CEAnF implementation

 BEGIN
    FOR i IN 1..p_tab_security_class.COUNT()
    LOOP
       p_tab_security_typ_bonitat(i).secu_typ_cd := NVL(p_tab_security_class(i).secu_typ_cd, 'Alle') ;
       p_tab_security_typ_bonitat(i).bonitat := NVL(p_tab_security_class(i).secu_bonitat, 'Alle') ;
		 p_tab_security_typ_bonitat(i).secu_provider := NVL(p_tab_security_class(i).secu_provider, 'Alle') ; 	-- Added by Rajagopal on 09-11-2007 for CEAnF implementation
    END LOOP;

    l_secu_bonitat_tab_count := p_tab_security_typ_bonitat.COUNT();

    IF l_secu_bonitat_tab_count = 0 THEN
       lsSecclass := 'Alle';
       lsBonitat    := 'Alle';
		 lsSuppliers := 'Alle';  -- Added by Rajagopal on 09-11-2007 for CEAnF implementation
    END IF;

    FOR i IN 1..l_secu_bonitat_tab_count
    LOOP
       IF i < l_secu_bonitat_tab_count THEN
          lsSecClass := lsSecClass || p_tab_security_typ_bonitat(i).secu_typ_cd || ',' ;
          lsBonitat := lsBonitat || p_tab_security_typ_bonitat(i).bonitat || ',' ;
			 lsSuppliers := lsSuppliers || p_tab_security_typ_bonitat(i).secu_provider || ',' ;   	-- Added by Rajagopal on 09-11-2007 for CEAnF implementation
       ELSE
          lsSecClass := lsSecClass || p_tab_security_typ_bonitat(i).secu_typ_cd ;
          lsBonitat := lsBonitat || p_tab_security_typ_bonitat(i).bonitat ;
			 lsSuppliers := lsSuppliers || p_tab_security_typ_bonitat(i).secu_provider ;  -- Added by Rajagopal on 09-11-2007 for CEAnF implementation
       END IF;
    END LOOP;
    
    vSecurityClass := lsSecClass;
    vBonitat := lsBonitat;
    vSuppliers := lsSuppliers;  -- Added by Rajagopal on 23-10-2007 for CEAnF implementation

END;


 PROCEDURE proc_order_security_class                          -- 13-SEP-2005
   AS
      v_tab_size        NUMBER := 0;
      v_new_tab_count   NUMBER := 0;
      v_min_no          NUMBER := 0;
   BEGIN
      p_tab_security_class_new.DELETE ();
      v_tab_size := p_tab_security_class.COUNT ();
      v_new_tab_count := 0;

      IF v_tab_size > 0
      THEN
         FOR i IN p_tab_security_class.FIRST .. p_tab_security_class.LAST
         LOOP
            FOR j IN p_tab_security_class.FIRST .. p_tab_security_class.LAST
            LOOP
               IF (p_tab_security_class (i).secu_calcn_order <
                                     p_tab_security_class (j).secu_calcn_order
                  )
               THEN
                  p_tab_security_class_new (i).secu_typ_cd :=
                                         p_tab_security_class (i).secu_typ_cd;
                  p_tab_security_class_new (i).secu_desc :=
                                           p_tab_security_class (i).secu_desc;
                  p_tab_security_class_new (i).secu_calcn_order :=
                                    p_tab_security_class (i).secu_calcn_order;
                  p_tab_security_class_new (i).secu_grp :=
                                            p_tab_security_class (i).secu_grp;
                  p_tab_security_class_new (i).secu_risk_pct :=
                                       p_tab_security_class (i).secu_risk_pct;
                  p_tab_security_class_new (i).secu_bonitat :=
                                        p_tab_security_class (i).secu_bonitat;
                  p_tab_security_class (i).secu_typ_cd :=
                                         p_tab_security_class (j).secu_typ_cd;
                  p_tab_security_class (i).secu_desc :=
                                           p_tab_security_class (j).secu_desc;
                  p_tab_security_class (i).secu_calcn_order :=
                                    p_tab_security_class (j).secu_calcn_order;
                  p_tab_security_class (i).secu_grp :=
                                            p_tab_security_class (j).secu_grp;
                  p_tab_security_class (i).secu_risk_pct :=
                                       p_tab_security_class (j).secu_risk_pct;
                  p_tab_security_class (i).secu_bonitat :=
                                        p_tab_security_class (j).secu_bonitat;
                  p_tab_security_class (j).secu_typ_cd :=
                                     p_tab_security_class_new (i).secu_typ_cd;
                  p_tab_security_class (j).secu_desc :=
                                       p_tab_security_class_new (i).secu_desc;
                  p_tab_security_class (j).secu_calcn_order :=
                                p_tab_security_class_new (i).secu_calcn_order;
                  p_tab_security_class (j).secu_grp :=
                                        p_tab_security_class_new (i).secu_grp;
                  p_tab_security_class (j).secu_risk_pct :=
                                   p_tab_security_class_new (i).secu_risk_pct;
                  p_tab_security_class (j).secu_bonitat :=
                                    p_tab_security_class_new (i).secu_bonitat;
               END IF;
            END LOOP;
         END LOOP;
      END IF;
   END proc_order_security_class;

   PROCEDURE PROC_VERWALTUNGS_RISK_KOSTEN 
   (
      pv_actv_dt                  IN       uc_sub_segment_ms.actv_dt%TYPE,
      pv_subseg_cd                IN       uc_sub_segment_ms.subseg_cd%TYPE,
      pv_cntrct_way               IN       uc_contract_ms.cntrct_way%TYPE,
      pv_refin_typ                IN       uc_sub_segment_ms.refin_typ%TYPE,
      pv_lgs_refin_typ            IN       uc_sub_segment_ms.lgs_refin_typ%TYPE,
      pv_distrib_chnl_cd          IN       uc_contract_ms.distrib_chnl_cd%TYPE,
      pv_bus_seg_cd               IN       uc_contract_ms.bus_seg_cd%TYPE,
      pv_cr_worth                 IN       uc_partner_ms.cr_worth%TYPE,
      pv_lease_end_dt             IN       uc_sub_segment_ms.lease_end_dt%TYPE,
      pv_first_instlmnt_dt        IN       uc_sub_segment_ms.lease_end_dt%TYPE,
      pv_cntrct_end_dt            IN       uc_contract_ms.cntrct_end_dt%TYPE,
      pv_cntrct_stat_num          IN       uc_sub_segment_ms.cntrct_stat_num%TYPE,
      pv_elmntry_pdt_cd           IN       uc_segment_ms.elmntry_pdt_cd%TYPE,
      pv_ms_pdt_id                IN       uc_master_product_ms.ms_pdt_id%TYPE,
      pv_comp_prtnr_id            IN       uc_contract_ms.comp_prtnr_id%TYPE,
      pv_prtnr_id                 IN       uc_partner_ms.prtnr_id%TYPE,
      pv_partner                  IN       uc_object_package_ms.supl_id%TYPE,
      pv_acqstn_value             IN       uc_pricing_ms.acqstn_value%TYPE,
      pv_cntrct_durtn             IN       uc_sub_segment_ms.cntrct_durtn%TYPE,
      pv_comp_num                 IN       uc_company_ms.comp_num%TYPE,
      pv_subseg_num               IN       uc_sub_segment_ms.subseg_num%TYPE,
      pv_districhnl_sh_nm         IN       uc_distrib_chnl_ms.short_name%TYPE,
      pv_districhnl_name          IN       uc_distrib_chnl_ms.NAME%TYPE,
      pv_ms_pdt_name              IN       uc_master_product_ms.ms_pdt_name%TYPE,
      pv_elmntry_pdt_name         IN       uc_elmntry_product_ms.elmntry_pdt_name%TYPE,
      pv_calc_fact_book_dt_flg    IN       CHAR,
      pv_calc_fact_dt             IN       DATE,
      pv_ext_flg                  IN       CHAR
    )
   IS
   lv_spl_post_bus_expct_pct            NUMBER(17,6) ; --UC_PAYMENT_MS.EXPCT_POST_SALE_PFT_PCT%TYPE; 
   lv_calc_post_bus_expct_pct           NUMBER(17,6) ;--UC_PAYMENT_MS.EXPCT_POST_SALE_PFT_PCT%TYPE; 
   lv_CNTRCT_WAY                        UC_CONTRACT_MS.CNTRCT_WAY%TYPE;
   v_Anfangsaufwand                     NUMBER(12,2);
   v_Laufender_Aufwand                  NUMBER(17,4);
   v_GLZ_AMT                            NUMBER(17,4);
   v_VLZ_AMT                            NUMBER(17,4);
   v_Endaufwand                         NUMBER(17,4);
   v_Risikokosten                       NUMBER(6,4);
   v_Factors                            UC_FACTORSARRAY_TYPE;
   v_Factors_size                       NUMBER := 50;
   v_riskFactors                        UC_RISKOUTARRAY_TYPE;
   v_riskFactors_size                   NUMBER := 30;

   v_lgsFactors		                  UC_LGSOUTARRAY_TYPE;
   v_lgsFactors_size	                  NUMBER := 30;

   v_errArray                           UC_ERROUTARRAY_TYPE;
   v_errArray_size                      NUMBER := 150;

   v_LGSerrArray                        UC_LGSERROUTARRAY_TYPE;
   v_LGSerrArray_size                   NUMBER := 10;

   tab_RiskValues                       ArrRiskValues;

   tab_RiskNGEValues                    ArrRiskNGEValues;

   v_actv_dt                            UC_SUB_SEGMENT_MS.ACTV_DT%TYPE;
   v_cr_rate                            UC_SUB_SEGMENT_MS.CR_RATE%TYPE;
   v_securityclass                      UC_SECURITY_TYPE_DN.SECU_GRP%TYPE;
   v_distrib_chnl_cd                    UC_DISTRIB_CHNL_MS.DISTRIB_CHNL_CD%TYPE;
   v_distrib_chnl_cd2                   UC_DISTRIB_CHNL_MS.DISTRIB_CHNL_CD%TYPE;
   v_bus_seg_cd                         UC_BUS_SEG_MS.BUS_SEG_CD%TYPE;
   v_bus_seg_cd2                        UC_BUS_SEG_MS.BUS_SEG_CD%TYPE;

   v_elmntry_pdt_typ_flg                UC_ELMNTRY_PRODUCT_MS.ELMNTRY_PDT_TYP_FLG%TYPE;
   v_nge_perc                           CONSTANT NUMBER(12,3) := 250/100; -- percentage   		
   v_ctr                                NUMBER := 0;
   v_size                               NUMBER := 0;
   v_incr_1                             NUMBER := 0;
   l_ctr                                NUMBER := 0;

   v_risk_in_pct                        NUMBER := 0;
   v_risk_nge_pct                       NUMBER := 0;
   v_futr_cost_glz_amt                  NUMBER(17,2) := 0;
   v_futr_cost_glz_pct                  NUMBER(7,4) := 0;
   v_futr_cost_vlz_amt                  NUMBER(17,2) := 0; 
   v_futr_cost_vlz_pct                  NUMBER(7,4) := 0;
   v_futr_cost_corr_amt                 NUMBER(17,2) := 0;
   v_futr_cost_corr_pct                 NUMBER(7,4) := 0;
   v_futr_cost_glz_red_amt              NUMBER := 0;
   v_futr_cost_vlz_red_amt              NUMBER := 0; 
   v_futr_cost_redn_amt                 NUMBER := 0;
   v_realstn_cost_amt                   NUMBER(17,2) := 0;
   v_realstn_cost_pct                   NUMBER(7,4) := 0;

   lv_first_instlmnt_dt                 VARCHAR2(50);
   lv_actv_dt                           VARCHAR2(50);
   lv_lease_end_dt                      VARCHAR2(50);
   lv_cntrct_end_dt                     VARCHAR2(50);
   lv_temp                              VARCHAR2(50);
   is_extended                          VARCHAR2(50) := '0';
   lv_cntrct_stat_num                   VARCHAR2(50);

   v_calc_fact_map                      Pkg_Batch_Prc_Prf_Routines.ArrCalcFactorValuesMap;
   v_vak_cntrct_fix_in_pct              NUMBER;
   v_vak_cntrct_fix_amt                 NUMBER;
   v_vak_sales_amt                      NUMBER;
   v_vak_sales_pct                      NUMBER;
   v_vak_cntrct_var_amt                 NUMBER;
   v_vak_cntrct_var_in_pct              NUMBER;
   v_vak_serv_area_amt                  NUMBER;
   v_vak_serv_area_in_pct               NUMBER;

   v_piece                              NUMBER;
   v_vak_amt_tot                        NUMBER;
   v_vak_pr_tot                         NUMBER;
   v_costofinterest                     NUMBER;
   v_act_duration                       NUMBER;
   v_risk_amt                           NUMBER;
   p_tab_input_param                    Pkg_Batch_Prc_Prf_Routines.tab_input_param;        
   --Changes for defect 13873 
   v_refin_typ                          uc_refin_ms.REFIN_TYP%TYPE;
   vSecurityClass                       VARCHAR2(4000) := NULL;
   vBonitat                             VARCHAR2(4000) := NULL;
   v_risk_flg                           NUMBER(2) := 0;
   vsupplier                 VARCHAR2 (4000)                       := NULL;        
   -- Defect 13872 
   v_border_50_amt                      NUMBER :=0; -- Version 1.6
   v_border_100_amt                     NUMBER :=0; -- Version 1.6
   v_aw_1                               NUMBER := 0; -- Version 1.9
   v_aw_2                               NUMBER := 0; -- Version 1.9
   v_aw_3                               NUMBER := 0; -- Version 1.9
   v_lgs_comp_num1           uc_company_ms.comp_num%TYPE              := 5;
   v_lgs_comp_num2           uc_company_ms.comp_num%TYPE             := 83;
   v_lgs_comp_num3           uc_company_ms.comp_num%TYPE            := 599;
   v_lgs_comp_num4           uc_company_ms.comp_num%TYPE            := 597;
   s_lgs_flg                 VARCHAR2 (1)                           := 'N';
   s_confirm_flg             VARCHAR2 (1)                          := NULL;
   s_partnercode             uc_object_package_ms.supl_id%TYPE;
   s_purchase_ord_dt         uc_prchse_order_ms.prchse_order_dt%TYPE;
   f_cr_worth                uc_partner_ms.cr_worth%type;
BEGIN
   v_refin_typ := pv_refin_typ;

   IF v_refin_typ IS NULL
   THEN
      v_refin_typ := pv_lgs_refin_typ;
   END IF;

   lv_first_instlmnt_dt := TO_CHAR (pv_first_instlmnt_dt, 'YYYY-MM-DD');

   IF (pv_cntrct_stat_num IN ('500', '505', '590', '595'))
   THEN                                                                 --{
      is_extended := '1';
   ELSE                                                                --}{
      is_extended := '0';
   END IF;                                                              --}

   IF (pv_calc_fact_book_dt_flg = 'J')
   THEN                                --{  this is input parameter of main
      BEGIN                                                            --{
         lv_first_instlmnt_dt :=
            TO_CHAR (NVL (TO_DATE (pv_calc_fact_dt, 'YYYYMMDD'), SYSDATE),
                     'YYYY-MM-DD'
                    );  -- this inp_calc_fact_dt is input parameter of main
      EXCEPTION
         WHEN OTHERS
         THEN
            pkg_batch_logger.proc_log (lf_file_handle,
                                       'FATAL',
                                       'BAT_F_9999',
                                          'lv_FIRST_INSTLMNT_DT,'
                                       || pv_calc_fact_dt,
                                       SQLERRM
                                      );
            DBMS_OUTPUT.put_line ('error189:' || SQLERRM);
            raise v_fatal_excp;
      END;                                                              --}
   END IF;

---------------------=====================================
   BEGIN
      SELECT prchse_order_dt
        INTO s_purchase_ord_dt
        FROM uc_subseg_obj_pkg_tx sopt, uc_prchse_order_ms pom
       WHERE sopt.subseg_obj_pkg_cd = pom.subseg_obj_pkg_cd
         AND subseg_cd = pv_subseg_cd
         AND ROWNUM < 2;
   EXCEPTION
      WHEN OTHERS
      THEN
         s_purchase_ord_dt := NULL;
   END;

 /*  IF s_purchase_ord_dt IS NOT NULL
   THEN
      s_confirm_flg := 'Y';
   ELSE
      s_confirm_flg := 'N';
   END IF;
*/
   f_cr_worth     :=  v_curr_contract_rec.CR_WORTH;

   -- The below IF..ELSE block was added by Rajagopal on 03-12-2007 for CEAnF implementation
   IF ((v_curr_contract_rec.prtnr_infn_dt IS NOT NULL) OR (s_purchase_ord_dt IS NOT NULL)) 
   THEN
     f_cr_worth     := v_curr_contract_rec.CR_WORTH;
     s_confirm_flg := 'Y';
   ELSE
     f_cr_worth    :=  v_curr_contract_rec.PRTNR_CR_WORTH;
     s_confirm_flg := 'N';
   END IF;

   IF pv_comp_num IN
         (v_lgs_comp_num1,
          v_lgs_comp_num2,
          v_lgs_comp_num3
         )
   THEN
      s_lgs_flg := 'Y';
      f_cr_worth    :=  'Alle';
   ELSE
      s_lgs_flg := 'N';
   END IF;

   BEGIN
      SELECT c.supl_id
        INTO s_partnercode
        FROM uc_subseg_obj_pkg_tx b, uc_object_package_ms c
       WHERE b.obj_pkg_cd = c.obj_pkg_id AND b.subseg_cd = pv_subseg_cd;
   EXCEPTION
      WHEN OTHERS
      THEN
         s_partnercode := NULL;
   END;

-- Fix For Defect 17768 and 17769 - fetch level2  distrib channel name
   BEGIN --{ 

      SELECT distrib_chnl_cd 
      INTO v_distrib_chnl_cd2
      FROM uc_distrib_chnl_ms
      WHERE UPPER(SHORT_NAME) = v_cntr_other_info.districhnl_sh_nm
      AND NAME = '*'; 

   EXCEPTION
   WHEN NO_DATA_FOUND 
   THEN
      BEGIN --{
         SELECT distrib_chnl_cd 
         INTO v_distrib_chnl_cd2
         FROM uc_distrib_chnl_ms
         WHERE UPPER(SHORT_NAME) = v_cntr_other_info.districhnl_sh_nm
         AND UPPER(NAME) = 'ALLE';

      EXCEPTION
      WHEN NO_DATA_FOUND 
      THEN
         v_distrib_chnl_cd2 := 'Alle';
      WHEN TOO_MANY_ROWS 
      THEN
         Pkg_Batch_Logger.proc_log(lf_file_handle,'ERROR','BAT_E_0091','PROC_VERWALTUNGS_RISK_KOSTEN,v_DISTRIB_CHNL_CD2',v_cntr_other_info.districhnl_sh_nm);
         raise v_fatal_excp;
      WHEN OTHERS 
      THEN
         Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999','PROC_VERWALTUNGS_RISK_KOSTEN,v_DISTRIB_CHNL_CD2'||v_cntr_other_info.districhnl_sh_nm, SQLERRM);
         raise v_fatal_excp;
      END; --}
   WHEN TOO_MANY_ROWS 
   THEN
      Pkg_Batch_Logger.proc_log(lf_file_handle,'ERROR','BAT_E_0091','PROC_VERWALTUNGS_RISK_KOSTEN,v_DISTRIB_CHNL_CD',v_cntr_other_info.districhnl_sh_nm);
      raise v_fatal_excp;
   WHEN OTHERS 
   THEN
      Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999','PROC_VERWALTUNGS_RISK_KOSTEN,v_DISTRIB_CHNL_CD'||v_cntr_other_info.districhnl_sh_nm, SQLERRM);
      raise v_fatal_excp;
   END; --}

-- Fix For Defect 17768 and 17769 - fetch level2  distrib channel name
   BEGIN --{ 

      SELECT BUS_SEG_CD 
      INTO v_bus_seg_cd2
      FROM UC_BUS_SEG_MS
      WHERE UPPER(SHORT_NAME) = v_cntr_other_info.bus_seg_cd_sh_nm
      AND NAME = '*'; 

   EXCEPTION
   WHEN NO_DATA_FOUND 
   THEN
      BEGIN --{
         
         SELECT bus_seg_cd 
         INTO v_bus_seg_cd2
         FROM uc_bus_seg_ms
         WHERE SHORT_NAME = v_cntr_other_info.bus_seg_cd_sh_nm
         AND UPPER(NAME) = 'ALLE';
        
      EXCEPTION
      WHEN NO_DATA_FOUND 
      THEN
         v_bus_seg_cd2 := 'Alle';
      WHEN TOO_MANY_ROWS 
      THEN
         Pkg_Batch_Logger.proc_log(lf_file_handle,'ERROR','BAT_E_0091','PROC_VERWALTUNGS_RISK_KOSTEN,v_BUS_SEG_CD2',v_cntr_other_info.bus_seg_cd_sh_nm);
         raise v_fatal_excp;
      WHEN OTHERS 
      THEN
         Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999','PROC_VERWALTUNGS_RISK_KOSTEN,v_BUS_SEG_CD2'||v_cntr_other_info.bus_seg_cd_sh_nm,SQLERRM);
         raise v_fatal_excp;
      END; --}
   WHEN TOO_MANY_ROWS 
   THEN
      Pkg_Batch_Logger.proc_log(lf_file_handle,'ERROR','BAT_E_0091','PROC_VERWALTUNGS_RISK_KOSTEN,v_BUS_SEG_CD',v_cntr_other_info.bus_seg_cd_sh_nm);
      raise v_fatal_excp;
   WHEN OTHERS 
   THEN
      Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999','PROC_VERWALTUNGS_RISK_KOSTEN,v_BUS_SEG_CD'||v_cntr_other_info.bus_seg_cd_sh_nm, SQLERRM);
      raise v_fatal_excp;
   END; --}

-------------------- =====================================
                                                      --}

   ---Changes for defect 13873
   BEGIN
      populate_security_class (pv_distrib_chnl_cd,
                               pv_bus_seg_cd,
                               pv_refin_typ,
                               f_cr_worth,
                               pv_subseg_cd,
                               s_partnercode,
                               s_confirm_flg,
                               s_lgs_flg,
                               v_cntr_other_info.sparte
                              );
   EXCEPTION
      WHEN OTHERS
      THEN
         pkg_batch_logger.proc_log (lf_file_handle,
                                    'ERROR',
                                    'BAT_E_0091',
                                    'POPULATE_SECURITY_CLASS',
                                    SQLERRM
                                   );
         DBMS_OUTPUT.put_line ('error 501' || SQLERRM);
         raise v_fatal_excp;
   END;

   BEGIN
      proc_gen_secu_class_arr (p_tab_security_class,
                               vsecurityclass,
                               vbonitat,
                               vsupplier
                              );
   EXCEPTION
      WHEN OTHERS
      THEN
         pkg_batch_logger.proc_log (lf_file_handle,
                                    'ERROR',
                                    'BAT_E_0091',
                                    'PROC_GEN_SECU_CLASS_ARR',
                                    SQLERRM
                                   );
         DBMS_OUTPUT.put_line ('error 501' || SQLERRM);
         raise v_fatal_excp;
   END;
/*   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' pv_distrib_chnl_cd'||pv_distrib_chnl_cd,'', '');                
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' pv_bus_seg_cd'||pv_bus_seg_cd,'', '');                
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' pv_cntrct_way'||pv_cntrct_way,'', '');                
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' pv_elmntry_pdt_cd'||pv_elmntry_pdt_cd,'', '');                
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' pv_ms_pdt_id'||pv_ms_pdt_id,'', '');                
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' pv_comp_prtnr_id'||pv_comp_prtnr_id,'', '');                
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' vbonitat'||vbonitat,'', '');                
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_bus_seg_cd2'||v_bus_seg_cd2,'', '');                
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_distrib_chnl_cd2'||v_distrib_chnl_cd2,'', '');                
*/
   BEGIN                                                                --{
      uc_pkg_calc_priceproofing_trig.pgcal_fact_values
                                               (lv_first_instlmnt_dt,
                                                TO_CHAR (pv_actv_dt,
                                                         'YYYY-MM-DD'
                                                        ),
                                                TO_CHAR (pv_lease_end_dt,
                                                         'YYYY-MM-DD'
                                                        ),
                                                TO_CHAR (pv_lease_end_dt,
                                                         'YYYY-MM-DD'
                                                        ),
                                                lv_temp,
                                                is_extended,
                                                pv_distrib_chnl_cd,
                                                v_distrib_chnl_cd2,
                                                pv_bus_seg_cd,
                                                v_bus_seg_cd2,
                                                pv_cntrct_way,
                                                pv_elmntry_pdt_cd,
                                                pv_ms_pdt_id,
                                                pv_comp_prtnr_id,
                                                pv_prtnr_id,
                                                pv_partner,
                                                pv_refin_typ,
                                                vbonitat,
                                                vsecurityclass,
                                                pv_acqstn_value,
                                                pv_cntrct_durtn,
                                                vsupplier,
                                                v_riskfactors,
                                                v_factors,
                                                v_lgsfactors,
                                                v_errarray,
                                                v_lgserrarray
                                               );
   EXCEPTION
      WHEN OTHERS
      THEN
         pkg_batch_logger.proc_log (lf_file_handle,
                                    'ERROR',
                                    'BAT_E_0091',
                                    'UC_PKG_CALC_PRICEPROOFING',
                                    SQLERRM
                                   );
         DBMS_OUTPUT.put_line ('error 501' || SQLERRM);
         raise v_fatal_excp;
   END;                                                                 --}

   v_ctr := 1;
   v_size := (v_riskfactors.LAST) / 2;
   v_incr_1 := 1;
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' CONTRACT ==>'||v_curr_contract_rec.cntrct_num||' Extension='||pv_ext_flg,'', '');                
   FOR l_n_i IN 1 .. v_size
   LOOP                                                                 --{
      tab_riskvalues (v_incr_1).val := v_riskfactors (v_ctr);
      v_incr_1 := v_incr_1 + 1;
      v_ctr := v_ctr + 2;
   END LOOP;                                                            --}

   l_ctr := 2;
   v_ctr := 1;

   FOR l_n_i IN 1 .. v_size
   LOOP                                                                 --{
      tab_riskngevalues (l_n_i).val := v_riskfactors (v_ctr);
      v_ctr := l_ctr + 2;
   END LOOP;                                                            --}

   FOR i IN tab_riskvalues.FIRST .. tab_riskvalues.LAST
   LOOP
      IF (NVL (tab_riskvalues (i).val, 0) != 0)
      THEN
         v_risk_in_pct := tab_riskvalues (i).val;
         EXIT;
      END IF;
   END LOOP;

   --v_RISK_IN_PCT := tab_RiskValues(1).val; /* CHANGES INCORPORATED FOR DEFECT # 11152 */
   v_risk_nge_pct := v_size;
   v_futr_cost_glz_amt := v_factors (19);
   v_futr_cost_glz_pct := v_factors (20);
   v_futr_cost_vlz_amt := v_factors (21);
   v_futr_cost_vlz_pct := v_factors (22);
   v_futr_cost_redn_amt := v_factors (23);
   v_costofinterest := v_factors (6);
   v_realstn_cost_amt := v_factors (25);
   v_realstn_cost_pct := v_factors (26);
   v_futr_cost_corr_amt := v_factors (23);
   v_futr_cost_corr_pct := v_factors (24);
/*Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_futr_cost_glz_amt==>'||v_futr_cost_glz_amt,'', '');                
Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_futr_cost_glz_pct>'|| v_futr_cost_glz_pct,'', '');                
Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_futr_cost_vlz_amt>'|| v_futr_cost_vlz_amt,'', '');                
Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_futr_cost_vlz_pct>'|| v_futr_cost_vlz_pct,'', '');                
Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_futr_cost_redn_amt>'|| v_futr_cost_redn_amt,'', '');                
Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_costofinterest>'|| v_costofinterest,'', '');                
Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_futr_cost_corr_pct>'|| v_futr_cost_corr_pct,'', '');                
Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_futr_cost_corr_amt>'|| v_futr_cost_corr_amt,'', '');                
Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_realstn_cost_amt>'|| v_realstn_cost_amt,'', '');                
Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_realstn_cost_pct>'|| v_realstn_cost_pct,'', '');                
Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_risk_in_pct>'|| v_risk_in_pct,'', '');                
*/

   -- Based on discussion with raja 5% logic implemented
   IF (UPPER(pv_districhnl_name) = 'DIREKT' OR UPPER(pv_districhnl_sh_nm) = 'SPARKASSE'
      )                                                -- Check for product
   THEN
      IF (    UPPER (pv_ms_pdt_name) = 'KV'
          AND UPPER (pv_elmntry_pdt_name) IN ('KV', 'V2-LGS')
         )
      THEN
         IF ((100 / pv_cntrct_durtn) > v_nge_perc)
         THEN
            lv_spl_post_bus_expct_pct := 5 / 100;
         ELSE
            lv_spl_post_bus_expct_pct :=
                                         (100 / pv_cntrct_durtn)
                                       * (2 / 100);
         END IF;
      ELSE
       --  lv_spl_post_bus_expct_pct := 0;
         lv_spl_post_bus_expct_pct := v_factors (31)/100;
      END IF;
   ELSE
      lv_spl_post_bus_expct_pct := v_factors (31)/100;
   END IF;
--Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' lv_spl_post_bus_expct_pct>'|| lv_spl_post_bus_expct_pct,'', '');                

--Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' pv_districhnl_name>'|| pv_districhnl_name,'', '');                

--Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' pv_districhnl_sh_nm>'|| pv_districhnl_sh_nm,'', '');                

   IF (pv_subseg_num = 1)
   THEN
      v_piece := 1;
   ELSE
      v_piece := 0.65;
   END IF;

   v_vak_cntrct_fix_amt := v_factors (27);                 --VAK-VERTRAG-DM
   v_vak_cntrct_fix_in_pct := v_factors (28);              --VAK-VERTRAG-PR
   v_vak_sales_amt := v_factors (17);                     --VAK-VERTRIEB-DM
   v_vak_sales_pct := v_factors (18);                     --VAK-VERTRIEB-PR
   v_vak_cntrct_var_amt := v_factors (29);                --VAK-VARIABEL-DM
   v_vak_cntrct_var_in_pct := v_factors (30);             --VAK-VARIABEL-PR
   v_vak_serv_area_amt := v_factors (13);
   v_vak_serv_area_in_pct := v_factors (14);
   -- Defect 13872 - Version 1.6
   v_border_50_amt := v_factors (32);
   v_border_100_amt := v_factors (33);
/*Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_vak_cntrct_fix_amt>'|| v_vak_cntrct_fix_amt,'', '');                
Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' pv_acqstn_value>'|| pv_acqstn_value,'', '');                
Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_vak_cntrct_fix_in_pct>'|| v_vak_cntrct_fix_in_pct,'', '');                
Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_vak_sales_amt>'|| v_vak_sales_amt,'', '');                
Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_vak_sales_pct>'|| v_vak_sales_pct,'', '');                
Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_vak_cntrct_var_amt>'|| v_vak_cntrct_var_amt,'', '');                
Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_vak_cntrct_var_in_pct>'|| v_vak_cntrct_var_in_pct,'', '');                

Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_vak_serv_area_amt>'|| v_vak_serv_area_amt,'', '');                
Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_vak_serv_area_in_pct>'|| v_vak_serv_area_in_pct,'', '');                
Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' pv_cntrct_stat_num>'|| pv_cntrct_stat_num,'', '');                
*/
   IF (pv_acqstn_value > 0 AND pv_cntrct_stat_num = 400)
   THEN
      v_vak_amt_tot :=
           NVL (v_vak_cntrct_fix_amt, 0)
         + NVL (v_vak_sales_amt, 0)
         + NVL (v_vak_cntrct_var_amt, 0)
         + NVL (v_vak_serv_area_amt, 0);
      v_vak_pr_tot :=
           NVL (v_vak_cntrct_fix_in_pct, 0)
         + NVL (v_vak_sales_pct, 0)
         + NVL (v_vak_cntrct_var_in_pct, 0)
         + NVL (v_vak_serv_area_in_pct, 0);
      -- Defect 13872 Version 1.9
      v_aw_1 := 0;
      v_aw_2 := 0;
      v_aw_3 := 0;

      IF (pv_acqstn_value > v_border_100_amt)
      THEN
         v_aw_3 := pv_acqstn_value - v_border_100_amt;
         v_aw_2 := pv_acqstn_value - v_aw_3 - v_border_50_amt + 0.01;
         v_aw_1 := v_border_50_amt - 0.01;
      ELSIF (    pv_acqstn_value >= v_border_50_amt
             AND pv_acqstn_value <= v_border_100_amt
            )
      THEN
         v_aw_3 := 0;
         v_aw_2 := pv_acqstn_value - v_border_50_amt + 0.01;
         v_aw_1 := v_border_50_amt - 0.01;
      ELSIF (pv_acqstn_value < v_border_50_amt)
      THEN
         v_aw_3 := 0;
         v_aw_2 := 0;
         v_aw_1 := pv_acqstn_value;
      END IF;

      v_anfangsaufwand :=
         ROUND (  (  (v_vak_amt_tot * v_piece)
                   + (  (v_aw_1 * v_vak_pr_tot / 100)
                      + (v_aw_2 * v_vak_pr_tot * 0.5 / 100)
                     )
                  )
                * 100
               )/100;
               
   END IF;                                                              --}
--Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_anfangsaufwand>'|| v_anfangsaufwand,'', '');                

   v_glz_amt :=
        (  NVL (v_futr_cost_glz_amt, 0)
         + ((NVL (v_futr_cost_glz_pct, 0) * pv_acqstn_value) / 100)
         + NVL (v_futr_cost_corr_amt, 0)
         + ((NVL (v_futr_cost_corr_pct, 0) * pv_acqstn_value) / 100)
        )
      / 12;
--Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_glz_amt>'|| v_glz_amt,'', '');                

   v_vlz_amt :=
        (  NVL (v_futr_cost_vlz_amt, 0)
         + ((NVL (v_futr_cost_vlz_pct, 0) * pv_acqstn_value) / 100)
        )
      / 12;
--Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_vlz_amt>'|| v_vlz_amt,'', '');                

   IF (nvl(pv_ext_flg,'N') = 'N')                          /* FOR NORMAL CONTRACT */
   THEN
      v_laufender_aufwand := v_glz_amt;
   ELSE                                        /* FOR EXTENSION CONTRACT */
      v_laufender_aufwand := v_vlz_amt;
   END IF;
--Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_laufender_aufwand>'|| v_laufender_aufwand,'', '');                

   IF (pv_subseg_num > 1
      )          /* Changes incorporated for Defect # 11151,11152, 11154 */
   THEN
      v_laufender_aufwand := ROUND (v_laufender_aufwand * (65/100),2);
      v_endaufwand :=
         ROUND (  (  NVL (v_realstn_cost_amt, 0)
                   + ((NVL (v_realstn_cost_pct, 0) * pv_acqstn_value) / 100
                     )
                  )
                * 65
               )/100;
      v_risikokosten := v_risk_in_pct * (65 / 100);
   ELSE
      v_laufender_aufwand := ROUND (v_laufender_aufwand ,2);
      v_endaufwand :=
         ROUND (  (  NVL (v_realstn_cost_amt, 0)
                   + ((NVL (v_realstn_cost_pct, 0) * pv_acqstn_value) / 100
                     )
                  )
                * 100
               )/100;
      v_risikokosten := v_risk_in_pct;
   END IF;


/*  Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_anfangsaufwand>'|| v_anfangsaufwand,'', '');                
  Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_anfangsaufwand>'|| v_anfangsaufwand,'', '');                

  Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_laufender_aufwand>'|| v_laufender_aufwand,'', '');                
  Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_endaufwand>'|| v_endaufwand,'', '');                

  Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_risikokosten>'|| v_risikokosten,'', '');                
*/
   v_verwaltungskosten_rec.createRestwert        := true;
   v_verwaltungskosten_rec.anfang_betrag         := ABS(v_anfangsaufwand);
   v_verwaltungskosten_rec.laufend_betrag        := ABS(v_laufender_aufwand);
   v_verwaltungskosten_rec.ende_betrag           := ABS(v_endaufwand);

   v_risikovorsorge_rec.createRestwert           := true;
   v_risikovorsorge_rec.prozent                  := ABS(v_risikokosten);
   v_risikovorsorge_rec.bezugszeitraum           := 'JAHR';
   
--  Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_cntr_other_info.spl_post_bus_expct_pct>'|| v_cntr_other_info.spl_post_bus_expct_pct,'', '');                
  
   IF(nvl(v_cntr_other_info.spl_post_bus_expct_pct,0) > 0)
   THEN
--     Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' inside v_cntr_other_info.spl_post_bus_expct_pct>'|| v_cntr_other_info.spl_post_bus_expct_pct,'', '');                
      lv_calc_post_bus_expct_pct := v_cntr_other_info.spl_post_bus_expct_pct/100;
   ELSE
--    Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' inside lv_spl_post_bus_expct_pct>'||lv_spl_post_bus_expct_pct ,'', '');                
      lv_calc_post_bus_expct_pct := nvl(lv_spl_post_bus_expct_pct,0);
   END IF;
--   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' lv_calc_post_bus_expct_pct>'|| lv_calc_post_bus_expct_pct,'', '');                

   IF(lv_calc_post_bus_expct_pct > 0)
   THEN
   --Changes for defect 17984
--           v_nachgeschaeft_rec.faelligkeit    := v_curr_contract_rec.lease_end_dt + 1;     
           v_nachgeschaeft_rec.faelligkeit    := v_curr_contract_rec.lease_end_dt ;     
           v_nachgeschaeft_rec.betrag         :=
                         ROUND ((NVL (pv_acqstn_value, 0) * lv_calc_post_bus_expct_pct),
                                2
                               );
                         
           v_nachgeschaeft_rec.createRestwert := true;
   ELSE
           v_nachgeschaeft_rec.createRestwert := false;
   END IF;
-- Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',' v_nachgeschaeft_rec.betrag>'|| v_nachgeschaeft_rec.betrag,'', '');                

   EXCEPTION
   WHEN OTHERS
   THEN
         pkg_batch_logger.proc_log (lf_file_handle,
                                    'FATAL',
                                    'BAT_F_9999',
                                    'VERWALTUNGS',
                                    SQLERRM
                                   );
         RAISE v_fatal_excp;
   END PROC_VERWALTUNGS_RISK_KOSTEN ;


   PROCEDURE PROC_CREATE_RESTWERT IS
   BEGIN
         v_restwert_rec:= null;
         v_restwert_rec.createRestwert :=  FALSE;
         v_restwert_rec.rw_betrag := null;
         v_restwert_rec.rw_betrag_vor_verl := null;
         v_restwert_rec.faelligkeit := null;

         IF(v_vertragsheader_rec.vertragstyp != 'MIETKAUF' 
         AND v_curr_contract_rec.elmntry_pdt_name NOT IN('KV','V2-LGS'))
         THEN
            v_restwert_rec.createRestwert   := true;

            /*-------------------------------------------------*/
            /* Geting value for faelligkeit                    */
            /*-------------------------------------------------*/

            IF v_curr_contract_rec.lease_end_dt IS NOT NULL
            THEN
               -- changes for defect 17984 
               --v_restwert_rec.faelligkeit := v_curr_contract_rec.lease_end_dt + 1;
               v_restwert_rec.faelligkeit := v_curr_contract_rec.lease_end_dt ;
            ELSE
               v_restwert_rec.faelligkeit :=ADD_MONTHS (v_curr_contract_rec.lease_bgn_dt, v_curr_contract_rec.min_cntrct_durtn)       - 1;
            END IF;
            
            v_restwert_rec.rw_betrag := v_cntr_other_info.rsdl_value;

         /*-----------------------------------------------*/
         /* Geting value for v_rw_betrag_vor_verl         */
         /*-----------------------------------------------*/
            v_restwert_rec.rw_betrag_vor_verl := 0;

            IF (v_cntr_other_info.berites = 'J'	AND v_curr_contract_rec.old_subseg_cd != 'X')
            THEN  --$$$$
               FOR cur_old IN cur_old_sub_seg_cd (v_curr_contract_rec.subseg_cd)
               LOOP
                  BEGIN
                        SELECT rsdl_value
                        INTO v_restwert_rec.rw_betrag_vor_verl
                        FROM uc_payment_ms
                        WHERE subseg_cd = cur_old.subseg_cd;
                  EXCEPTION
                  WHEN OTHERS
                  THEN
                        v_restwert_rec.rw_betrag_vor_verl := 0;
                        pkg_batch_logger.proc_log (lf_file_handle,
                                                   'FATAL',
                                                   'BAT_F_9999',
                                                      'v_rw_betrag_vor_verl'
                                                   || ','
                                                   || v_curr_contract_rec.subseg_cd,
                                                   SQLERRM
                                                  );
                  END;

                  EXIT;
               END LOOP;
            END IF;
            IF(nvl(v_restwert_rec.rw_betrag_vor_verl,0) = 0)
            THEN
               v_restwert_rec.rw_betrag_vor_verl :=v_restwert_rec.rw_betrag;
            END IF;

            IF(v_cntr_other_info.berites = 'J' AND v_curr_contract_rec.comp_num = '599')
            THEN
               v_restwert_rec.rw_betrag         :=   0 ;
               -- changes for defect 17984 
--              v_restwert_rec.faelligkeit       :=   v_vertragsheader_rec.vende_verlaengerung +1;
              v_restwert_rec.faelligkeit       :=   v_vertragsheader_rec.vende_verlaengerung;
            END IF;
            --Fix for defect 17840. If residal value is zero,then do not create restwert component.
            IF(nvl(v_restwert_rec.rw_betrag,0) = 0 AND nvl(v_restwert_rec.rw_betrag_vor_verl,0) = 0 )
            THEN
                         v_restwert_rec.createRestwert :=  FALSE;
            END IF;
         END IF;
   END PROC_CREATE_RESTWERT;

   --Defect 17982 nutzungsentgelt
   PROCEDURE PROC_CREATE_NUTZUNGSENTGELT IS

   BEGIN
      v_nutzungsentgelt_rec := null;
      v_nutzungsentgelt_rec.createNutzungsentgelt    := false;
      IF v_cntr_other_info.utlztn_charge > 0
      THEN
         v_nutzungsentgelt_rec.betrag                 := v_cntr_other_info.utlztn_charge;
         v_nutzungsentgelt_rec.faelligkeit            := v_cntr_other_info.utlztn_frm;
         v_nutzungsentgelt_rec.createNutzungsentgelt  := true;
      ELSE
         v_nutzungsentgelt_rec.createNutzungsentgelt    := false;
      END IF;
   END PROC_CREATE_NUTZUNGSENTGELT;


   PROCEDURE PROC_CREATE_ZAHLUNGSPLAN IS
   v_zlg_rec            zlg_typ;
   v_rate_explizit      rate_explizit_tab;
   v_diff_mon           NUMBER(10);
   v_rate_index         BINARY_INTEGER := 1;
   v_first_inst_record  BOOLEAN := true;
   v_first_inst_zlg  BOOLEAN := false;
   BEGIN
      /* ------ Element  Zahlungsplan   Starts         */

         v_zahlungsplan_rec := null;
      /*-----------------------------------------------*/
      /* Geting value for v_zahl_linearisierungsart    */
      /*-----------------------------------------------*/
           v_zahlungsplan_rec.linearisierungsart := 'ABSCHNITT';
      /*-----------------------------------------------*/
      /* Geting value for v_zahl_ratentyp              */
      /*-----------------------------------------------*/
           v_zahlungsplan_rec.ratentyp := 'LEASING';
      /*-----------------------------------------------*/
      /* Geting value for v_ratenplan_explizit_rate    */
      /*-----------------------------------------------*/

       v_zahlungsplan_rec.createZahlungpalan    := FALSE;
/* Commented to close defect 17982 -replaced with nutzungsentgelt 
      IF v_cntr_other_info.utlztn_charge > 0
      THEN
         v_zlg_rec.betrag := v_cntr_other_info.utlztn_charge;
         v_zlg_rec.termin := v_cntr_other_info.utlztn_frm;
         v_zahlungsplan_rec.createZahlungpalan    := true;
      END IF; 
      v_zahlungsplan_rec.zlg  := v_zlg_rec;
*/



      v_rate_explizit.delete;
      /*---------------------------------------------------------*/
      /* Geting values for set of elements ( v_rate_exp_str )    */
      /*---------------------------------------------------------*/
      BEGIN
        v_rate_index := 1;
--         Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',v_rate_index,'', '');                
         v_first_inst_record := TRUE;

         FOR J  IN v_cur_lease_rntl_tab.FIRST..v_cur_lease_rntl_tab.LAST
         LOOP
        
            v_diff_mon := MONTHS_BETWEEN(v_cur_lease_rntl_tab(J).to_dt,v_cur_lease_rntl_tab(J).frm_dt);
          
            IF(v_first_inst_record = TRUE AND nvl(v_cntr_other_info.utlztn_charge,0) <= 0 
            AND v_cntr_other_info.first_instlmnt_dt < v_curr_contract_rec.lease_bgn_dt )
            THEN
                   v_zlg_rec.betrag := v_cur_lease_rntl_tab(J).end_rate_amt;
                   v_zlg_rec.termin := v_vertragsheader_rec.vbeginn;
                   v_zahlungsplan_rec.createZahlungpalan    := true;
                   v_zahlungsplan_rec.zlg  := v_zlg_rec;
                   v_first_inst_zlg := true;
            ELSE
                   v_first_inst_zlg := false;
            END IF; 
            
            v_first_inst_record  := false;

            IF(v_cur_lease_rntl_tab(J).to_dt >= v_vertragsheader_rec.vbeginn 
            and v_cur_lease_rntl_tab(J).frm_dt <= v_vertragsheader_rec.vende_verlaengerung)
            THEN
               v_zahlungsplan_rec.createZahlungpalan    := true;
               IF(v_diff_mon < 888)
               THEN
                  v_rate_explizit(v_rate_index).betrag        := v_cur_lease_rntl_tab(J).end_rate_amt;
                  if(v_first_inst_zlg = TRUE)
                  THEN
                     v_rate_explizit(v_rate_index).faellig_ab    := add_months(v_cur_lease_rntl_tab(J).frm_dt,1);
                  ELSE
                     v_rate_explizit(v_rate_index).faellig_ab    := v_cur_lease_rntl_tab(J).frm_dt;
                  END IF;
                  v_rate_explizit(v_rate_index).ratenabstand  := v_cur_lease_rntl_tab(J).pymt_md;
                  v_rate_explizit(v_rate_index).gueltig_bis   := v_cur_lease_rntl_tab(J).to_dt;
               ELSE
                  IF(ROUND(MONTHS_BETWEEN(v_vertragsheader_rec.vende_verlaengerung, v_cur_lease_rntl_tab(J).frm_dt)) >= 1)
                  THEN
                       v_rate_explizit(v_rate_index).betrag        := v_cur_lease_rntl_tab(J).end_rate_amt;
                       v_rate_explizit(v_rate_index).faellig_ab    := v_cur_lease_rntl_tab(J).frm_dt;
                       v_rate_explizit(v_rate_index).ratenabstand  := v_cur_lease_rntl_tab(J).pymt_md;
                       v_rate_explizit(v_rate_index).gueltig_bis   := v_vertragsheader_rec.vende_verlaengerung;
                  END IF;
               END IF;
               v_rate_index := v_rate_index + 1;
--               Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',v_rate_index,'', '');                
--               Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','v_rate_explizit.count='||v_rate_explizit.count,'', '');                

            END IF;
         END LOOP;
--        Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','v_rate_explizit.count='||v_rate_explizit.count,'', '');                

      EXCEPTION
         WHEN OTHERS
         THEN
            pkg_batch_logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999','v_rate_exp_str'|| ','|| v_curr_contract_rec.subseg_cd,SQLERRM);
            raise v_fatal_excp;
      END;
      v_zahlungsplan_rec.rate_explizit  := v_rate_explizit;
   END PROC_CREATE_ZAHLUNGSPLAN;


   PROCEDURE PROC_CREATE_VETRAGHEADER IS
      
   v_fn_ret                      VARCHAR2(2);
   lv_prim_durtn_end_dt          DATE;
   v_next_inst_date              DATE;
   v_next_inst_date1             VARCHAR2(5);
   v_tmp                         NUMBER(3);

   BEGIN

      v_cntr_other_info.acqstn_value       := 0;
      v_cntr_other_info.down_pymt          := 0;
      v_cntr_other_info.pkt_cd             := 0;
      v_cntr_other_info.rsdl_value         := 0;
      /*---------------------------------------------*/
      /* Geting value for v_vname                    */
         /*---------------------------------------------*/
         SELECT    'V'
             || LPAD (v_curr_contract_rec.prtnr_num, 10, 0)
             || '-'
             || LPAD (v_curr_contract_rec.cntrct_num, 12, '0')
             || '-'
             || LPAD (v_curr_contract_rec.seg_num, 3, 0)
             || '-'
             || LPAD (v_curr_contract_rec.subseg_num, 3, 0)
        INTO v_vertragsheader_rec.vname
        FROM DUAL;

        v_vertragsheader_rec.gesellschaft  := lpad(v_curr_contract_rec.comp_num,3,'0');        
        v_vertragsheader_rec.branche       := lpad(v_curr_contract_rec.comp_num,3,'0');       
        
        /*---------------------------------------------*/
        /* Geting value for v_geschaeftsstelle         */
        /*---------------------------------------------*/
         BEGIN
            SELECT cd_desc
              INTO v_vertragsheader_rec.geschaeftsstelle
              FROM uc_cntrct_codes_ms
             WHERE cntrct_codes_cd = v_curr_contract_rec.cntrct_way;
         EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
               v_vertragsheader_rec.geschaeftsstelle := NULL;
               pkg_batch_logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999','geschaeftsstelle'|| ','|| v_curr_contract_rec.subseg_cd,SQLERRM);
         END;

         BEGIN
                  SELECT refin_cd
                  INTO v_cntr_other_info.lgs_refin_typ_desc
                  FROM uc_refin_codes_ms
                  WHERE refin_codes_cd = v_curr_contract_rec.lgs_refin_typ;
         EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            v_cntr_other_info.lgs_refin_typ_desc := NULL;
         END;

         /*---------------------------------------------*/
         /* Geting value for v_plz                      */
         /*---------------------------------------------*/
         BEGIN
            
            SELECT ltrim(rtrim(a.zip_cd))
                 INTO v_vertragsheader_rec.plz            
                FROM uc_address_info_tx a,
                     uc_partner_role_map_tx b
                WHERE  a.addr_typ = 'M'
                  AND b.ROLE_ID = 0
                  AND a.prtnr_role_map_cd = b.prtnr_role_map_cd  
                  AND b.prtnr_id =v_curr_contract_rec.prtnr_id;               
            EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                  v_vertragsheader_rec.plz := NULL;
                  pkg_batch_logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999','v_plz' || ',' || v_curr_contract_rec.subseg_cd,SQLERRM);
         END;

         BEGIN                                                          --{ 
               SELECT c.NAME segmentcode, c.short_name
                 INTO v_cntr_other_info.segcd_sh_nm, v_cntr_other_info.bus_seg_cd_sh_nm
                 FROM uc_bus_seg_ms c
                WHERE c.bus_seg_cd = v_curr_contract_rec.bus_seg_cd;
         EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
                  pkg_batch_logger.proc_log (lf_file_handle,'ERROR','BAT_I_0016',v_curr_contract_rec.bus_seg_cd,'v_cntr_other_info.segcd_sh_nm');
                  v_cntr_other_info.segcd_sh_nm :=NULL;
                  v_cntr_other_info.bus_seg_cd_sh_nm :=NULL;
         WHEN TOO_MANY_ROWS
         THEN
                  pkg_batch_logger.proc_log (lf_file_handle,'ERROR','BAT_E_0091',v_curr_contract_rec.bus_seg_cd,'v_cntr_other_info.segcd_sh_nm');
                  v_cntr_other_info.segcd_sh_nm :=NULL;
                  v_cntr_other_info.bus_seg_cd_sh_nm :=NULL;
         WHEN OTHERS
         THEN
                  pkg_batch_logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',SQLCODE|| SQLERRM|| 'v_cntr_other_info.segcd_sh_nm',v_curr_contract_rec.bus_seg_cd);
                  v_cntr_other_info.segcd_sh_nm :=NULL;
                  v_cntr_other_info.bus_seg_cd_sh_nm :=NULL;
         END;                                                           --} 

         BEGIN                                                          --{ 
            SELECT UPPER(b.short_name) distributionchannel, UPPER(b.NAME),SHORT_NAME||'/'||Name
              INTO v_cntr_other_info.districhnl_sh_nm, v_cntr_other_info.districhnl_name,v_cntr_other_info.sparte
              FROM uc_distrib_chnl_ms b
             WHERE b.distrib_chnl_cd = v_curr_contract_rec.distrib_chnl_cd;
         EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
               pkg_batch_logger.proc_log (lf_file_handle,'ERROR','BAT_I_0016',v_curr_contract_rec.distrib_chnl_cd,'DISTRIBUTIONCHANNEL');
               v_cntr_other_info.districhnl_sh_nm :=NULL;
               v_cntr_other_info.districhnl_name :=NULL;
         WHEN TOO_MANY_ROWS
         THEN
               pkg_batch_logger.proc_log (lf_file_handle,'ERROR','BAT_E_0091',v_curr_contract_rec.distrib_chnl_cd,'DISTRIBUTIONCHANNEL');
               v_cntr_other_info.districhnl_sh_nm :=NULL;
               v_cntr_other_info.districhnl_name := NULL;
         WHEN OTHERS
         THEN
               pkg_batch_logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',SQLCODE|| SQLERRM|| 'DISTRIBUTIONCHANNEL',v_curr_contract_rec.distrib_chnl_cd);
               v_cntr_other_info.districhnl_sh_nm :=NULL;
               v_cntr_other_info.districhnl_name :=NULL;
         END;                                                           --}

         BEGIN                                                          --{ 
            SELECT a.lease_bill_pay_dt, NVL (a.rsdl_value, 0),NVL (a.rsdl_value, 0),
                   e.acqstn_value, a.down_pymt,
                   a.incrse_first_instlmnt_pct,
                   a.expct_post_sale_pft_pct, a.pymt_cd, a.utlztn_charge,
                   a.rv_redn_fact, a.rntl_typ_codes_cd,
                   a.prmsbl_pymt_modes, a.vat_cd, a.utlztn_charge,
                   a.utlztn_frm
              INTO v_cntr_other_info.first_instlmnt_dt, v_cntr_other_info.rsdl_value,v_cntr_other_info.rsdl_value_org,
                   v_cntr_other_info.acqstn_value, v_cntr_other_info.down_pymt,
                   v_cntr_other_info.incrse_first_instlmnt_pct,
                   v_cntr_other_info.spl_post_bus_expct_pct, v_cntr_other_info.pymt_cd, v_cntr_other_info.spl_rate,
                   v_cntr_other_info.rv_redn_fact, v_cntr_other_info.pymt_rntl_typ_codes_cd,
                   v_cntr_other_info.pymt_prmsbl_pymt_modes, v_cntr_other_info.vat_cd, v_cntr_other_info.utlztn_charge,
                   v_cntr_other_info.utlztn_frm
             FROM uc_payment_ms a, uc_pricing_ms e
             WHERE a.subseg_cd = v_curr_contract_rec.subseg_cd 
             AND a.subseg_cd = e.subseg_cd;
         EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
               pkg_batch_logger.proc_log (lf_file_handle,'ERROR','BAT_I_0016',v_curr_contract_rec.subseg_cd,'FIRST_INSTLMNT_DT');
               RAISE v_skip_record;
         WHEN TOO_MANY_ROWS
         THEN
               pkg_batch_logger.proc_log (lf_file_handle,'ERROR','BAT_E_0091',v_curr_contract_rec.subseg_cd,'FIRST_INSTLMNT_DT');
               RAISE v_skip_record;
         WHEN OTHERS
         THEN
               pkg_batch_logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',SQLCODE|| SQLERRM|| 'FIRST_INSTLMNT_DT',v_curr_contract_rec.subseg_cd);
               RAISE v_skip_record;
         END;                                                           --} 

         IF (NVL (v_curr_contract_rec.min_fnl_pymt, 0) != 0)
         THEN
               v_cntr_other_info.rsdl_value := v_curr_contract_rec.min_fnl_pymt;
         END IF;

         BEGIN                                                          --{ 
            SELECT c.rntl_typ_codes_cd, c.cd_desc
              INTO v_cntr_other_info.rntl_typ_codes_cd, v_cntr_other_info.rntl_typ_codes_desc
              FROM uc_rntl_typ_ms c
             WHERE c.rntl_typ_codes_cd = v_cntr_other_info.pymt_rntl_typ_codes_cd;
         EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            pkg_batch_logger.proc_log (lf_file_handle,'ERROR','BAT_I_0016',v_cntr_other_info.pymt_cd,'v_cntr_other_info.rntl_typ_codes_desc');
            RAISE v_skip_record;
         WHEN TOO_MANY_ROWS
         THEN
            pkg_batch_logger.proc_log (lf_file_handle,'ERROR','BAT_E_0091',v_cntr_other_info.pymt_cd,'v_cntr_other_info.rntl_typ_codes_desc');
            RAISE v_skip_record;
         WHEN OTHERS
         THEN
            pkg_batch_logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',SQLCODE|| SQLERRM|| 'v_cntr_other_info.rntl_typ_codes_desc',v_cntr_other_info.pymt_cd);
            RAISE v_skip_record;
         END;                                                           --}


         BEGIN                                                          --{
             SELECT UPPER (a.cd_desc), UPPER (codes_cd)
             INTO v_cntr_other_info.prmsbl_pymt_modes, v_cntr_other_info.prmsbl_pymt_modes_cd
             FROM uc_cntrct_codes_ms a
             WHERE a.cntrct_codes_cd = v_cntr_other_info.pymt_prmsbl_pymt_modes
             AND cd_type = 'PAYMENT_MODE';
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               pkg_batch_logger.proc_log (lf_file_handle,'ERROR','BAT_I_0016',v_curr_contract_rec.subseg_cd,'v_PRMSBL_PYMT_MODES');
               RAISE v_skip_record;
            WHEN TOO_MANY_ROWS
            THEN
               pkg_batch_logger.proc_log (lf_file_handle,'ERROR','BAT_E_0091',v_curr_contract_rec.subseg_cd,'v_PRMSBL_PYMT_MODES');
               RAISE v_skip_record;
            WHEN OTHERS
            THEN
               pkg_batch_logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',SQLCODE|| SQLERRM|| 'v_PRMSBL_PYMT_MODES',v_curr_contract_rec.subseg_cd);
               RAISE v_skip_record;
         END;        

         PROC_FETCH_LEASE_RNTL_DTL(v_cntr_other_info.pymt_cd);

         /*   v_supplier for price proofing     */
         BEGIN
            SELECT p.obj_pkg_id
            INTO v_cntr_other_info.supplier
            FROM uc_object_package_ms p, uc_subseg_obj_pkg_tx o
            WHERE p.obj_pkg_id = o.obj_pkg_cd
            AND o.subseg_cd = v_curr_contract_rec.subseg_cd
            AND ROWNUM < 2;
--          dbms_output.put_line('The value of Output v_partner : '||v_partner);                  
         EXCEPTION            
         WHEN OTHERS
         THEN
            v_cntr_other_info.supplier := NULL;
         END;

         BEGIN                                                          --{
         -- Added pkt code in the selection to retrieve sum_lin_amt and sum_fin_amt -kali
         -- Added fin_early_trmntd_flg condition to avoid inactive refinancing records.
               SELECT c.refin_cd, a.prchse_comp_cd, a.refin_typ,
                   NVL (a.stlmnt_int_rate, 0),
                   DECODE (NVL (a.refin_int_rate, 0), 0, v_curr_contract_rec.refin_int_rate),
                   NVL (a.stlmnt_sales_price, sales_price),
                   a.refin_start_dt,                            --- nvl function added
                   a.sale_dt,                            --- nvl function added
                   a.trnsfr_num, f.comp_num, g.prtnr_num,
                   g.cr_worth, a.pkt_cd,a.num_of_sold_mon
               INTO v_cntr_other_info.refin_cd, v_cntr_other_info.prchse_comp_cd, v_cntr_other_info.refin_typ,
                   v_cntr_other_info.stlmnt_int_rate,
                   v_cntr_other_info.refin_int_rate,
                   v_cntr_other_info.stlmnt_sales_price,
                   v_cntr_other_info.refin_start_dt,
                   v_cntr_other_info.sale_dt,
                   v_cntr_other_info.trnsfr_num, v_cntr_other_info.prchse_comp_num, v_cntr_other_info.refin_prtnr_num,
                   v_cntr_other_info.cr_worth, v_cntr_other_info.pkt_cd,v_cntr_other_info.num_of_sold_mon
               FROM uc_refin_ms a,
                   uc_refin_codes_ms c,
                   uc_company_ms f,
                   uc_partner_ms g
               WHERE a.subseg_cd = v_curr_contract_rec.subseg_cd
               AND c.refin_codes_cd = a.refin_typ
               AND f.prtnr_id = a.prchse_comp_cd
               AND g.prtnr_id = a.prtnr_id
               AND a.refin_sub_typ = 'GMZ'
               AND a.fin_early_trmntd_flg = 'N';
         EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
         BEGIN
               -- Added fin_early_trmntd_flg condition to fetch future dated terminated contracts.
            SELECT c.refin_cd, a.prchse_comp_cd, a.refin_typ,
                   NVL (a.stlmnt_int_rate, 0),
                   DECODE (NVL (a.refin_int_rate, 0), 0, v_curr_contract_rec.refin_int_rate),
                   NVL (a.stlmnt_sales_price, sales_price),
                   a.refin_start_dt,                            --- nvl function added
                   a.sale_dt,                            --- nvl function added
                   a.trnsfr_num, f.comp_num, g.prtnr_num,
                   g.cr_worth, a.pkt_cd,a.num_of_sold_mon
               INTO v_cntr_other_info.refin_cd, v_cntr_other_info.prchse_comp_cd, v_cntr_other_info.refin_typ,
                   v_cntr_other_info.stlmnt_int_rate,
                   v_cntr_other_info.refin_int_rate,
                   v_cntr_other_info.stlmnt_sales_price,
                   v_cntr_other_info.refin_start_dt,
                   v_cntr_other_info.sale_dt,
                   v_cntr_other_info.trnsfr_num, v_cntr_other_info.prchse_comp_num, v_cntr_other_info.refin_prtnr_num,
                   v_cntr_other_info.cr_worth, v_cntr_other_info.pkt_cd,v_cntr_other_info.num_of_sold_mon
                 FROM uc_refin_ms a,
                      uc_refin_codes_ms c,
                      uc_company_ms f,
                      uc_partner_ms g
                WHERE a.subseg_cd = v_curr_contract_rec.subseg_cd
                  AND c.refin_codes_cd = a.refin_typ
                  AND f.prtnr_id = a.prchse_comp_cd
                  AND g.prtnr_id = a.prtnr_id
                  AND a.refin_sub_typ = 'GMZ'
                  AND a.fin_early_trmntd_flg = 'T'
                  AND ROWNUM < 2;
            EXCEPTION
               WHEN NO_DATA_FOUND
               THEN
                  v_cntr_other_info.refin_cd := NULL;
                  v_cntr_other_info.prchse_comp_cd := NULL;
                  v_cntr_other_info.refin_typ := NULL;
                  v_cntr_other_info.stlmnt_int_rate := v_curr_contract_rec.refin_int_rate;
                  v_cntr_other_info.refin_int_rate := v_curr_contract_rec.refin_int_rate;
                  v_cntr_other_info.stlmnt_sales_price := 0;
                  v_cntr_other_info.sale_dt := v_curr_contract_rec.cntrct_start_dt;
                  v_cntr_other_info.trnsfr_num := NULL;
                  v_cntr_other_info.prchse_comp_num := NULL;
                  v_cntr_other_info.refin_prtnr_num := NULL;
                  v_cntr_other_info.cr_worth := 'Alle';
               WHEN TOO_MANY_ROWS
               THEN
                  pkg_batch_logger.proc_log (lf_file_handle,'ERROR','BAT_E_0091',v_curr_contract_rec.subseg_cd,'REFIN_CD');
                  RAISE v_skip_record;
         END;
         WHEN TOO_MANY_ROWS
         THEN
            pkg_batch_logger.proc_log (lf_file_handle,'ERROR','BAT_E_0091',v_curr_contract_rec.subseg_cd,'REFIN_CD');
            RAISE v_skip_record;
         WHEN OTHERS
         THEN
            pkg_batch_logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',SQLCODE || SQLERRM || 'REFIN_CD',v_curr_contract_rec.subseg_cd);
            RAISE v_skip_record;
         END;                
         
         --Added for defect 18010
         IF(v_cntr_other_info.refin_typ IS NOT NULL)
         THEN
                BEGIN
                        SELECT REPYMT_START_DT
                        INTO v_cntr_other_info.repymt_start_dt
                        FROM UC_BBILANZ_MS
                        WHERE PKT_CD = v_cntr_other_info.pkt_cd;
                EXCEPTION 
                WHEN NO_DATA_FOUND 
                THEN
                      v_cntr_other_info.repymt_start_dt:=  NULL;
                END ;
         END IF;


        v_vertragsheader_rec.geschaeftsbereich       := v_cntr_other_info.bus_seg_cd_sh_nm;
        
        /*---------------------------------------------*/
        /* Geting value for v_rating                   */
        /*---------------------------------------------*/
         ---$$$ 
   /*      IF ((v_curr_contract_rec.comp_num IN (05,83)) AND (v_curr_contract_rec.supl_prtnr_num = 390127) AND (v_curr_contract_rec.smntry_agrmnt_cd = '99')) THEN --{
            v_vertragsheader_rec.rating := '99';
         ELSE --}{
            v_vertragsheader_rec.rating := '00';
         END IF; --} */

         v_vertragsheader_rec.rating := FN_GET_BONITAET_NOTE;
         
         /*---------------------------------------------*/
         /* Geting value for objektart                */
         /*---------------------------------------------*/
         IF (UPPER (v_cntr_other_info.bus_seg_cd_sh_nm) = 'EQUIP')
         THEN                                                           --{
            v_vertragsheader_rec.objektart := '10';
         ELSIF (UPPER (v_cntr_other_info.bus_seg_cd_sh_nm) = 'COM')
         THEN                                                          --}{
            v_vertragsheader_rec.objektart := '20';
         ELSIF (UPPER (v_cntr_other_info.bus_seg_cd_sh_nm) = 'AUTO')
         THEN                                                          --}{
            v_vertragsheader_rec.objektart := '40';
         ELSE                                                          --}{
            v_vertragsheader_rec.objektart := '99';
         END IF;                                                        --}
   
         /*---------------------------------------------*/
         /* Geting value for v_vertriebsweg             */
         /*---------------------------------------------*/
         IF (UPPER (v_cntr_other_info.districhnl_sh_nm) = 'SPARKASSE')
         THEN                                                           --{
            v_vertragsheader_rec.vertriebsweg := 'BANK';
         ELSIF (UPPER (v_cntr_other_info.districhnl_sh_nm) = 'PARTNER')
         THEN                                                          --}{
            v_vertragsheader_rec.vertriebsweg := 'HAENDLER';
         ELSIF (UPPER (v_cntr_other_info.districhnl_sh_nm) = 'DIREKT')
         THEN                                                          --}{
            v_vertragsheader_rec.vertriebsweg := 'DIREKT';
         ELSE                                                          --}{
            v_vertragsheader_rec.vertriebsweg := 'DIREKT';
         END IF;                                                        --}

         /*---------------------------------------------*/
         /* Geting value for v_ratenstruktur            */
         /*---------------------------------------------*/
         IF (v_curr_contract_rec.comp_num = 599 OR UPPER (v_cntr_other_info.rntl_typ_codes_desc) = 'LINEAR')
         THEN                                                           --{
            v_vertragsheader_rec.ratenstruktur := 'LINEAR';
         ELSIF (UPPER (v_cntr_other_info.rntl_typ_codes_desc) = 'DEGRESSIV')
         THEN                                                          --}{
            v_vertragsheader_rec.ratenstruktur := 'DEGRESSIV';
         ELSE                                                          --}{
            v_vertragsheader_rec.ratenstruktur := 'ANDERE';
         END IF;          

         /*---------------------------------------------*/
         /* Geting value for v_beginn                   */
         /*---------------------------------------------*/
         IF v_cntr_other_info.first_instlmnt_dt < v_curr_contract_rec.lease_bgn_dt
         THEN
            v_vertragsheader_rec.vbeginn1 := v_cntr_other_info.first_instlmnt_dt;
         ELSE
            v_vertragsheader_rec.vbeginn1 := v_curr_contract_rec.lease_bgn_dt;
         END IF;

         IF(v_cntr_other_info.first_instlmnt_dt < v_curr_contract_rec.lease_bgn_dt)
         THEN
               IF( v_cntr_other_info.utlztn_charge > 0 )
               THEN
                   v_vertragsheader_rec.vbeginn := v_cntr_other_info.first_instlmnt_dt;
               ELSE
                   v_vertragsheader_rec.vbeginn := v_curr_contract_rec.lease_bgn_dt;
               END IF;
         ELSE
                   v_vertragsheader_rec.vbeginn := v_curr_contract_rec.lease_bgn_dt;
         END IF;
         
			IF(v_curr_contract_rec.old_subseg_cd != 'X')
			THEN
				BEGIN --{
					SELECT CNTRCT_STAT_NUM 
					INTO v_cntr_other_info.old_cntrct_stat_num
					FROM UC_SUB_SEGMENT_MS
					WHERE SUBSEG_CD = v_curr_contract_rec.old_subseg_cd;
				EXCEPTION
				WHEN NO_DATA_FOUND 
				THEN
					v_cntr_other_info.old_cntrct_stat_num := null;
				WHEN TOO_MANY_ROWS 
				THEN
					Pkg_Batch_Logger.proc_log(lf_file_handle,'ERROR','BAT_E_0091',v_curr_contract_rec.old_subseg_cd,'CNTRCT_STAT_NUM');
					RAISE v_skip_record;
				WHEN OTHERS 
				THEN
					Pkg_Batch_Logger.proc_log(lf_file_handle,'FATAL','BAT_F_9999',SQLCODE||SQLERRM||'CNTRCT_STAT_NUM',v_curr_contract_rec.old_subseg_cd);
					RAISE v_skip_record;
				END; --}
			END IF;
         --$$$ v_berites
         IF (v_curr_contract_rec.comp_num != 599) THEN --{
            lv_prim_durtn_end_dt := ADD_MONTHS(v_curr_contract_rec.lease_bgn_dt-1,v_curr_contract_rec.CNTRCT_DURTN);
         ELSIF (v_curr_contract_rec.comp_num = 599) THEN --}{	
            lv_prim_durtn_end_dt := ADD_MONTHS(v_cntr_other_info.first_instlmnt_dt-1,v_curr_contract_rec.CNTRCT_DURTN);
         END IF; --}

         IF (v_curr_contract_rec.cntrct_stat_num = 400 AND v_curr_contract_rec.old_subseg_cd != 'X' AND NVL(v_cntr_other_info.old_cntrct_stat_num,0) = 500) THEN --{
            v_cntr_other_info.berites := 'J';
         ELSIF (v_curr_contract_rec.cntrct_stat_num = 400 AND v_curr_contract_rec.old_subseg_cd != 'X' AND NVL(v_cntr_other_info.old_cntrct_stat_num,0) != 500) THEN --}{
            IF(v_stichtag_date >= v_curr_contract_rec.lease_end_dt)
            THEN
                v_cntr_other_info.berites := 'J';
            ELSE
                v_cntr_other_info.berites := 'N';
            END IF;
         ELSIF ((v_curr_contract_rec.cntrct_stat_num = 400 AND v_curr_contract_rec.old_subseg_cd = 'X' AND (lv_prim_durtn_end_dt <= v_Stichtag_Date)) or (v_Stichtag_Date > v_curr_contract_rec.lease_end_dt)) THEN --}{
            v_cntr_other_info.berites := 'J';
         ELSIF (v_curr_contract_rec.cntrct_stat_num = 400 AND v_curr_contract_rec.old_subseg_cd = 'X' AND (lv_prim_durtn_end_dt > v_Stichtag_Date)) THEN --}{
            v_cntr_other_info.berites := 'N';
         END IF; --}
         
         /*------------------------------------------------*/
         /* Geting value for v_naechste_sollstellung       */
         /*------------------------------------------------*/
         IF v_curr_contract_rec.comp_num IN (599, 596, 597)
         THEN
            v_vertragsheader_rec.naechste_sollstellung := TRUNC (ADD_MONTHS (v_stichtag_date, 1), 'MM');
         ELSE
               BEGIN --{
                  SELECT decode(v_cntr_other_info.prmsbl_pymt_modes_cd,'MON',1,'QUAR',3,'HALF',6,'YRLY',12)
                  INTO v_tmp 
                  FROM DUAL;

                  SELECT floor((months_between(v_stichtag_date,v_vertragsheader_rec.vbeginn)/v_tmp)+1)*v_tmp
                  INTO v_next_inst_date1 
                  FROM DUAL;
               EXCEPTION
               WHEN OTHERS THEN
                  Pkg_Batch_Logger.proc_log(lf_file_handle,'FATAL','BAT_F_9999','next_inst_date1'||SQLCODE||SQLERRM,v_vertragsheader_rec.vbeginn||','||v_tmp);
                  raise v_skip_record;
               END; --}

               v_next_inst_date := add_months (v_vertragsheader_rec.vbeginn,v_next_inst_date1 );

               IF(v_cntr_other_info.berites = 'J')
               THEN
                    v_vertragsheader_rec.naechste_sollstellung    := v_next_inst_date;
               ELSE
                    v_vertragsheader_rec.naechste_sollstellung   := nvl(g_next_installement_dt,v_next_inst_date);
               END IF;
         END IF;

        v_fn_ret := FN_CALC_REST_EXT_DURATION(v_cntr_other_info.berites,v_cntr_other_info.prmsbl_pymt_modes_cd,v_cntr_other_info.first_instlmnt_dt,v_cntr_other_info.ende_grundlaufzeit,v_cntr_other_info.ende_verlaengerung);

        v_vertragsheader_rec.vende_grundlaufzeit    := v_cntr_other_info.ende_grundlaufzeit;
        v_vertragsheader_rec.vende_verlaengerung    := v_cntr_other_info.ende_verlaengerung;
        v_vertragsheader_rec.vertragstyp            := FN_GET_TRIGONIS_PDF_TYP(v_curr_contract_rec.comp_num,v_curr_contract_rec.ms_pdt_name,v_curr_contract_rec.elmntry_pdt_name);
        v_vertragsheader_rec.vertragstyp_erweitert  := v_curr_contract_rec.elmntry_pdt_name;
        v_vertragsheader_rec.vertragsart            := 'DIREKT';  
      /*---------------------------------------------*/
      /* Geting value for  v_intern_kalkuzins        */
      /*---------------------------------------------*/
        IF(v_vertragsheader_rec.vertragstyp = 'MIETKAUF')
        THEN
--             v_vertragsheader_rec.intern_kalkuzins := v_cntr_other_info.refin_int_rate; 
               v_vertragsheader_rec.intern_kalkuzins := v_curr_contract_rec.intrnl_rate_rtn; 
        ELSE
               v_vertragsheader_rec.intern_kalkuzins := null;
        END IF;

      /*---------------------------------------------*/
      /* Geting value for  v_refi_kalkuzins          */
      /*---------------------------------------------*/
         v_vertragsheader_rec.refi_kalkuzins  := NVL (v_curr_contract_rec.refin_int_rate, 0);
         -- fix for the defect 17770
         IF(v_vertragsheader_rec.refi_kalkuzins = 0)
         THEN
            v_vertragsheader_rec.refi_kalkuzins := 
               ROUND(
                     NVL(
                        PKG_EGMNT_CALC_ROUTINES.FUNC_GET_INT_RATE_CTYPE_NPO
                        (
                           v_comp_prtnr_id_01,
                           nvl(v_curr_contract_rec.actv_dt,v_curr_contract_rec.lease_bgn_dt),
                           v_curr_contract_rec.cntrct_durtn,
                           v_cntr_other_info.rsdl_value_org, 
                           v_cntr_other_info.acqstn_value
                        ),
                    0)
               ,3);
         END IF;
      /*---------------------------------------------*/
      /* Geting value for  v_geschaeftsfeld          */
      /*---------------------------------------------*/
        v_vertragsheader_rec.geschaeftsfeld  := v_cntr_other_info.bus_seg_cd_sh_nm || v_cntr_other_info.segcd_sh_nm;

      /*---------------------------------------------*/
      /* Geting value for  v_zahlungsweise           */
      /*---------------------------------------------*/
      IF nvl(v_curr_contract_rec.bank_coll_flg,'N') = 'N'
      THEN                                                           --{
         v_vertragsheader_rec.zahlungsweise := 'SELBSTZAHLER';
      ELSE                                                          --}{
         v_vertragsheader_rec.zahlungsweise := 'LASTSCHRIFT';
      END IF;                                                        --}

      /*---------------------------------------------*/
      /* Geting value for  v_mahnstufe               */
      /*---------------------------------------------*/
      
      IF nvl(v_curr_contract_rec.dub_flg,'N') = 'N'
      THEN
         v_vertragsheader_rec.mahnstufe   := 0;
      ELSE
         v_vertragsheader_rec.mahnstufe   := 9;
      END IF;

      /*---------------------------------------------*/
      /* Geting value for  v_rechenart_mk            */
      /*---------------------------------------------*/
         v_vertragsheader_rec.rechenart_mk := 'VORSCHUESSIG';
      /*---------------------------------------------*/
      /* Geting value for  v_status                  */
      /*---------------------------------------------*/
        v_vertragsheader_rec.status  := 'AKTIV';
      /*---------------------------------------------*/
      /* Geting value for  v_betrag                  */
      /*---------------------------------------------*/
        v_vertragsheader_rec.anschaffungswert   := NVL (v_cntr_other_info.acqstn_value, 0);
/*        
        v_vertragsheader_rec.zugangsdatum   - will be set by tll

*/
       /* ------ Element Vertragsheader over          */
   EXCEPTION
	WHEN OTHERS 
	THEN
		Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999','PROC_CREATE_VETRAGHEADER:CONTRCT_NUM=>'||v_curr_contract_rec.cntrct_num || ' Subseg Code '|| v_curr_contract_rec.subseg_cd, SQLERRM);
		RAISE v_fatal_excp;
   END PROC_CREATE_VETRAGHEADER ;


   PROCEDURE PROC_GET_PRAP_ACCR_AMT (p_cntr_other_info IN OUT contract_other_info_typ) IS

      v_fincl_accrl_amt             UC_ACCRL_COLTR_MS.FINCL_ACCRL_AMT%TYPE;
      v_linear_accrl_amt            UC_ACCRL_COLTR_MS.LINEAR_ACCRL_AMT%TYPE;
      v_fincl_accrl_amt_npo         UC_ACCRL_COLTR_MS.FINCL_ACCRL_AMT%TYPE;
      v_linear_accrl_amt_npo        UC_ACCRL_COLTR_MS.LINEAR_ACCRL_AMT%TYPE;

      v_accr_max_cntrct_durtn       UC_SUB_SEGMENT_MS.MAX_CNTRCT_DURTN%TYPE;
      v_outs_linear_amt             v_typ_linear_amt ;
      v_outs_fin_amt                v_typ_linear_amt ;
      v_accrl_obj                   v_typ_accrl_obj;
      v_accrl_durtn                 v_typ_accrl_durtn;
      v_mk_accr_obj_found_200       boolean;
      v_accrl_not_found_flg         NUMBER;
      rw_ende_aufloesungszeit       date;

   BEGIN
      v_linear_accrl_amt := 0; 
      v_fincl_accrl_amt := 0;
      --v_linear_accrl_amt_100 := 0; 
      v_accr_max_cntrct_durtn := 0;
v_linear_accrl_amt_npo := 0;
v_linear_accrl_amt_npo := 0;
      v_outs_linear_amt.delete;
      v_outs_fin_amt.delete;
      v_accrl_durtn.delete;
      v_accrl_obj.delete;

         -- Added mk accural object to close defect 16619
      IF(v_curr_contract_rec.ms_pdt_name = 'MK')
      THEN
               BEGIN
                  SELECT 
                     FINCL_ACCRL_AMT,
                     FINCL_ACCRL_AMT,
                     ACCRL_DURTN
                     INTO
                     v_linear_accrl_amt ,
                     v_fincl_accrl_amt	,
                     v_accr_max_cntrct_durtn 
                  FROM UC_ACCRUAL_RPT_TRGNS_TP
                  WHERE accrl_key = v_curr_contract_rec.SUBSEG_CD
                  AND ACCRL_OBJ = 'MK';


                  v_mk_accr_obj_found_200  := true;

                  BEGIN
                        SELECT  last_accr_relse_dt 
                        INTO rw_ende_aufloesungszeit
                        FROM UC_ACCRUAL_RPT_TRGNS_TP
                        WHERE accrl_key = v_curr_contract_rec.SUBSEG_CD
                        AND ACCRL_OBJ = 'MKMAX';
                  EXCEPTION
                  WHEN OTHERS
                  THEN
                        NULL;
                  END;
               EXCEPTION
               WHEN NO_DATA_FOUND
               THEN
                  BEGIN
                        v_mk_accr_obj_found_200  := false;
                        SELECT 
                              linear_outstdng_prncpl_amt,
                              linear_outstdng_prncpl_amt,
                              accrl_durtn
                        INTO
                              v_linear_accrl_amt ,
                              v_fincl_accrl_amt	,
                              v_accr_max_cntrct_durtn 
                        FROM UC_ACCRUAL_RPT_TRGNS_TP
                        WHERE accrl_key = v_cntr_other_info.pkt_cd
                        AND ACCRL_OBJ = 'MK_Verwk';

                     BEGIN
                           SELECT  last_accr_relse_dt 
                           INTO rw_ende_aufloesungszeit
                           FROM UC_ACCRUAL_RPT_TRGNS_TP
                           WHERE accrl_key = v_cntr_other_info.pkt_cd
                           AND ACCRL_OBJ = 'MK_VerwkMAX';
                     EXCEPTION
                     WHEN OTHERS
                     THEN
                           NULL;
                     END;
                  EXCEPTION
                  WHEN OTHERS
                  THEN
                              v_linear_accrl_amt := 0;
                              v_fincl_accrl_amt	:= 0;
                              v_accr_max_cntrct_durtn := 0;
                              rw_ende_aufloesungszeit := null;
                  END;

               END;
      ELSE -- Otherthan mk product
            -- Following query is modified to consider the RAP_NPO. 
            -- This is added to the Accrl_Amt calculated.
            -- Defect 14033 (CR)
            BEGIN
               SELECT linear_outstdng_prncpl_amt,
                  fincl_outstdng_prncpl_amt,
                  accrl_durtn,
                  accrl_obj
               BULK COLLECT INTO
                  v_outs_linear_amt ,
                  v_outs_fin_amt	,
                  v_accrl_durtn ,
                  v_accrl_obj
               FROM UC_ACCRUAL_RPT_TRGNS_TP
               WHERE accrl_key = v_cntr_other_info.pkt_cd
               AND (ACCRL_OBJ = 'PRAP_FVK'
               OR  ACCRL_OBJ = 'RAP_Zi'
               OR  ACCRL_OBJ = 'RAP_NPO');

               FOR M IN  1..v_accrl_obj.COUNT
               LOOP
                  IF(v_accrl_obj(M) = 'PRAP_FVK')
                  THEN
                     v_linear_accrl_amt := v_linear_accrl_amt + v_outs_linear_amt (M);
                     v_fincl_accrl_amt := v_fincl_accrl_amt + v_outs_fin_amt(M);
                     v_accr_max_cntrct_durtn := v_accrl_durtn(M);
                  ELSIF(v_accrl_obj(M) = 'RAP_Zi')
                  THEN
                     v_linear_accrl_amt  := v_linear_accrl_amt  - v_outs_linear_amt(M);
                     v_fincl_accrl_amt   := v_fincl_accrl_amt - v_outs_fin_amt(M);
                  ELSIF(v_accrl_obj(M) = 'RAP_NPO')
                  THEN
                     v_linear_accrl_amt_npo := v_linear_accrl_amt_npo + v_outs_fin_amt (M);
                     v_fincl_accrl_amt_npo := v_fincl_accrl_amt_npo  + v_outs_fin_amt(M);
                  END IF;
/*                    Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',v_cntr_other_info.pkt_cd||'v_outs_fin_amt (M)=>'||v_accrl_obj(M)||v_outs_fin_amt (M),'', '');                
        Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','v_outs_linear_amt(M)=>'||v_outs_linear_amt (M),'', '');                
        Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','v_linear_accrl_amt_npo(M)=>'||v_linear_accrl_amt_npo,'', '');                
        Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','v_fincl_accrl_amt_npo(M)=>'||v_fincl_accrl_amt_npo,'', '');                
*/


               END LOOP;

               -- Following Query has been modified for solving the Defect 14033 - Reopend 06-Jul-2006
               -- NPO value can be had only from FINCL_ACCRL_AMT, irrespective of being Linear or Non-Linear

               v_accrl_not_found_flg := 0;

               IF(v_accrl_obj.COUNT = 0)
               THEN

                   v_accrl_not_found_flg := 1;

                   SELECT SUM(DECODE(ACCRL_OBJ ,'PRAP_FVK',LINEAR_ACCRL_AMT,0) -  DECODE(ACCRL_OBJ ,'RAP_Zi',LINEAR_ACCRL_AMT,0)), -- + DECODE(ACCRL_OBJ ,'RAP_NPO',FINCL_ACCRL_AMT,0)),
                              SUM(DECODE(ACCRL_OBJ ,'PRAP_FVK',FINCL_ACCRL_AMT,0) - DECODE(ACCRL_OBJ ,'RAP_Zi',FINCL_ACCRL_AMT,0) ), --+ DECODE(ACCRL_OBJ ,'RAP_NPO',FINCL_ACCRL_AMT,0) ),
                              NVL(MIN(ACCRL_DURTN),0)
                   INTO v_linear_accrl_amt,
                        v_fincl_accrl_amt,
                        v_accr_max_cntrct_durtn
                   FROM UC_ACCRL_COLTR_MS
                   WHERE PKT_CD = v_cntr_other_info.pkt_cd
                   AND RELSE_FRM_DT > v_stichtag_date
                   AND (ACCRL_OBJ = 'PRAP_FVK'
                   OR  ACCRL_OBJ = 'RAP_Zi') --							 OR  ACCRL_OBJ = 'RAP_NPO')
                   AND TRNSCTN_TYP = '200'
                   AND CANCL_FLG IS NULL; 
               END IF;

                BEGIN
                        SELECT  last_accr_relse_dt 
                        INTO rw_ende_aufloesungszeit
                        FROM UC_ACCRUAL_RPT_TRGNS_TP
                        WHERE accrl_key = v_cntr_other_info.pkt_cd
                        AND ACCRL_OBJ = 'PRAP_FVKMAX';
                EXCEPTION
                WHEN OTHERS
                THEN
                        rw_ende_aufloesungszeit:=NULL;
                END;

            EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                SELECT SUM(DECODE(ACCRL_OBJ ,'PRAP_FVK',LINEAR_ACCRL_AMT,0) -  DECODE(ACCRL_OBJ ,'RAP_Zi',LINEAR_ACCRL_AMT,0)),-- + DECODE(ACCRL_OBJ ,'RAP_NPO',FINCL_ACCRL_AMT,0)),
                  SUM(DECODE(ACCRL_OBJ ,'PRAP_FVK',FINCL_ACCRL_AMT,0) - DECODE(ACCRL_OBJ ,'RAP_Zi',FINCL_ACCRL_AMT,0) ),--+ DECODE(ACCRL_OBJ ,'RAP_NPO',FINCL_ACCRL_AMT,0) ),
                  NVL(MIN(ACCRL_DURTN),0),max(relse_frm_dt)
                INTO v_linear_accrl_amt,
                     v_fincl_accrl_amt,
                     v_accr_max_cntrct_durtn,
                     rw_ende_aufloesungszeit
                FROM UC_ACCRL_COLTR_MS
                WHERE PKT_CD = v_cntr_other_info.pkt_cd
                AND RELSE_FRM_DT > v_stichtag_date
                AND (ACCRL_OBJ = 'PRAP_FVK'
                OR  ACCRL_OBJ = 'RAP_Zi') 
                AND TRNSCTN_TYP = '200'
                AND CANCL_FLG IS NULL; 
            END;
      END IF; -- End of MK product check


      p_cntr_other_info.fincl_accrl_amt         :=v_fincl_accrl_amt    ;
      p_cntr_other_info.linear_accrl_amt        := v_linear_accrl_amt   ;
      p_cntr_other_info.fincl_accrl_amt_npo         := v_linear_accrl_amt_npo   ;
      p_cntr_other_info.linear_accrl_amt_npo        := v_linear_accrl_amt_npo   ;
      
     -- Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Processing Started for the CONTRACT ==>'||v_fincl_accrl_amt_npo,'', '');                
      --Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Processing Started for the CONTRACT ==>'||v_linear_accrl_amt_npo,'', '');                

      p_cntr_other_info.accr_max_cntrct_durtn   := v_accr_max_cntrct_durtn ;
      p_cntr_other_info.ende_aufloesungszeit    := rw_ende_aufloesungszeit;
   END PROC_GET_PRAP_ACCR_AMT;


   PROCEDURE PROC_CREATE_REFI_MIETEN IS

   l_lgs_refin_typ      uc_refin_codes_ms.refin_cd%type;
   l_refin_typ      uc_refin_codes_ms.refin_cd%type;
   l_rate_explizit      rate_explizit_tab;
   l_refi_rec           refi_mieten_typ;
   l_refi_rw_rec        refi_mieten_typ;
   l_cntr_other_info    contract_other_info_typ;
   l_npo_cnt            NUMBER;
   v_Accrl_Amt_Flg      NUMBER(2);
   v_diff_mon           NUMBER(10);
   v_rate_index         BINARY_INTEGER := 1;
   BEGIN
      /*             REFINANCING CALCULATION             */
        l_lgs_refin_typ := v_cntr_other_info.lgs_refin_typ_desc;

--         IF ( ((p_Stichtag_Date < lv_prim_durtn_end_dt) OR (v_refinanzierungsart != 0)) 
   ---         ( v_cntr_other_info.trnsfr_num IS NOT NULL ) AND ( v_Accrl_Amt_Flg = 1) )THEN --{
---IF ((v_refinanzierungsart = 1) OR (v_refinanzierungsart = 5)) THEN --{
         
         v_refi_mieten_rec     := null;
         v_refi_mieten_rw_rec  := null;
         v_refi_rw_rec         := null;
         v_refi_mieten_rec.createRefinMeiten     := FALSE;
         v_refi_mieten_rw_rec.createRefinMeiten  := FALSE;
         v_refi_rw_rec.createRefinMeiten         := FALSE;
         v_Accrl_Amt_Flg := 0;
      
         IF (v_curr_contract_rec.comp_num IN (5,83,599) AND v_cntr_other_info.trnsfr_num IS NOT NULL AND l_lgs_refin_typ IN ('F', 'G'))
         THEN
                  PROC_GET_PRAP_ACCR_AMT(v_cntr_other_info);

                  IF(v_vertragsheader_rec.ratenstruktur = 'LINEAR')
                  THEN --{
                        IF ( v_cntr_other_info.linear_accrl_amt > 0 ) THEN 
                           v_Accrl_Amt_Flg := 1;
                        END IF;
                  ELSE --}{
                        IF ( v_cntr_other_info.fincl_accrl_amt > 0 ) THEN 
                           v_Accrl_Amt_Flg := 1;
                        END IF;
                  END IF; --}

                ---Setting up value for refi_mieten and refi_mieten_rw - ie GMZ
                  IF(v_cntr_other_info.refin_typ is NOT NULL AND v_Accrl_Amt_Flg = 1 ) -- If GMZ refin sub  is present 
                  THEN
                           BEGIN
                                 SELECT refin_cd
                                 INTO l_refin_typ
                                 FROM uc_refin_codes_ms
                                 WHERE refin_codes_cd = v_cntr_other_info.refin_typ;
                           EXCEPTION
                           WHEN NO_DATA_FOUND
                           THEN
                              L_REFIN_TYP := NULL;
                           END;
                           
                           l_refi_rec.createRefinMeiten     := TRUE;
                           l_refi_rec.barwert_betrag        := v_cntr_other_info.stlmnt_sales_price;      

                           IF(v_vertragsheader_rec.ratenstruktur = 'LINEAR')
                           THEN
                              l_refi_rec.rap_hgb_betrag     :=   v_cntr_other_info.linear_accrl_amt;
                              l_refi_rec.aufloesungsart     := 'LINEAR';
                           ELSE
                              l_refi_rec.rap_hgb_betrag     :=   v_cntr_other_info.fincl_accrl_amt;
                              l_refi_rec.aufloesungsart     := 'FINANZMATHEMATISCH';
                           END IF;
                        --Defect 18010 - repayment start date from bbilanz_ms --- FC134 STARTDT ta 
                     /*      IF(v_curr_contract_rec.comp_num = 599)
                           THEN
                              l_refi_rec.aufloesung_beginn := ADD_MONTHS(v_cntr_other_info.refin_start_dt,1); 
                           ELSE
                              l_refi_rec.aufloesung_beginn := v_cntr_other_info.refin_start_dt;
                           END IF; */

                           l_refi_rec.aufloesung_beginn := v_cntr_other_info.REPYMT_START_DT;

                           l_refi_rec.aufloesung_prap_auf_null := 'no';

                           IF(l_refi_rec.aufloesung_beginn = last_day(l_refi_rec.aufloesung_beginn))
                           THEN
                              l_refi_rec.aufloesung_beginn  :=   l_refi_rec.aufloesung_beginn + 1;
                           END IF;

                           l_refi_rec.aufloesung_ende  :=   v_curr_contract_rec.lease_end_dt;
                           l_refi_rec.zins             :=   v_cntr_other_info.stlmnt_int_rate;
                           l_refi_rec.faelligkeit_barwert := nvl(v_cntr_other_info.sale_dt,l_refi_rec.aufloesung_beginn);

                           IF l_refin_typ IN (95, 98, 99, 97, 94)
                           THEN
                                 l_refi_rec.refityp := 'FORDERUNGSVERKAUF';
                           ELSE
                                 l_refi_rec.refityp := 'DARLEHEN';
                           END IF;


                           l_refi_rec.ende_aufloesungszeit := v_cntr_other_info.ende_aufloesungszeit;

                           l_refi_rec.rechenart           :=     'VORSCHUESSIG';

                           /*---------------------------------------------------------*/
                           /* Geting values for set of elements ( v_rate_exp_str )    */
                           /*---------------------------------------------------------*/
                           BEGIN
                              v_rate_index  := 1;
                              
                              l_rate_explizit.delete;

                              FOR J  IN v_cur_lease_rntl_tab.FIRST..v_cur_lease_rntl_tab.LAST
                              LOOP
                                 v_diff_mon := MONTHS_BETWEEN(v_cur_lease_rntl_tab(J).to_dt,v_cur_lease_rntl_tab(J).frm_dt);
                                 IF(
                                    (v_cur_lease_rntl_tab(J).frm_dt <= l_refi_rec.aufloesung_ende 
                                     AND v_cur_lease_rntl_tab(J).to_dt <= l_refi_rec.aufloesung_ende)
                                  AND (v_diff_mon < 800)
                                  )
                                 THEN
                                    IF(v_cur_lease_rntl_tab(J).frm_dt < l_refi_rec.aufloesung_beginn)
                                    THEN
                                       l_rate_explizit(v_rate_index).faellig_ab    := l_refi_rec.aufloesung_beginn;
                                    ELSE
                                       l_rate_explizit(v_rate_index).faellig_ab    := v_cur_lease_rntl_tab(J).frm_dt;
                                    END IF;
                                    l_rate_explizit(v_rate_index).betrag        := v_cur_lease_rntl_tab(J).end_rate_amt;
                                    l_rate_explizit(v_rate_index).gueltig_bis   := v_cur_lease_rntl_tab(J).to_dt;
                                    l_rate_explizit(v_rate_index).ratenabstand  := v_cur_lease_rntl_tab(J).pymt_md;
                                    v_rate_index := v_rate_index + 1;

                                 -- Defect 18010 Based on the discussion with Mr.Michael Bosselmann, 888 period payment plan entry will not considered for refinancing payment plan (ratenplan_explizit)
                                /*
                                 ELSIF(v_diff_mon > 800)
                                 THEN
                                    IF(v_cur_lease_rntl_tab(J).frm_dt <= l_refi_rec.aufloesung_ende )
                                    THEN
                                            IF(v_cur_lease_rntl_tab(J).frm_dt < l_refi_rec.aufloesung_beginn)
                                            THEN
                                               l_rate_explizit(v_rate_index).faellig_ab    := l_refi_rec.aufloesung_beginn;
                                            ELSE
                                               l_rate_explizit(v_rate_index).faellig_ab    := v_cur_lease_rntl_tab(J).frm_dt;
                                            END IF;
                                            l_rate_explizit(v_rate_index).betrag        := v_cur_lease_rntl_tab(J).end_rate_amt;
                                            l_rate_explizit(v_rate_index).gueltig_bis   := l_refi_rec.aufloesung_ende;
                                            l_rate_explizit(v_rate_index).ratenabstand  := v_cur_lease_rntl_tab(J).pymt_md;
                                            v_rate_index := v_rate_index + 1;
                                   END IF;
                                 */
                                 END IF;
                              END LOOP;
                           EXCEPTION
                              WHEN OTHERS
                              THEN
                                 pkg_batch_logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999','v_rate_exp_str'|| ','|| v_curr_contract_rec.subseg_cd,SQLERRM);
                                 raise v_fatal_excp;
                           END;
                           l_refi_rec.rate_explizit := l_rate_explizit;

                           -- Check whether residual value is present or not
                           IF(v_curr_contract_rec.comp_num  = 599 ) 
                           THEN
                                 -- Defect 17985 condition added berites equal to 'N' residual value is not valid in extension period
                                 IF(nvl(v_cntr_other_info.rsdl_value,0) > 0 AND v_cntr_other_info.berites='N') -- create refi_mieten_rw
                                 THEN
                                    v_refi_mieten_rw_rec := l_refi_rec;
                                    v_refi_mieten_rw_rec.restwert_refi_betrag   :=v_cntr_other_info.rsdl_value ;
                                 ELSE -- Residual Value Check < 0 create reif_meiten record 
                                    v_refi_mieten_rec := l_refi_rec;
                             /*  
                               Defect 17985 Extension period: "Belegdatum" of last row with "Bewegungsart"=200 of corresponding accrual table
                                  ==> attribute "refi_mieten/@aufloesung_ende"
                              */
                                    v_refi_mieten_rec.aufloesung_ende := v_cntr_other_info.ende_aufloesungszeit;
                                 END IF;-- Residual Value Check 
                           ELSE -- company check
                                v_refi_mieten_rec := l_refi_rec;
                               --Create refi_mieten record
                               l_npo_cnt := 0;
                               --check for npo refin sub type to create refi_rw
                               BEGIN                                                          --{
                                    SELECT c.refin_cd, a.prchse_comp_cd, a.refin_typ,
                                        NVL (a.stlmnt_int_rate, 0),
                                        DECODE (NVL (a.refin_int_rate, 0), 0, v_curr_contract_rec.refin_int_rate),
                                        NVL (a.stlmnt_sales_price, sales_price),
                                        a.refin_start_dt,                            --- nvl function added
                                        a.sale_dt,                            --- nvl function added
                                        a.trnsfr_num, f.comp_num, g.prtnr_num,
                                        g.cr_worth, a.pkt_cd,a.num_of_sold_mon,rownum
                                    INTO l_cntr_other_info.refin_cd, l_cntr_other_info.prchse_comp_cd, l_cntr_other_info.refin_typ,
                                        l_cntr_other_info.stlmnt_int_rate,
                                        l_cntr_other_info.refin_int_rate,
                                        l_cntr_other_info.stlmnt_sales_price,
                                        l_cntr_other_info.refin_start_dt,
                                        l_cntr_other_info.sale_dt,
                                        l_cntr_other_info.trnsfr_num, l_cntr_other_info.prchse_comp_num, l_cntr_other_info.refin_prtnr_num,
                                        l_cntr_other_info.cr_worth, l_cntr_other_info.pkt_cd,l_cntr_other_info.num_of_sold_mon,l_npo_cnt
                                    FROM uc_refin_ms a,
                                        uc_refin_codes_ms c,
                                        uc_company_ms f,
                                        uc_partner_ms g
                                    WHERE a.subseg_cd = v_curr_contract_rec.subseg_cd
                                    AND c.refin_codes_cd = a.refin_typ
                                    AND f.prtnr_id = a.prchse_comp_cd
                                    AND g.prtnr_id = a.prtnr_id
                                    AND a.refin_sub_typ = 'NPO'
                                    AND a.fin_early_trmntd_flg = 'N';
                              EXCEPTION
                              WHEN NO_DATA_FOUND
                              THEN
                              BEGIN
                                    -- Added fin_early_trmntd_flg condition to fetch future dated terminated contracts.
                                 SELECT c.refin_cd, a.prchse_comp_cd, a.refin_typ,
                                        NVL (a.stlmnt_int_rate, 0),
                                        DECODE (NVL (a.refin_int_rate, 0), 0, v_curr_contract_rec.refin_int_rate),
                                        NVL (a.stlmnt_sales_price, sales_price),
                                        a.refin_start_dt,                            --- nvl function added
                                        a.sale_dt,                            --- nvl function added
                                        a.trnsfr_num, f.comp_num, g.prtnr_num,
                                        g.cr_worth, a.pkt_cd,a.num_of_sold_mon,rownum
                                    INTO l_cntr_other_info.refin_cd, l_cntr_other_info.prchse_comp_cd, l_cntr_other_info.refin_typ,
                                        l_cntr_other_info.stlmnt_int_rate,
                                        l_cntr_other_info.refin_int_rate,
                                        l_cntr_other_info.stlmnt_sales_price,
                                        l_cntr_other_info.refin_start_dt,
                                        l_cntr_other_info.sale_dt,
                                        l_cntr_other_info.trnsfr_num, l_cntr_other_info.prchse_comp_num, l_cntr_other_info.refin_prtnr_num,
                                        l_cntr_other_info.cr_worth, l_cntr_other_info.pkt_cd,l_cntr_other_info.num_of_sold_mon,l_npo_cnt
                                      FROM uc_refin_ms a,
                                           uc_refin_codes_ms c,
                                           uc_company_ms f,
                                           uc_partner_ms g
                                     WHERE a.subseg_cd = v_curr_contract_rec.subseg_cd
                                       AND c.refin_codes_cd = a.refin_typ
                                       AND f.prtnr_id = a.prchse_comp_cd
                                       AND g.prtnr_id = a.prtnr_id
                                       AND a.refin_sub_typ = 'NPO'
                                       AND a.fin_early_trmntd_flg = 'T'
                                       AND ROWNUM < 2;
                                 EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                       l_npo_cnt := 0;
                                       l_cntr_other_info.refin_cd := NULL;
                                       l_cntr_other_info.prchse_comp_cd := NULL;
                                       l_cntr_other_info.refin_typ := NULL;
                                       l_cntr_other_info.stlmnt_int_rate := v_curr_contract_rec.refin_int_rate;
                                       l_cntr_other_info.refin_int_rate := v_curr_contract_rec.refin_int_rate;
                                       l_cntr_other_info.stlmnt_sales_price := 0;
                                       l_cntr_other_info.sale_dt := v_curr_contract_rec.cntrct_start_dt;
                                       l_cntr_other_info.trnsfr_num := NULL;
                                       l_cntr_other_info.prchse_comp_num := NULL;
                                       l_cntr_other_info.refin_prtnr_num := NULL;
                                       l_cntr_other_info.cr_worth := 'Alle';
                                    WHEN TOO_MANY_ROWS
                                    THEN
                                       pkg_batch_logger.proc_log (lf_file_handle,'ERROR','BAT_E_0091',v_curr_contract_rec.subseg_cd,'REFIN_CD');
                                       RAISE v_skip_record;
                              END;
                              WHEN TOO_MANY_ROWS
                              THEN
                                 pkg_batch_logger.proc_log (lf_file_handle,'ERROR','BAT_E_0091',v_curr_contract_rec.subseg_cd,'REFIN_CD');
                                 RAISE v_skip_record;
                              WHEN OTHERS
                              THEN
                                 pkg_batch_logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',SQLCODE || SQLERRM || 'REFIN_CD',v_curr_contract_rec.subseg_cd);
                                 RAISE v_skip_record;
                              END;     
                              IF(nvl(l_npo_cnt,0) > 0) --if NPO record is present,create refi_rw
                              THEN 
                                 BEGIN
                                       SELECT refin_cd
                                       INTO l_refin_typ
                                       FROM uc_refin_codes_ms
                                       WHERE refin_codes_cd = l_cntr_other_info.refin_typ;
                                 EXCEPTION
                                 WHEN NO_DATA_FOUND
                                 THEN
                                    l_refin_typ := NULL;
                                 END;
                                 --PROC_GET_PRAP_ACCR_AMT(l_cntr_other_info);
                                 l_refi_rw_rec.createRefinMeiten     := TRUE;
                                 l_refi_rw_rec.barwert_betrag        := l_cntr_other_info.stlmnt_sales_price;      

                                 IF(v_vertragsheader_rec.ratenstruktur = 'LINEAR')
                                 THEN
                                    l_refi_rw_rec.rap_hgb_betrag     :=   v_cntr_other_info.linear_accrl_amt_npo;
                                 ELSE
                                    l_refi_rw_rec.rap_hgb_betrag     :=   v_cntr_other_info.linear_accrl_amt_npo;
                                 END IF;
                                 l_refi_rw_rec.aufloesungsart     := 'FINANZMATHEMATISCH'; --If refi type is DARLEHEN ,then change aufloesungsart to finanzmathematisch

                                 IF(v_curr_contract_rec.comp_num = 599)
                                 THEN
                                    l_refi_rw_rec.aufloesung_beginn := TRUNC(ADD_MONTHS(l_cntr_other_info.refin_start_dt,1),'MONTH'); 
                                 ELSE
                                    l_refi_rw_rec.aufloesung_beginn := l_cntr_other_info.refin_start_dt;
                                 END IF;
                                 l_refi_rw_rec.aufloesung_prap_auf_null := 'no';

                                 IF(l_refi_rw_rec.aufloesung_beginn = last_day(l_refi_rw_rec.aufloesung_beginn))
                                 THEN
                                    l_refi_rw_rec.aufloesung_beginn  :=   l_refi_rw_rec.aufloesung_beginn + 1;
                                 END IF;

                                 l_refi_rw_rec.aufloesung_ende  :=   v_curr_contract_rec.lease_end_dt;
                                 l_refi_rw_rec.zins             :=   l_cntr_other_info.stlmnt_int_rate;
                                 l_refi_rw_rec.faelligkeit_barwert := nvl(l_cntr_other_info.sale_dt,l_refi_rw_rec.aufloesung_beginn);

                                 IF l_refin_typ IN (95, 98, 99, 97, 94)
                                 THEN
                                       l_refi_rw_rec.refityp := 'FORDERUNGSVERKAUF';
                                 ELSE
                                       l_refi_rw_rec.refityp := 'DARLEHEN';
                                 END IF;

                                 l_refi_rw_rec.ende_aufloesungszeit := v_cntr_other_info.ende_aufloesungszeit;
                  
                  
                                 l_refi_rw_rec.restwert_refi_betrag   :=v_cntr_other_info.rsdl_value ;
                                 l_refi_rw_rec.rechenart           :=     'VORSCHUESSIG';
                                 v_refi_rw_rec := l_refi_rw_rec;
                              END IF; -- End of NPO Check

                        END IF; -- 599 Company check
                  END IF;  /** GMZ Present */
              END IF;/** End of 599,5 and 83 check */
   END PROC_CREATE_REFI_MIETEN;


   PROCEDURE PROC_START_TRGN_PROCESS  IS
   
   
   BEGIN
      FOR I IN v_cur_contract_tab.FIRST..v_cur_contract_tab.LAST
      LOOP
      BEGIN
            v_curr_contract_rec := null;
            v_curr_contract_rec := v_cur_contract_tab(I);
            Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Processing Started for the CONTRACT ==>'||v_curr_contract_rec.cntrct_num,'', '');                

            IF v_curr_comp_no <> v_curr_contract_rec.comp_num
            THEN
               Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','INSIDE COMPANY '||v_curr_contract_rec.cntrct_num,'', '');                
               IF UTL_FILE.is_open (v_contract_fp)
               THEN
                  UTL_FILE.fclose (v_contract_fp);
               END IF;
               
               Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Processing Started for the company ==>'||v_curr_contract_rec.comp_num,'', '');                

               v_curr_contract_file := 'BUCS'|| TO_CHAR (v_stichtag_date, 'YYMM')|| LPAD (v_curr_contract_rec.comp_num, 3, 0)|| '.xml';
               v_contract_fp        := UTL_FILE.fopen ('OUTGOING_DIR', v_curr_contract_file, 'W', 32767);
               v_contract_filecnt   := v_contract_filecnt + 1;
               v_contract_filenames(v_contract_filecnt) := v_curr_contract_file;
               UTL_FILE.put_line (v_filelist_fp, v_curr_contract_file,TRUE);               
               v_curr_comp_no := v_curr_contract_rec.comp_num;
               v_new_comp := TRUE;
            END IF;         
                      
            PROC_CREATE_VETRAGHEADER;
            
            PROC_CREATE_MIETKAUFVERMOGEN;

            PROC_CREATE_MSZ;

            PROC_CREATE_RESTWERT;

            PROC_VERWALTUNGS_RISK_KOSTEN  (v_curr_contract_rec.actv_dt,
                         v_curr_contract_rec.subseg_cd,
                         v_curr_contract_rec.cntrct_way,
                         v_curr_contract_rec.refin_typ,
                         v_curr_contract_rec.lgs_refin_typ,
                         v_curr_contract_rec.distrib_chnl_cd,
                         v_curr_contract_rec.bus_seg_cd,
                         v_cntr_other_info.cr_worth,
                         v_curr_contract_rec.lease_end_dt,
                         v_cntr_other_info.first_instlmnt_dt,
                         v_curr_contract_rec.cntrct_end_dt,
                         v_curr_contract_rec.cntrct_stat_num,
                         v_curr_contract_rec.elmntry_pdt_cd,
                         v_curr_contract_rec.ms_pdt_id,
                         v_curr_contract_rec.comp_prtnr_id,
                         v_curr_contract_rec.prtnr_id,
                         v_cntr_other_info.supplier,
                         v_cntr_other_info.acqstn_value,
                         v_curr_contract_rec.cntrct_durtn,
                         v_curr_contract_rec.comp_num,
                         v_curr_contract_rec.subseg_num,
                         v_cntr_other_info.districhnl_sh_nm,
                         v_cntr_other_info.districhnl_name,
                         v_curr_contract_rec.ms_pdt_name,
                         v_curr_contract_rec.elmntry_pdt_name,
                         g_inp_calc_fact_book_dt_flg,
                         g_inp_calc_fact_dt,
                         v_cntr_other_info.berites
            );
            
            PROC_CREATE_NUTZUNGSENTGELT;

            PROC_CREATE_ZAHLUNGSPLAN;

            PROC_CREATE_CONTR_FINAL_XML;
           
            --Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Fianl finished ==>'||RESULT,'', '');                

            UTL_FILE.put_line (v_contract_fp, RESULT);
            UTL_FILE.put_line (v_contract_fp, '<!-- EndOfRecord -->');
            UTL_FILE.fflush (v_contract_fp);
            RESULT             := null;
            
            PROC_CREATE_REFI_MIETEN;
            PROC_CREATE_REFI_XML(v_new_comp);
            refin_result             := null;
       EXCEPTION
       WHEN v_skip_record
       THEN
            v_skip_cnt := v_skip_cnt + 1;
        WHEN OTHERS
        THEN
          DBMS_OUTPUT.put_line ('error1544:' || SQLERRM);
          RESULT := null;
          refin_result             := null;
          pkg_batch_logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',SQLCODE,SQLERRM);
       END;
       END LOOP;
   END PROC_START_TRGN_PROCESS;


   PROCEDURE main_proc (
      stichtag_date               IN       Date,
      inp_calc_fact_book_dt_flg   IN       VARCHAR2,
      inp_calc_fact_dt            IN       DATE,
      inp_version                 IN       VARCHAR2,
      inp_extn_period             IN       VARCHAR2,
      inp_extn_period_lsva_jz     IN       VARCHAR2,
      inp_extn_period_lsva_hz     IN       VARCHAR2,
      inp_extn_period_lsva_qz     IN       VARCHAR2,
      inp_extn_period_lsva_mz     IN       VARCHAR2,
      inp_extn_period_lsta_jz     IN       VARCHAR2,
      inp_extn_period_lsta_hz     IN       VARCHAR2,
      inp_extn_period_lsta_qz     IN       VARCHAR2,
      inp_extn_period_lsta_mz     IN       VARCHAR2,
      inp_extn_period_dlva_jz     IN       VARCHAR2,
      inp_extn_period_dlva_hz     IN       VARCHAR2,
      inp_extn_period_dlva_qz     IN       VARCHAR2,
      inp_extn_period_dlva_mz     IN       VARCHAR2,
      inp_extn_period_dlta_jz     IN       VARCHAR2,
      inp_extn_period_dlta_hz     IN       VARCHAR2,
      inp_extn_period_dlta_qz     IN       VARCHAR2,
      inp_extn_period_dlta_mz     IN       VARCHAR2,
      v_return_code               OUT      NUMBER
   )
   IS
   BEGIN                                                                   --1

      PROC_VALIDATE_PARAMS( stichtag_date            ,
                           inp_calc_fact_book_dt_flg,
                           inp_calc_fact_dt         ,
                           inp_version              ,
                           inp_extn_period          ,
                           inp_extn_period_lsva_jz  ,
                           inp_extn_period_lsva_hz  ,
                           inp_extn_period_lsva_qz  ,
                           inp_extn_period_lsva_mz  ,
                           inp_extn_period_lsta_jz  ,
                           inp_extn_period_lsta_hz  ,
                           inp_extn_period_lsta_qz  ,
                           inp_extn_period_lsta_mz  ,
                           inp_extn_period_dlva_jz  ,
                           inp_extn_period_dlva_hz  ,
                           inp_extn_period_dlva_qz  ,
                           inp_extn_period_dlva_mz  ,
                           inp_extn_period_dlta_jz  ,
                           inp_extn_period_dlta_hz  ,
                           inp_extn_period_dlta_qz  ,
                           inp_extn_period_dlta_mz  ,
                           v_return_code     );
      v_stichtag_date                     :=      stichtag_date             ;
      g_inp_calc_fact_book_dt_flg         :=      inp_calc_fact_book_dt_flg ;
      g_inp_calc_fact_dt                  :=      inp_calc_fact_dt          ;
      g_inp_version                       :=      inp_version               ;
      g_inp_extn_period                   :=      inp_extn_period           ;
      g_inp_extn_period_lsva_jz           :=      inp_extn_period_lsva_jz   ;
      g_inp_extn_period_lsva_hz           :=      inp_extn_period_lsva_hz   ;
      g_inp_extn_period_lsva_qz           :=      inp_extn_period_lsva_qz   ;
      g_inp_extn_period_lsva_mz           :=      inp_extn_period_lsva_mz   ;
      g_inp_extn_period_lsta_jz           :=      inp_extn_period_lsta_jz   ;
      g_inp_extn_period_lsta_hz           :=      inp_extn_period_lsta_hz   ;
      g_inp_extn_period_lsta_qz           :=      inp_extn_period_lsta_qz   ;
      g_inp_extn_period_lsta_mz           :=      inp_extn_period_lsta_mz   ;
      g_inp_extn_period_dlva_jz           :=      inp_extn_period_dlva_jz   ;
      g_inp_extn_period_dlva_hz           :=      inp_extn_period_dlva_hz   ;
      g_inp_extn_period_dlva_qz           :=      inp_extn_period_dlva_qz   ;
      g_inp_extn_period_dlva_mz           :=      inp_extn_period_dlva_mz   ;
      g_inp_extn_period_dlta_jz           :=      inp_extn_period_dlta_jz   ;
      g_inp_extn_period_dlta_hz           :=      inp_extn_period_dlta_hz   ;
      g_inp_extn_period_dlta_qz           :=      inp_extn_period_dlta_qz   ;
      g_inp_extn_period_dlta_mz           :=      inp_extn_period_dlta_mz   ;


      v_missing_pdt := 0;
      v_curr_comp_no := 0;
      
      PROC_BUILD_ACCR_OBJECTS;

      BEGIN
         SELECT prtnr_id 
         into v_comp_prtnr_id_01
         FROM UC_COMPANY_MS
         WHERE comp_num = 1;
      EXCEPTION
      WHEN OTHERS
      THEN
            v_comp_prtnr_id_01 := null;
      END;

      Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Company  Partner id 001='||v_comp_prtnr_id_01,'', '');    

      OPEN contract_dtl_cursor;

      LOOP
                FETCH contract_dtl_cursor BULK COLLECT into v_cur_contract_tab LIMIT v_bulk_fetch_cnt;  

                Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Number contracts Fetched'||v_cur_contract_tab.COUNT,'', '');    

                IF(v_cur_contract_tab.COUNT > 0)
                THEN
                     PROC_START_TRGN_PROCESS;
                END IF;
                Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','After PROCESS_CONTRACT ','', '');    
                EXIT WHEN contract_dtl_cursor%NOTFOUND; 
      END LOOP;
   /* closing the file transfer utl file    */
      IF UTL_FILE.is_open (v_filelist_fp) 
      THEN      
        UTL_FILE.fclose (v_filelist_fp);
      END IF;

      IF UTL_FILE.is_open (v_refin_fp) 
      THEN
         IF(v_no_of_refin_cnt > 0)
         THEN
                  refin_result := '</txs_refi_data>';
                  UTL_FILE.put_line (v_refin_fp, refin_result);                     
         END IF;
         UTL_FILE.fclose (v_refin_fp);
      END IF;
      IF UTL_FILE.is_open (v_contract_fp) 
      THEN
         UTL_FILE.fclose (v_contract_fp);
      END IF;

      IF v_missing_pdt = 0
      THEN
         pkg_batch_logger.proc_log (lf_pdt_file_handle,
                                    'DEBUG',
                                    '',
                                    '',
                                    'No Contract Type is missing'
                                   );    -- Fix for Version 1.6 - Defect 16426 
      END IF;

      UTL_FILE.fclose (lf_pdt_file_handle); 
      v_return_code := 0;
      pkg_batch_logger.proc_log_status (lf_file_handle, 'C');

   EXCEPTION
   WHEN v_proc_err
   THEN
    v_return_code := 1;
    pkg_batch_logger.proc_log (lf_file_handle,'INFO','BAT_I_0019','MAIN_PROC' || ',' || v_pkg_id,NULL);
    pkg_batch_logger.proc_log_status (lf_file_handle, 'B');
   DBMS_OUTPUT.put_line ('error544:' || SQLERRM);

   WHEN v_file_open_err
   THEN
    pkg_batch_logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',SQLCODE,SQLERRM);
    pkg_batch_logger.proc_log_status (lf_file_handle, 'B');
    DBMS_OUTPUT.put_line ('error544:' || SQLERRM);
    v_return_code := 20;
   WHEN OTHERS
   THEN
    pkg_batch_logger.proc_log_status (lf_file_handle, 'B');
    DBMS_OUTPUT.put_line ('error52:' || SQLERRM);
    v_return_code := 16;
    -- Fatal. Problem needs to be corrected and program re-run
   END MAIN_PROC;
END PKG_TRIGONIS_UCS_XML;
/
