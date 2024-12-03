CREATE OR REPLACE PACKAGE PKG_TLL_REC_EXTRATION
AS

   /*-------------------------------------------------------------------------------------------------*/
   /*  Name                 :  PKG_TLL_REC_EXTRATION                                                  */
   /*  Author               :  Hexaware Technologies                                                  */
   /*  Purpose              :  extract data's from different leasing contract management system and   */
   /*                           TXS.                                                                  */
   /*                                                                                                 */
   /*                        1.extract data's from different leasing contract management system xml   */
   /*                          files  txs xml files,insert all the data into TP tables with process  */
   /*                          data and company number.                                               */
   /*                                                                                                 */
   /*                                                                                                 */
   /*                                                                                                 */
   /*                                                                                                 */
   /*  Revision History    :                                                                          */
   /*  <<Ver No>>           <<Modified By>>                    <<Modified Date>>                      */
   /*      1.0                Roshan  F                         31-Oct-2007                           */
   /*-------------------------------------------------------------------------------------------------*/

   -- Global variable declarations

   g_v_pkg_id        CONSTANT        VARCHAR2(100) := 'PKG_TLL_REC_EXTRACTION ';   /* Variable to Store Package Name */
   g_v_prog_id       CONSTANT        VARCHAR2(100) := 'TLL_REC_EXTRACTION';       /* Variable to Store Program Name */
   g_v_proc_name     CONSTANT        VARCHAR2(100) := 'TLL_REC_EXTRACTION';
   g_v_pkg_prog_id   CONSTANT        VARCHAR2(300) :=  g_v_pkg_id || ' , ' || g_v_prog_id;
   g_v_user                          VARCHAR2(40)                  := 'TLL_REC_EXTRACTION_BATCH';
   g_v_err  varchar2(100);

   g_v_errtable      VARCHAR2(50);

   lf_file_handle    UTL_FILE.FILE_TYPE;   -- Variable for Log File Handler

   v_proc_err        EXCEPTION;
   v_tech_err        EXCEPTION;
   v_exists_err      EXCEPTION;
   v_insert_err      EXCEPTION;

   g_n_no_records NUMBER(5) := 0;
   g_n_no_exists NUMBER(5)  := 0;


   -- Public procedure declarations

