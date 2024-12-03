CREATE OR REPLACE PACKAGE PKG_TLL_TXS_REC_EXTRACTION
AS
   /*-------------------------------------------------------------------------------------------------*/
   /*  Name                 :  PKG_TLL_TXS_REC_EXTRACTION                                             */
   /*  Author               :  Hexaware Technologies                                                  */
   /*  Purpose              :  extract data's from different leasing contract management system and   */
   /*                           TXS.                                                                  */
   /*                                                                                                 */
   /*                        1.extract refinancing data's from different leasing contract management  */
   /*                          system xml files ,insert all the data into TP tables with process      */
   /*                          data and company number.                                               */
   /*                                                                                                 */
   /*                                                                                                 */
   /*                                                                                                 */
   /*                                                                                                 */
   /*                                                                                                 */
   /*  Revision History    :                                                                          */
   /*  <<Ver No>>           <<Modified By>>                    <<Modified Date>>                      */
   /*      1.0                Roshan  F                         31-Oct-2007                           */
   /*      1.1                Roshan  F                         24-Jan-2008                           */
   /*                         Hot fix for UAT to handle company number length issue                   */
   /*      1.2                Benjamine   Fix for 25053 - Batch Error Handling       07-Jun-2011      */
   /*      1.3                Benjamine   Fix for 25435 - file with zero bytes       08-Nov-2011      */
   /*      1.4                Vaishnavi B   PER_SI4 implementation                   02-Dec-2011      */
   /*      1.5                Roshan F    Fix for defect 25972                       09-July-2012     */
   /*      1.6                Rajasekaran Fix for CR 23923		                     09-Aug-2018      */
   /*-------------------------------------------------------------------------------------------------*/

   -- Global variable declarations

   g_v_pkg_id        CONSTANT        VARCHAR2(100) := 'PKG_TLL_TXS_REC_EXTRACTION ';   /* Variable to Store Package Name */
   g_v_prog_id       CONSTANT        VARCHAR2(100) := 'TLL_TXS_REC_EXTRACTION';        /* Variable to Store Program Name */
   g_v_proc_name     CONSTANT        VARCHAR2(100) := 'TLL_TXS_REC_EXTRACTION';
   g_v_pkg_prog_id   CONSTANT        VARCHAR2(300) :=  g_v_pkg_id || ' , ' || g_v_prog_id;
   g_v_user                          VARCHAR2(40)                  := 'TLL_TXS_REC_EXTRACTION_BATCH';
   g_v_err  VARCHAR2(100);

   g_v_errtable      VARCHAR2(50);

   lf_file_handle    UTL_FILE.FILE_TYPE;   -- Variable for Log File Handler

   v_proc_err        EXCEPTION;
   v_tech_err        EXCEPTION;
   v_exists_err      EXCEPTION;
   v_skip_record     EXCEPTION;
   v_insert_err      EXCEPTION;
   g_e_file_open_err EXCEPTION;

   g_n_no_records NUMBER(5) := 0;
   g_n_no_exists  NUMBER(5) := 0;
   g_n_no_files   number(5) := 0; -- Fix for 25053 Batch Error Handling
   g_n_no_excep   number(5) := 0; -- Fix for 25053 Batch Error Handling

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

   PROCEDURE XML_REFI_FILE_INS  (
                p_process_date IN DATE,
				p_comp_num in NUMBER,
				p_src_system IN VARCHAR2,
				p_o_n_ret_flg OUT NUMBER
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

END PKG_TLL_TXS_REC_EXTRACTION;
/
CREATE OR REPLACE PACKAGE BODY PKG_TLL_TXS_REC_EXTRACTION
AS
	  PROCEDURE MAIN_PROC (
	                        p_i_d_process_date     IN   DATE,
	                        p_o_n_ret_flg          OUT  NUMBER
	                       )
   AS

    CURSOR cursor_comp is SELECT distinct comp_num FROM TLL_CNTRCT_DET_TP  ;

BEGIN
      p_o_n_ret_flg         := 0;

/*-----------------------------------------------*/
/* Initialize File Handle for  Log File Writing  */
/*-----------------------------------------------*/

      BEGIN
        lf_file_handle := Pkg_Batch_Logger.func_open_log(g_v_prog_id);

        EXCEPTION
            WHEN OTHERS  THEN
          Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','Error while opening Spool file : ', NULL, SQLERRM);
            RAISE g_e_file_open_err;
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

	    VALIDATE_INPUT_PARMS ( p_i_d_process_date,
                                p_o_n_ret_flg
                              );

  	  IF  p_o_n_ret_flg<> 0
      THEN
            RAISE v_proc_err;
      END IF;

     /****************************************************/
     /* Block to delete refi tp table for given due date */
     /****************************************************/

      DELETE FROM TLL_REFIN_DET_TP WHERE DUE_DT = p_i_d_process_date;

     /****************************************************/
     /* Calling the txs extract procedure with file names*/
     /****************************************************/

      FOR I IN cursor_comp
      LOOP
            --IF(i.comp_num IN('5','83','599','120'))--1.5 --1.6
            --THEN --1.6
               XML_REFI_FILE_INS(p_i_d_process_date, i.comp_num,'UCS',p_o_n_ret_flg);
               XML_REFI_FILE_INS(p_i_d_process_date, i.comp_num,'UCS_INV',p_o_n_ret_flg); --PER_SI4
              -- IF  p_o_n_ret_flg<> 0  --1.6
             --  THEN  --1.6
             --     RAISE v_proc_err;  --1.6
             --  END IF;  --1.6
            --   g_n_no_files := g_n_no_files + 1;  -- Fix for 25053 Batch Error Handling  --1.6
           -- END IF;  --1.6

            XML_REFI_FILE_INS(p_i_d_process_date, i.comp_num,'TXS',p_o_n_ret_flg);

            IF  p_o_n_ret_flg<> 0
            THEN
               RAISE v_proc_err;
            END IF;
            g_n_no_files := g_n_no_files + 1;  -- Fix for 25053 Batch Error Handling
      END LOOP;

      IF g_n_no_files = g_n_no_excep THEN -- Fix for 25053 Batch Error Handling
        FOR cnt IN 1..2
        LOOP
          Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0000', '', '');
        END LOOP;
        Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','No Input file from UCS and TXS for Job Processing. Hence Failing the Job','','');
        RAISE v_tech_err;
      ELSE
        BEGIN
           UPDATE TLL_PROCESSING_TX SET   TXS_IMPORT_FLG  = 'Y'
           WHERE DUE_DT          = p_i_d_process_date;
        EXCEPTION
        WHEN OTHERS THEN
           Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Error in updating control table','','');
           RAISE v_tech_err;
        END;
      END IF;

      Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_TXS_REC_EXTRACTION        = ','',p_o_n_ret_flg);

      Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT',NULL,NULL,NULL);


      Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0012','MAIN_PROC'||','||g_v_pkg_id,NULL);
      Pkg_Batch_Logger.proc_log_status (lf_file_handle,'C');
EXCEPTION
WHEN  g_e_file_open_err
THEN
   p_o_n_ret_flg := 16;

   Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT',NULL,NULL,NULL);
   Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT','Error in File Opening',NULL,NULL);
   Pkg_Batch_Logger.proc_log_status (lf_file_handle,'S');
WHEN  v_proc_err
THEN
   p_o_n_ret_flg := 1;
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_TXS_REC_EXTRACTION       = ','',p_o_n_ret_flg);
   Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019','MAIN_PROC'||','||g_v_pkg_id,NULL);
   Pkg_Batch_Logger.proc_log_status (lf_file_handle,'B');
WHEN v_tech_err
THEN
   p_o_n_ret_flg :=2;
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_TXS_REC_EXTRACTION        = ','',p_o_n_ret_flg);
   Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019','MAIN_PROC'||','||g_v_pkg_id,NULL);
   Pkg_Batch_Logger.proc_log_status (lf_file_handle,'S');
WHEN v_exists_err
THEN
   p_o_n_ret_flg :=3;
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_TXS_REC_EXTRACTION        = ','',p_o_n_ret_flg);
   Pkg_Batch_Logger.proc_log(lf_file_handle,'DEBUG','RECORDS ALREADY DELETED FOR THE CURRENT DATE','','');
   Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019','MAIN_PROC'||','||g_v_pkg_id,NULL);
   Pkg_Batch_Logger.proc_log_status (lf_file_handle,'B');
WHEN  OTHERS
THEN

/* ------------------------------------------------------- */
/*      Other fatal Errors. Close and Terminate program    */
/* ------------------------------------------------------- */
   p_o_n_ret_flg := 20;
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_TXS_REC_EXTRACTION        = ','',p_o_n_ret_flg);
   Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019',  'MAIN_PROC' || ' , ' || g_v_pkg_id, '');
   Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',NULL,SQLERRM);
   Pkg_Batch_Logger.proc_log_status (lf_file_handle,'S');
   Pkg_Batch_Logger.proc_close_log(lf_file_handle);
END MAIN_PROC;

PROCEDURE XML_REFI_FILE_INS  (	p_process_date IN DATE,p_comp_num in NUMBER,p_src_system IN VARCHAR2,
				p_o_n_ret_flg       OUT NUMBER	)
AS
	v_file          BFILE   ;
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
	res             BOOLEAN;
	v_xmlvalue      CLOB;
	v_xmlvalue_type      XMLTYPE;
	v_xmlvalue_c    CLOB;
  p_contract_file_name varchar2(200) := null;

BEGIN
  p_o_n_ret_flg := 0;

  v_comp_num := p_comp_num;

  IF(p_src_system = 'UCS')
  THEN
        p_contract_file_name :=  'UCS2TLL_REFIDATA'||lpad(p_comp_num,3,0)||'_' ||TO_CHAR(p_process_date,'YYYYMMDD')||'.xml';
  ELSIF  (p_src_system = 'TXS') THEN
        p_contract_file_name :=  'RESP_TLL2TXS_REFIDATA'||lpad(p_comp_num,3,0) ||'_'||TO_CHAR(p_process_date,'YYYYMMDD')||'.xml';
  ELSE                                                                             --PER_SI4
        p_contract_file_name :=  'UCS2TLL_REFIDATA'||lpad(p_comp_num,3,0)||'_INACTV_' ||TO_CHAR(p_process_date,'YYYYMMDD')||'.xml';
  END IF;
  --v_file := BFILENAME ('INCOMING_DIR', p_contract_file_name);


	BEGIN
		v_file := BFILENAME ('INCOMING_DIR', p_contract_file_name);
	EXCEPTION
	WHEN UTL_FILE.INVALID_OPERATION
	THEN
		Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','The File < '||p_contract_file_name||' > is not available in FTP_IN Directory','','');
	WHEN OTHERS
	THEN
		Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Error while while check BFILENAME -'||sqlerrm,'','');
		p_o_n_ret_flg := 2;
	END;

  Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','XML_REFI_FILE_INS Procedure - STARTS -'||p_contract_file_name,'','');
  Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT','Company Number   =','',v_comp_num);

  IF DBMS_LOB.fileexists (v_file) = 1
  THEN
      Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','File exists '||p_contract_file_name,'','');
      DBMS_LOB.filegetname (v_file, dir_alias, v_name);
      Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Opening the file ','',dir_alias|| '  and  '||v_name);

      v_buffer_line := get_clob_xmldocument (p_contract_file_name);
      v_str_size := LENGTH (v_buffer_line);
      Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT','FILE SIZE  =','',v_str_size);

      v_count := occurs ('<refi_contract', v_buffer_line);
      Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT','Number of Records in file =','',v_count);
      IF (v_count > 0)
      THEN
            v_due_dt:=TO_DATE(SUBSTR (v_buffer_line,INSTR (v_buffer_line, 'sim_date', 1, 1) + 10,10),'DD.MM.RRRR');
            Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT','Due Date  =','',v_due_dt);
            LOOP
                  v_temp := (INSTR (v_buffer_line, '</refi_contract>', v_value_num, 1)+16);
                  v_value :=
                  TRIM (SUBSTR (v_buffer_line,
                  INSTR (v_buffer_line, '<refi_contract', v_value_num, 1),
                  (  INSTR (v_buffer_line,
                   '</refi_contract>',
                   v_value_num,
                   1
                  )
                  +16
                  - INSTR (v_buffer_line, '<refi_contract', v_value_num, 1)
                  )
                  )
                  );


                  IF  INSTR (v_buffer_line, '</refi_contract>', v_value_num, 1) - INSTR (v_buffer_line, '<refi_contract', v_value_num, 1) > 0
                  THEN
                        BEGIN
                           SELECT Extractvalue(Xmltype(v_value),'/refi_contract/@asset_id')
                           INTO  v_contract_id
                           FROM dual;
                        EXCEPTION
                        WHEN OTHERS
                        THEN
                           Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','Error in extracting asset_id : ', NULL, SQLERRM);
                           raise v_proc_err;
                        END;
                        v_value := '<?xml version="1.0"?><txs_refi_data xsi:noNamespaceSchemaLocation="TLL_refi_request_response.xsd" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" sim_date="'||v_due_dt||'" type="RESPONSE">'||v_value||'</txs_refi_data>';

                        BEGIN
                              INSERT INTO TLL_REFIN_DET_TP values (v_contract_id,v_due_dt,v_comp_num,xmltype(v_value));
                              commit;
                        EXCEPTION
                        WHEN OTHERS
                        THEN
                           Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Error while inserting ','',SQLERRM);
                           raise v_proc_err;
                        END ;
                  END IF;
                  EXIT WHEN (v_value_num > v_str_size) OR (v_inc > v_count);
                  v_inc := v_inc + 1;
                  v_value_num := v_temp;
                  v_contract_id  := NULL;
            END LOOP;
      ELSE
         Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','NO RECORDS IN TXS FILE    '||p_contract_file_name,'','');
      END IF;
  ELSE
   g_n_no_excep := g_n_no_excep + 1;  -- Fix for 25053 Batch Error Handling
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG',p_contract_file_name||' file does not exists ','','');
  END IF;

EXCEPTION
WHEN v_skip_record
THEN
     p_o_n_ret_flg := 0;
WHEN OTHERS
THEN
      p_o_n_ret_flg := 5;
      Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'PRO_XML_REFI_FILE_INS'||','||g_v_pkg_id, SQLERRM);
END XML_REFI_FILE_INS;


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
      -- Fix for 25435
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
END get_clob_xmldocument;

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

END PKG_TLL_TXS_REC_EXTRACTION;
/