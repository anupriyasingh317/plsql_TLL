CREATE OR REPLACE PACKAGE PKG_TLL_UCS_REC_EXTRACTION
AS

 /*-------------------------------------------------------------------------------------------------*/
   /*  Name                 :  PKG_TLL_UCS_REC_EXTRACTION                                                  */
   /*  Author               :  Hexaware Technologies                                                  */
   /*  Purpose              :  extract data's from different leasing contract management system and   */
   /*                           TXS.                                                                  */
   /*                                                                                                 */
   /*                        1.extract data's from different leasing contract management system xml   */
   /*                          files ,insert all the data into TP tables with process                 */
   /*                          data and company number.                                               */
   /*                                                                                                 */
   /*                                                                                                 */
   /*                                                                                                 */
   /*                                                                                                 */
   /*  Revision History    :                                                                          */
   /*  <<Ver No>>           <<Modified By>>                    <<Modified Date>>                      */
   /*      1.0                Roshan  F                         31-Oct-2007                           */
   /*      1.1                Roshan  F                         29-Jan-2008                           */
   /*                        1.new logic added to scan the ftp_in for accessing the incoming xml file */
   /*      1.2                Kalimuthu                         21-Feb-2008                           */
   /*                         1) Changes to handle multiple object package number for a contract
   /*      1.3                Kalimuthu                         05-Mar-2008                           */
   /*                         1) Changes to handle zero bytes xml file
   /*      1.4                Kalimuthu
   /*                         1) Miles contract file is start with 'B' where as ucs contract is start with BUCS.
   /*                            Incorporated necessary changes to handle both miles and UCS xml files. 
   /*                         2) Extraction company number for miles is not picked up correctly.
   /*                            Done necessary the changes to pick up correctly.
   /*      1.5                Benjamine                         25-Nov-2008                           */
   /*                         Fix for the Defect 20225 ( '%' is replaced with 3 underscore's in       */
   /*                         the cursor cur_dir )						                  */
   /*-------------------------------------------------------------------------------------------------*/

   -- Global variable declarations

   g_v_pkg_id        CONSTANT        VARCHAR2(100) := 'PKG_TLL_UCS_REC_EXTRACTION ';   /* Variable to Store Package Name */
   g_v_prog_id       CONSTANT        VARCHAR2(100) := 'TLL_UCS_REC_EXTRACTION';        /* Variable to Store Program Name */
   g_v_proc_name     CONSTANT        VARCHAR2(100) := 'TLL_UCS_REC_EXTRACTION';
   g_v_pkg_prog_id   CONSTANT        VARCHAR2(300) :=  g_v_pkg_id || ' , ' || g_v_prog_id;
   g_v_user                          VARCHAR2(40)  := 'TLL_UCS_REC_EXTRACTION_BATCH';
   g_v_err  varchar2(100);

   g_v_errtable      VARCHAR2(50);

   lf_file_handle    UTL_FILE.FILE_TYPE;   -- Variable for Log File Handler

   v_proc_err        EXCEPTION;
   v_tech_err        EXCEPTION;
   v_skip_record     EXCEPTION;
   v_exists_err      EXCEPTION;
   v_insert_err      EXCEPTION;
   g_e_file_open_err EXCEPTION;

   g_n_no_records 	 NUMBER(10)  := 0;
   g_n_no_exists 	 NUMBER(10)  := 0;
   g_n_cntrl_records NUMBER(10)  := 0;   

   TYPE v_dir_list_tab_typ IS TABLE OF varchar2(255)  INDEX BY BINARY_INTEGER;

   v_dir_list_tab    v_dir_list_tab_typ;

   -- Public procedure declarations

/**************************************************/
/* Main Procedure which calls all other procedures*/
/**************************************************/
   
   PROCEDURE MAIN_PROC (
                        p_i_d_process_date     IN   DATE,
                        p_o_n_ret_flg          OUT  NUMBER
                       );

/*****************************************************/
/*Function for converting given ftp file to clob data*/
/*****************************************************/

   FUNCTION get_clob_xmldocument (
                                   f_v_filename IN VARCHAR2
                                 )
   RETURN CLOB;

/********************************************/
/*Function to calculate the occurs in string*/
/********************************************/

   FUNCTION occurs (
                     csearchexpression NVARCHAR2,
                     cexpressionsearched CLOB
                   )
   RETURN SMALLINT DETERMINISTIC;