/**************************************************/
/* Main Procedure which calls all other procedures*/
/**************************************************/

   PROCEDURE MAIN_PROC (
                        p_i_d_process_date     IN   DATE,
                        p_i_c_ext_typ          IN   VARCHAR2,
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
/*Procedure to   */
/********************************************/

   PROCEDURE XML_FILE_EXT (
                           p_contract_file_name IN   VARCHAR2,
                           p_o_n_ret_flg        OUT  NUMBER);


/*********************************************/
/*Procedure to extract data from txs response*/
/*********************************************/

   PROCEDURE XML_REFI_FILE_INS (p_contract_file_name IN   VARCHAR2,
                                p_o_n_ret_flg        OUT  NUMBER
                               );


END PKG_TLL_REC_EXTRATION;
/

CREATE OR REPLACE PACKAGE BODY PKG_TLL_REC_EXTRATION
AS
   PROCEDURE MAIN_PROC (
                        p_i_d_process_date     IN   DATE,
                        p_i_c_ext_typ          IN   VARCHAR2,
                        p_o_n_ret_flg          OUT  NUMBER
                       )

   AS
      v_contract_file_1        VARCHAR2 (30) := 'BUCS0711042.xml';  --'BUCS'||TO_CHAR(p_i_d_process_date,'YYMM')||'001.xml';
      v_contract_file_2        VARCHAR2 (30) := 'BUCS0711038.xml';  --'BUCS'||TO_CHAR(p_i_d_process_date,'YYMM')||'002.xml';
      v_contract_file_5        VARCHAR2 (30) := 'BUCS0711005.xml';  --'BUCS'||TO_CHAR(p_i_d_process_date,'YYMM')||'005.xml';
      v_contract_file_596      VARCHAR2 (30) := 'BUCS0711596.xml';  --'BUCS'||TO_CHAR(p_i_d_process_date,'YYMM')||'596.xml';
      v_contract_file_597      VARCHAR2 (30) := 'BUCS0711597.xml';  --'BUCS'||TO_CHAR(p_i_d_process_date,'YYMM')||'597.xml';
      v_contract_file_81       VARCHAR2 (30) := 'BUCS'||TO_CHAR(p_i_d_process_date,'YYMM')||'081.xml';
      v_contract_file_82       VARCHAR2 (30) := 'BUCS'||TO_CHAR(p_i_d_process_date,'YYMM')||'082.xml';
      v_contract_file_83       VARCHAR2 (30) := 'BUCS0711083.xml';  --'BUCS'||TO_CHAR(p_i_d_process_date,'YYMM')||'083.xml';
      v_contract_file_599      VARCHAR2 (30) := 'BUCS0711599.xml';  --'BUCS'||TO_CHAR(p_i_d_process_date,'YYMM')||'599.xml';
      v_contract_file_100      VARCHAR2 (30) := 'BUCS0711100.xml';  --'BUCS'||TO_CHAR(p_i_d_process_date,'YYMM')||'100.xml';
      v_contract_file_36      VARCHAR2 (30) := 'BUCS0711036.xml';  --'BUCS'||TO_CHAR(p_i_d_process_date,'YYMM')||'300.xml';
      v_contract_file_300      VARCHAR2 (30) := 'BUCS0711300.xml';  --'BUCS'||TO_CHAR(p_i_d_process_date,'YYMM')||'300.xml';
      v_contract_file_400      VARCHAR2 (30) := 'BUCS0711400.xml';  --'BUCS'||TO_CHAR(p_i_d_process_date,'YYMM')||'400.xml';
      v_contract_file_600      VARCHAR2 (30) := 'BUCS0711600.xml';  --'BUCS'||TO_CHAR(p_i_d_process_date,'YYMM')||'600.xml';

      v_contract_refi_file_5   VARCHAR2 (30) := 'BTXSREFIN005.xml';  --'BTXS'||TO_CHAR(p_i_d_process_date,'YYMM')||'005.xml';
      v_contract_refi_file_83  VARCHAR2 (30) := 'BTXSREFIN083.xml';  --'BTXS'||TO_CHAR(p_i_d_process_date,'YYMM')||'083.xml';
      v_contract_refi_file_599 VARCHAR2 (30) := 'BTXSREFIN599.xml';  --'BTXS'||TO_CHAR(p_i_d_process_date,'YYMM')||'599.xml';
      v_contract_refi_file_400 VARCHAR2 (130) := 'RESP_TLL2TXS_REFIDATA400_20071130.xml';  --'BTXS'||TO_CHAR(p_i_d_process_date,'YYMM')||'599.xml';
      v_contract_refi_file_100 VARCHAR2 (130) := 'RESP_TLL2TXS_REFIDATA100_20071130.xml';  --'BTXS'||TO_CHAR(p_i_d_process_date,'YYMM')||'599.xml';


   BEGIN

      /*DBMS_OUTPUT.put_line (   'Start Time - '
                            || TO_CHAR (SYSDATE, 'dd:MM:YYYY HH:MI:SSSS')
                           );*/



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
    Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT','EXTRATION TYPE     = ','',p_i_c_ext_typ);


     IF p_i_c_ext_typ = 'U' THEN

     /****************************************************/
     /* Calling the ucs extract procedure with file names*/
     /****************************************************/



     XML_FILE_EXT (v_contract_file_1,   p_o_n_ret_flg);
     XML_FILE_EXT (v_contract_file_36,   p_o_n_ret_flg);
     XML_FILE_EXT (v_contract_file_2,   p_o_n_ret_flg);
     XML_FILE_EXT (v_contract_file_5,   p_o_n_ret_flg);
     XML_FILE_EXT (v_contract_file_596, p_o_n_ret_flg);
     XML_FILE_EXT (v_contract_file_597, p_o_n_ret_flg);
     XML_FILE_EXT (v_contract_file_81,  p_o_n_ret_flg);
     XML_FILE_EXT (v_contract_file_82,  p_o_n_ret_flg);
     XML_FILE_EXT (v_contract_file_83,  p_o_n_ret_flg);
     XML_FILE_EXT (v_contract_file_599, p_o_n_ret_flg);
     XML_FILE_EXT (v_contract_file_100, p_o_n_ret_flg);
     XML_FILE_EXT (v_contract_file_300, p_o_n_ret_flg);
     XML_FILE_EXT (v_contract_file_400, p_o_n_ret_flg);
     XML_FILE_EXT (v_contract_file_600, p_o_n_ret_flg);

     END IF;


      IF p_i_c_ext_typ = 'T' THEN

     /****************************************************/
     /* Calling the TXS extract procedure with file names*/
     /****************************************************/

      XML_REFI_FILE_INS(v_contract_refi_file_5, p_o_n_ret_flg);
      XML_REFI_FILE_INS(v_contract_refi_file_83, p_o_n_ret_flg);
      XML_REFI_FILE_INS(v_contract_refi_file_599, p_o_n_ret_flg);
      XML_REFI_FILE_INS(v_contract_refi_file_100, p_o_n_ret_flg);
      XML_REFI_FILE_INS(v_contract_refi_file_400, p_o_n_ret_flg);


     END IF;

   /*------------------------------------------------------------------*/
   /* Stop Execution of Program if the Input Parms are Invalid         */
   /*------------------------------------------------------------------*/

        IF  p_o_n_ret_flg<> 0
        THEN
            RAISE v_proc_err;
        END IF;

        Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLLREFI_REQ_CREATION        = ','',p_o_n_ret_flg);

        Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT',NULL,NULL,NULL);


        Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0012','MAIN_PROC'||','||g_v_pkg_id,NULL);
        Pkg_Batch_Logger.proc_log_status (lf_file_handle,'C');


        /*DBMS_OUTPUT.put_line (   'END  Time - '
                            || TO_CHAR (SYSDATE, 'dd:MM:YYYY HH:MI:SSSS')
                           );*/
   EXCEPTION
WHEN  v_proc_err THEN
   p_o_n_ret_flg := 1;

   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_REC_EXTRATION        = ','',p_o_n_ret_flg);
   Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019','MAIN_PROC'||','||g_v_pkg_id,NULL);
   Pkg_Batch_Logger.proc_log_status (lf_file_handle,'B');

WHEN v_tech_err THEN
   p_o_n_ret_flg :=2;
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_REC_EXTRATION        = ','',p_o_n_ret_flg);
   Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019','MAIN_PROC'||','||g_v_pkg_id,NULL);
   Pkg_Batch_Logger.proc_log_status (lf_file_handle,'S');

WHEN v_exists_err THEN
   p_o_n_ret_flg :=3;
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_REC_EXTRATION        = ','',p_o_n_ret_flg);
   Pkg_Batch_Logger.proc_log(lf_file_handle,'DEBUG','RECORDS ALREADY DELETED FOR THE CURRENT DATE','','');
   Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019','MAIN_PROC'||','||g_v_pkg_id,NULL);
   Pkg_Batch_Logger.proc_log_status (lf_file_handle,'B');


WHEN  OTHERS THEN

/* ------------------------------------------------------- */
/*      Other fatal Errors. Close and Terminate program    */
/* ------------------------------------------------------- */
   p_o_n_ret_flg := 20;
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_REC_EXTRATION        = ','',p_o_n_ret_flg);
   Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019',  'MAIN_PROC' || ' , ' || g_v_pkg_id, '');
   Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',NULL,SQLERRM);
   Pkg_Batch_Logger.proc_log_status (lf_file_handle,'S');
   Pkg_Batch_Logger.proc_close_log(lf_file_handle);


    /*DBMS_OUTPUT.put_line (   'END  Time  - '
                            || TO_CHAR (SYSDATE, 'dd:MM:YYYY HH:MI:SSSS')
                           );*/

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
     -- v_ins_if        NUMBER (10)    := 0;
     v_asset_num        varchar2(20);
     v_vertragstyp      VARCHAR2(60);
   BEGIN

      p_o_n_ret_flg := 0;

      DBMS_OUTPUT.put_line ('xml_file_ext Procedure - STARTS - '||p_contract_file_name);

      IF DBMS_LOB.fileexists (v_file) = 1
      THEN
         DBMS_LOB.filegetname (v_file, dir_alias, v_name);
         DBMS_OUTPUT.put_line ('Opening ' || dir_alias || v_name);
         v_buffer_line := get_clob_xmldocument (p_contract_file_name);
         v_str_size := LENGTH (v_buffer_line);
         DBMS_OUTPUT.put_line ('the file size :' || v_str_size);
         v_due_dt :=
            TO_DATE (SUBSTR (v_buffer_line,
                             INSTR (v_buffer_line, 'stichtag', 1, 1) + 10,
                             10
                            ),
                     'DD.MM.YYYY'
                    );
         --DBMS_OUTPUT.put_line ('the process date is ' || v_due_dt);
         --------------------------------------------
           v_comp_num :=
               to_number(SUBSTR (p_contract_file_name,9,INSTR (p_contract_file_name,'.',1,1)-9),'9G999D99');

         ---------------------------------------------
--          v_comp_num :=
--             TO_NUMBER (SUBSTR (p_contract_file,
--                                INSTR (p_contract_file, '_', 1, 2) + 1,
--                                  INSTR (p_contract_file, '.xml', 1, 1)
--                                - 1
--                                - INSTR (p_contract_file, '_', 1, 2)
--                               )
--                       );
         --DBMS_OUTPUT.put_line ('the company no is ' || v_comp_num);
         v_count := occurs ('<!-- EndOfRecord -->', v_buffer_line);
         DBMS_OUTPUT.put_line ('the count is ' || v_count);

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
               --v_ins_if := v_ins_if + 1;
               v_contract_id :=
                  SUBSTR (v_buffer_line,
                          INSTR (v_buffer_line, 'vname', v_value_num, 1) + 7,
                          32
                         );
               --DBMS_OUTPUT.put_line ('the contract_id is ' || v_contract_id);

               BEGIN
                  INSERT INTO tll_cntrct_det_tp
                       VALUES (v_contract_id, v_due_dt, v_comp_num,
                               XMLTYPE (v_value));
							   
--                   IF(existsNode(v_value,'/bestand/vorgang/direktvertrag/vertrag/anlagevermoegen							   
                        
                        SELECT extract(xmltype(v_value),'/bestand/vorgang/direktvertrag/vertrag/anlagevermoegen/@asset_num').getStringVal() ,
                        extract(xmltype(v_value),'/bestand/vorgang/direktvertrag/vertrag/vertragsheader/@vertragstyp').getStringVal() 
                        into v_asset_num,v_vertragstyp
                        from dual;
    		        
                        IF(v_vertragstyp != 'MIETKAUF')
                        THEN
                                insert into TLL_CNTRCT_STG_TP (CNTRCT_ID, OBJ_PKG_NUM, COMP_NUM, DUE_DT)
                                values(v_contract_id,v_asset_num,v_comp_num,v_due_dt) ;
                        END IF;
                        
              EXCEPTION
              WHEN OTHERS   THEN
              p_o_n_ret_flg := 5;
              Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'PRO_XML_FILE_EXT'||','||g_v_pkg_id, SQLERRM);

               END;
            END IF;

            --INSERT INTO TEST VALUES (v_inc,'v_value_num is ' || v_value_num  || 'v_value is  ' || length (v_value) || ' 1 - '||INSTR (v_buffer_line, '<?xml', v_value_num, 1)||' 2 - '||INSTR (v_buffer_line,'<!-- EndOfRecord -->',v_value_num,1)||' 3 - '||INSTR (v_buffer_line, '<?xml', v_value_num, 1),v_contract_id);

            EXIT WHEN (v_value_num > v_str_size) OR (v_inc > v_count);

            v_inc := v_inc + 1;
            --v_value_num := DBMS_LOB.getlength (v_value) + v_value_num + 20;

            v_value_num := v_temp + 20;

         END LOOP;

         --DBMS_OUTPUT.put_line ('v_inc : ' || v_inc);
         --DBMS_OUTPUT.put_line ('v_ins_if : ' || v_ins_if);
      ELSE

         p_o_n_ret_flg := 0;
         DBMS_OUTPUT.put_line ('the is no file in the directory');


      END IF;
    EXCEPTION
              WHEN OTHERS   THEN
              p_o_n_ret_flg := 5;
              Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'PRO_XML_FILE_EXT'||','||g_v_pkg_id, SQLERRM);

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
      DBMS_OUTPUT.put_line ('In GET_CLOB_XMLDOCUMENT - ' || f_v_filename);
      targetfile := v_file;
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
      RETURN charcontent;
   EXCEPTION
      WHEN OTHERS
      THEN
         DBMS_OUTPUT.put_line (   'GET_CLOB_XMLDOCUMENT - WHEN OTHERS - '
                               || SQLERRM
                              );
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



      PROCEDURE XML_REFI_FILE_INS(p_contract_file_name IN VARCHAR2,
                                p_o_n_ret_flg       OUT NUMBER)
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
      res             BOOLEAN;
      v_xmlvalue      CLOB;
      v_xmlvalue_type      xmltype;
      v_xmlvalue_c    CLOB;
   BEGIN

      p_o_n_ret_flg := 0;



		   DBMS_OUTPUT.put_line ('xml_refi_file_ext Procedure - STARTS');

	       Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','Checking for the file  '||p_contract_file_name,'','');


	     IF DBMS_LOB.fileexists (v_file) = 1
         THEN

		 Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','File exists '||p_contract_file_name,'','');

		 DBMS_LOB.filegetname (v_file, dir_alias, v_name);

		 DBMS_OUTPUT.put_line ('Opening ' || dir_alias || v_name);


		 v_buffer_line := get_clob_xmldocument (p_contract_file_name);
		 v_str_size := LENGTH (v_buffer_line);
         DBMS_OUTPUT.put_line ('the file size :' || v_str_size);



		 v_due_dt:=TO_DATE(SUBSTR (v_buffer_line,INSTR (v_buffer_line, 'sim_date', 1, 1) + 10,10),'DD.MM.RRRR');

         DBMS_OUTPUT.put_line ('the process date is ' || v_due_dt);


         v_comp_num :=
               to_number(SUBSTR (v_buffer_line,INSTR (v_buffer_line, 'comp_no=', 1, 1)+9,3),'9G999D99');

         DBMS_OUTPUT.put_line ('comp_no is ' || v_comp_num );

         v_count := occurs ('<refi_contract', v_buffer_line);

         DBMS_OUTPUT.put_line ('the count is ' || v_count);



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


					    IF   INSTR (v_buffer_line, '</refi_contract>', v_value_num, 1)

                - INSTR (v_buffer_line, '<refi_contract', v_value_num, 1) > 0
             THEN
					v_contract_id :=
                  SUBSTR (v_buffer_line,
                          INSTR (v_buffer_line, 'asset_id=', v_value_num, 1) + 10,
						  (  INSTR (v_buffer_line,
                                       ' comp_no',
                                       v_value_num,
                                       1
                                      )
                              -2
                              - INSTR (v_buffer_line, 'asset_id=', v_value_num, 1) -10
                             )

                         );

				--DBMS_OUTPUT.put_line ('asset_num  ' || v_contract_id);

					--insert into sample values (v_inc,v_value);


					v_value := '<?xml version="1.0"?><txs_refi_data xsi:noNamespaceSchemaLocation="TLL_refi_request_response.xsd" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" sim_date="'||v_due_dt||'" type="RESPONSE">'||v_value||'</txs_refi_data>';
					--dbms_output.put_line('BEfore Insert');
					INSERT INTO TLL_REFIN_DET_TP values (v_contract_id,v_due_dt,v_comp_num,xmltype(v_value));
					--dbms_output.put_line('After Insert');
					commit;

				END IF;


--
            EXIT WHEN (v_value_num > v_str_size) OR (v_inc > v_count);

            v_inc := v_inc + 1;

            v_value_num := v_temp;

					v_contract_id  := NULL;

         END LOOP;



       END IF;

         EXCEPTION
              WHEN OTHERS   THEN
              p_o_n_ret_flg := 5;
              Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'PRO_XML_REFI_FILE_INS'||','||g_v_pkg_id, SQLERRM);



   END XML_REFI_FILE_INS;




END PKG_TLL_REC_EXTRATION;
/
