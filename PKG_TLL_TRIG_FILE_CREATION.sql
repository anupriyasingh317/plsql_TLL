CREATE OR REPLACE PACKAGE PKG_TLL_TRIG_FILE_CREATION
IS
   /*-------------------------------------------------------------------------------------------------*/
   /*  Name                 :  PKG_TLL_TRIG_FILE_CREATION                                             */
   /*  Author               :  Hexaware Technologies                                                  */
   /*  Purpose              :  generates the final xml files company wise to TRIGONIS Terminal        */
   /*                                                                                                 */
   /*                        1.Extract the  obj_pkg_num and comp_num from the xmltype column and send */
   /*                          the same to SAP system for depresion details.                          */
   /*                        2.generates the final trigonis xml file company wise for trigonis        */
   /*                          terminal.                                                              */
   /*                                                                                                 */
   /*                                                                                                 */
   /*  Revision History    :                                                                          */
   /*  <<Ver No>>           <<Modified By>>                    <<Modified Date>>                      */
   /*      1.0                Roshan  F                         31-Oct-2007                           */
   /*      1.1                Roshan  F                         05-Jan-2008                           */
   /*      New block is added to generate the csv file if riskcoverage tag is not in                  */
   /*      contract leasing system.                                                                   */
   /*      1.2                Roshan  F                         11-Jan-2008                           */
   /*      New block is added to validate the generated xml file company wise  against external DTD.  */
   /*      1.3                Kalimuthu                         06-Feb-2008                           */
   /*      If txs ref id is null,then vname is assigned to pickup ucs refinancing data                */
   /*      1.4                Roshan  F                         15-Feb-2008                           */
   /*      New component is added to extract from ucs contract and merge in final xml file            */
   /*      defect id :17982                                                                           */
   /*      1.3                Kalimuthu                         21-Feb-2008                           */
   /*                   1) To handle multiple object package
   /*      1.4                Kalimuthu                         03-Mar-2008                           */
   /*                   1) faelligkeit_awert and aufloesung_ende are populated
   /*                      when handling multiple object package details
   /*      1.4                Kalimuthu                         26-Mar-2008                           */
   /*                   1) if multiple object is available for a sub segment ,then
   /*                      take highest betrag object package sap depreciation details and
   /*               sum of all betrag and populate as single anlagvormorgen.
   /*               defect id 18096
   /*      1.5                Kalimuthu                         01-Apr-2008                           */
   /*                   1) delete condition on vitria table has been changed 
   /*                      delete records only based on company number. Removed the effective date condition
   /*      1.6                Kalimuthu                         05-May-2008                           */
   /*                                        no of record count variable length from 5 to 10 digits   */
   /*      1.7                Kalimuthu                         27-May-2008                           */
   /*                                        Fix for result var length increased from 15000 to 25000 */
   /*      1.8                Kalimuthu    fix for plsql value error - v_result_var is converted to clob variable
   /*      1.9                Kalimuthu    Fix for 338
   /*      2.0                Kalimuthu                         03-Nov-2008  
   /*                              Fix for defect 20238 to remove the following element
   /*                                 1)  /bestand/vorgang/direktvertrag/vertrag/anlagevermoegen/abschreibung/@aufloesung_ende
   /*                                 2)  /bestand/vorgang/direktvertrag/vertrag/anlagevermoegen/abschreibung/@aufloesung_ende_glz
   /*                                 3)  Additionally the whole element '/bestand/vorgang/direktvertrag/vertrag/anlagevermoegen/abschreibung/afa_restwert_vor_verl
   /*      3.0                Kalimuthu                         10-Oct-2010 - ESB Releated Changes
   /*      3.1                Benjamine     Fix for 25053 - Batch Error Handling   09-Jun-2011
   /*      3.2                Benjamine     Commented the procedure PRC_BILANZ_TRIGONIS and PRC_HOST_COMM for 
   /*                                       Removing the vitria dblink dl_ubc_vit  
   /*      3.3                Roshan F      Performance defect 25768  
   /*      3.4                Roshan F      Fix done for defect 25822  
   /*      3.5                Benjamine S   Fix for New SAP 15 Depreciation 
   /*      3.6                Benjamine S   New SAP 15 removed and SAP 16 Depreciation added
   /*      3.7                Benjamine S   Fix for CR 27514 Depreciation code changed from 16 to 15
   /*-------------------------------------------------------------------------------------------------*/

   -- Global variable declarations

g_v_pkg_id        CONSTANT        VARCHAR2(100) := 'PKG_TLL_TRIG_FILE_CREATION';   /* Variable to Store Package Name */
g_v_prog_599_id       CONSTANT        VARCHAR2(100) := 'TLL_TRIG_FILE_CREATION_599';
g_v_prog_N599_id       CONSTANT        VARCHAR2(100) := 'TLL_TRIG_FILE_CREATION_N599';        /* Variable to Store Program Name */
g_v_proc_name     CONSTANT        VARCHAR2(100) := 'TLL_TRIG_FILE_CREATION';
g_v_pkg_prog_id   CONSTANT        VARCHAR2(300) :=  g_v_pkg_id || ' , ' || g_v_pkg_id;
g_v_user          VARCHAR2(40)                  := 'TLL_TRIG_FILE_CREATION_BATCH';
g_v_err           varchar2(100);
g_d_due_dt        DATE;

v_max_date        DATE;
v_bckup_data      CHAR(1):= 'N';
v_batch_job_number  NUMBER(10) :=0;

g_v_errtable        VARCHAR2(50);

lf_file_handle      UTL_FILE.FILE_TYPE;   -- Variable for Log File Handler
v_filelist_599_fp   UTL_FILE.FILE_TYPE;   -- Variable for final xml files
v_filelist_n599_fp  UTL_FILE.FILE_TYPE;   -- Variable for final xml files
v_output_filename   VARCHAR2 (50) ;

v_proc_err        EXCEPTION;
v_tech_err        EXCEPTION;
v_exists_err      EXCEPTION;
v_insert_err      EXCEPTION;
v_file_open_err   EXCEPTION;

g_n_no_records      NUMBER(10)  := 0;
g_n_cntrl_records   NUMBER(10)  := 0;

g_n_no_exists_con   NUMBER(10)  := 0;
g_n_no_exists_refin NUMBER(10)  := 0;
g_n_no_exists_sap   NUMBER(10)  := 0;
-- Public procedure declarations
TYPE v_tab_job_id IS TABLE OF NUMBER(10) INDEX BY BINARY_INTEGER;
p_trgns_tran_id      CONSTANT VARCHAR2 (15) := 'LISUBC1008 '; -- Trigonis Transfer ID

/**************************************************/
/* Main Procedure which calls all other procedures*/
/**************************************************/

PROCEDURE MAIN_PROC (
                        p_i_d_due_date         IN   DATE,
                        p_i_n_comp_num         IN   VARCHAR2,
                        p_i_n_risk_val         IN   NUMBER,
                        p_o_n_ret_flg          OUT  NUMBER

                       );


PROCEDURE PROC_VALIDATION (
                           p_i_d_due_date         IN   DATE,
                           p_i_n_comp_num         IN   VARCHAR2,
                           p_o_n_ret_flg          OUT  NUMBER

                       );

PROCEDURE PROC_POST_VALIDATION (
                                p_i_d_due_date         IN   DATE,
                                p_o_n_ret_flg          OUT  NUMBER

                       );



PROCEDURE PROC_PUSH_DATA_TO_VITRIA
(Stichtag_Date IN DATE,v_comp_num IN VARCHAR2,v_return_code OUT NUMBER,v_rec_limit in NUMBER,v_esb_flag IN varchar2,v_instance_id IN varchar2);

/********************************************/
/*Procedure to generate the final xml file  */
/********************************************/

PROCEDURE FINAL_TRIG_XML_FILE_CREATION (
                                           v_i_n_comp_num          IN VARCHAR2,
                                           v_i_d_due_date          IN DATE,
                                                     v_i_n_risk_val          IN NUMBER,
                                           p_o_n_ret_flg          OUT NUMBER
                                         );

/********************************************/
/*Function to calculate the occurs of string*/
/********************************************/

FUNCTION occurs (
                    csearchexpression NVARCHAR2,
                    cexpressionsearched CLOB
                   )
RETURN SMALLINT DETERMINISTIC;

/*PROCEDURE PRC_BILANZ_TRIGONIS (
                               p_stitchtagdate IN DATE,
                                       v_comp_num IN NUMBER,
                               lf_file_handle IN UTL_FILE.file_type,
                               p_err_cd OUT VARCHAR2
                               ); */

PROCEDURE PRC_BILANZ_TRIGONIS_ESB (
                   v_instance_id IN VARCHAR2,
                   p_rec_limit in NUMBER,
           p_stitchtagdate IN DATE,
                   v_comp_num IN NUMBER,
           lf_file_handle IN UTL_FILE.file_type,
           p_err_cd OUT VARCHAR2
                                 );

--PROCEDURE PRC_HOST_COMM(p_stream VARCHAR2,p_stitchtagdate IN DATE);

FUNCTION func_vitria_path  (if_file_handle utl_file.file_type)  RETURN VARCHAR2 ;

PROCEDURE prc_vitria_transfer(p_stitchtagdate IN DATE,
                              p_vitria_path IN VARCHAR2,
                              p_tab_jobnum IN v_tab_job_id,
                              p_tranid IN VARCHAR2,
                              p_ercd OUT PLS_INTEGER,
                              if_file_handle utl_file.file_type);

/********************************************/
/*     Procedure to validate the xml file   */
/********************************************/

PROCEDURE DOMParserUtil(dir IN varchar2,
            inpfile IN varchar2,
            inpdtd IN varchar2      );

/********************************************/
/* Procedure to retrival the tll data       */
/********************************************/

PROCEDURE TLL_READ_HISTORY_DATA(p_run_date IN DATE,
                p_sap_flag IN CHAR,
                v_return_code OUT NUMBER );

END PKG_TLL_TRIG_FILE_CREATION;
/
CREATE OR REPLACE PACKAGE BODY PKG_TLL_TRIG_FILE_CREATION
IS
PROCEDURE MAIN_PROC (
                        p_i_d_due_date         IN   DATE,
                        p_i_n_comp_num         IN   VARCHAR2,
                        p_i_n_risk_val         IN   NUMBER,
                        p_o_n_ret_flg          OUT  NUMBER

)
 IS