/********************************************/
/* Procedure to  import contract details    */
/********************************************/

   PROCEDURE XML_FILE_EXT (
                           p_contract_file_name IN   VARCHAR2,
                           p_o_n_ret_flg        OUT  NUMBER
   );
   
   /********************************************/
   /* Procedure to validate the input details  */
   /********************************************/
   
   PROCEDURE VALIDATE_INPUT_PARMS ( p_i_d_process_date  IN   DATE,
                                     p_o_n_ret_flg    OUT  NUMBER
                                  );
    
   FUNCTION FN_IS_VALID_DATE( v_valid_date  IN VARCHAR2,
                              v_date_format IN VARCHAR2 DEFAULT 'DD.MM.YYYY')
   RETURN NUMBER;

   /********************************************/
   /* Procedure to scan the incoming directories*/
   /********************************************/
   
   PROCEDURE pro_dir (
                     p_i_d_process_date     IN   DATE,
                     p_o_n_ret_flg          OUT  NUMBER
                    );
   
END PKG_TLL_UCS_REC_EXTRACTION;
/

CREATE OR REPLACE PACKAGE BODY PKG_TLL_UCS_REC_EXTRACTION
AS

   PROCEDURE pro_dir (p_i_d_process_date     IN   DATE,p_o_n_ret_flg  OUT NUMBER)
               
   AS
      CURSOR cur_dir is SELECT distinct FILENAME 
      FROM TLL_DIR_LIST_TP 
--      where FILENAME LIKE 'B%'||TO_CHAR(p_i_d_process_date,'YYMM')||'%' || '.xml';
      where FILENAME LIKE 'B%'||TO_CHAR(p_i_d_process_date,'YYMM')||'___' || '.xml';  -- Fix for 20225

   BEGIN
      p_o_n_ret_flg := 0;
      OPEN  cur_dir;
      BEGIN
            v_dir_list_tab.DELETE;
      EXCEPTION
      WHEN OTHERS
      THEN
            NULL;
      END;

      FETCH cur_dir BULK COLLECT INTO v_dir_list_tab;

      CLOSE cur_dir;
      
      IF(v_dir_list_tab.COUNT = 0)
      THEN
         Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','No files Like B% in TLL Incoming Directory. Hence Failing the Job','','');
         Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','No Input Contract Files For Process Date '||p_i_d_process_date, NULL, SQLERRM);
         raise v_proc_err;
      END IF;

      FOR I IN v_dir_list_tab.FIRST..v_dir_list_tab.LAST
      LOOP
         XML_FILE_EXT (v_dir_list_tab(I),p_o_n_ret_flg);
         IF(p_o_n_ret_flg <> 0)
         THEN
            RAISE v_proc_err;
         END IF;
      END LOOP;

   EXCEPTION
   WHEN v_proc_err
   THEN
        dbms_output.put_line('v_proc_err:Error in pro_dir:'||sqlerrm);
        Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','Error in pro_dir ', NULL, SQLERRM);
        RAISE v_proc_err;
   WHEN OTHERS 
   THEN
    p_o_n_ret_flg := 1;
    dbms_output.put_line('Error in pro_dir:'||sqlerrm);
    Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','Error in pro_dir ', NULL, SQLERRM);
    RAISE v_proc_err;
   END pro_dir;

PROCEDURE MAIN_PROC (
                        p_i_d_process_date     IN   DATE,
                        p_o_n_ret_flg          OUT  NUMBER
                       )

AS
   v_directory_path VARCHAR2(400);
BEGIN

    /*DBMS_OUTPUT.put_line (   'Start Time - '
                            || TO_CHAR (SYSDATE, 'dd:MM:YYYY HH:MI:SSSS')
                           );*/


