CREATE OR REPLACE PACKAGE PKG_TLL_REFI_REQ_XML_CREATION
IS
   /*-------------------------------------------------------------------------------------------------*/
   /*  Name                 :  PKG_TLL_REFI_REQ_CREATION                                              */
   /*  Author               :  Hexaware Technologies                                                  */
   /*  Purpose              :  generates the requested files company wise to TXS for Refinancing data.*/
   /*                                                                                                 */ 
   /*                          Get all the asset id and company number from  table                    */
   /*                          TLL_CONTRACT_DTL_TP for the given process date and send the requested  */
   /*                          files to TXS for the refinancing data.                                 */
   /*                                                                                                 */
   /*  Revision History    :                                                                          */
   /*  <<Ver No>>           <<Modified By>>                    <<Modified Date>>                      */
   /*      1.0                Roshan  F                         31-Oct-2007                           */
   /*      1.1                Roshan  F                         06-Jan-2008                           */
   /*                         new logic added to avoid creating the request file without a record     */  
   /*      1.2                Benjamine.S       Fix for 25053 - Batch Error Handling   03-June-2011   */   
   /*-------------------------------------------------------------------------------------------------*/

   -- Global variable declarations

   g_v_pkg_id        CONSTANT        VARCHAR2(100) := 'PKG_TLL_REFI_REQ_CREATION';   /* Variable to Store Package Name */
   g_v_prog_id       CONSTANT        VARCHAR2(100) := 'TLL_REFI_REQ_CREATION';       /* Variable to Store Program Name */
   g_v_proc_name     CONSTANT        VARCHAR2(100) := 'TLL_REFI_REQ_CREATION';
   g_v_pkg_prog_id   CONSTANT        VARCHAR2(300) :=  g_v_pkg_id || ' , ' || g_v_prog_id;
   g_v_user          VARCHAR2(40)                  := 'TLL_REFI_REQ_CREATION_BATCH';
   g_v_err  varchar2(100);
   
   g_v_errtable      VARCHAR2(50);

   lf_file_handle    UTL_FILE.FILE_TYPE;   -- Variable for Log File Handler
   v_outfile_handle  UTL_FILE.FILE_TYPE;   -- Variable for Output File Handler
   v_filelist_fp     UTL_FILE.FILE_TYPE;   -- Variable for Output File ftp
   v_output_filename   VARCHAR2 (50) ;
   v_refi_filename     VARCHAR2 (50) ;

   v_proc_err        EXCEPTION;
   v_tech_err        EXCEPTION;
   v_exists_err      EXCEPTION;
   v_insert_err      EXCEPTION;
  
   g_n_no_records NUMBER(10) := 0;
   g_n_no_exists NUMBER(10)  := 0;

 -- Public procedure declarations

/**************************************************/
/* Main Procedure which calls all other procedures*/
/**************************************************/

   PROCEDURE MAIN_PROC (
                        p_i_d_process_date     IN   DATE,
                        p_o_n_ret_flg          OUT  NUMBER
                       );

/********************************************/
/*Procedure to validate the input parameters*/
/********************************************/

END PKG_TLL_REFI_REQ_XML_CREATION;
/

CREATE OR REPLACE PACKAGE BODY PKG_TLL_REFI_REQ_XML_CREATION
AS
PROCEDURE MAIN_PROC (
                        p_i_d_process_date     IN   DATE,
                        p_o_n_ret_flg          OUT  NUMBER
                    )
IS

p_o_v_outxml        VARCHAR2(6000);
p_i_n_comp_num      NUMBER(10) ;
p_comp_num          NUMBER(10);
p_i_v_asset_id      VARCHAR2(40);
p_i_n_cou           NUMBER := 0;
v_rec_count         NUMBER := NULL;

doc         dbms_xmldom.DOMDocument;
node        dbms_xmldom.DOMNode;
cur_node    dbms_xmldom.DOMNode;
root_node   dbms_xmldom.DOMNode;
com_node    dbms_xmldom.DOMNode;
elem        dbms_xmldom.DOMElement;
root_elem   dbms_xmldom.DOMElement;
com         dbms_xmldom.DOMComment;