BEGIN

    p_o_n_ret_flg         := 0;
    g_d_due_dt            := p_i_d_due_date;
   /*-----------------------------------------------*/
   /* Initialize File Handle for  Log File Writing  */
   /*-----------------------------------------------*/

   IF p_i_n_comp_num = '599' THEN 

    BEGIN
      lf_file_handle := Pkg_Batch_Logger.func_open_log(g_v_prog_599_id);
    EXCEPTION
    WHEN OTHERS
    THEN
         DBMS_OUTPUT.PUT_LINE('Unable to open the Spool File due to '||SQLERRM);
         RAISE v_file_open_err;
    END;

  ELSE
    
    BEGIN
      lf_file_handle := Pkg_Batch_Logger.func_open_log(g_v_prog_N599_id);
    EXCEPTION
    WHEN OTHERS
    THEN
         DBMS_OUTPUT.PUT_LINE('Unable to open the Spool File due to '||SQLERRM);
         RAISE v_file_open_err;
    END;

  
  
  END IF;


   /*--------------------------------------------------------------------*/
   /*  Log Blank lines at the start of the Output files for readability  */
   /*--------------------------------------------------------------------*/

    FOR cnt IN 1..15
    LOOP
        Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0000', '', '');
    END LOOP;

   /*---------------------------------------------*/
   /* Writing Input Parameter Details to Out File */
   /*---------------------------------------------*/
   IF p_i_n_comp_num = '599' THEN 

   Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0008','MAIN_PROC'||','||g_v_prog_599_id,'');

   ELSE
      
   Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0008','MAIN_PROC'||','||g_v_prog_N599_id,'');

   END IF;

   Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT','List of Input Parameters :-', '', '');
   Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT','Input Process date       = ','', to_char( p_i_d_due_date,'dd.mm.rrrr') );
   Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT','Input company Number     = ','',p_i_n_comp_num);


   /*------------------------------------------------------------------*/
   /* Check if Input Parameters are Valid                              */
   /*------------------------------------------------------------------*/

   FINAL_TRIG_XML_FILE_CREATION (p_i_n_comp_num,p_i_d_due_date,p_i_n_risk_val,p_o_n_ret_flg);

   IF  p_o_n_ret_flg<> 0
   THEN
      RAISE v_proc_err;
   END IF;

   
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_TRIG_FILE_CREATION        = ','',p_o_n_ret_flg);
   Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT',NULL,NULL,NULL);
   IF p_i_n_comp_num = '599' THEN 
   Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0012','MAIN_PROC'||','||g_v_prog_599_id,NULL);
   
   ELSE
     Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0012','MAIN_PROC'||','||g_v_prog_N599_id,NULL);
   END IF;
   Pkg_Batch_Logger.proc_log_status (lf_file_handle,'C');

EXCEPTION
WHEN  v_proc_err THEN
      p_o_n_ret_flg := 1;

      Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_TRIG_FILE_CREATION        = ','',p_o_n_ret_flg);
      IF p_i_n_comp_num = '599' THEN
      Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019','MAIN_PROC'||','||g_v_prog_599_id,NULL);
      ELSE
      Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019','MAIN_PROC'||','||g_v_prog_N599_id,NULL);
      END IF;

      Pkg_Batch_Logger.proc_log_status (lf_file_handle,'B');

WHEN v_tech_err THEN        
      p_o_n_ret_flg :=2;
      Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_TRIG_FILE_CREATION        = ','',p_o_n_ret_flg);
      IF p_i_n_comp_num = '599' THEN
      Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019','MAIN_PROC'||','||g_v_prog_599_id,NULL);
      ELSE
      Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019','MAIN_PROC'||','||g_v_prog_N599_id,NULL);
      END IF;
      Pkg_Batch_Logger.proc_log_status (lf_file_handle,'S');

WHEN v_exists_err THEN
      p_o_n_ret_flg :=3;
      Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_TRIG_FILE_CREATION        = ','',p_o_n_ret_flg);
      Pkg_Batch_Logger.proc_log(lf_file_handle,'DEBUG','RECORDS ALREADY DELETED FOR THE CURRENT DATE','','');
      IF p_i_n_comp_num = '599' THEN
      Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019','MAIN_PROC'||','||g_v_prog_599_id,NULL);
      ELSE
      Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019','MAIN_PROC'||','||g_v_prog_N599_id,NULL);
      END IF;

      Pkg_Batch_Logger.proc_log_status (lf_file_handle,'B');

WHEN  OTHERS THEN

   /* ------------------------------------------------------- */
   /*      Other fatal Errors. Close and Terminate program    */
   /* ------------------------------------------------------- */
      p_o_n_ret_flg := 20;
      Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_TRIG_FILE_CREATION        = ','',p_o_n_ret_flg);
      IF p_i_n_comp_num = '599' THEN
      Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019',  'MAIN_PROC' || ' , ' || g_v_prog_599_id, '');
      ELSE
      Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019',  'MAIN_PROC' || ' , ' || g_v_prog_N599_id, '');
      END IF;


      Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',NULL,SQLERRM);
      Pkg_Batch_Logger.proc_log_status (lf_file_handle,'S');
      Pkg_Batch_Logger.proc_close_log(lf_file_handle);

END MAIN_PROC;

FUNCTION getXMLValue(p_node IN dbms_xmldom.DOMNode ,
                      p_attribute_name IN VARCHAR2
) RETURN VARCHAR2 AS
        l_attr_val      VARCHAR2(300) := null;
BEGIN
   BEGIN
        l_attr_val       := dbms_xmldom.getValue(dbms_xmldom.getAttributeNode(xmldom.makeElement(p_node),p_attribute_name));

        return l_attr_val;
   EXCEPTION
   WHEN OTHERS
   THEN
      return l_attr_val;
   END;
END getXMLValue;

FUNCTION FN_STR_NUMBER_CONV(p_inp_string IN VARCHAR2) RETURN NUMBER AS
        l_number_val      NUMBER(23,3) := 0;
BEGIN
   BEGIN
      l_number_val := TO_NUMBER(p_inp_string,'9999999999999999990D99','NLS_NUMERIC_CHARACTERS=.,');
      return l_number_val;
   EXCEPTION
   WHEN OTHERS
   THEN
      dbms_output.put_line('FN_CONVERT_NUMBER:Failed::'||sqlerrm);
      return l_number_val;
   END;
END FN_STR_NUMBER_CONV;

FUNCTION FN_NUMBER_STR_CONV(p_inp_number IN NUMBER) RETURN VARCHAR2 AS
        l_str_val      VARCHAR2(40) := 0;
BEGIN
   BEGIN
      l_str_val := TO_CHAR(p_inp_number,'9999999999999999990D99','NLS_NUMERIC_CHARACTERS=.,');
      return l_str_val;
   EXCEPTION
   WHEN OTHERS
   THEN
      dbms_output.put_line('FN_CONVERT_NUMBER:Failed::'||p_inp_number||sqlerrm);
      return l_str_val;
   END;
END FN_NUMBER_STR_CONV;

PROCEDURE FINAL_TRIG_XML_FILE_CREATION (
                                           v_i_n_comp_num          IN VARCHAR2,
                                           v_i_d_due_date          IN DATE,
                                                     v_i_n_risk_val          IN NUMBER,
                                           p_o_n_ret_flg          OUT NUMBER
                                                        )
IS

cursor cur_cmpno_599 is
select comp_num 
from   tll_comp_no_lst_tmp 
WHERE comp_num = 599;

cursor cur_cmpno_n599 is
select comp_num 
from   tll_comp_no_lst_tmp 
WHERE comp_num <> 599;

TYPE cur_cmpno_tab IS TABLE OF NUMBER INDEX BY PLS_INTEGER;

cur_cmpno_data             cur_cmpno_tab;

CURSOR cur_contract_xml1 (v_i_n_cmp_no in number, v_i_d_due_date in date) IS
SELECT   a.cntrct_id,a.cntrct_det
from tll_cntrct_det_tp a
where a.comp_num = v_i_n_cmp_no
and a.due_dt   = v_i_d_due_date;

CURSOR cur_sap_det (p_cntrct_id IN VARCHAR2,p_due_dt in DATE,p_comp_num in NUMBER) IS
SELECT deprc_det
FROM TLL_SAP_DEPRC_TP e , TLL_CNTRCT_STG_TP a
WHERE a.cntrct_id = p_cntrct_id
and a.due_dt = p_due_dt
and a.comp_num    = p_comp_num
and e.obj_pkg_num = a.obj_pkg_num
and e.due_dt      = a.due_dt
and e.comp_num    = a.comp_num
order by extractValue(deprc_det,'/anlagevermoegen/zugangswert/@betrag') desc;

TYPE cur_contract_tab IS TABLE OF cur_contract_xml1%ROWTYPE INDEX BY BINARY_INTEGER;
cur_contract_data1             cur_contract_tab;

TYPE cur_sap_tab IS TABLE OF cur_sap_det%ROWTYPE INDEX BY BINARY_INTEGER;
v_sap_tab         cur_sap_tab;

p_comp_num              NUMBER;
p_txs_ref_id             VARCHAR2(50);
p_vname                  VARCHAR2(50);
v_result                 xmltype;
v_head                     VARCHAR2(2000);
v_result_final         xmltype;
v_length                 NUMBER(20);
v_sap_final_data     XMLTYPE;
v_sap_final_data01     XMLTYPE;  -- Fix for New SAP 01 and 16
v_sap_final_data16     XMLTYPE;  -- Fix for New SAP 01 and 16
v_record_count         NUMBER := 0;
v_output_file_handle     UTL_FILE.FILE_TYPE;
v_output_file_name         VARCHAR2(100);
v_count_pl                 NUMBER;
p_acquisition                VARCHAR2(50);
l_cntrct_det                 tll_cntrct_det_tp.cntrct_det%type;
v_refin_det                  XMLType ;
v_deprc_det                  XMLType ;
v_risikovorsorge_var    VARCHAR2(100);
v_sap_zugangsdatum        VARCHAR2(20);
v_vende_verlaengerung    VARCHAR2(20);
--v_result_var            VARCHAR2(32000);
v_result_var              CLOB;
v_result_buff              VARCHAR2(32000);
v_bytelen             NUMBER := 32000;
v_curr_length         NUMBER(20);
vstart                NUMBER(20);
v_temp_comp_str              VARCHAR2(2000);
v_i_s_comp_num              VARCHAR2(2000);
v_risk_csv                  VARCHAR2(200);
doc                          dbms_xmldom.DOMDocument;
node                         dbms_xmldom.DOMNode;
Element_v                 dbms_xmldom.DOMElement;
Element_v1                 dbms_xmldom.DOMElement;
v_element_vetrag      dbms_xmldom.DOMElement;
tnodeList                   dbms_xmldom.DOMNodeList ;
tnode                          dbms_xmldom.DOMNode ;
tnodeList1                  dbms_xmldom.DOMNodeList ;
tnodeListAnlag              dbms_xmldom.DOMNodeList ;
tnode1                         dbms_xmldom.DOMNode ;
doc_risk                    dbms_xmldom.DOMDocument;
elem                          dbms_xmldom.DOMElement;
cur_node                    dbms_xmldom.DOMNode;
v_prd_type                  varchar2(100);
v_sap_flag                  boolean := false;
v_risk_filenm         VARCHAR2(200) := null;
v_index_cnt           PLS_INTEGER;
v_sap_cnt             NUMBER(10);
v_curr_contract_rec   cur_contract_xml1%ROWTYPE;
I                     NUMBER := 1;
v_zugangswert_betrag01  VARCHAR2(50);    -- Fix for New SAP 01 and 16
v_restbuchwert_betrag01 VARCHAR2(50);    -- Fix for New SAP 01 and 16
v_monatlicher_betrag01  VARCHAR2(50);    -- Fix for New SAP 01 and 16
v_afa_restwert_vor_verl01    VARCHAR2(50);    -- Fix for New SAP 01 and 16

v_zugangswert_betrag16  VARCHAR2(50);    -- Fix for New SAP 01 and 16
v_restbuchwert_betrag16 VARCHAR2(50);    -- Fix for New SAP 01 and 16
v_monatlicher_betrag16  VARCHAR2(50);    -- Fix for New SAP 01 and 16
v_afa_restwert_vor_verl16   VARCHAR2(50);    -- Fix for New SAP 01 and 16

v_zugangswert_betrag_sum01   NUMBER(23,2);    -- Fix for New SAP 01 and 16
v_restbuchwert_betrag_sum01  NUMBER(23,2);    -- Fix for New SAP 01 and 16
v_monatlicher_betrag_sum01   NUMBER(23,2);    -- Fix for New SAP 01 and 16
v_afa_restwert_vor_verl_sum01 NUMBER(23,2);    -- Fix for New SAP 01 and 16

v_zugangswert_betrag_sum16   NUMBER(23,2);    -- Fix for New SAP 01 and 16
v_restbuchwert_betrag_sum16  NUMBER(23,2);    -- Fix for New SAP 01 and 16
v_monatlicher_betrag_sum16   NUMBER(23,2);    -- Fix for New SAP 01 and 16
v_afa_restwert_vor_verl_sum16 NUMBER(23,2);    -- Fix for New SAP 01 and 16