/*-----------------------------------------------*/
/* Initialize File Handle for  Log File Writing  */
/*-----------------------------------------------*/
   p_o_n_ret_flg         := 0;

   BEGIN
        lf_file_handle := Pkg_Batch_Logger.func_open_log(g_v_prog_id);
   EXCEPTION
   WHEN OTHERS  
   THEN
      dbms_output.put_line('Error Opening Logfile.'||g_v_prog_id||sqlerrm);
      Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','Error while opening Spool file : ', NULL, SQLERRM);
      RAISE g_e_file_open_err;
   END;

   /*---------------------------------------------*/
   /* Writing Input Parameter Details to Out File */
   /*---------------------------------------------*/
  
    Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0008','MAIN_PROC'||','||g_v_pkg_id,'');
    Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT','List of Input Parameters :-', '', '');
    Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT','Input Process date       = ','', to_char( p_i_d_process_date,'dd.mm.rrrr') );
    
     
	 
   /*------------------------------------------------------------------*/
   /* Check if Input Parameters are Valid                              */
   /*------------------------------------------------------------------*/
   VALIDATE_INPUT_PARMS ( p_i_d_process_date,p_o_n_ret_flg);
 
   IF  p_o_n_ret_flg<> 0
   THEN
           RAISE v_proc_err;
   END IF;

   BEGIN
        SELECT count(1) 
        INTO g_n_cntrl_records 
        FROM TLL_PROCESSING_TX 
        WHERE due_dt = p_i_d_process_date;
        
        IF g_n_cntrl_records > 0 
        THEN
               Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT','Updating Processing Tx = ','', to_char( p_i_d_process_date,'dd.mm.rrrr') );

               UPDATE TLL_PROCESSING_TX SET 
                  due_dt  = p_i_d_process_date,
                  ucs_import_flg   	= 'N',
                  txs_refi_req_flg 	= 'N',
                  txs_import_flg   	= 'N',
                  sap_deprc_import_flg = 'N',
                  final_xml_flg        = 'N'
               WHERE  due_dt   = p_i_d_process_date;
        ELSE        
            INSERT INTO TLL_PROCESSING_TX 
            (
                DUE_DT, 
                UCS_IMPORT_FLG, 
                TXS_REFI_REQ_FLG, 
                TXS_IMPORT_FLG, 
                SAP_DEPRC_IMPORT_FLG, 
                FINAL_XML_FLG
             )
            VALUES 
            (
               p_i_d_process_date,
               'N',
               'N',
               'N',
               'N',
               'N'
            );

        END IF;

   EXCEPTION
   WHEN OTHERS 
   THEN
         Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'Main procedure - Control table (TLL_PROCESSING_TX)'||','||g_v_pkg_id, SQLERRM);
         RAISE v_proc_err;
   END;

   /*--------------------------------------------------------------------*/
   /*  Log Blank lines at the start of the Output files for readability  */
   /*--------------------------------------------------------------------*/

   FOR cnt IN 1..15
   LOOP
       Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0000', '', '');
   END LOOP;

  

   /****************************************************/
   /* Block to Delete Contract and Stagging TP Table   */
   /****************************************************/
   BEGIN
         DELETE FROM TLL_CNTRCT_DET_TP 
         WHERE DUE_DT =  p_i_d_process_date;

         DELETE FROM TLL_CNTRCT_STG_TP 
         WHERE DUE_DT =  p_i_d_process_date;
   EXCEPTION
   WHEN OTHERS
   THEN
      Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'Error While Deleting From TP tables(TLL_CNTRCT_DET_TP,TLL_CNTRCT_STG_TP) '||','||p_i_d_process_date, SQLERRM);
      RAISE v_proc_err;
   END;

   v_directory_path := PKG_TLL_UTILS.FN_GET_ORACLE_DIR_PATH(lf_file_handle,'INCOMING_DIR',p_o_n_ret_flg);

   Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT','Checking the directory  = '||v_directory_path,'', to_char( p_i_d_process_date,'dd.mm.rrrr') );

   IF (p_o_n_ret_flg <> 0)
   THEN
      RAISE v_proc_err;
   END IF;

   BEGIN

      BEGIN
       PKG_TLL_UTILS.GET_DIR_LIST(v_directory_path);
       COMMIT;
      EXCEPTION
      WHEN OTHERS
      THEN
         null;
      END;

      PKG_TLL_UTILS.GET_DIR_LIST(v_directory_path);
   EXCEPTION
   WHEN OTHERS
   THEN
      Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'Error While Reading the files in get_dir_list'||','||p_i_d_process_date, SQLERRM);
      RAISE v_proc_err;
   END;
   /****************************************************/
   /* Calling the ucs extract procedure with file names*/
   /****************************************************/

   pro_dir (p_i_d_process_date,p_o_n_ret_flg);

   /*------------------------------------------------------------------*/
   /* Stop Execution of Program if the Input Parms are Invalid         */
   /*------------------------------------------------------------------*/

   IF  p_o_n_ret_flg<> 0
   THEN
      RAISE v_proc_err;
   END IF;		
		
	 BEGIN		
		UPDATE TLL_PROCESSING_TX SET ucs_import_flg   	= 'Y'
		                         WHERE due_dt           = p_i_d_process_date;
		COMMIT;
	 EXCEPTION
	 WHEN OTHERS THEN
		 
	    Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'Main procedure - update Control table  '||','||g_v_pkg_id, SQLERRM);
	    RAISE v_proc_err;
		
	 END;

   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from TLL_UCS_REC_EXTRACTION        = ','',p_o_n_ret_flg);

   Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT',NULL,NULL,NULL);

   Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0012','MAIN_PROC'||','||g_v_pkg_id,NULL);
   Pkg_Batch_Logger.proc_log_status (lf_file_handle,'C');

