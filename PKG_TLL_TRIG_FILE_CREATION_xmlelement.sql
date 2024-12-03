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
   /*-------------------------------------------------------------------------------------------------*/
   
   
   -- Global variable declarations

   g_v_pkg_id        CONSTANT        VARCHAR2(100) := 'PKG_TLL_TRIG_FILE_CREATION';   /* Variable to Store Package Name */
   g_v_prog_id       CONSTANT        VARCHAR2(100) := 'TLL_TRIG_FILE_CREATION';       /* Variable to Store Program Name */
   g_v_proc_name     CONSTANT        VARCHAR2(100) := 'TLL_TRIG_FILE_CREATION';
   g_v_pkg_prog_id   CONSTANT        VARCHAR2(300) :=  g_v_pkg_id || ' , ' || g_v_prog_id;
   g_v_user          VARCHAR2(40)                  := 'TLL_TRIG_FILE_CREATION_BATCH';
   g_v_err  varchar2(100);
   
   g_v_errtable      VARCHAR2(50);

   lf_file_handle    UTL_FILE.FILE_TYPE;   -- Variable for Log File Handler
   
   v_output_filename   VARCHAR2 (50) ;
   
   v_proc_err        EXCEPTION;
   v_tech_err        EXCEPTION;
   v_exists_err      EXCEPTION;
   v_insert_err      EXCEPTION;
  
   g_n_no_records      NUMBER(5)  := 0;
   
   g_n_no_exists_con   NUMBER(5)  := 0;
   g_n_no_exists_refin NUMBER(5)  := 0;
   g_n_no_exists_sap   NUMBER(5)  := 0;
   -- Public procedure declarations
   TYPE v_tab_job_id IS TABLE OF NUMBER(10) INDEX BY BINARY_INTEGER;
   p_trgns_tran_id      CONSTANT VARCHAR2 (15) := 'LISUBC1008 '; -- Trigonis Transfer ID
   
/**************************************************/
/* Main Procedure which calls all other procedures*/
/**************************************************/


  PROCEDURE MAIN_PROC (
                        p_i_d_process_date     IN   DATE,
                        p_i_d_due_date         IN   DATE,
                        p_i_n_comp_num         IN   NUMBER,
                        p_o_n_ret_flg          OUT  NUMBER
                       );
                       