BEGIN
      p_o_n_ret_flg := 0;

      cur_cmpno_data.delete;

      v_i_s_comp_num := v_i_n_comp_num;


         IF v_i_s_comp_num = '599' THEN

          OPEN cur_cmpno_599;
          fetch cur_cmpno_599 bulk collect into cur_cmpno_data;
          CLOSE cur_cmpno_599;
         ELSE
          
          OPEN cur_cmpno_n599;
          fetch cur_cmpno_n599 bulk collect into cur_cmpno_data;
          CLOSE cur_cmpno_n599;   
         
         END IF;

      

      IF cur_cmpno_data.count > 0
      THEN

        IF v_i_s_comp_num = '599' THEN
         BEGIN                                                                --3
            v_filelist_599_fp := UTL_FILE.fopen ('OUTGOING_DIR','TLL_TRIG_FILE_CREATION_599.ftp.list', 'W');
         EXCEPTION
         WHEN OTHERS
         THEN
            pkg_batch_logger.proc_log (lf_file_handle,'INFO','*** No Permissions to the Location OUTGOING_DIR ***','',SQLERRM);
            RAISE v_tech_err;
         END;                                                                       --}
        ELSE
         BEGIN                                                                --3
            v_filelist_n599_fp := UTL_FILE.fopen ('OUTGOING_DIR','TLL_TRIG_FILE_CREATION_N599.ftp.list', 'W');
         EXCEPTION
         WHEN OTHERS
         THEN
            pkg_batch_logger.proc_log (lf_file_handle,'INFO','*** No Permissions to the Location OUTGOING_DIR ***','',SQLERRM);
            RAISE v_tech_err;
         END;    
        END IF;


         FOR i IN cur_cmpno_data.FIRST .. cur_cmpno_data.LAST
         LOOP
               p_comp_num  := cur_cmpno_data (i);

               v_record_count :=0;

               v_head := '<?xml version="1.0" encoding="UTF-8" standalone="no"?>'||CHR(10)||'<!DOCTYPE bestand SYSTEM "Bestand.dtd">'||CHR(10)||'<bestand sim_stichtag="'||to_char(v_i_d_due_date +1,'DD.MM.YYYY')||'" bestandstyp="BESTAND">';

               v_output_file_name := 'B'||to_char(v_i_d_due_date +1,'YYMM')||lpad(p_comp_num,3,0)||'.xml';

               v_output_file_handle := UTL_FILE.fopen ('OUTGOING_DIR',v_output_file_name, 'w', 32767);

               UTL_FILE.put_line (v_output_file_handle,v_head);
               UTL_FILE.fflush(v_output_file_handle);

               cur_contract_data1.delete;

               IF p_comp_num = 599 THEN
               UTL_FILE.put_line (v_filelist_599_fp,v_output_file_name);
               UTL_FILE.fflush(v_filelist_599_fp);
               ELSE
               UTL_FILE.put_line (v_filelist_n599_fp,v_output_file_name);
               UTL_FILE.fflush(v_filelist_n599_fp);               
               END IF;


               
               OPEN cur_contract_xml1 (p_comp_num,v_i_d_due_date);
               LOOP
                  fetch cur_contract_xml1 bulk collect into cur_contract_data1 LIMIT 5000;
                  IF cur_contract_data1.count > 0
                  THEN
                     FOR i IN cur_contract_data1.FIRST .. cur_contract_data1.LAST
                     LOOP
                           v_result              := NULL;
                           v_sap_final_data      := NULL;
                           p_txs_ref_id      := NULL;
                           p_vname           := NULL;
                           v_vende_verlaengerung := NULL;
                           v_sap_zugangsdatum    := NULL;
                           v_result_var      := NULL;
                           v_refin_det           := NULL;
                           v_deprc_det           := NULL;
                           v_risikovorsorge_var  := NULL;
                           p_acquisition         := NULL;
                           v_risk_csv            := NULL;
                           v_curr_contract_rec   := NULL;

                           v_curr_contract_rec := cur_contract_data1(I);
                           p_vname      := v_curr_contract_rec.cntrct_id;