cursor cur_refin_xml (v_i_n_cmp_no in number) is 
select comp_num,extractvalue(cntrct_det,'/bestand/vorgang/direktvertrag/vertrag/txs_reference/@txs_ref_id') asset_id 
from tll_cntrct_det_tp where comp_num = v_i_n_cmp_no
                       and existsnode(cntrct_det,'/bestand/vorgang/direktvertrag/vertrag/txs_reference') = 1;

TYPE cur_refin_tab IS TABLE OF cur_refin_xml%ROWTYPE INDEX BY BINARY_INTEGER;

cur_refin_data             cur_refin_tab;

cursor cur_cmpno is 
select distinct comp_num from tll_cntrct_det_tp;

TYPE cur_cmpno_tab IS TABLE OF NUMBER INDEX BY PLS_INTEGER;

cur_cmpno_data             cur_cmpno_tab;

/*-----------------------------------------------------*/
/*      Start of Main Execution                        */
/*-----------------------------------------------------*/

BEGIN
    
   p_o_n_ret_flg         := 0;

/*-----------------------------------------------*/
/* Initialize File Handle for  Log File Writing  */
/*-----------------------------------------------*/

   BEGIN
       lf_file_handle := Pkg_Batch_Logger.func_open_log(g_v_prog_id);

   EXCEPTION
   WHEN OTHERS  
   THEN
      DBMS_OUTPUT.PUT_LINE('Unable to open the Spool File due to '||SQLERRM);
      pkg_batch_logger.proc_log (lf_file_handle,'INFO','Unable to open the Spool File due to ','',SQLERRM);
      RAISE v_tech_err;
   END;   
    
   BEGIN                                                                --3
      v_filelist_fp := UTL_FILE.fopen ('OUTGOING_DIR',g_v_prog_id||'.ftp.list', 'W');

   EXCEPTION
   WHEN OTHERS
   THEN
      Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','No Permissions to the Location - OUTGOING_DIR','', '');  
      Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Unable to open the FTP File = '||g_v_prog_id||'.ftp.list'||SQLERRM,'', '');
      RAISE v_tech_err;
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
              
   BEGIN
     SELECT COUNT(1) INTO g_n_no_exists 
     FROM TLL_CNTRCT_DET_TP 
     WHERE DUE_DT = p_i_d_process_date; 
                 
     IF g_n_no_exists = 0 THEN
        RAISE v_exists_err;
     END IF;
                                   
   END; 
          
   BEGIN
   
   cur_cmpno_data.delete;
   
   OPEN cur_cmpno ;
   fetch cur_cmpno bulk collect into cur_cmpno_data;  
   close cur_cmpno ;
   
   IF cur_cmpno_data.count > 0   
   THEN 
      FOR i IN cur_cmpno_data.FIRST .. cur_cmpno_data.LAST
      LOOP          
        p_comp_num  := cur_cmpno_data (i);
        v_rec_count := NULL;
		
		    BEGIN
		      select count(1) 
          INTO v_rec_count 
          from tll_cntrct_det_tp 
          where comp_num = p_comp_num
          and existsnode(cntrct_det,'/bestand/vorgang/direktvertrag/vertrag/txs_reference/@txs_ref_id') =1; 

		    EXCEPTION 
		    WHEN OTHERS THEN
		      Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',NULL,SQLERRM);
          p_o_n_ret_flg         := 5;
		    END;

        cur_refin_data.delete;
        g_n_no_records := 0;
                
        OPEN cur_refin_xml (p_comp_num) ;
        fetch cur_refin_xml bulk collect into cur_refin_data;  
        close cur_refin_xml ;
                
        doc := dbms_xmldom.newDOMDocument;

        node := dbms_xmldom.makeNode(doc);

        dbms_xmldom.setversion(doc, '1.0');

        dbms_xmldom.setCharset(doc, 'UTF8');

        elem := dbms_xmldom.createElement(doc, 'txs_refi_data');

        dbms_xmldom.setAttribute(elem,'xsi:noNamespaceSchemaLocation','TLL_refi_request_response.xsd');

        dbms_xmldom.setAttribute(elem,'xmlns:xsi','http://www.w3.org/2001/XMLSchema-instance');

        dbms_xmldom.setAttribute(elem, 'sim_date', to_char(p_i_d_process_date,'dd.mm.yyyy'));

        dbms_xmldom.setAttribute(elem,'type','REQUEST');

        cur_node := dbms_xmldom.appendChild(node, dbms_xmldom.makeNode(elem));
  
        IF cur_refin_data.count > 0   
        then
          FOR i IN cur_refin_data.FIRST .. cur_refin_data.LAST
          LOOP
                   
             p_i_n_comp_num := cur_refin_data (i).comp_num;

             p_i_v_asset_id := cur_refin_data (i).asset_id;
                      
             root_elem := dbms_xmldom.createElement(doc, 'refi_contract');

             dbms_xmldom.setAttribute(root_elem, 'asset_id',p_i_v_asset_id);

             dbms_xmldom.setAttribute(root_elem, 'comp_no',p_i_n_comp_num);

             root_node := dbms_xmldom.appendChild(cur_node, dbms_xmldom.makeNode(root_elem));

             g_n_no_records := g_n_no_records +1;
                      
          END LOOP;
        END IF;
                      
        Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Number of requested created in file       = ','', g_n_no_records ||'   '|| 'for the company number   :' ||lpad(p_comp_num,3,0));

        v_refi_filename := 'TLL2TXS_REFIDATA'||lpad(p_comp_num,3,0)||'_'||to_char(p_i_d_process_date,'YYYYMMDD')||'.xml';
        v_output_filename := 'OUTGOING_DIR/'||v_refi_filename;
                
		    IF v_rec_count > 0 
		    THEN
           dbms_xmldom.writeToFile(doc,v_output_filename,'UTF8');
           UTL_FILE.put_line (v_filelist_fp,v_refi_filename);
        END IF;
		    
        dbms_xmldom.freeDocument(doc);

      END LOOP;
   --END IF;
    
      UTL_FILE.FCLOSE(v_filelist_fp);
                                  
      /*------------------------------------------------------------------*/
      /* Stop Execution of Program if the Input Parms are Invalid         */
      /*------------------------------------------------------------------*/

      IF  p_o_n_ret_flg<> 0
      THEN
        RAISE v_proc_err;
      END IF;       

      BEGIN
        UPDATE TLL_PROCESSING_TX 
        SET   TXS_REFI_REQ_FLG  = 'Y'
        WHERE DUE_DT            = p_i_d_process_date;
      END;
    
    ELSE
      Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','No Records Available to be Written to the Output xml file', '', '');
      UTL_FILE.FCLOSE(v_filelist_fp);
    END IF;
    
    END; -- }        

    Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_REFI_REQ_CREATION        = ','',p_o_n_ret_flg);

    Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT',NULL,NULL,NULL);

    Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0012','MAIN_PROC'||','||g_v_pkg_id,NULL);
    Pkg_Batch_Logger.proc_log_status (lf_file_handle,'C');
    