/********************************************/
/*Procedure to generate the final xml file  */
/********************************************/
    
   
  PROCEDURE FINAL_TRIG_XML_FILE_CREATION (
                                           v_i_d_process_date      IN DATE,
                                           v_i_n_comp_num          IN NUMBER,
                                           v_i_d_due_date          IN DATE,
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
      
/*	PROCEDURE PROC_PUSH_DATA_TO_VITRIA (
                                        Stichtag_Date IN DATE,
                                        v_return_code OUT NUMBER
                                       );
*/
   PROCEDURE PRC_BILANZ_TRIGONIS (
                                   p_stitchtagdate IN DATE,
                                   if_file_handle IN UTL_FILE.file_type, 
                                   p_err_cd OUT VARCHAR2
                                 );

   PROCEDURE PRC_HOST_COMM(p_stream VARCHAR2);

   FUNCTION func_vitria_path  (if_file_handle utl_file.file_type)  RETURN VARCHAR2 ;

   PROCEDURE prc_vitria_transfer(p_vitria_path IN VARCHAR2,
                              p_tab_jobnum IN v_tab_job_id,
                              p_tranid IN VARCHAR2,
                              p_ercd OUT PLS_INTEGER,
                              if_file_handle utl_file.file_type);
   
END PKG_TLL_TRIG_FILE_CREATION;
/

CREATE OR REPLACE PACKAGE BODY PKG_TLL_TRIG_FILE_CREATION 
IS
PROCEDURE MAIN_PROC (
                        p_i_d_process_date     IN   DATE,
                        p_i_d_due_date         IN   DATE,
                        p_i_n_comp_num         IN   NUMBER,
                        p_o_n_ret_flg          OUT  NUMBER
                       )
                       
   IS

   
   BEGIN
   
   p_o_n_ret_flg         := 0;
   
/*-----------------------------------------------*/
/* Initialize File Handle for  Log File Writing  */
/*-----------------------------------------------*/

    BEGIN
        lf_file_handle := Pkg_Batch_Logger.func_open_log(g_v_prog_id);

        EXCEPTION
            WHEN OTHERS  THEN
        DBMS_OUTPUT.PUT_LINE('Unable to open the Spool File due to '||SQLERRM);
    END;   
    
    
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
    Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0008','MAIN_PROC'||','||g_v_pkg_id,'');
    Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT','List of Input Parameters :-', '', '');
    Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT','Input Process date       = ','', to_char( p_i_d_process_date,'dd.mm.rrrr') );
    

   /*------------------------------------------------------------------*/
   /* Check if Input Parameters are Valid                              */
   /*------------------------------------------------------------------*/
   
   /*BEGIN
                SELECT COUNT(1) INTO g_n_no_exists_con 
                  FROM TLL_CONTRACT_DTL_TP 
                 WHERE DUE_DT = p_i_d_process_date; 
                 
                 SELECT COUNT(1) INTO g_n_no_exists_refin 
                  FROM TLL_REFIN_DTL_TP 
                 WHERE DUE_DT = p_i_d_process_date;
                 
                 SELECT COUNT(1) INTO g_n_no_exists_sap 
                  FROM TLL_SAP_DEPR_TP 
                 WHERE DUE_DT = p_i_d_process_date;
                 
                 IF g_n_no_exists_con = 0 OR g_n_no_exists_refin = 0 OR g_n_no_exists_sap = 0 THEN
                  RAISE v_exists_err;
                 END IF;
                                   
            END; */

   
   FINAL_TRIG_XML_FILE_CREATION (
                                 p_i_d_process_date,
                                 p_i_n_comp_num,
                                 p_i_d_due_date,
                                 p_o_n_ret_flg
                                 );
                                 
    IF  p_o_n_ret_flg<> 0
        THEN
            RAISE v_proc_err;
        END IF;
        
        Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_TRIG_FILE_CREATION        = ','',p_o_n_ret_flg);

        Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT',NULL,NULL,NULL);


        Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0012','MAIN_PROC'||','||g_v_pkg_id,NULL);
        Pkg_Batch_Logger.proc_log_status (lf_file_handle,'C');
        
   EXCEPTION
WHEN  v_proc_err THEN
   p_o_n_ret_flg := 1;
   
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_TRIG_FILE_CREATION        = ','',p_o_n_ret_flg);
   Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019','MAIN_PROC'||','||g_v_pkg_id,NULL);
   Pkg_Batch_Logger.proc_log_status (lf_file_handle,'B');
 
WHEN v_tech_err THEN
   p_o_n_ret_flg :=2;
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_TRIG_FILE_CREATION        = ','',p_o_n_ret_flg);
   Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019','MAIN_PROC'||','||g_v_pkg_id,NULL);
   Pkg_Batch_Logger.proc_log_status (lf_file_handle,'S');

WHEN v_exists_err THEN
   p_o_n_ret_flg :=3;
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_TRIG_FILE_CREATION        = ','',p_o_n_ret_flg);
   Pkg_Batch_Logger.proc_log(lf_file_handle,'DEBUG','RECORDS ALREADY DELETED FOR THE CURRENT DATE','','');
   Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019','MAIN_PROC'||','||g_v_pkg_id,NULL);
   Pkg_Batch_Logger.proc_log_status (lf_file_handle,'B');
   

WHEN  OTHERS THEN

/* ------------------------------------------------------- */
/*      Other fatal Errors. Close and Terminate program    */
/* ------------------------------------------------------- */
   p_o_n_ret_flg := 20;
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_TRIG_FILE_CREATION        = ','',p_o_n_ret_flg);
   Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019',  'MAIN_PROC' || ' , ' || g_v_pkg_id, '');
   Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',NULL,SQLERRM);
   Pkg_Batch_Logger.proc_log_status (lf_file_handle,'S');
   Pkg_Batch_Logger.proc_close_log(lf_file_handle);
   

   
   END MAIN_PROC;
                       
    
   
PROCEDURE FINAL_TRIG_XML_FILE_CREATION (
                                           v_i_d_process_date      IN DATE,
                                           v_i_n_comp_num          IN NUMBER,
                                           v_i_d_due_date          IN DATE,
                                           p_o_n_ret_flg          OUT NUMBER
                                          )
IS 
   
doc             dbms_xmldom.DOMDocument;
node            dbms_xmldom.DOMNode;
root_node       dbms_xmldom.DOMNode;
cur_node_bes    dbms_xmldom.DOMNode;
cur_node_vor    dbms_xmldom.DOMNode;
cur_node_dir    dbms_xmldom.DOMNode;
cur_node_ver    dbms_xmldom.DOMNode;

 
elem_bes        dbms_xmldom.DOMElement;
elem_vor        dbms_xmldom.DOMElement;
elem_dir        dbms_xmldom.DOMElement;
elem_ver        dbms_xmldom.DOMElement;


xi_doc_vertragsheader       DBMS_XMLDOM.DOMDOCUMENT;
xi_node_vertragsheader      DBMS_XMLDOM.DOMNODE;
xi_doc_anlagevermoegen      DBMS_XMLDOM.DOMDOCUMENT;
xi_node_anlagevermoegen     DBMS_XMLDOM.DOMNODE;
xi_doc_mietkaufvermoegen    DBMS_XMLDOM.DOMDOCUMENT;
xi_node_mietkaufvermoegen   DBMS_XMLDOM.DOMNODE;
xi_doc_msz                  DBMS_XMLDOM.DOMDOCUMENT;
xi_node_msz                 DBMS_XMLDOM.DOMNODE;
xi_doc_nachgeschaeft        DBMS_XMLDOM.DOMDOCUMENT;
xi_node_nachgeschaeft       DBMS_XMLDOM.DOMNODE;
xi_doc_restwert             DBMS_XMLDOM.DOMDOCUMENT;
xi_node_restwert            DBMS_XMLDOM.DOMNODE;
xi_doc_zahlungsplan         DBMS_XMLDOM.DOMDOCUMENT;
xi_node_zahlungsplan        DBMS_XMLDOM.DOMNODE;
xi_doc_refi_mieten          DBMS_XMLDOM.DOMDOCUMENT;
xi_node_refi_mieten         DBMS_XMLDOM.DOMNODE;
xi_doc_refi_mieten_rw       DBMS_XMLDOM.DOMDOCUMENT;
xi_node_refi_mieten_rw      DBMS_XMLDOM.DOMNODE;
xi_doc_refi_rw              DBMS_XMLDOM.DOMDOCUMENT;
xi_node_refi_rw             DBMS_XMLDOM.DOMNODE;
xi_doc_verwaltungskosten    DBMS_XMLDOM.DOMDOCUMENT;
xi_node_verwaltungskosten   DBMS_XMLDOM.DOMNODE;
xi_doc_risikovorsorge       DBMS_XMLDOM.DOMDOCUMENT;
xi_node_risikovorsorge      DBMS_XMLDOM.DOMNODE;

xixml_anlagevermoegen xmltype := xmltype('<anlagevermoegen zugangsdatum="...">
	                                     <zugangswert betrag="..."/>
	                                     <afa_steuerlich aufloesung_beginn="..." aufloesung_ende_glz="..."
		                                 aufloesung_ende="..." afa_zeit="..." afa_auf_rw="..."
		                                 aufloesungsart="..." degressionsfaktor="..." halbjahresregel="..."
		                                 kontrolldatum_switch="...">
		                                 <restbuchwert betrag="..."/>
		                                 <monatlicher_betrag betrag="..."/>
		                                 <afa_restwert_vor_verl betrag="..."/>
	                                     </afa_steuerlich>
                                         </anlagevermoegen>');

                                                                                    

p_comp_num NUMBER(5);
p_txs_ref_id tll_refin_det_tp.cntrct_id%type;
p_vname  VARCHAR2(34);
p_obj_pkg_num NUMBER; 
v_output_filename  VARCHAR2(50);

cursor cur_cmpno is 
select distinct comp_num from tll_cntrct_det_tp;

TYPE cur_cmpno_tab IS TABLE OF NUMBER INDEX BY PLS_INTEGER;

cur_cmpno_data             cur_cmpno_tab;

cursor cur_contract_xml (v_i_n_cmp_no in number, v_i_d_due_date in date) is
select extract(cntrct_det,'/bestand/vorgang/direktvertrag/vertrag/vertragsheader').getclobval() vertragsheader,
       extract(cntrct_det,'/bestand/vorgang/direktvertrag/vertrag/msz').getclobval() msz,
       extract(cntrct_det,'/bestand/vorgang/direktvertrag/vertrag/nachgeschaeft').getclobval() nachgeschaeft,
       extract(cntrct_det,'/bestand/vorgang/direktvertrag/vertrag/restwert').getclobval() restwert,
       extract(cntrct_det,'/bestand/vorgang/direktvertrag/vertrag/risikovorsorge').getclobval() risikovorsorge,
       extract(cntrct_det,'/bestand/vorgang/direktvertrag/vertrag/mietkaufvermoegen').getclobval() mietkaufvermoegen,
       extract(cntrct_det,'/bestand/vorgang/direktvertrag/vertrag/verwaltungskosten').getclobval() verwaltungskosten,
       extract(cntrct_det,'/bestand/vorgang/direktvertrag/vertrag/zahlungsplan').getclobval() zahlungsplan,
       extract(cntrct_det,'/bestand/vorgang/direktvertrag/vertrag/anlagevermoegen').getclobval() anlagevermoegen,
       extract(cntrct_det,'/bestand/vorgang/direktvertrag/vertrag/txs_reference/@txs_ref_id').getstringval() txs_ref_id,
       extract(cntrct_det,'/bestand/vorgang/@vname').getstringval() vname 
       from tll_cntrct_det_tp 
       where comp_num = v_i_n_cmp_no 
       and   due_dt   = v_i_d_due_date ;

cursor cur_contract_xml1 (v_i_n_cmp_no in number, v_i_d_due_date in date) is
select   cntrct_det
       from tll_cntrct_det_tp 
       where comp_num = v_i_n_cmp_no 
       and   due_dt   = v_i_d_due_date
       AND ROWNUM < 10000;

TYPE cur_contract_tab1 IS TABLE OF cur_contract_xml%ROWTYPE INDEX BY BINARY_INTEGER;

TYPE cur_contract_tab IS TABLE OF tll_cntrct_det_tp.cntrct_det%TYPE INDEX BY BINARY_INTEGER;

cur_contract_data             cur_contract_tab;
--cur_contract_xml_data           cur_contract_xml_tab;

cursor cur_refin_xml (v_i_n_txs_ref_id in VARCHAR2, v_i_d_due_date in date) is
select               extract(refin_det,'/txs_refi_data/refi_contract/refi_mieten_rw').getclobval() refi_mieten_rw,
                     extract(refin_det,'/txs_refi_data/refi_contract/refi_mieten').getclobval() refi_mieten,
                     extract(refin_det,'/txs_refi_data/refi_contract/refi_rw').getclobval() refi_rw   
from                 tll_refin_det_tp
where                 replace(cntrct_id,'-') = TRIM(v_i_n_txs_ref_id);

TYPE cur_refin_tab IS TABLE OF cur_refin_xml%ROWTYPE INDEX BY PLS_INTEGER;

cur_refin_data             cur_refin_tab;


TYPE ref_type IS REF CURSOR;

REFCUR_OBJ_PKG_NUM ref_type;

TYPE REFCUR_OBJ_PKG_NUM_TAB IS TABLE OF NUMBER INDEX BY PLS_INTEGER;

REFCUR_OBJ_PKG_NUM_DATA REFCUR_OBJ_PKG_NUM_TAB;

PROCEDURE PROCESS_CONTRACT IS

l_cntrct_det tll_cntrct_det_tp.cntrct_det%type;
v_vertragsheader        XMLType ;
v_msz        XMLType ;
v_nachgeschaeft        XMLType ;
v_restwert        XMLType ;
v_risikovorsorge        XMLType ;
v_mietkaufvermoegen        XMLType ;
v_verwaltungskosten        XMLType ;
v_zahlungsplan        XMLType ;
v_anlagevermoegen        XMLType ;

v_vorgang XMLType ;
BEGIN
        if cur_contract_data.count > 0   then
         
            FOR i IN cur_contract_data.FIRST .. cur_contract_data.LAST
            LOOP
                l_cntrct_det :=          cur_contract_data(I);
                select replace(extract(l_cntrct_det,'/bestand/vorgang/direktvertrag/vertrag/txs_reference/@txs_ref_id').getstringval() ,'-')
                into p_txs_ref_id
                from dual;

                select extract(l_cntrct_det,'/bestand/vorgang/@vname').getstringval() 
                into p_vname
                from dual;

            
                select  extract(l_cntrct_det,'/bestand/vorgang/direktvertrag/vertrag/vertragsheader') vertragsheader,
                        extract(l_cntrct_det,'/bestand/vorgang/direktvertrag/vertrag/msz') msz,
                        extract(l_cntrct_det,'/bestand/vorgang/direktvertrag/vertrag/nachgeschaeft') nachgeschaeft,
                        extract(l_cntrct_det,'/bestand/vorgang/direktvertrag/vertrag/restwert') restwert,
                        extract(l_cntrct_det,'/bestand/vorgang/direktvertrag/vertrag/risikovorsorge') risikovorsorge,
                        extract(l_cntrct_det,'/bestand/vorgang/direktvertrag/vertrag/mietkaufvermoegen') mietkaufvermoegen,
                        extract(l_cntrct_det,'/bestand/vorgang/direktvertrag/vertrag/verwaltungskosten') verwaltungskosten,
                        extract(l_cntrct_det,'/bestand/vorgang/direktvertrag/vertrag/zahlungsplan') zahlungsplan,
                        extract(l_cntrct_det,'/bestand/vorgang/direktvertrag/vertrag/anlagevermoegen') anlagevermoegen
                into    v_vertragsheader        ,
                        v_msz        ,
                        v_nachgeschaeft        ,
                        v_restwert        ,
                        v_risikovorsorge        ,
                        v_mietkaufvermoegen        ,
                        v_verwaltungskosten        ,
                        v_zahlungsplan        ,
                        v_anlagevermoegen        
                from dual;


                      --  p_txs_ref_id  := cur_contract_data (i).txs_ref_id;

                --        p_vname  := cur_contract_data (i).vname;

                        Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Process_contract:'||p_vname,'', '');    


                        g_n_no_records := g_n_no_records +1;

                        cur_refin_data.delete;

                        OPEN cur_refin_xml (p_txs_ref_id,v_i_d_due_date) ;
                        fetch cur_refin_xml bulk collect into cur_refin_data;  
                        close cur_refin_xml ;

        Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','currefin xml:'||p_vname,'', '');    


  /*                      Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Number of obj_pkg_num  = ','', occurs('asset_num',v_anlagevermoegen.getClobVal()) ||'   '|| 'for the vname    :' ||p_vname);

                        FOR  J IN 1..occurs('asset_num',v_anlagevermoegen.getclobval())
                        LOOP
                                --dbms_output.put_line('SELECT extract(contract_det,''/bestand/vorgang/direktvertrag/vertrag/anlagevermoegen['||J||']/@asset_num'').getnumberval() asset_num FROM tll_contract_dtl_tp where contract_id ='|| p_vname )  ;
                               // OPEN REFCUR_OBJ_PKG_NUM FOR 'SELECT extract(cntrct_det,''/bestand/vorgang/direktvertrag/vertrag/anlagevermoegen['||J||']/@asset_num'').getnumberval() asset_num FROM tll_cntrct_det_tp where cntrct_id ='''|| p_vname||''' ';


                                //FETCH  REFCUR_OBJ_PKG_NUM  INTO REFCUR_OBJ_PKG_NUM_DATA(J);
                        END LOOP;

*/


/*                        FOR i IN   (SELECT EXTRACTVALUE(value(t),'ASSET_CATEGORY')   ASSET_CATEGORY,
                                           EXTRACTVALUE(value(t),'/ASSET_MESSAGE/ASSET_ID_EXTERN')  ASSET_ID_EXTERN,
                                           EXTRACTVALUE(value(t),'/ASSET_MESSAGE/ORG_UNIT')         ORG_UNIT,
                                           EXTRACTVALUE(value(t),'/ASSET_MESSAGE/PARTNER')          PARTNER,
                                           EXTRACTVALUE(value(t),'/ASSET_MESSAGE/ACKNOWLEDGE')      ACKNOWLEDGE,
                                           EXTRACTVALUE(value(t),'/ASSET_MESSAGE/MESSAGE_TYPE')     MESSAGE_TYPE,
                                           EXTRACTVALUE(value(t),'/ASSET_MESSAGE/MESSAGE_ID')       MESSAGE_ID,
                                           EXTRACTVALUE(value(t),'/ASSET_MESSAGE/MESSAGE_NUMBER')   MESSAGE_NUMBER,
                                           EXTRACTVALUE(value(t),'/ASSET_MESSAGE/MESSAGE')          MESSAGE,
                                           EXTRACTVALUE(value(t),'/ASSET_MESSAGE/FIELD')            FIELD
                             FROM TABLE(XMLSEQUENCE(
                                 EXTRACT(v_anlagevermoegen,'anlagevermoegen'))
                                ) t  ) 
                        LOOP
                            DBMS_OUTPUT.PUT_LINE(SUBSTR(i.ASSET_CATEGORY,1,255)||'----'||SUBSTR(i.ASSET_ID_EXTERN,1,255)||'----'||SUBSTR(i.ORG_UNIT,1,255)||'----'||SUBSTR(i.PARTNER,1,255)||'----'||SUBSTR(i.ACKNOWLEDGE,1,255)||'----'||SUBSTR(i.MESSAGE_TYPE,1,255)||'----'||SUBSTR(i.MESSAGE_ID,1,255)||'----'||SUBSTR(i.MESSAGE_NUMBER,1,255)||'----'||SUBSTR(i.MESSAGE,1,255));
                            INSERT INTO UC_TXS_ERROR_LOG_CONTRACTS_TX (ASSET_CTGRY,ASSET_ID_EXTERN)
                            values (SUBSTR(i.ASSET_CATEGORY,1,255),SUBSTR(i.ASSET_ID_EXTERN,1,255));
                        END LOOP; */

--                        Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','testingof obj_pkg_num  = ','', occurs('asset_num',cur_contract_data (i).anlagevermoegen) ||'   '|| 'for the vname    :' ||cur_contract_data (i).vname);
                    

                        elem_vor := dbms_xmldom.createElement(doc, 'vorgang');

                        dbms_xmldom.setAttribute(elem_vor,'vname',p_vname);

                        cur_node_vor := dbms_xmldom.appendChild(cur_node_bes, dbms_xmldom.makeNode(elem_vor));

                        elem_dir := dbms_xmldom.createElement(doc, 'direktvertrag');
                        cur_node_dir := dbms_xmldom.appendChild(cur_node_vor, dbms_xmldom.makeNode(elem_dir));

                        elem_ver := dbms_xmldom.createElement(doc, 'vertrag');
                        cur_node_ver := dbms_xmldom.appendChild(cur_node_dir, dbms_xmldom.makeNode(elem_ver));
                        Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','test1...:'||p_vname,'', '');    

                        IF v_vertragsheader IS NOT NULL

                        THEN
                                Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','before vetrag...:'||p_vname,'', '');    

                                xi_doc_vertragsheader := dbms_xmldom.newdomdocument(v_vertragsheader);

                                xi_node_vertragsheader := dbms_xmldom.makeNode(dbms_xmldom.getDocumentElement(xi_doc_vertragsheader));
                                 
                                xi_node_vertragsheader := dbms_xmldom.importNOde(doc, xi_node_vertragsheader, true);
                                 
                                xi_node_vertragsheader := dbms_xmldom.appendChild(cur_node_ver, xi_node_vertragsheader);

                        END IF;
                                Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','after vetrag...:'||p_vname,'', '');    

/*                        FOR J IN REFCUR_OBJ_PKG_NUM_DATA.FIRST..REFCUR_OBJ_PKG_NUM_DATA.LAST 

                        LOOP

                                p_obj_pkg_num := REFCUR_OBJ_PKG_NUM_DATA(J);


                                xi_doc_anlagevermoegen := dbms_xmldom.newdomdocument(xixml_anlagevermoegen);

                                xi_node_anlagevermoegen := dbms_xmldom.makeNode(dbms_xmldom.getDocumentElement(xi_doc_anlagevermoegen));
                                 
                                xi_node_anlagevermoegen := dbms_xmldom.importNOde(doc, xi_node_anlagevermoegen, true);
                                 
                                xi_node_anlagevermoegen := dbms_xmldom.appendChild(cur_node_ver, xi_node_anlagevermoegen);

                        END LOOP;
*/

                        IF v_mietkaufvermoegen IS NOT NULL

                        THEN

                                xi_doc_mietkaufvermoegen := dbms_xmldom.newdomdocument(v_mietkaufvermoegen);

                                xi_node_mietkaufvermoegen := dbms_xmldom.makeNode(dbms_xmldom.getDocumentElement(xi_doc_mietkaufvermoegen));
                                 
                                xi_node_mietkaufvermoegen := dbms_xmldom.importNOde(doc, xi_node_mietkaufvermoegen, true);
                                 
                                xi_node_mietkaufvermoegen := dbms_xmldom.appendChild(cur_node_ver, xi_node_mietkaufvermoegen);

                        END IF;

                        IF v_msz IS NOT NULL

                        THEN

                                xi_doc_msz := dbms_xmldom.newdomdocument(v_msz);

                                xi_node_msz := dbms_xmldom.makeNode(dbms_xmldom.getDocumentElement(xi_doc_msz));
                                 
                                xi_node_msz := dbms_xmldom.importNOde(doc, xi_node_msz, true);
                                 
                                xi_node_msz := dbms_xmldom.appendChild(cur_node_ver, xi_node_msz);

                        END IF;

                        IF v_nachgeschaeft IS NOT NULL

                        THEN

                                xi_doc_nachgeschaeft := dbms_xmldom.newdomdocument(v_nachgeschaeft);

                                xi_node_nachgeschaeft := dbms_xmldom.makeNode(dbms_xmldom.getDocumentElement(xi_doc_nachgeschaeft));
                                 
                                xi_node_nachgeschaeft := dbms_xmldom.importNOde(doc, xi_node_nachgeschaeft, true);
                                 
                                xi_node_nachgeschaeft := dbms_xmldom.appendChild(cur_node_ver, xi_node_nachgeschaeft);

                        END IF;


                        IF v_restwert IS NOT NULL

                        THEN


                                xi_doc_restwert  := dbms_xmldom.newdomdocument(v_restwert);

                                xi_node_restwert := dbms_xmldom.makeNode(dbms_xmldom.getDocumentElement(xi_doc_restwert));
                                 
                                xi_node_restwert := dbms_xmldom.importNOde(doc, xi_node_restwert, true);
                                 
                                xi_node_restwert := dbms_xmldom.appendChild(cur_node_ver, xi_node_restwert);

                        END IF;


                        IF v_zahlungsplan IS NOT NULL

                        THEN

                                xi_doc_zahlungsplan  := dbms_xmldom.newdomdocument(v_zahlungsplan);

                                xi_node_zahlungsplan := dbms_xmldom.makeNode(dbms_xmldom.getDocumentElement(xi_doc_zahlungsplan));
                                 
                                xi_node_zahlungsplan := dbms_xmldom.importNOde(doc, xi_node_zahlungsplan, true);
                                 
                                xi_node_zahlungsplan := dbms_xmldom.appendChild(cur_node_ver, xi_node_zahlungsplan);

                        END IF;


                        if cur_refin_data.count > 0   then
                         
                                FOR i IN cur_refin_data.FIRST .. cur_refin_data.LAST
                                LOOP
                                    
                                        IF cur_refin_data (i).refi_mieten IS NOT NULL

                                        THEN


                                                xi_doc_refi_mieten   := dbms_xmldom.newdomdocument(xmltype(cur_refin_data (i).refi_mieten));

                                                xi_node_refi_mieten  := dbms_xmldom.makeNode(dbms_xmldom.getDocumentElement(xi_doc_refi_mieten));
                                                 
                                                xi_node_refi_mieten  := dbms_xmldom.importNOde(doc, xi_node_refi_mieten, true);
                                                 
                                                xi_node_refi_mieten  := dbms_xmldom.appendChild(cur_node_ver, xi_node_refi_mieten);

                                        END IF;

                                        IF cur_refin_data (i).refi_mieten_rw IS NOT NULL

                                        THEN


                                                xi_doc_refi_mieten_rw   := dbms_xmldom.newdomdocument(xmltype(cur_refin_data (i).refi_mieten_rw));

                                                xi_node_refi_mieten_rw  := dbms_xmldom.makeNode(dbms_xmldom.getDocumentElement(xi_doc_refi_mieten_rw));
                                                 
                                                xi_node_refi_mieten_rw  := dbms_xmldom.importNOde(doc, xi_node_refi_mieten_rw, true);
                                                 
                                                xi_node_refi_mieten_rw  := dbms_xmldom.appendChild(cur_node_ver, xi_node_refi_mieten_rw);

                                        END IF;

                                        IF cur_refin_data (i).refi_rw IS NOT NULL

                                        THEN

                                                xi_doc_refi_rw          := dbms_xmldom.newdomdocument(xmltype(cur_refin_data (i).refi_rw));

                                                xi_node_refi_rw         := dbms_xmldom.makeNode(dbms_xmldom.getDocumentElement(xi_doc_refi_rw));
                                                 
                                                xi_node_refi_rw         := dbms_xmldom.importNOde(doc, xi_node_refi_rw, true);
                                                 
                                                xi_node_refi_rw         := dbms_xmldom.appendChild(cur_node_ver, xi_node_refi_rw);

                                        END IF;

                                END LOOP;
                        END IF;

                            
                        IF v_verwaltungskosten IS NOT NULL

                        THEN

                                xi_doc_verwaltungskosten   := dbms_xmldom.newdomdocument(v_verwaltungskosten);

                                xi_node_verwaltungskosten  := dbms_xmldom.makeNode(dbms_xmldom.getDocumentElement(xi_doc_verwaltungskosten));
                                 
                                xi_node_verwaltungskosten  := dbms_xmldom.importNOde(doc, xi_node_verwaltungskosten, true);
                                 
                                xi_node_verwaltungskosten  := dbms_xmldom.appendChild(cur_node_ver, xi_node_verwaltungskosten);

                        END IF;

                            
                        IF v_risikovorsorge IS NOT NULL

                        THEN

                                xi_doc_risikovorsorge   := dbms_xmldom.newdomdocument(v_risikovorsorge);

                                xi_node_risikovorsorge  := dbms_xmldom.makeNode(dbms_xmldom.getDocumentElement(xi_doc_risikovorsorge));
                                 
                                xi_node_risikovorsorge  := dbms_xmldom.importNOde(doc, xi_node_risikovorsorge, true);
                                 
                                xi_node_risikovorsorge  := dbms_xmldom.appendChild(cur_node_ver, xi_node_risikovorsorge);

                        END IF;

                END LOOP;
             END IF;
END PROCESS_CONTRACT;

BEGIN
   
   p_o_n_ret_flg := 0;
   
   cur_cmpno_data.delete;
   
   IF v_i_n_comp_num IS NULL
   THEN
      OPEN cur_cmpno ;
      fetch cur_cmpno bulk collect into cur_cmpno_data;  
      close cur_cmpno ;
   ELSE
      cur_cmpno_data(1) := v_i_n_comp_num ; 
   END IF;   

   if cur_cmpno_data.count > 0   then
 
    FOR i IN cur_cmpno_data.FIRST .. cur_cmpno_data.LAST
    LOOP
    
        p_comp_num  := cur_cmpno_data (i);

        cur_contract_data.delete;

        g_n_no_records := 0;
    
        Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Processing for company number = ','', p_comp_num);    

        doc := dbms_xmldom.newDOMDocument;
	
        dbms_xmldom.setdoctype(doc,'bestand',null,pubid=>'Bestand.dtd'); 

        node := dbms_xmldom.makeNode(doc);

        dbms_xmldom.setversion(doc, '1.0');

        dbms_xmldom.setCharset(doc, 'UTF8');

        elem_bes := dbms_xmldom.createElement(doc, 'bestand');

        --dbms_xmldom.setAttribute(elem_bes,'xsi:noNamespaceSchemaLocation','TLL_Bestand.xsd');

        --dbms_xmldom.setAttribute(elem_bes,'xmlns:xsi','http://www.w3.org/2001/XMLSchema-instance');

        dbms_xmldom.setAttribute(elem_bes, 'sim_stichtag', to_char(v_i_d_process_date,'DD-MM-YYYY'));

        dbms_xmldom.setAttribute(elem_bes,'bestandstyp','BESTAND');

        cur_node_bes := dbms_xmldom.appendChild(node, dbms_xmldom.makeNode(elem_bes));
        
        Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Before open the contract cursor','', '');    

        OPEN cur_contract_xml1 (p_comp_num,v_i_d_due_date) ;
        LOOP
                Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Before fetch the contract cursor','', '');    

                fetch cur_contract_xml1 bulk collect into cur_contract_data LIMIT 500;  
                 Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Number contracts FEtched'||cur_contract_data.COUNT,'', '');    
                IF(cur_contract_data.COUNT > 0)
                THEN
                        PROCESS_CONTRACT;
                END IF;
                Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','After PROCESS_CONTRACT ','', '');    
                EXIT WHEN cur_contract_xml1%NOTFOUND; 
        END LOOP;
        CLOSE cur_contract_xml1 ;

        
        Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Number of records created in file       = ','', g_n_no_records ||'   '|| 'for the company number   :' ||lpad(p_comp_num,3,0));    
            
        v_output_filename := 'OUTGOING_DIR/'||'Final_xml_file_'||lpad(p_comp_num,3,0)||'.xml';

        dbms_xmldom.writeToFile(doc,v_output_filename,'UTF8');

        dbms_xmldom.freeDocument(doc);

      END LOOP;
    END IF;
    
    EXCEPTION     
     WHEN OTHERS   THEN
      p_o_n_ret_flg := 4;
      Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'FINAL_TRIG_XML_FILE_CREATION'||','||g_v_pkg_id, SQLERRM);

  
   END FINAL_TRIG_XML_FILE_CREATION;
   
                                          
FUNCTION occurs (csearchexpression NVARCHAR2, cexpressionsearched CLOB)
      RETURN SMALLINT DETERMINISTIC
   AS
      occurs           SMALLINT := 0;
      start_location   SMALLINT
                            := INSTR (cexpressionsearched, csearchexpression);
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

	PROCEDURE PROC_PUSH_DATA_TO_VITRIA(Stichtag_Date IN DATE,v_return_code OUT NUMBER)
	IS
		lf_file_handle 		UTL_FILE.FILE_TYPE;
		v_vit_pkg_id		VARCHAR2(30) := 'TRIGONIS_VIT_PUSH';
		vitria_push_failure	EXCEPTION;
		V_FILE_OPEN_ERR		EXCEPTION;
	BEGIN

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

		PRC_BILANZ_TRIGONIS(Stichtag_Date,lf_file_handle,v_return_code); 

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
  
   PROCEDURE PRC_BILANZ_TRIGONIS (
                                   p_stitchtagdate IN DATE,
                                   if_file_handle IN UTL_FILE.file_type, 
                                   p_err_cd OUT VARCHAR2
                                 ) IS

   CURSOR cur_trig IS
         SELECT LPAD(comp_num, 4, 0) comp_num, obj_pkg_num, '01' deprc_area_cd,
                TO_CHAR(due_dt, 'YYYYMMDD') cur_effctv_dt
         FROM   TLL_CNTRCT_STG_TP where DUE_DT = p_stitchtagdate;

      v_no_trig_rec                 PLS_INTEGER := 0;
      v_batch_job_number            NUMBER(10);
      -- Vitria
      v_loop_counter                PLS_INTEGER := 1;
      data_length                   PLS_INTEGER;
      max_length                    PLS_INTEGER := 32000;
      remaining_length              PLS_INTEGER;
   BEGIN

      v_batch_job_number := 0 ;
      BEGIN
         SELECT NVL(MAX(batch_num),0) + 1
         INTO   v_batch_job_number
         FROM   vit_ubc_ir_bilanz_batch_det@dl_ubc_vit;
      EXCEPTION
          WHEN OTHERS THEN
              v_batch_job_number := 0;
      END ;

      FOR v_cur IN cur_trig LOOP
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
     WHEN OTHERS THEN
         p_err_cd := 20; --fatal error
   END prc_bilanz_trigonis;

PROCEDURE PRC_HOST_COMM(p_stream VARCHAR2) AS
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
FROM            vit_ubc_ir_bilanz_batch_det@dl_ubc_vit;

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
prc_vitria_transfer(v_vitria_path, v_trg_job, p_trgns_tran_id,v_ercd,if_file_handle);
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

END PRC_HOST_COMM;

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

PROCEDURE prc_vitria_transfer(p_vitria_path IN VARCHAR2,
                              p_tab_jobnum IN v_tab_job_id,
                              p_tranid IN VARCHAR2,
                              p_ercd OUT PLS_INTEGER,
                              if_file_handle utl_file.file_type) IS
   v_bulkbatch_job               VARCHAR2(32000) := ' ';
   v_loop_counter                PLS_INTEGER := 1;
   data_length                   PLS_INTEGER;
   max_length                    PLS_INTEGER := 220;   -- To Restrict The Size of Command to less Than 255
   remaining_length              PLS_INTEGER;
   v_ercd								PLS_INTEGER;
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
EXCEPTION
   WHEN VALUE_ERROR THEN
      p_ercd := 1;
    Pkg_Batch_Logger.proc_log(if_file_handle, 'DEBUG', 'inside value error exce', '','');
  WHEN v_vitria_bw_err THEN
    p_ercd := 3;
    Pkg_Batch_Logger.proc_log(if_file_handle, 'DEBUG', 'inside vit bw err excep', '','');
   WHEN OTHERS THEN
     Pkg_Batch_Logger.proc_log(if_file_handle, 'DEBUG', 'inisde when other excep', '','');
      p_ercd := 2;
END prc_vitria_transfer;

END PKG_TLL_TRIG_FILE_CREATION;
/