--                           Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','p_vname'||p_vname,'', '' );

                           --Takes 32 mins
                           SELECT extract(v_curr_contract_rec.cntrct_det,'/bestand/vorgang'),
                                  extractvalue(v_curr_contract_rec.cntrct_det,'/bestand/vorgang/direktvertrag/vertrag/vertragsheader/@vende_verlaengerung'),
                                  extractValue(v_curr_contract_rec.cntrct_det,'/bestand/vorgang/direktvertrag/vertrag/vertragsheader/@vertragstyp_erweitert') ,
                                  extractValue(v_curr_contract_rec.cntrct_det,'/bestand/vorgang/direktvertrag/vertrag/vertragsheader/anschaffungswert/@betrag'),
                                  extractValue(v_curr_contract_rec.cntrct_det,'/bestand/vorgang/direktvertrag/vertrag/txs_reference/@txs_ref_id')
                           INTO   l_cntrct_det,v_vende_verlaengerung,v_prd_type,p_acquisition,p_txs_ref_id
                           FROM   DUAL;
                           
                           SELECT deleteXML(l_cntrct_det,'/vorgang/direktvertrag/vertrag/txs_reference')
                           into l_cntrct_det
                           FROM dual;

                           SELECT deleteXML(l_cntrct_det,'/vorgang/direktvertrag/vertrag/anlagevermoegen')
                           into l_cntrct_det
                           FROM dual;

                           BEGIN
                              IF(p_txs_ref_id is null)
                              THEN
                                 p_txs_ref_id := p_vname;
                              END IF;

                              SELECT refin_det
                              INTO v_refin_det
                              FROM TLL_REFIN_DET_TP
                              WHERE  CNTRCT_ID  = p_txs_ref_id
                              AND DUE_DT        = v_i_d_due_date
                              AND COMP_NUM      = p_comp_num;

                              SELECT appendChildXML(l_cntrct_det,'/vorgang/direktvertrag/vertrag',extract(v_refin_det,'/txs_refi_data/refi_contract/*'))
                              into l_cntrct_det
                              FROM dual;
                           EXCEPTION
                           WHEN NO_DATA_FOUND
                           THEN
                           Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','NO Refin DATA FOUND  FOR ','', p_vname ||'   '|| 'for the company number   :' ||lpad(p_comp_num,3,0));
                           END;
                           v_sap_flag := false;
                           --Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','v_prd_type','', v_prd_type||'   '|| '' ||lpad(p_comp_num,3,0));
                           v_sap_final_data := null;

                           IF(v_prd_type != 'MK')
                           THEN
                              BEGIN
                                   --Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','v_sap_flag=true','', '' );

                                  OPEN  cur_sap_det(p_vname, v_i_d_due_date,p_comp_num);
                                  FETCH cur_sap_det bulk collect into v_sap_tab;
                                  CLOSE cur_sap_det ;

                                  IF(v_sap_tab.COUNT = 0)
                                  THEN
                                       v_sap_flag := false;
                                       Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','NO SAP DATA FOUND  FOR ','', p_vname ||'   '|| 'for the company number   :' ||lpad(p_comp_num,3,0));
                                  ELSE
                                       v_sap_flag := true;
                                       v_deprc_det := v_sap_tab(1).deprc_det;
                                     BEGIN
                                       SELECT XMLElement("anlagevermoegen",
                                                 XMLAttributes(extractValue(v_deprc_det,'/anlagevermoegen/@zugangsdatum') as "zugangsdatum"),
                                                      extract(v_deprc_det,'/anlagevermoegen/*')
                                        )
                                       INTO v_sap_final_data
                                       FROM DUAL;
                                     EXCEPTION
                                     WHEN OTHERS
                                     THEN
                                         Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Contract Key has more than one Object --> '||p_vname,'','');
                                     END;

				       -- Fix for New SAP 16 and contract has more than one object
                                       IF(v_sap_tab.COUNT > 1)
                                       THEN
					  -- Fix for New SAP 01 and 16 -- Starts here
                                          v_zugangswert_betrag_sum01      := 0;
                                          v_restbuchwert_betrag_sum01     := 0;
                                          v_monatlicher_betrag_sum01      := 0;
                                          v_afa_restwert_vor_verl_sum01   := 0;

                                          v_zugangswert_betrag_sum16      := 0;
                                          v_restbuchwert_betrag_sum16     := 0;
                                          v_monatlicher_betrag_sum16      := 0;
                                          v_afa_restwert_vor_verl_sum16   := 0;

                                          FOR sap_rec IN v_sap_tab.FIRST..v_sap_tab.LAST
                                          LOOP

                                             v_deprc_det := v_sap_tab(sap_rec).deprc_det;

                                             BEGIN
                                             SELECT xmltype(REPLACE ( SUBSTR (v_deprc_det,1,INSTR (v_deprc_det, '<abschreibung', 1, 1) - 1)
                                                                    || TRIM (SUBSTR (v_deprc_det,INSTR (v_deprc_det, '<abschreibung', 1, 1),
                                                                                    (  INSTR (v_deprc_det, '</abschreibung>', 1, 1)
                                                                                        - INSTR (v_deprc_det, '<abschreibung', 1, 1)
                                                                                    )+ 15
                                                                                    )
                                                                     )|| '</anlagevermoegen>',
                                            'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="TLL_depreciation.xsd" '
                                                                     )),
                                                   xmltype(REPLACE ( SUBSTR (v_deprc_det,1,INSTR (v_deprc_det, '<abschreibung', 1, 1) - 1)
                                                                    || TRIM (SUBSTR (v_deprc_det,INSTR (v_deprc_det, '<abschreibung', 1, 2),
                                                                                    (  INSTR (v_deprc_det, '</abschreibung>', 1, 2)
                                                                                        - INSTR (v_deprc_det, '<abschreibung', 1, 2)
                                                                                    )+ 15
                                                                                    )
                                                                     )|| '</anlagevermoegen>',
                                            'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="TLL_depreciation.xsd" '
                                                                     ))                                                                     
                                            into  v_sap_final_data01,v_sap_final_data16
                                            from dual;
                                            EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Error while getting SAP Depreciation --> '||sqlerrm,'',' p_vname --> '||p_vname);
						v_sap_flag := false;
                                            END; 

                                            BEGIN
                                             SELECT extractValue(v_sap_final_data01,'/anlagevermoegen/zugangswert/@betrag'),
                                                    extractValue(v_sap_final_data01,'/anlagevermoegen/abschreibung/restbuchwert/@betrag'),
                                                    extractValue(v_sap_final_data01,'/anlagevermoegen/abschreibung/monatlicher_betrag/@betrag'),
                                                    extractValue(v_sap_final_data01,'/anlagevermoegen/abschreibung/afa_restwert_vor_verl/@betrag'),
                                                    extractValue(v_sap_final_data16,'/anlagevermoegen/zugangswert/@betrag'),
                                                    extractValue(v_sap_final_data16,'/anlagevermoegen/abschreibung/restbuchwert/@betrag'),
                                                    extractValue(v_sap_final_data16,'/anlagevermoegen/abschreibung/monatlicher_betrag/@betrag'),
                                                    extractValue(v_sap_final_data16,'/anlagevermoegen/abschreibung/afa_restwert_vor_verl/@betrag')                                                    
                                             INTO
                                                v_zugangswert_betrag01,
                                                v_restbuchwert_betrag01,
                                                v_monatlicher_betrag01,
                                                v_afa_restwert_vor_verl01,
                                                v_zugangswert_betrag16,
                                                v_restbuchwert_betrag16,
                                                v_monatlicher_betrag16,
                                                v_afa_restwert_vor_verl16                                                
                                             FROM DUAL;

                                            EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Error in extractValue --> '||sqlerrm,'','p_vname --> '||p_vname);
						v_sap_flag := false;
                                            END;   

                                            BEGIN
                                             v_zugangswert_betrag_sum01    := FN_STR_NUMBER_CONV(nvl(v_zugangswert_betrag01,0))    + v_zugangswert_betrag_sum01;
                                             v_restbuchwert_betrag_sum01   := FN_STR_NUMBER_CONV(nvl(v_restbuchwert_betrag01,0))   + v_restbuchwert_betrag_sum01;
                                             v_monatlicher_betrag_sum01    := FN_STR_NUMBER_CONV(nvl(v_monatlicher_betrag01,0))    + v_monatlicher_betrag_sum01;
                                             v_afa_restwert_vor_verl_sum01 := FN_STR_NUMBER_CONV(nvl(v_afa_restwert_vor_verl01,0)) + v_afa_restwert_vor_verl_sum01;
                                             
                                             v_zugangswert_betrag_sum16    := FN_STR_NUMBER_CONV(nvl(v_zugangswert_betrag16,0))    + v_zugangswert_betrag_sum16;
                                             v_restbuchwert_betrag_sum16   := FN_STR_NUMBER_CONV(nvl(v_restbuchwert_betrag16,0))   + v_restbuchwert_betrag_sum16;
                                             v_monatlicher_betrag_sum16    := FN_STR_NUMBER_CONV(nvl(v_monatlicher_betrag16,0))    + v_monatlicher_betrag_sum16;
                                             v_afa_restwert_vor_verl_sum16 := FN_STR_NUMBER_CONV(nvl(v_afa_restwert_vor_verl16,0)) + v_afa_restwert_vor_verl_sum16;                                             
                                            EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Error while getting anlagevermoegen details --> '||sqlerrm,'','p_vname --> '||p_vname);
						v_sap_flag := false;
                                            END;

                                          END LOOP;

					BEGIN   
                                          v_zugangswert_betrag01    := FN_NUMBER_STR_CONV(v_zugangswert_betrag_sum01);
                                          v_restbuchwert_betrag01   := FN_NUMBER_STR_CONV(v_restbuchwert_betrag_sum01);
                                          v_monatlicher_betrag01    := FN_NUMBER_STR_CONV(v_monatlicher_betrag_sum01);
                                          v_afa_restwert_vor_verl01 := FN_NUMBER_STR_CONV(v_afa_restwert_vor_verl_sum01);

                                          v_zugangswert_betrag16    := FN_NUMBER_STR_CONV(v_zugangswert_betrag_sum16);
                                          v_restbuchwert_betrag16   := FN_NUMBER_STR_CONV(v_restbuchwert_betrag_sum16);
                                          v_monatlicher_betrag16    := FN_NUMBER_STR_CONV(v_monatlicher_betrag_sum16);
                                          v_afa_restwert_vor_verl16 := FN_NUMBER_STR_CONV(v_afa_restwert_vor_verl_sum16);                                          
                                        EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Error while getting Final anlagevermoegen details --> '||sqlerrm,'','p_vname --> '||p_vname);
					    v_sap_flag := false;
                                        END; 

                                        BEGIN
                                          SELECT updateXml(v_sap_final_data01,'/anlagevermoegen/zugangswert/@betrag',v_zugangswert_betrag01,
                                                                       '/anlagevermoegen/abschreibung/restbuchwert/@betrag',v_restbuchwert_betrag01,
                                                                       '/anlagevermoegen/abschreibung/monatlicher_betrag/@betrag',v_monatlicher_betrag01,
                                                                       '/anlagevermoegen/abschreibung/afa_restwert_vor_verl/@betrag',v_afa_restwert_vor_verl01
                                                          )
                                          INTO v_sap_final_data01
                                          FROM DUAL;
                                        EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Error v_sap_final_data01 updateXml --> '||sqlerrm,'','p_vname --> '||p_vname);
					    v_sap_flag := false;
                                        END;                                          
                                        
                                        BEGIN
                                          SELECT updateXml(v_sap_final_data16,'/anlagevermoegen/zugangswert/@betrag',v_zugangswert_betrag16,
                                                                       '/anlagevermoegen/abschreibung/restbuchwert/@betrag',v_restbuchwert_betrag16,
                                                                       '/anlagevermoegen/abschreibung/monatlicher_betrag/@betrag',v_monatlicher_betrag16,
                                                                       '/anlagevermoegen/abschreibung/afa_restwert_vor_verl/@betrag',v_afa_restwert_vor_verl16
                                                          )
                                          INTO v_sap_final_data16
                                          FROM DUAL;
                                        EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Error v_sap_final_data16 updateXml --> '||sqlerrm,'','p_vname --> '||p_vname);
					    v_sap_flag := false;
                                        END;
                                        
                                        BEGIN
                                            SELECT XMLTYPE ( 
                                            substr(v_sap_final_data01,1,INSTR (v_sap_final_data01, '</abschreibung>', 1, 1)+14)||
                                            substr(v_sap_final_data16,INSTR (v_sap_final_data16, '<abschreibung', 1, 1),
                                                    INSTR (v_sap_final_data16, '</anlagevermoegen>', 1, 1)+18)
                                                           )         
                                            INTO v_sap_final_data
                                            FROM DUAL;                                        
                                        EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','55 Error in final sap_final_data --> '||sqlerrm,'','p_vname --> '||p_vname);
					    v_sap_flag := false;
                                        END;

					/*
                                          SELECT updateXml(v_sap_final_data,'/anlagevermoegen/zugangswert/@betrag',v_zugangswert_betrag,
                                                                       '/anlagevermoegen/abschreibung/restbuchwert/@betrag',v_restbuchwert_betrag,
                                                                       '/anlagevermoegen/abschreibung/monatlicher_betrag/@betrag',v_monatlicher_betrag,
                                                                       '/anlagevermoegen/abschreibung/afa_restwert_vor_verl/@betrag',v_afa_restwert_vor_verl
                                                          )
                                          INTO v_sap_final_data
                                          FROM DUAL;
					 */

                                       END IF;
				       -- Fix for New SAP 01 and 16 -- Ends here

                                    BEGIN
                                       SELECT deleteXML(deleteXML(
                                                           deleteXML(
                                                              deleteXML(v_sap_final_data,
                                                          '/anlagevermoegen/abschreibung/@aufloesung_ende_glz'),
                      				                              '/anlagevermoegen/abschreibung/afa_restwert_vor_verl'), 
							                                                '/anlagevermoegen/abschreibung/monatlicher_betrag'),  -- Fix for 25822
                                                                '/anlagevermoegen/abschreibung/@aufloesung_ende')
                                       INTO v_sap_final_data
                                       FROM DUAL;
                                    EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Error in deleteXML --> '||sqlerrm,'','p_vname --> '||p_vname);
                                        v_sap_flag := false;
                                    END;

                                    BEGIN
                                       SELECT appendChildXML(l_cntrct_det,'/vorgang/direktvertrag/vertrag',v_sap_final_data)
                                       into l_cntrct_det
                                       FROM dual;
                                    EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Error in appendChildXML --> '||sqlerrm,'','p_vname --> '||p_vname);
                                        v_sap_flag := false;
                                    END;

                                 END IF;
                              EXCEPTION
                              WHEN NO_DATA_FOUND
                              THEN
                                 Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','NO SAP DATA FOUND  FOR ','', p_vname ||'   '|| 'for the company number   :' ||lpad(p_comp_num,3,0));
                                 v_sap_flag := false;
                              WHEN OTHERS
                              THEN
                                 p_o_n_ret_flg := 1;
                                 Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'FINAL_TRIG_XML_FILE_CREATION - sap data '||','||g_v_pkg_id, SQLERRM);
                                 v_sap_flag := false;
                              END;
                           END IF;
                           /*  IF v_risikovorsorge IS NULL
                           THEN
                           doc_risk := dbms_xmldom.newDOMDocument;
                           node := dbms_xmldom.makeNode(doc_risk);
                           elem := dbms_xmldom.createElement(doc_risk, 'risikovorsorge');
                           dbms_xmldom.setAttribute(elem, 'prozent',v_i_n_risk_val);
                           dbms_xmldom.setAttribute(elem, 'bezugszeitraum','JAHR');
                           cur_node := dbms_xmldom.appendChild(node, dbms_xmldom.makeNode(elem));
                           dbms_xmldom.writeToBuffer(doc_risk,v_risikovorsorge_var,'UTF8');
                           dbms_xmldom.freeDocument(doc_risk);
                           v_risikovorsorge := XMLTYPE(v_risikovorsorge_var);

                           v_risk_csv := p_vname||','||v_i_n_risk_val||','||p_acquisition;
                           UTL_FILE.put_line (lf_riskfile_handle,v_risk_csv);
                           UTL_FILE.fflush(lf_riskfile_handle);
                           END IF;
                           */
                           doc := dbms_xmldom.newdomdocument(l_cntrct_det);
                           Element_v := dbms_xmldom.getDocumentElement(doc);

                           IF(v_sap_flag = TRUE)
                           THEN
                                 tnodeList := dbms_xmldom.getElementsByTagName(Element_v,'vertragsheader');

                                 tnode :=     xmldom.item(tnodeList,0);
                                 v_element_vetrag := xmldom.makeElement(tnode );
                                 tnodeListAnlag := dbms_xmldom.getElementsByTagName(Element_v,'anlagevermoegen');

                                 --pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','count='||xmldom.getLength(tnodeListAnlag),'', '' );

                                 tnode1 :=     xmldom.item(tnodeListAnlag,0);
                                 Element_v1 := xmldom.makeElement(tnode1);
                                 v_sap_zugangsdatum := getXMLValue(tnode1,'zugangsdatum');
                                 dbms_xmldom.setAttribute(Element_v1,'faelligkeit_awert',v_sap_zugangsdatum);

                           /*    tnodeList1 := dbms_xmldom.getElementsByTagName(Element_v1,'abschreibung');
                                 tnode1 :=     xmldom.item(tnodeList1,0);
                                 Element_v1 := xmldom.makeElement(tnode1);
                                 dbms_xmldom.setAttribute(Element_v1,'aufloesung_ende',v_vende_verlaengerung); */

                                 v_index_cnt := v_index_cnt + 1;
                                 dbms_xmldom.setAttribute(v_element_vetrag,'zugangsdatum',v_sap_zugangsdatum);

                           END IF;
                        --   dbms_xmldom.writeToBuffer(doc,v_result_var,'UTF8');
                           DBMS_LOB.CreateTemporary(v_result_var, TRUE);
                           dbms_xmldom.writeToClob(doc,v_result_var,'UTF8');
                           v_length := dbms_lob.getlength(v_result_var);

                           vstart := 1;
                           v_bytelen := 32000;
                           if(v_length > 32000)
                           THEN
                                   v_curr_length := v_length;
                                   WHILE(vstart < v_length and v_bytelen > 0)
                                   LOOP
                                           v_result_buff := null;
                                           dbms_lob.read(v_result_var,v_bytelen,vstart,v_result_buff);
                                           UTL_FILE.put (v_output_file_handle,v_result_buff);
                                           UTL_FILE.fflush(v_output_file_handle);                                        
                                           vstart := vstart + v_bytelen;
                                           v_curr_length := v_curr_length - v_bytelen;
                                           if(v_curr_length < 32000)
                                           THEN
                                                v_bytelen := v_curr_length;
                                           END IF;
                                   END LOOP;
                           ELSE
                                   UTL_FILE.put_line (v_output_file_handle,v_result_var);
                                   UTL_FILE.fflush(v_output_file_handle);
                           END IF;

                           dbms_xmldom.freeDocument(doc);
                           v_record_count :=v_record_count +1;
                  END LOOP;
               END IF;

               EXIT WHEN cur_contract_xml1%NOTFOUND;
               END LOOP;
               close cur_contract_xml1;

               DBMS_OUTPUT.put_line('record count = '||v_record_count);

               UTL_FILE.put_line (v_output_file_handle,'</bestand>');

               UTL_FILE.fflush(v_output_file_handle);

               UTL_FILE.fclose (v_output_file_handle);

               /*DOMParserUtil('OUTGOING_DIR',v_output_file_name,'Bestand.dtd');*/

         END LOOP;

         IF p_comp_num = 599 THEN
         UTL_FILE.fclose (v_filelist_599_fp);
         ELSE
         UTL_FILE.fclose (v_filelist_n599_fp);         
         END IF;

             
      
      ELSE
         Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','NO Records Available to be written to the output xml file ','','');
         RAISE v_tech_err;
      END IF;