EXCEPTION
   
WHEN  g_e_file_open_err  THEN
   p_o_n_ret_flg := 16;
   
	Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT',NULL,NULL,NULL);
	Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT','Error in File Opening',NULL,NULL);
	Pkg_Batch_Logger.proc_log_status (lf_file_handle,'S');
WHEN  v_proc_err THEN
   p_o_n_ret_flg := 1;

   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_REC_EXTRACTION        = ','',p_o_n_ret_flg);
   Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019','MAIN_PROC'||','||g_v_pkg_id,NULL);
   Pkg_Batch_Logger.proc_log_status (lf_file_handle,'B');

WHEN v_tech_err THEN
   p_o_n_ret_flg :=2;
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_REC_EXTRACTION        = ','',p_o_n_ret_flg);
   Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019','MAIN_PROC'||','||g_v_pkg_id,NULL);
   Pkg_Batch_Logger.proc_log_status (lf_file_handle,'S');

WHEN v_exists_err THEN
   p_o_n_ret_flg :=3;
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_REC_EXTRACTION        = ','',p_o_n_ret_flg);
   Pkg_Batch_Logger.proc_log(lf_file_handle,'DEBUG','RECORDS ALREADY DELETED FOR THE CURRENT DATE','','');
   Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019','MAIN_PROC'||','||g_v_pkg_id,NULL);
   Pkg_Batch_Logger.proc_log_status (lf_file_handle,'B');

WHEN  OTHERS THEN

/* ------------------------------------------------------- */
/*      Other fatal Errors. Close and Terminate program    */
/* ------------------------------------------------------- */
   p_o_n_ret_flg := 20;
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_REC_EXTRACTION        = ','',p_o_n_ret_flg);
   Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019',  'MAIN_PROC' || ' , ' || g_v_pkg_id, '');
   Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',NULL,SQLERRM);
   Pkg_Batch_Logger.proc_log_status (lf_file_handle,'S');
   Pkg_Batch_Logger.proc_close_log(lf_file_handle);

END MAIN_PROC;

PROCEDURE XML_FILE_EXT (p_contract_file_name IN  VARCHAR2,
                        p_o_n_ret_flg        OUT NUMBER)