EXCEPTION
WHEN  v_proc_err THEN
   p_o_n_ret_flg := 1;
   
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_REFI_REQ_CREATION        = ','',p_o_n_ret_flg);
   Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019','MAIN_PROC'||','||g_v_pkg_id,NULL);
   Pkg_Batch_Logger.proc_log_status (lf_file_handle,'B');
 
WHEN v_tech_err THEN
   p_o_n_ret_flg :=2;
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_REFI_REQ_CREATION        = ','',p_o_n_ret_flg);
   Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019','MAIN_PROC'||','||g_v_pkg_id,NULL);
   Pkg_Batch_Logger.proc_log_status (lf_file_handle,'S');

WHEN v_exists_err THEN
   p_o_n_ret_flg :=3;
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_REFI_REQ_CREATION        = ','',p_o_n_ret_flg);
   Pkg_Batch_Logger.proc_log(lf_file_handle,'DEBUG','RECORDS ALREADY DELETED FOR THE CURRENT DATE','','');
   Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019','MAIN_PROC'||','||g_v_pkg_id,NULL);
   Pkg_Batch_Logger.proc_log_status (lf_file_handle,'B');

WHEN  OTHERS THEN

/* ------------------------------------------------------- */
/*      Other fatal Errors. Close and Terminate program    */
/* ------------------------------------------------------- */
   p_o_n_ret_flg := 20;
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_REFI_REQ_CREATION        = ','',p_o_n_ret_flg);
   Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019',  'MAIN_PROC' || ' , ' || g_v_pkg_id, '');
   Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',NULL,SQLERRM);
   Pkg_Batch_Logger.proc_log_status (lf_file_handle,'S');
   Pkg_Batch_Logger.proc_close_log(lf_file_handle);
    
END MAIN_PROC;

END PKG_TLL_REFI_REQ_XML_CREATION;
/