EXCEPTION
WHEN OTHERS
THEN
      p_o_n_ret_flg := 4;
      Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'FINAL_TRIG_XML_FILE_CREATION'||','||g_v_pkg_id, 'Contract Number '||p_vname ||SQLERRM);
--Takes 17 mins
END FINAL_TRIG_XML_FILE_CREATION;

FUNCTION occurs (csearchexpression NVARCHAR2, cexpressionsearched CLOB)
      RETURN SMALLINT DETERMINISTIC
      AS
      occurs           SMALLINT := 0;
      start_location   SMALLINT := INSTR (cexpressionsearched, csearchexpression);
BEGIN
      IF cexpressionsearched IS NOT NULL AND csearchexpression IS NOT NULL
      THEN
         WHILE start_location > 0
         LOOP
            occurs := occurs + 1;
            start_location :=
               INSTR (cexpressionsearched,
                      csearchexpression,
                      start_location + 1
                     );
         END LOOP;
      END IF;

RETURN occurs;
END occurs;

PROCEDURE TLL_READ_HISTORY_DATA(p_run_date IN DATE,
                    p_sap_flag IN CHAR,
                    v_return_code OUT NUMBER )
        IS
   v_max_date           DATE      := NULL;
   lf_file_handle       UTL_FILE.FILE_TYPE;
   v_read_pkg_id        VARCHAR2(100) := 'TLL_READ_HISTORY_DATA';
   v_final_xml_flg      TLL_PROCESSING_TX.FINAL_XML_FLG%TYPE;
   v_p_sap_flag         CHAR(1);
   BEGIN
         v_return_code := 0;
         v_p_sap_flag := p_sap_flag;
         BEGIN --{
            lf_file_handle := Pkg_Batch_Logger.func_open_log(v_read_pkg_id);
         EXCEPTION
         WHEN OTHERS
         THEN
            Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','*filehandle1*', '',sqlerrm);
            RAISE v_file_open_err;
         END; --}

         BEGIN
            SELECT FINAL_XML_FLG
            INTO v_final_xml_flg
            FROM TLL_PROCESSING_TX
            WHERE due_dt = p_run_date;
         EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Data for given run date is not available'||p_run_date,'','');
            RAISE v_tech_err;
         WHEN OTHERS
         THEN
            Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','ERROR IN SELECT BLOCK - TLL_PROCESSING_TX','',SQLERRM);
            RAISE v_tech_err;
         END;

         IF v_final_xml_flg IN ('Y','R')
         THEN
            IF TO_CHAR(TO_DATE(p_run_date, 'DD-MM-YYYY'),'MM') IN (09)
            THEN
               insert into TLL_CNTRCT_DET_TP select * from TLL_CNTRCT_DET_YRLY_TX where due_dt = p_run_date;
               insert into TLL_CNTRCT_STG_TP select * from TLL_CNTRCT_STG_YRLY_TX where due_dt = p_run_date;
               insert into TLL_REFIN_DET_TP select * from TLL_REFIN_DET_YRLY_TX   where due_dt = p_run_date;
               IF(v_p_sap_flag = 'N')
               THEN
                  insert into TLL_SAP_DEPRC_TP select * from TLL_SAP_DEPRC_YRLY_TX   where due_dt= p_run_date;
               END IF;
            ELSIF TO_CHAR(TO_DATE(p_run_date, 'DD-MM-YYYY'),'MM') IN (03,06,09,12)
            THEN
               insert into TLL_CNTRCT_DET_TP  select * from TLL_CNTRCT_DET_QTRLY_TX  where due_dt = p_run_date;
               insert into TLL_CNTRCT_STG_TP select * from TLL_CNTRCT_STG_QTRLY_TX where due_dt = p_run_date;
               insert into TLL_REFIN_DET_TP select * from TLL_REFIN_DET_QTRLY_TX where due_dt = p_run_date;
               IF(v_p_sap_flag = 'N')
               THEN
                  insert into TLL_SAP_DEPRC_TP select * from TLL_SAP_DEPRC_QTRLY_TX where due_dt= p_run_date;
               END IF;
            ELSE
               insert into TLL_CNTRCT_DET_TP select * from TLL_CNTRCT_DET_MON_TX where due_dt = p_run_date;
               insert into TLL_CNTRCT_STG_TP select * from TLL_CNTRCT_STG_MON_TX where due_dt = p_run_date;
               insert into TLL_REFIN_DET_TP select * from TLL_REFIN_DET_MON_TX   where due_dt = p_run_date;
               IF(v_p_sap_flag = 'N')
               THEN
                  insert into TLL_SAP_DEPRC_TP select * from TLL_SAP_DEPRC_MON_TX   where due_dt=  p_run_date;
               END IF;
            END IF;
            UPDATE TLL_PROCESSING_TX
            SET FINAL_XML_FLG = 'R'
            WHERE due_dt = p_run_date;
         END IF;
         v_return_code := 0;
         commit;
         Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0012', v_read_pkg_id, '');
         Pkg_Batch_Logger.proc_log_status (lf_file_handle,'C');
EXCEPTION
WHEN v_file_open_err
THEN
      Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',SQLCODE, SQLERRM);
      Pkg_Batch_Logger.proc_log_status (lf_file_handle,'B');
      v_return_code := 20;  -- This record was not processed.
WHEN OTHERS
THEN
      Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','ERROR in Moving files from historization table to TP ','',SQLERRM);
      Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',SQLCODE, SQLERRM);
      Pkg_Batch_Logger.proc_log_status (lf_file_handle,'B');
      v_return_code := 1;
END TLL_READ_HISTORY_DATA;


PROCEDURE PROC_PUSH_DATA_TO_VITRIA(Stichtag_Date IN DATE,v_comp_num IN VARCHAR2,v_return_code OUT NUMBER,v_rec_limit in NUMBER,v_esb_flag IN varchar2,v_instance_id IN varchar2)
   IS
      lf_file_handle         UTL_FILE.FILE_TYPE;
      v_vit_pkg_id        VARCHAR2(30) := 'TRIGONIS_VIT_PUSH';
      vitria_push_failure    EXCEPTION;
      V_FILE_OPEN_ERR        EXCEPTION;
      g_comp_num VARCHAR2(250) := NULL;

      cursor cur_compno is
      select distinct comp_num from tll_cntrct_det_tp;

      TYPE cur_compno_tab IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
      v_esb_header_rec        PKG_ESB_COMMON_UTILS.esb_header_typ;
      cur_compno_data             cur_compno_tab;
      i NUMBER :=1;
      v_temp_comp_str            VARCHAR2(2000);
       v_status            BOOLEAN;
     -- p_comp_num NUMBER := NULL;
BEGIN
      g_comp_num := v_comp_num;
      BEGIN --{
         lf_file_handle := Pkg_Batch_Logger.func_open_log(v_vit_pkg_id);
      EXCEPTION
      WHEN OTHERS
      THEN
         Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','*filehandle1*', '',sqlerrm);
         RAISE v_file_open_err;
      END; --}


      FOR i IN 1..50 LOOP
             Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0000', '', '');
      END LOOP;

      Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0008', v_vit_pkg_id, '');

      Pkg_Batch_Logger.proc_log(lf_file_handle, 'DEBUG', 'Company Number ='||g_comp_num, '','');
      IF g_comp_num IS NULL OR g_comp_num = 'ALL'
      THEN
         OPEN cur_compno ;
         fetch cur_compno bulk collect into cur_compno_data;
         CLOSE cur_compno ;
      ELSE
         Pkg_Batch_Logger.proc_log(lf_file_handle, 'DEBUG', 'Running for selected company ='||g_comp_num, '','');
         WHILE (g_comp_num IS NOT NULL) OR (i = 8)
         LOOP
            IF (INSTR (g_comp_num, ',', 1, 1) != 0) THEN
               v_temp_comp_str := SUBSTR (g_comp_num, 1, INSTR (g_comp_num, ',',1, 1) - 1);
            ELSE
               v_temp_comp_str := SUBSTR (g_comp_num, 1, LENGTH (g_comp_num));
            END IF;
            cur_compno_data(i) := to_number(v_temp_comp_str,'9G999D99');
            IF (INSTR (g_comp_num, ',', 1, 1) != 0) THEN
               g_comp_num := SUBSTR (g_comp_num, INSTR (g_comp_num, ',', 1, 1) + 1);
            ELSE
               g_comp_num := SUBSTR (g_comp_num, LENGTH (g_comp_num) + 1);
            END IF;
            i :=i +1;
         END LOOP;
       END IF;

       IF(v_esb_flag  = 'ESB')
         THEN
            v_esb_header_rec.prog_id                    := g_v_pkg_id;    
            v_esb_header_rec.batch_typ                := 'TLL';    
            v_esb_header_rec.requestInstanceId      := v_instance_id;
            v_status := PKG_ESB_COMMON_UTILS.FN_CLEANUP_SAP_BATCH_PROCESS(v_esb_header_rec,lf_file_handle);
         END IF;

       FOR i IN cur_compno_data.FIRST .. cur_compno_data.LAST
       LOOP
         Pkg_Batch_Logger.proc_log(lf_file_handle, 'DEBUG', 'Processing Company Number ='||cur_compno_data(i), '','');
           IF(v_esb_flag  = 'ESB')
           THEN
               PRC_BILANZ_TRIGONIS_ESB(v_instance_id,v_rec_limit,Stichtag_Date,cur_compno_data(i),lf_file_handle,v_return_code);
           --ELSE
           --    PRC_BILANZ_TRIGONIS(Stichtag_Date,cur_compno_data(i),lf_file_handle,v_return_code);
           END IF;
       END LOOP;

      IF(v_return_code != 0)
      THEN
         RAISE vitria_push_failure;
      END IF;
      Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0012', v_vit_pkg_id, '');
      Pkg_Batch_Logger.proc_log_status (lf_file_handle,'C');
      v_return_code := 0;

EXCEPTION
WHEN v_file_open_err
THEN
      Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',SQLCODE, SQLERRM);
      Pkg_Batch_Logger.proc_log_status (lf_file_handle,'B');
      v_return_code := 20;  -- This record was not processed.
WHEN OTHERS
THEN
      Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',SQLERRM,'');
      Pkg_Batch_Logger.proc_log_status (lf_file_handle,'B');
      v_return_code := 16;  -- Fatal. Problem needs to be corrected and program re-run
END PROC_PUSH_DATA_TO_VITRIA;