AS
	v_file          BFILE    := BFILENAME ('INCOMING_DIR', p_contract_file_name);
	dir_alias       VARCHAR2 (100);
	v_name          VARCHAR2 (100);
	v_buffer_line   CLOB;
	v_str_size      NUMBER;
	v_value         CLOB;
	v_value_num     NUMBER         := 1;
	v_due_dt        DATE;
	v_contract_id   VARCHAR2 (32);
	v_comp_num      NUMBER (10);
	v_count         NUMBER (10);
	v_inc           NUMBER (10)    := 1;
	v_temp          NUMBER (10)    := 0;
	v_asset_num     VARCHAR2(20);
	v_vertragstyp   VARCHAR2(60);
    BEGIN

	   p_o_n_ret_flg := 0;

        Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','XML Extraction  Procedure - STARTS - ','',p_contract_file_name);
      
        IF DBMS_LOB.fileexists (v_file) = 1
        THEN
         
	       DBMS_LOB.filegetname (v_file, dir_alias, v_name);
         
         Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Opening the file ','',dir_alias|| '  and  '||v_name);
	 
         v_buffer_line := get_clob_xmldocument (p_contract_file_name);
         v_str_size := LENGTH (v_buffer_line);
	       Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT','FILE SIZE  =','',v_str_size);	 
         
         v_due_dt :=
            TO_DATE (SUBSTR (v_buffer_line,
                             INSTR (v_buffer_line, 'stichtag', 1, 1) + 10,
                             10
                            ),
                     'DD.MM.RRRR'
                    );
         IF(TRUNC(v_due_dt,'MM') = v_due_dt)
         THEN
                v_due_dt := v_due_dt-1;
         END IF;


        Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT','Due Date  =','',v_due_dt);
         --------------------------------------------
           v_comp_num :=     to_number(SUBSTR (p_contract_file_name,INSTR (p_contract_file_name,'.',1,1)-3,3),'9G999D99');
          --     to_number(SUBSTR (p_contract_file_name,9,INSTR (p_contract_file_name,'.',1,1)-9),'9G999D99');

        Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT','Company Number   =','',v_comp_num);
         v_count := occurs ('<!-- EndOfRecord -->', v_buffer_line);
        Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT','Number of Records in file =','',v_count);

         LOOP
            v_temp :=
                INSTR (v_buffer_line, '<!-- EndOfRecord -->', v_value_num, 1);
            v_value :=
               TRIM (SUBSTR (v_buffer_line,
                             INSTR (v_buffer_line, '<?xml', v_value_num, 1),
                             (  INSTR (v_buffer_line,
                                       '<!-- EndOfRecord -->',
                                       v_value_num,
                                       1
                                      )
                              - 1
                              - INSTR (v_buffer_line, '<?xml', v_value_num, 1)
                             )
                            )
                    );

            IF   INSTR (v_buffer_line, '<!-- EndOfRecord -->', v_value_num, 1)
               - 1
               - INSTR (v_buffer_line, '<?xml', v_value_num, 1) > 0
            THEN
             
               v_contract_id :=
                  SUBSTR (v_buffer_line,
                          INSTR (v_buffer_line, 'vname', v_value_num, 1) + 7,
                          32
                         );
              
                  BEGIN
                           INSERT INTO tll_cntrct_det_tp
                           (
                              CNTRCT_ID,
                              DUE_DT,
                              COMP_NUM,
                              CNTRCT_DET
                           )
                           VALUES 
                           (
                               v_contract_id, 
                               v_due_dt, 
                               v_comp_num,
                               XMLTYPE (v_value)
                           );

                           SELECT extract(xmltype(v_value),'/bestand/vorgang/direktvertrag/vertrag/vertragsheader/@vertragstyp').getStringVal() 
                           into v_vertragstyp
                           from dual;
                    
                           IF(v_vertragstyp != 'MIETKAUF')
                           THEN
                                   FOR  J IN 1..occurs('asset_num',v_value)
                                   LOOP
                                          SELECT  extract(xmltype(v_value),'/bestand/vorgang/direktvertrag/vertrag/anlagevermoegen['||J||']/@asset_num').getStringVal()  
                                          INTO v_asset_num
                                          FROM dual;
                                         
                                          IF(nvl(v_asset_num,0) = 0) 
                                          THEN
                                                Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT','Object Package Number Is null for contract id='||v_contract_id,'','');
                                          ELSE
                                                BEGIN
                                                  INSERT INTO TLL_CNTRCT_STG_TP 
                                                  (
                                                        CNTRCT_ID, 
                                                        OBJ_PKG_NUM, 
                                                        COMP_NUM, 
                                                        DUE_DT
                                                  )
                                                  VALUES
                                                  (
                                                     V_CONTRACT_ID,
                                                     V_ASSET_NUM,
                                                     V_COMP_NUM,
                                                     V_DUE_DT
                                                  ) ;
                                               EXCEPTION
                                               WHEN OTHERS
                                               THEN
                                                        Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT','Object Package Number is NULL for contract id='||v_contract_id,'','');
                                               END;
                                          END IF;
                                   END LOOP;
                           END IF;
                           
                 EXCEPTION
                 WHEN OTHERS   
                 THEN
                    Pkg_Batch_Logger.proc_log(lf_file_handle, 'DEBUG', 'PRO_XML_FILE_EXT:Error'||sqlerrm, '','');
                    Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'PRO_XML_FILE_EXT'||','||g_v_pkg_id, SQLERRM);
                    RAISE v_tech_err;
                 END;
            END IF;

            EXIT WHEN (v_value_num > v_str_size) OR (v_inc > v_count);

            v_inc := v_inc + 1;
            v_value_num := v_temp + 20;

         END LOOP;
      ELSE
         p_o_n_ret_flg := 0;
         Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT','No Such File in the dir ','',NULL);
      END IF;