/*PROCEDURE PRC_BILANZ_TRIGONIS (
           p_stitchtagdate IN DATE,
                 v_comp_num IN NUMBER,
           lf_file_handle IN UTL_FILE.file_type,
           p_err_cd OUT VARCHAR2
                               ) IS

  CURSOR cur_trig IS
         SELECT DISTINCT LPAD(comp_num, 4, 0) comp_num, obj_pkg_num, '01' deprc_area_cd,
                TO_CHAR(due_dt, 'YYYYMMDD') cur_effctv_dt
         FROM   TLL_CNTRCT_STG_TP 
         where DUE_DT = p_stitchtagdate
     AND comp_num = v_comp_num
         order by obj_pkg_num;


      v_no_trig_rec                 PLS_INTEGER := 0;
      -- Vitria
      v_loop_counter                PLS_INTEGER := 1;
      data_length                   PLS_INTEGER;
      max_length                    PLS_INTEGER := 32000;
      remaining_length              PLS_INTEGER;
      vitria_push_failure           EXCEPTION;
BEGIN
      v_batch_job_number := 0 ;
      BEGIN
         DELETE FROM tll_sap_deprc_tp 
         WHERE due_dt = p_stitchtagdate
           AND COMP_NUM = v_comp_num ;

         COMMIT;

         DELETE FROM vit_ubc_ir_bilanz_batch_det@dl_ubc_vit 
         where comp_num = v_comp_num;

         COMMIT;
      EXCEPTION
      WHEN OTHERS
      THEN
         p_err_cd := 20;
         Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',SQLERRM,'');
         RAISE vitria_push_failure;
      END;

      BEGIN
         SELECT NVL(MAX(batch_num),0) + 1
         INTO   v_batch_job_number
         FROM   vit_ubc_ir_bilanz_batch_det@dl_ubc_vit;
      EXCEPTION
      WHEN OTHERS
      THEN
              v_batch_job_number := 0;
      END ;

      FOR v_cur IN cur_trig
      LOOP
         v_no_trig_rec := v_no_trig_rec + 1;

         IF MOD(v_no_trig_rec, 5000) = 1 THEN --generating batch job number at first then at interval of 5000
            COMMIT;
            v_batch_job_number := v_batch_job_number + 1 ;
         END IF;

         INSERT INTO vit_ubc_ir_bilanz_batch_det@dl_ubc_vit
                     (
                     comp_num,
                     obj_pkg_num,
                     afabe,
                     cur_effctv_dt,
                     batch_num
                     )
         VALUES      (
                     v_cur.comp_num,
                     v_cur.obj_pkg_num,
                     v_cur.deprc_area_cd,
                     v_cur.cur_effctv_dt,
                     v_batch_job_number
                     );
      END LOOP;
      COMMIT;
      p_err_cd := 0; --Sucess Full Completion
EXCEPTION
WHEN OTHERS
THEN
      Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',SQLERRM,'');
      p_err_cd := 20; --fatal error
END PRC_BILANZ_TRIGONIS; */

PROCEDURE PRC_BILANZ_TRIGONIS_ESB (
                   v_instance_id IN VARCHAR2,
                   p_rec_limit in NUMBER,
                                   p_stitchtagdate IN DATE,
                   v_comp_num IN NUMBER,
                                   lf_file_handle IN UTL_FILE.file_type,
                                   p_err_cd OUT VARCHAR2
                                 ) IS
/*    SELECT DISTINCT LPAD(comp_num, 4, 0) comp_num, obj_pkg_num, '01' deprc_area_cd,
                TO_CHAR(due_dt, 'YYYYMMDD') cur_effctv_dt
         FROM   TLL_CNTRCT_STG_TP 
         where DUE_DT = p_stitchtagdate
     AND comp_num = v_comp_num
         order by obj_pkg_num;
     */

   v_esb_header_rec        PKG_ESB_COMMON_UTILS.esb_header_typ;
   v_batch_grp_id               VARCHAR2(32);
   v_status            BOOLEAN;
   v_prcss_dt                   DATE;   
   v_esbhdr_det_xml        xmltype;
   v_xml_det            xmltype;
   CURSOR cur_trig IS
    SELECT XMLAgg(    
            XMLElement("IT_TRIGONIS_IN",
                XMLElement("BUKRS",comp_num),
                XMLElement("ANLN1",obj_pkg_num),
                XMLElement("AFABE",deprc_area_cd),
                XMLElement("DATE_CALCULATE",cur_effctv_dt)                                        
            )
           )ir_xml_det,batch_job_num,count(1) tot_entr
    FROM ( 
        SELECT comp_num,obj_pkg_num,deprc_area_cd,cur_effctv_dt,trunc(rownum/p_rec_limit)+1 batch_job_num
        FROM          (
             SELECT DISTINCT LPAD(comp_num, 4, 0) comp_num, obj_pkg_num, 
                -- Fix for New 16 SAP Depreciation -- 3.5
                --'01' deprc_area_cd,
                '' deprc_area_cd,
                TO_CHAR(due_dt, 'YYYYMMDD') cur_effctv_dt
             FROM   TLL_CNTRCT_STG_TP 
             where  DUE_DT = p_stitchtagdate
             and    comp_num = v_comp_num
         
        )
        order by obj_pkg_num
    )
    GROUP BY batch_job_num;


      v_no_trig_rec                 PLS_INTEGER := 0;
      -- Vitria
      v_loop_counter                PLS_INTEGER := 1;
      data_length                   PLS_INTEGER;
      max_length                    PLS_INTEGER := 32000;
      remaining_length              PLS_INTEGER;
      vitria_push_failure           EXCEPTION;

BEGIN
      v_batch_job_number := 0 ;
      BEGIN
           DELETE FROM tll_sap_deprc_tp 
           WHERE due_dt = p_stitchtagdate
             AND COMP_NUM = v_comp_num ;

           COMMIT;
      EXCEPTION
      WHEN OTHERS
      THEN
         p_err_cd := 20;
         Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',SQLERRM,'');
         RAISE vitria_push_failure;
      END;
/*
      BEGIN
         SELECT NVL(MAX(batch_num),0) + 1
         INTO   v_batch_job_number
         FROM   vit_ubc_ir_bilanz_batch_det@dl_ubc_vit;
      EXCEPTION
      WHEN OTHERS
      THEN
              v_batch_job_number := 0;
      END ;*/
      
      v_prcss_dt:= p_stitchtagdate ;

      BEGIN
          SELECT UNIQUEKEY 
          into v_batch_grp_id
          FROM DUAL;

          v_esb_header_rec.prog_id                    := g_v_pkg_id;    
          v_esb_header_rec.batch_typ                := 'TLL';    
          v_esb_header_rec.requestInstanceId            := v_instance_id;
          v_esb_header_rec.repost_flag                := false;
          v_esb_header_rec.applicationName                := 'TLL';
          v_esb_header_rec.batch_grp_id                := v_batch_grp_id;
          v_esb_header_rec.batch_end                := false;
          v_esb_header_rec.prcss_dt                 := v_prcss_dt;
          v_status := PKG_ESB_COMMON_UTILS.FN_START_SAP_BATCH_PROCESS(v_esb_header_rec,lf_file_handle);
      END;

      FOR v_cur IN cur_trig
      LOOP
            v_no_trig_rec := v_no_trig_rec + 1;

            IF MOD(v_no_trig_rec, 5) = 1 THEN --generating batch job number at first then at interval of 5000
            COMMIT;
            END IF;

          v_batch_job_number := v_batch_job_number + 1 ;

          SELECT XMLElement("Z_DL_UCS_TRIGONIS",XMLElement("INPUT",XMLElement("I_NUMBER_OF_ENTRIES",v_cur.tot_entr)),
                   -- Fix for New 15 SAP Depreciation -- 3.7 
                   XMLELEMENT ("IT_TRIGONIS_AFABE_IN",XMLELEMENT ("AFABE",'01')),                   
                   XMLELEMENT ("IT_TRIGONIS_AFABE_IN",XMLELEMENT ("AFABE",'15')),
            v_cur.ir_xml_det    )
          into v_xml_det
          FROM dual;

            v_esb_header_rec.batch_seq_num := v_no_trig_rec;
           v_esb_header_rec.batch_job_num :=v_batch_job_number;
            v_esbhdr_det_xml := PKG_ESB_COMMON_UTILS.FN_GET_ESB_HEADER(v_esb_header_rec,lf_file_handle);

            INSERT INTO TLL_ESB_BATCH_TRNSFR_DET_TP
            (    
               BATCH_GRP_ID,
               BATCH_JOB_NUM, 
               ESB_HEADER_DATA,
               BATCH_EVENT_DATA, 
               TRNSFR_STAT, 
               CRDT_DT, 
               CRDT_USR
            )
            VALUES(
               v_batch_grp_id,
               v_batch_job_number,
               v_esbhdr_det_xml,
               v_xml_det,
               'R',
               sysdate,
               g_v_pkg_id
            );

      END LOOP;
      v_status := PKG_ESB_COMMON_UTILS.FN_END_SAP_BATCH_PROCESS(v_esb_header_rec,lf_file_handle);

      COMMIT;
      p_err_cd := 0; --Sucess Full Completion
EXCEPTION
WHEN OTHERS
THEN
      Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',SQLERRM,'');
      p_err_cd := 20; --fatal error
END PRC_BILANZ_TRIGONIS_ESB;

/*PROCEDURE PRC_HOST_COMM(p_stream VARCHAR2,p_stitchtagdate IN DATE) AS
v_vitria_path                 VARCHAR2(1000);
v_prog_id                     VARCHAR2(30)    := 'PRC_HOST_COMM';
v_pkg_prog_id                 VARCHAR2(30)    := 'PRC_HOST_COMM';
if_file_handle                UTL_FILE.FILE_TYPE;
v_trg_job                     v_tab_job_id;
v_cnt                         PLS_INTEGER := 0;
v_ercd                        PLS_INTEGER;
v_vitria_bw_err               EXCEPTION;
v_file_open_err               EXCEPTION;
-- Trigonis Transfer

CURSOR cur_trig_vit IS
SELECT DISTINCT batch_num batch_num
FROM   vit_ubc_ir_bilanz_batch_det@dl_ubc_vit;

BEGIN
  BEGIN
     if_file_handle := Pkg_Batch_Logger.func_open_log(v_prog_id);
  EXCEPTION
     WHEN OTHERS THEN
        dbms_output.put_line('Error while opening file');
        RETURN;
  END ;

FOR i IN 1 .. 15 LOOP
         Pkg_Batch_Logger.proc_log(if_file_handle, 'INFO', 'BAT_I_0000', '','');
END LOOP;

v_vitria_path :=  func_vitria_path(if_file_handle); -- Get Vitria Path
IF LTRIM(RTRIM(v_vitria_path)) IS NULL THEN
        RAISE v_vitria_bw_err;
END IF;
Pkg_Batch_Logger.proc_log(if_file_handle, 'DEBUG', 'value for p_stream'||p_stream, '','');

Pkg_Batch_Logger.proc_log(if_file_handle, 'DEBUG', 'Inside TRG stream', '','');
FOR cur_trig IN cur_trig_vit
LOOP
   v_trg_job(v_cnt) := cur_trig.batch_num;
   v_cnt  := v_cnt + 1;
END LOOP;
Pkg_Batch_Logger.proc_log(if_file_handle, 'DEBUG', 'B4 calling vitria', '','');
prc_vitria_transfer(p_stitchtagdate,v_vitria_path, v_trg_job, p_trgns_tran_id,v_ercd,if_file_handle);
Pkg_Batch_Logger.proc_log(if_file_handle, 'DEBUG', 'return code from vitra'||v_ercd, '','');
IF (v_ercd > 0 ) THEN
   RAISE v_vitria_bw_err;
END IF;
Pkg_Batch_Logger.proc_log_status(if_file_handle, 'C');
Pkg_Batch_Logger.proc_close_log(if_file_handle);

EXCEPTION
    WHEN v_file_open_err THEN
        NULL;
    WHEN v_vitria_bw_err THEN
            Pkg_Batch_Logger.proc_log(
            if_file_handle, 'FATAL', 'BAT_F_9999','Vitria Connectivity Error ',
            v_pkg_prog_id
         );
    WHEN OTHERS THEN
         Pkg_Batch_Logger.proc_log(
            if_file_handle, 'FATAL', 'BAT_F_9999', SQLERRM,
            v_pkg_prog_id
         );
ROLLBACK;

END PRC_HOST_COMM;*/

FUNCTION func_vitria_path (if_file_handle utl_file.file_type) RETURN VARCHAR2 IS
  v_dir                         VARCHAR2(1000) := ' ';
  v_prog_id                     VARCHAR2(100)  := '' ;
  v_pkg_id                      VARCHAR2(100)  := '' ;
  v_pkg_prog_id                 VARCHAR2(1000) := '';
BEGIN
   v_prog_id                     := 'FUNC_VITRIA_PATH';
   v_pkg_prog_id  := v_pkg_id || ',' || v_prog_id; --variable to store package and program name

   SELECT '/usr/bin/sh ' || TRIM(directory_path) || '/bin/sapbatchpub.sh '
   INTO   v_dir
   FROM   all_directories
   WHERE  directory_name = 'VITRIA_DIR';
   RETURN v_dir;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      Pkg_Batch_Logger.proc_log(
         if_file_handle, 'DEBUG', 'vitria Directory Not Available ', '', ''
      );
      Pkg_Batch_Logger.proc_log(
         if_file_handle, 'FATAL', 'BAT_F_9999',SQLERRM,
         v_pkg_prog_id
      ); --caution dont remove sqlcode here
      Pkg_Batch_Logger.proc_log_status(if_file_handle, 'S');
      RETURN v_dir;
   WHEN OTHERS THEN
     Pkg_Batch_Logger.proc_log(
         if_file_handle, 'FATAL', 'BAT_F_9999', SQLERRM,
         v_pkg_prog_id
      ); --caution dont remove sqlcode here
      Pkg_Batch_Logger.proc_log_status(if_file_handle, 'S');
      RETURN v_dir;
END func_vitria_path;

PROCEDURE prc_vitria_transfer(p_stitchtagdate IN DATE,
                              p_vitria_path IN VARCHAR2,
                              p_tab_jobnum IN v_tab_job_id,
                              p_tranid IN VARCHAR2,
                              p_ercd OUT PLS_INTEGER,
                              if_file_handle utl_file.file_type) IS
   v_bulkbatch_job               VARCHAR2(32000) := ' ';
   v_loop_counter                PLS_INTEGER := 1;
   data_length                   PLS_INTEGER;
   max_length                    PLS_INTEGER := 220;   -- To Restrict The Size of Command to less Than 255
   remaining_length              PLS_INTEGER;
   v_ercd                                PLS_INTEGER;
   v_vitria_bw_err               EXCEPTION;
BEGIN
   remaining_length := (max_length - LENGTH(p_vitria_path || ' ' || p_tranid));
   Pkg_Batch_Logger.proc_log(if_file_handle, 'DEBUG', 'Inisde vit trans proc', '','');
   Pkg_Batch_Logger.proc_log(if_file_handle, 'DEBUG', 'batch job cnt'||p_tab_jobnum.COUNT, '','');
   IF (p_tab_jobnum.COUNT > 0) THEN
      <<non_zero_indx>>
      BEGIN
         FOR i IN p_tab_jobnum.FIRST .. p_tab_jobnum.LAST LOOP
            data_length := LENGTH(p_tab_jobnum(i) );

            IF ( (remaining_length - data_length) > 0) THEN
               IF (v_loop_counter > 1) THEN
                  v_bulkbatch_job := TRIM(v_bulkbatch_job) ||'#'|| TRIM(p_tab_jobnum(i) );
                  remaining_length := remaining_length - data_length + 1;
               ELSE
                  v_bulkbatch_job := p_tab_jobnum(i);
               END IF;
            ELSE
               Host_Command(p_vitria_path|| p_tranid || trim(v_bulkbatch_job),v_ercd);
                  IF (v_ercd > 0 ) THEN
                     RAISE v_vitria_bw_err;
                  END IF;
               remaining_length := max_length
                                   - LENGTH(
                                        p_vitria_path || ' ' || p_tranid
                                     ); -- Intializing Remaining Length
               v_loop_counter := 1; -- Intializing loop counter to add #
               v_bulkbatch_job := p_tab_jobnum(i);
            END IF;

            v_loop_counter := v_loop_counter + 1;
         END LOOP;

         IF TRIM(v_bulkbatch_job) IS NOT NULL THEN
            Host_Command(p_vitria_path|| p_tranid || trim(v_bulkbatch_job),v_ercd);
               IF (v_ercd > 0 ) THEN
                     RAISE v_vitria_bw_err;
               END IF;
         END IF;
      END non_zero_indx;
   END IF;
   p_ercd := 0;

   UPDATE TLL_PROCESSING_TX
   SET    SAP_DEPRC_IMPORT_FLG = 'Y'
   WHERE  DUE_DT   = p_stitchtagdate;

EXCEPTION
WHEN VALUE_ERROR
THEN
   p_ercd := 1;
   Pkg_Batch_Logger.proc_log(if_file_handle, 'DEBUG', 'inside value error exce', '','');
WHEN v_vitria_bw_err
THEN
   p_ercd := 3;
   Pkg_Batch_Logger.proc_log(if_file_handle, 'DEBUG', 'inside vit bw err excep', '','');
WHEN OTHERS
THEN
   Pkg_Batch_Logger.proc_log(if_file_handle, 'DEBUG', 'inisde when other excep', '','');
   p_ercd := 2;
END prc_vitria_transfer;

PROCEDURE DOMParserUtil(dir IN varchar2,
                        inpfile IN varchar2,
            inpdtd IN varchar2)
            is
p xmlparser.parser;
doc xmldom.DOMDocument;
dt xmldom.DOMDocumentType;

-- prints elements in a document
procedure printElements(doc xmldom.DOMDocument) is
nl xmldom.DOMNodeList;
len number;
n xmldom.DOMNode;

begin
   -- get all elements
   nl := xmldom.getElementsByTagName(doc, '*');
   len := xmldom.getLength(nl);

   -- loop through elements
   for i in 0..len-1 loop
      n := xmldom.item(nl, i);
      dbms_output.put(xmldom.getNodeName(n) || ' ');
   end loop;

   --dbms_output.put_line('');--
end printElements;

-- prints the attributes of each element in a document
procedure printElementAttributes(doc xmldom.DOMDocument) is
nl xmldom.DOMNodeList;
len1 number;
len2 number;
n xmldom.DOMNode;
e xmldom.DOMElement;
nnm xmldom.DOMNamedNodeMap;
attrname varchar2(100);
attrval varchar2(100);

begin

   -- get all elements
   nl := xmldom.getElementsByTagName(doc, '*');
   len1 := xmldom.getLength(nl);

   -- loop through elements
   for j in 0..len1-1 loop
      n := xmldom.item(nl, j);
      e := xmldom.makeElement(n);
      --dbms_output.put_line(xmldom.getTagName(e) || ':');--

      -- get all attributes of element
      nnm := xmldom.getAttributes(n);

     if (xmldom.isNull(nnm) = FALSE) then
        len2 := xmldom.getLength(nnm);

        -- loop through attributes
        for i in 0..len2-1 loop
           n := xmldom.item(nnm, i);
           attrname := xmldom.getNodeName(n);
           attrval := xmldom.getNodeValue(n);
          -- dbms_output.put(' ' || attrname || ' = ' || attrval);--
        end loop;
       -- dbms_output.put_line('');--
     end if;
   end loop;

end printElementAttributes;

begin

-- new parser
  --dbms_output.put_line('Test1');--
   p := xmlparser.newParser;
  --dbms_output.put_line('Test2');--
-- set some characteristics
   xmlparser.setValidationMode(p, FALSE);
  -- xmlparser.setErrorLog(p, dir || '/' || e^rrfile);
   xmlparser.setBaseDir(p, dir);
  -- dbms_output.put_line('Test3');--
-- parse input file
   xmlparser.parse(p, dir || '/' || inpfile);

-- get document
   doc := xmlparser.getDocument(p);

-- Print document elements
   --dbms_output.put('The elements are: ');--
 -- printElements(doc);

-- Print document element attributes
   --dbms_output.put_line('The attributes of each element are: ');--
  -- printElementAttributes(doc);

------------------------------------------------------
-- parse dtd file
------------------------------------------------------
   xmlparser.parseDTD(p,inpdtd,'bestand');
   dt := xmlparser.getDoctype(p);
  -- dbms_output.put_line('Test4');--
--commented the below package since it is deprecated in 19c oracle db version, as the package DOMParserUtil is not used in this proc by Prasanna on 16.10.2020 
   --xmldom.writeExternalDTDToFile(doc, dir || '/' || 'dtdout.txt');
  -- dbms_output.put_line('Test5');--

------------------------------------------------------
-- parse with given DTD file
------------------------------------------------------
   xmlparser.setValidationMode(p, true);
   xmlparser.setDoctype(p, dt);
   --dbms_output.put_line('Test6');--
   --xmlparser.parse(p, dir || '/' || inpfile);

   doc := xmlparser.getDocument(p);


Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','DTD-Validation against xml file -SUCCESSFULLY FINESHED  :'||inpfile,'','');
-- deal with exceptions
exception

when xmldom.INDEX_SIZE_ERR then
   raise_application_error(-20120, 'Index Size error');

when xmldom.DOMSTRING_SIZE_ERR then
   raise_application_error(-20120, 'String Size error');

when xmldom.HIERARCHY_REQUEST_ERR then
   raise_application_error(-20120, 'Hierarchy request error');

when xmldom.WRONG_DOCUMENT_ERR then
   raise_application_error(-20120, 'Wrong doc error');

when xmldom.INVALID_CHARACTER_ERR then
   raise_application_error(-20120, 'Invalid Char error');

when xmldom.NO_DATA_ALLOWED_ERR then
   raise_application_error(-20120, 'Nod data allowed error');

when xmldom.NO_MODIFICATION_ALLOWED_ERR then
   raise_application_error(-20120, 'No mod allowed error');

when xmldom.NOT_FOUND_ERR then
   raise_application_error(-20120, 'Not found error');

when xmldom.NOT_SUPPORTED_ERR then
   raise_application_error(-20120, 'Not supported error');

when xmldom.INUSE_ATTRIBUTE_ERR then
   raise_application_error(-20120, 'In use attr error');
when OTHERS then
Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','DTD-Validation against xml file    :'||inpfile,'',SQLERRM);
End DOMParserUtil;


PROCEDURE PROC_VALIDATION (
                           p_i_d_due_date         IN   DATE,
                           p_i_n_comp_num         IN   VARCHAR2,
                           p_o_n_ret_flg          OUT  NUMBER

                       )