EXCEPTION
WHEN v_skip_record
THEN
     p_o_n_ret_flg := 0;
WHEN OTHERS   
THEN
     p_o_n_ret_flg := 5;
     Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'PRO_XML_FILE_EXT'||v_contract_id||','||g_v_pkg_id, SQLERRM);
END XML_FILE_EXT;

FUNCTION get_clob_xmldocument (f_v_filename IN VARCHAR2)
RETURN CLOB
AS
      v_file        BFILE  := BFILENAME ('INCOMING_DIR', f_v_filename);
      charcontent   CLOB   := ' ';
      targetfile    BFILE;
      lang_ctx      NUMBER := DBMS_LOB.default_lang_ctx;
      charset_id    NUMBER := 0;
      src_offset    NUMBER := 1;
      dst_offset    NUMBER := 1;
      warning       NUMBER;
   BEGIN
      
	  targetfile := v_file;
        dbms_output.put_line('Leng='||DBMS_LOB.getlength (targetfile));
      IF(DBMS_LOB.getlength (targetfile) <= 0)
      THEN
        RAISE v_skip_record;
      ELSE
              DBMS_LOB.fileopen (targetfile, DBMS_LOB.file_readonly);
              DBMS_LOB.loadclobfromfile (charcontent,
                                         targetfile,
                                         DBMS_LOB.getlength (targetfile),
                                         src_offset,
                                         dst_offset,
                                         charset_id,
                                         lang_ctx,
                                         warning
                                        );
              DBMS_LOB.fileclose (targetfile);
       END IF;
      RETURN charcontent;
   EXCEPTION
   WHEN v_skip_record
   THEN
        Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','The size of file ['|| f_v_filename || '] is zero bytes.','','');
        raise v_skip_record;
   WHEN OTHERS
   THEN
        Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','get_clob_xmldocument: ', NULL, SQLERRM);
        dbms_output.put_line('get_clob_xmldocument::'||sqlerrm);
	RAISE v_tech_err;
   END get_clob_xmldocument;

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
   
   PROCEDURE VALIDATE_INPUT_PARMS ( p_i_d_process_date  IN   DATE,
                                     p_o_n_ret_flg    OUT  NUMBER
                                  )
   IS
   BEGIN                 
      p_o_n_ret_flg := 1;

      IF  FN_IS_VALID_DATE (TO_CHAR(p_i_d_process_date,'DD.MM.RRRR'),'DD.MM.RRRR') = 1
      THEN
          Pkg_Batch_Logger.proc_log(lf_file_handle, 'FATAL', 'BAT_E_0037',NULL,NULL);
          Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019', 'VALIDATE_INPUT_PARMS'||','||g_v_pkg_id, NULL);
          RETURN;
      END IF;

      p_o_n_ret_flg := 0;

   EXCEPTION
   WHEN OTHERS THEN
      Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019', 'VALIDATE_INPUT_PARMS'||g_v_pkg_id,NULL);
      Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',NULL,SQLERRM);
      p_o_n_ret_flg := 1;
   END VALIDATE_INPUT_PARMS; 
   
   
   FUNCTION FN_IS_VALID_DATE( v_valid_date  IN VARCHAR2,
                              v_date_format IN VARCHAR2 DEFAULT 'DD.MM.YYYY')
   RETURN NUMBER AS v_ret_code NUMBER;
    v_is_valid_date DATE;
   BEGIN
      v_ret_code := 0;
      IF  v_valid_date IS NULL
      THEN
          v_ret_code := 1;
          RETURN (v_ret_code);
      ELSE
          SELECT TO_DATE(v_valid_date,v_date_format)
          INTO   v_is_valid_date
          FROM   dual;
          v_ret_code := 0;
          RETURN (v_ret_code);
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         v_ret_code := 1;
         RETURN (v_ret_code);
   END FN_IS_VALID_DATE;
   
   
END PKG_TLL_UCS_REC_EXTRACTION;
/