IS

      lf_file_handle                 UTL_FILE.FILE_TYPE;
      v_val_pkg_id                  VARCHAR2(30) := 'PROC_VALIDATION';
      v_file_open_err                EXCEPTION;
      v_exists_err              EXCEPTION;
      g_comp_num                VARCHAR2(250) := NULL;
      g_n_no_exists_con         NUMBER(10)  := 0;
      g_n_no_exists_refin       NUMBER(10)  := 0;
      g_n_no_exists_sap         NUMBER(10)  := 0;
      v_599_flg                 NUMBER(2)   := 0;
      v_n599_flg                NUMBER(2)   := 0;
      v_tgt_dir_name            VARCHAR2(50)   := 'OUTGOING_DIR';
      v_output_file             UTL_FILE.FILE_TYPE; 
      i                         NUMBER :=1;
      v_temp_comp_str                  VARCHAR2(2000);

      cursor cur_compno is
      select distinct comp_num from tll_cntrct_det_tp;

      TYPE cur_compno_tab IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
      cur_compno_data cur_compno_tab;

     
      BEGIN
      p_o_n_ret_flg := 0;
      g_comp_num := p_i_n_comp_num;

       
      BEGIN --{
         lf_file_handle := Pkg_Batch_Logger.func_open_log(v_val_pkg_id);
      EXCEPTION
      WHEN OTHERS
      THEN
         Dbms_Output.put_line('Error While Openning log File :'||SQLERRM);
         RAISE v_file_open_err;
      END; --}


      FOR i IN 1..50 LOOP
             Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0000', '', '');
      END LOOP;

      Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0008', v_val_pkg_id, '');

      Pkg_Batch_Logger.proc_log(lf_file_handle, 'DEBUG', 'Run date = '||p_i_d_due_date, '','');
      Pkg_Batch_Logger.proc_log(lf_file_handle, 'DEBUG', 'Company Numbers ='||g_comp_num, '','');


       BEGIN
       EXECUTE IMMEDIATE 'TRUNCATE TABLE tll_comp_no_lst_tmp';
       EXCEPTION
       WHEN OTHERS THEN
       p_o_n_ret_flg := 20;
       Pkg_Batch_Logger.proc_log(lf_file_handle, 'DEBUG', 'Error in Truncating the table :'||SQLERRM, '','');
       END;


      BEGIN
      SELECT COUNT(1) INTO g_n_no_exists_con
      FROM TLL_CNTRCT_DET_TP
      WHERE DUE_DT = p_i_d_due_date;

      SELECT COUNT(1) INTO g_n_no_exists_refin
      FROM TLL_REFIN_DET_TP
      WHERE DUE_DT = p_i_d_due_date;

      SELECT COUNT(1) INTO g_n_no_exists_sap
      FROM TLL_CNTRCT_STG_TP
      WHERE DUE_DT = p_i_d_due_date;

      IF g_n_no_exists_con = 0 --AND g_n_no_exists_refin = 0 AND g_n_no_exists_sap = 0
      THEN
         RAISE v_exists_err;
      END IF;
      END;


      IF g_comp_num IS NULL OR g_comp_num = 'ALL'
      THEN
         cur_compno_data.DELETE;
         OPEN cur_compno ;
         fetch cur_compno bulk collect into cur_compno_data;
         CLOSE cur_compno ;
      ELSE
         Pkg_Batch_Logger.proc_log(lf_file_handle, 'DEBUG', 'Running for selected company ='||g_comp_num, '','');
         WHILE (g_comp_num IS NOT NULL) OR (i = 8)
         LOOP
            IF (INSTR (g_comp_num, ',', 1, 1) != 0) THEN
               v_temp_comp_str := SUBSTR (g_comp_num, 1, INSTR (g_comp_num, ',',1, 1) - 1);
            ELSE
               v_temp_comp_str := SUBSTR (g_comp_num, 1, LENGTH (g_comp_num));
            END IF;
            cur_compno_data(i) := to_number(v_temp_comp_str,'9G999D99');
            IF (INSTR (g_comp_num, ',', 1, 1) != 0) THEN
               g_comp_num := SUBSTR (g_comp_num, INSTR (g_comp_num, ',', 1, 1) + 1);
            ELSE
               g_comp_num := SUBSTR (g_comp_num, LENGTH (g_comp_num) + 1);
            END IF;
            i :=i +1;
         END LOOP;
       END IF;


       BEGIN

         FOR i IN cur_compno_data.FIRST .. cur_compno_data.LAST
         LOOP
       
         INSERT INTO tll_comp_no_lst_tmp VALUES (cur_compno_data(i));
         
         END LOOP;
       
       EXCEPTION

       WHEN 
       OTHERS THEN
       p_o_n_ret_flg := 20;
       Pkg_Batch_Logger.proc_log(lf_file_handle,'DEBUG','Error in Insertation of records'||SQLERRM,'','');
       END;


            BEGIN
               v_599_flg :=0;
               SELECT 1
               INTO v_599_flg 
               FROM
               tll_comp_no_lst_tmp 
               WHERE comp_num = 599;
            EXCEPTION
            WHEN NO_DATA_FOUND 
            THEN
            v_599_flg :=0;
            END;
            
            BEGIN  
               v_n599_flg  := 0;
               SELECT 1
               INTO v_n599_flg
               FROM
               tll_comp_no_lst_tmp 
               WHERE comp_num <> 599 AND ROWNUM <2;
            EXCEPTION
            WHEN NO_DATA_FOUND THEN
            v_n599_flg  := 0;
            END;
            
       
       IF v_599_flg = 1 THEN

       v_output_file     := UTL_FILE.FOPEN(v_tgt_dir_name,'Trig_comp_599.txt', 'W', 32767);
       UTL_FILE.FCLOSE (v_output_file);
       END IF;

       IF v_n599_flg = 1 THEN

       v_output_file     := UTL_FILE.FOPEN(v_tgt_dir_name,'Trig_comp_n599.txt', 'W', 32767);
       UTL_FILE.FCLOSE (v_output_file);

       END IF;




      Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0012', v_val_pkg_id, '');
      Pkg_Batch_Logger.proc_log_status (lf_file_handle,'C');


EXCEPTION
WHEN v_file_open_err
THEN
      p_o_n_ret_flg := 20;
WHEN v_exists_err THEN
      p_o_n_ret_flg :=30;
      Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PROC_VALIDATION        = ','',p_o_n_ret_flg);
      Pkg_Batch_Logger.proc_log(lf_file_handle,'DEBUG','RECORDS ALREADY DELETED FOR THE CURRENT DATE','','');
      Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019','PROC_VALIDATION'||','||v_val_pkg_id,NULL);
      Pkg_Batch_Logger.proc_log_status (lf_file_handle,'B');
WHEN OTHERS
THEN
      Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',SQLERRM,'');
      Pkg_Batch_Logger.proc_log_status (lf_file_handle,'B');
      p_o_n_ret_flg := 16;  -- Fatal. Problem needs to be corrected and program re-run
END PROC_VALIDATION;


PROCEDURE PROC_POST_VALIDATION (
                                p_i_d_due_date         IN   DATE,
                                p_o_n_ret_flg          OUT  NUMBER

                       )
IS

      lf_file_handle                 UTL_FILE.FILE_TYPE;
      v_post_val_pkg_id                  VARCHAR2(30) := 'PROC_POST_VALIDATION';
      v_file_open_err                EXCEPTION;
      v_tech_err                EXCEPTION;
      v_final_xml_flg           tll_processing_tx.final_xml_flg%type;
      v_bckup_mon_no            NUMBER(10);
      v_bckup_qtrly_no          NUMBER(10);
      v_bckup_yrly_no           NUMBER(10);
BEGIN

      p_o_n_ret_flg := 0;
    
      BEGIN --{
         lf_file_handle := Pkg_Batch_Logger.func_open_log(v_post_val_pkg_id);
      EXCEPTION
      WHEN OTHERS
      THEN
         Dbms_Output.put_line('Error While Openning log File :'||SQLERRM);
         RAISE v_file_open_err;
      END; --}


      FOR i IN 1..50 LOOP
             Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0000', '', '');
      END LOOP;

      Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0008', v_post_val_pkg_id, '');

      Pkg_Batch_Logger.proc_log(lf_file_handle, 'DEBUG', 'Run date = '||p_i_d_due_date, '','');


      BEGIN
      SELECT final_xml_flg
      INTO v_final_xml_flg
      FROM TLL_PROCESSING_TX
      WHERE due_dt  =  p_i_d_due_date;
      EXCEPTION
      WHEN OTHERS
      THEN
      Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',SQLERRM,'TLL_PROCESSING_TX for due dt '||p_i_d_due_date);
      RAISE v_tech_err;
   END;

   BEGIN
      IF (v_final_xml_flg = 'R')
      THEN
         SELECT COUNT(1) INTO v_bckup_mon_no
         FROM TLL_CNTRCT_DET_MON_TX
         WHERE due_dt = p_i_d_due_date;

         SELECT COUNT(1) INTO v_bckup_qtrly_no
         FROM TLL_CNTRCT_DET_QTRLY_TX
         WHERE due_dt = p_i_d_due_date;

         SELECT COUNT(1) INTO v_bckup_yrly_no
         FROM TLL_CNTRCT_DET_YRLY_TX
         WHERE due_dt = p_i_d_due_date;

         IF (v_bckup_mon_no > 0 )
         THEN
            DELETE FROM TLL_SAP_DEPRC_MON_TX
            WHERE due_dt = p_i_d_due_date;

            INSERT INTO TLL_SAP_DEPRC_MON_TX
            SELECT * FROM TLL_SAP_DEPRC_TP
            WHERE due_dt = p_i_d_due_date;
         ELSIF (v_bckup_qtrly_no > 0 ) THEN
            DELETE FROM TLL_SAP_DEPRC_QTRLY_TX WHERE due_dt = p_i_d_due_date;

            INSERT INTO TLL_SAP_DEPRC_QTRLY_TX
            SELECT * FROM TLL_SAP_DEPRC_TP
            WHERE due_dt = p_i_d_due_date;
         ELSIF (v_bckup_yrly_no > 0 )
         THEN
            DELETE FROM TLL_SAP_DEPRC_YRLY_TX
            WHERE due_dt = p_i_d_due_date;

            INSERT INTO TLL_SAP_DEPRC_YRLY_TX
            select * FROM TLL_SAP_DEPRC_TP
            WHERE due_dt = p_i_d_due_date;
         END IF;
         commit;

         IF(v_bckup_mon_no=0 and v_bckup_yrly_no = 0 and v_bckup_qtrly_no = 0)
         THEN
                 Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT','Archive Job is not Run= ','', to_char( p_i_d_due_date,'dd.mm.rrrr') );
         ELSE
                 DELETE FROM TLL_CNTRCT_DET_TP WHERE due_dt = p_i_d_due_date;
                 DELETE FROM TLL_CNTRCT_STG_TP WHERE due_dt = p_i_d_due_date;
                 DELETE FROM TLL_REFIN_DET_TP WHERE due_dt = p_i_d_due_date;
                 DELETE FROM TLL_SAP_DEPRC_TP WHERE due_dt = p_i_d_due_date;
                 commit;
         END IF;
      END IF;

   EXCEPTION
   WHEN OTHERS
   THEN
      Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',SQLERRM,'');
      RAISE v_tech_err;
   END;

   BEGIN
      UPDATE TLL_PROCESSING_TX
      SET   FINAL_XML_FLG = 'Y'
      WHERE DUE_DT        =  p_i_d_due_date;
   EXCEPTION
   WHEN OTHERS THEN
      Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',SQLERRM,'');
      RAISE v_tech_err;
   END;

      Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0012', v_post_val_pkg_id, '');
      Pkg_Batch_Logger.proc_log_status (lf_file_handle,'C');
      
EXCEPTION
WHEN v_file_open_err
THEN
      p_o_n_ret_flg := 20;
WHEN v_tech_err THEN
      p_o_n_ret_flg :=2;
      Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_TRIG_FILE_CREATION        = ','',p_o_n_ret_flg);
      Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019','MAIN_PROC'||','||v_post_val_pkg_id,NULL);
      Pkg_Batch_Logger.proc_log_status (lf_file_handle,'S');
WHEN OTHERS
THEN
      Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',SQLERRM,'');
      Pkg_Batch_Logger.proc_log_status (lf_file_handle,'B');
      p_o_n_ret_flg := 16;  -- Fatal. Problem needs to be corrected and program re-run

END PROC_POST_VALIDATION;





END PKG_TLL_TRIG_FILE_CREATION;
/
