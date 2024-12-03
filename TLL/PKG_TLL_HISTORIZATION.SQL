CREATE OR REPLACE PACKAGE PKG_TLL_HISTORIZATION

IS
  
   /*-------------------------------------------------------------------------------------------------*/
   /*  Name                  :  PKG_TLL_HISTORIZATION                                                 */
   /*  Author                :  Hexaware Technologies                                                 */
   /*  Purpose               :  Populates all the  entries in HISTORIZATION tables and clear          */
   /*                           the TP table.                                                         */
   /*                                                                                                 */ 
   /*                           Get all the records of contract,refinancing and sap details from      */ 
   /*                           temp tables,stores the dump in the historization tables and           */
   /*                           delete the record in the historization tables as per the requirement. */
   /*                                                                                                 */
   /*                                                                                                 */
   /*  Revision History    :                                                                          */
   /*  <<Ver No>>           <<Modified By>>                    <<Modified Date>>                      */
   /*      1.0                Roshan  F                         31-Oct-2007                           */
   /*      1.1                Kalimuthu                         05-May-2008                           */
   /*                                        no of record count variable length from 5 to 10 digits   */
   /*-------------------------------------------------------------------------------------------------*/
   
   
    -- Global variable declarations

   g_v_pkg_id        CONSTANT        VARCHAR2(100) := 'PKG_TLL_HISTORIZATION';   /* Variable to Store Package Name */
   g_v_prog_id       CONSTANT        VARCHAR2(100) := 'TLL_HISTORIZATION';       /* Variable to Store Program Name */
   g_v_proc_name     CONSTANT        VARCHAR2(100) := 'TLL_HISTORIZATION';
   g_v_pkg_prog_id   CONSTANT        VARCHAR2(300) :=  g_v_pkg_id || ' , ' || g_v_prog_id;
   g_v_user          VARCHAR2(40)                  := 'TLL_HISTORIZATION_BATCH';
   g_v_err  varchar2(100);
   
   g_v_errtable      VARCHAR2(50);

   lf_file_handle    UTL_FILE.FILE_TYPE;   -- Variable for Log File Handler
   
   v_proc_err        EXCEPTION;
   v_tech_err        EXCEPTION;
   v_exists_err      EXCEPTION;
   v_insert_err      EXCEPTION;
   v_record_err      EXCEPTION;
   
   
   g_n_contract_no_exists  NUMBER(10) := 0;
   g_n_refin_no_exists     NUMBER(10) := 0;
   g_n_sap_no_exists       NUMBER(10) := 0;

   g_n_cnt_mon_no_exists       NUMBER(10) := 0;
   g_n_cnt_qtly_no_exists      NUMBER(10) := 0;
   g_n_cnt_yrly_no_exists      NUMBER(10) := 0;
   
   
   -- Public procedure declarations

/**************************************************/
/* Main Procedure which calls all other procedures*/
/**************************************************/
   

   PROCEDURE MAIN_PROC (
                        p_i_d_run_date            IN DATE,
                        p_o_n_ret_flg            OUT NUMBER
                       );
                       
                       
/********************************************/
/*Procedure to validate the input parameters*/
/********************************************/

PROCEDURE PRO_INS_TLL_TAB (
                           v_i_d_run_date         IN DATE,
                           p_o_n_ret_flg          OUT NUMBER
                          );
                          
                          
PROCEDURE PRO_DEL_TLL_TAB (
                           v_i_d_run_date         IN DATE,
                           p_o_n_ret_flg          OUT NUMBER
                          );
                          
                           
                           
END PKG_TLL_HISTORIZATION;
/


CREATE OR REPLACE PACKAGE BODY PKG_TLL_HISTORIZATION
AS

PROCEDURE MAIN_PROC    (
                        p_i_d_run_date            IN DATE,
                        p_o_n_ret_flg            OUT NUMBER
                       )
IS


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
    Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT','Input Run date       = ','', to_char( p_i_d_run_date ,'dd.mm.rrrr') );
    
    
    Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','START TIME FOR MAIN PROC  : ', '', TO_CHAR(SYSDATE,'hh:mi:ss'));
    
    
   /*------------------------------------------------------------------*/
   /* Check if Input Parameters are Valid                              */
   /*------------------------------------------------------------------*/

              
           BEGIN
                  
                  SELECT COUNT(1) INTO g_n_contract_no_exists 
                  FROM TLL_CNTRCT_DET_TP 
                  WHERE DUE_DT = p_i_d_run_date;
                 
                  SELECT COUNT(1) INTO g_n_refin_no_exists 
                  FROM TLL_REFIN_DET_TP 
                  WHERE DUE_DT = p_i_d_run_date;
                  
                  SELECT COUNT(1) INTO g_n_sap_no_exists 
                  FROM TLL_SAP_DEPRC_TP 
                  WHERE DUE_DT = p_i_d_run_date;
                 
                 
                 IF g_n_contract_no_exists = 0 --AND g_n_refin_no_exists = 0 AND g_n_sap_no_exists = 0 
                 THEN
                 
                  RAISE v_exists_err;
                 
                 END IF;
                                   
            END; 
            
	    BEGIN
            
            SELECT COUNT(1) INTO g_n_cnt_mon_no_exists 
                  FROM TLL_CNTRCT_DET_MON_TX 
                  WHERE DUE_DT = p_i_d_run_date;

            SELECT COUNT(1) INTO g_n_cnt_qtly_no_exists 
                  FROM TLL_CNTRCT_DET_QTRLY_TX
                  WHERE DUE_DT = p_i_d_run_date;

	    SELECT COUNT(1) INTO g_n_cnt_yrly_no_exists 
                  FROM TLL_CNTRCT_DET_YRLY_TX
                  WHERE DUE_DT = p_i_d_run_date;

	    IF g_n_cnt_mon_no_exists != 0 OR g_n_cnt_qtly_no_exists != 0 OR g_n_cnt_yrly_no_exists != 0 
            THEN
	    DELETE FROM TLL_CNTRCT_DET_TP where DUE_DT = p_i_d_run_date;
            DELETE FROM TLL_CNTRCT_STG_TP where DUE_DT = p_i_d_run_date;
	    DELETE FROM TLL_REFIN_DET_TP where DUE_DT = p_i_d_run_date;
	    DELETE FROM TLL_SAP_DEPRC_TP where DUE_DT = p_i_d_run_date;
            RAISE v_record_err;
            END IF;
	    END;




                           
           PRO_INS_TLL_TAB (
                            p_i_d_run_date,
                            p_o_n_ret_flg
                           );
						   
		 
        IF  p_o_n_ret_flg<> 0
        THEN
            RAISE v_proc_err;
        END IF;
                           
                           
           PRO_DEL_TLL_TAB (
                            p_i_d_run_date,
                            p_o_n_ret_flg
                           );
                           
                           



        IF  p_o_n_ret_flg<> 0
        THEN
            RAISE v_proc_err;
        END IF;
        
        
    Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_HISTORIZATION        = ','',p_o_n_ret_flg);
    Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','END TIME FOR MAIN PROC  : ', '', TO_CHAR(SYSDATE,'hh:mi:ss'));
    Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT',NULL,NULL,NULL);


    Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0012','MAIN_PROC'||','||g_v_pkg_id,NULL);
    Pkg_Batch_Logger.proc_log_status (lf_file_handle,'C');
    


    
    EXCEPTION
WHEN  v_proc_err THEN
   p_o_n_ret_flg := 1;
   
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_HISTORIZATION        = ','',p_o_n_ret_flg);
   Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019','MAIN_PROC'||','||g_v_pkg_id,NULL);
   Pkg_Batch_Logger.proc_log_status (lf_file_handle,'B');
 
WHEN v_tech_err THEN
   p_o_n_ret_flg :=2;
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_HISTORIZATION        = ','',p_o_n_ret_flg);
   Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019','MAIN_PROC'||','||g_v_pkg_id,NULL);
   Pkg_Batch_Logger.proc_log_status (lf_file_handle,'S');

WHEN v_exists_err THEN
   p_o_n_ret_flg :=0;
   Pkg_Batch_Logger.proc_log(lf_file_handle,'DEBUG','NO RECORDS EXITS FOR ARCHIVAL PROCESS','','');
   Pkg_Batch_Logger.proc_log_status (lf_file_handle,'C');
   
WHEN v_record_err THEN
   p_o_n_ret_flg :=0;
   Pkg_Batch_Logger.proc_log(lf_file_handle,'DEBUG','RECORDS ALLREADY THERE IN ARCHIVAL TABLES FOR THIS PROCESS DATE','','');
   Pkg_Batch_Logger.proc_log_status (lf_file_handle,'C'); 

WHEN OTHERS THEN

/* ------------------------------------------------------- */
/*      Other fatal Errors. Close and Terminate program    */
/* ------------------------------------------------------- */
   p_o_n_ret_flg := 20;
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','the return code generated from PKG_TLL_HISTORIZATION        = ','',p_o_n_ret_flg);
   Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019',  'MAIN_PROC' || ' , ' || g_v_pkg_id, '');
   Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999',NULL,SQLERRM);
   Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','END TIME FOR MAIN PROC  : ', '', TO_CHAR(SYSDATE,'hh:mi:ss'));
   Pkg_Batch_Logger.proc_log_status (lf_file_handle,'S');
   Pkg_Batch_Logger.proc_close_log(lf_file_handle);
   
   
   


END MAIN_PROC;




PROCEDURE PRO_INS_TLL_TAB (
                           v_i_d_run_date         IN DATE,
                           p_o_n_ret_flg          OUT NUMBER
                          )
                          
AS

CURSOR xml_cur_contract is select cntrct_id,due_dt,comp_num,cntrct_det from     TLL_CNTRCT_DET_TP WHERE due_dt = v_i_d_run_date;-- WHERE due_dt = to_date(p_process_dt,'DD.MM.YYYY' );
CURSOR xml_cur_refin is select cntrct_id,due_dt,comp_num,refin_det     from     TLL_REFIN_DET_TP WHERE due_dt = v_i_d_run_date;-- WHERE due_dt = to_date(p_process_dt,'DD.MM.YYYY' );
CURSOR xml_cur_sap is select obj_pkg_num,due_dt,comp_num,deprc_det     from     TLL_SAP_DEPRC_TP WHERE due_dt = v_i_d_run_date;-- WHERE due_dt = to_date(p_process_dt,'DD.MM.YYYY' );
CURSOR xml_cur_stg is select cntrct_id,obj_pkg_num,comp_num,due_dt     from     TLL_CNTRCT_STG_TP WHERE due_dt = v_i_d_run_date;-- WHERE due_dt = to_date(p_process_dt,'DD.MM.YYYY' );



TYPE v_typ_tab_xml_cntrct_id IS TABLE OF   TLL_CNTRCT_DET_TP.cntrct_id%TYPE INDEX BY BINARY_INTEGER;
TYPE v_typ_tab_xml_contract_dt IS TABLE OF   TLL_CNTRCT_DET_TP.due_dt%TYPE INDEX BY BINARY_INTEGER;
TYPE v_typ_tab_xml_contract_comp IS TABLE OF TLL_CNTRCT_DET_TP.comp_num%TYPE INDEX BY BINARY_INTEGER;
TYPE v_typ_tab_xml_cntrct_det IS TABLE OF  TLL_CNTRCT_DET_TP.cntrct_det%TYPE INDEX BY BINARY_INTEGER;

TYPE v_typ_tab_xml_refin_id IS TABLE OF   TLL_REFIN_DET_TP.cntrct_id%TYPE INDEX BY BINARY_INTEGER;
TYPE v_typ_tab_xml_refin_dt IS TABLE OF   TLL_REFIN_DET_TP.due_dt%TYPE INDEX BY BINARY_INTEGER;
TYPE v_typ_tab_xml_refin_comp IS TABLE OF TLL_REFIN_DET_TP.comp_num%TYPE INDEX BY BINARY_INTEGER;
TYPE v_typ_tab_xml_refin_det IS TABLE OF  TLL_REFIN_DET_TP.refin_det%TYPE INDEX BY BINARY_INTEGER;

TYPE v_typ_tab_xml_sap_id   IS TABLE OF   TLL_SAP_DEPRC_TP.obj_pkg_num%TYPE INDEX BY BINARY_INTEGER;
TYPE v_typ_tab_xml_sap_dt   IS TABLE OF   TLL_SAP_DEPRC_TP.due_dt%TYPE INDEX BY BINARY_INTEGER;
TYPE v_typ_tab_xml_sap_comp IS TABLE OF   TLL_SAP_DEPRC_TP.comp_num%TYPE INDEX BY BINARY_INTEGER;
TYPE v_typ_tab_xml_sap_det  IS TABLE OF TLL_SAP_DEPRC_TP.deprc_det%TYPE INDEX BY BINARY_INTEGER;


TYPE v_typ_tab_xml_stg_id   IS TABLE OF   TLL_CNTRCT_STG_TP.cntrct_id%TYPE INDEX BY BINARY_INTEGER;
TYPE v_typ_tab_xml_stg_num  IS TABLE OF   TLL_CNTRCT_STG_TP.obj_pkg_num%TYPE INDEX BY BINARY_INTEGER;
TYPE v_typ_tab_xml_stg_comp IS TABLE OF   TLL_CNTRCT_STG_TP.comp_num%TYPE INDEX BY BINARY_INTEGER;
TYPE v_typ_tab_xml_stg_dt  IS TABLE OF    TLL_CNTRCT_STG_TP.due_dt%TYPE INDEX BY BINARY_INTEGER;

v_tab_xml_cntrct_id         v_typ_tab_xml_cntrct_id;
v_tab_xml_contract_dt       v_typ_tab_xml_contract_dt;
v_tab_xml_contract_comp     v_typ_tab_xml_contract_comp;
v_tab_xml_cntrct_det        v_typ_tab_xml_cntrct_det;

v_tab_xml_refin_id          v_typ_tab_xml_refin_id;
v_tab_xml_refin_dt          v_typ_tab_xml_refin_dt;
v_tab_xml_refin_comp        v_typ_tab_xml_refin_comp;
v_tab_xml_refin_det         v_typ_tab_xml_refin_det;

v_tab_xml_sap_id            v_typ_tab_xml_sap_id;
v_tab_xml_sap_dt            v_typ_tab_xml_sap_dt;
v_tab_xml_sap_comp          v_typ_tab_xml_sap_comp;
v_tab_xml_sap_det           v_typ_tab_xml_sap_det;

v_tab_xml_stg_id            v_typ_tab_xml_stg_id;
v_tab_xml_stg_num           v_typ_tab_xml_stg_num;
v_tab_xml_stg_comp          v_typ_tab_xml_stg_comp;
v_tab_xml_stg_dt            v_typ_tab_xml_stg_dt;


BEGIN

/*-----------------------------------------------------------*/
/* inserting the records with due_dt in histrirization tables*/
/*-----------------------------------------------------------*/

p_o_n_ret_flg         := 0;


BEGIN

Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','INSERTING FOR CONTRACT DETAILS -STRATS   ', '',NULL);

OPEN xml_cur_contract;
LOOP
FETCH xml_cur_contract BULK COLLECT into v_tab_xml_cntrct_id,v_tab_xml_contract_dt,v_tab_xml_contract_comp,v_tab_xml_cntrct_det LIMIT 5000;

BEGIN

FORALL I IN v_tab_xml_cntrct_id.FIRST..v_tab_xml_cntrct_id.LAST
   
   INSERT INTO TLL_CNTRCT_DET_MON_TX
   (
   cntrct_id,
   DUE_DT,
   COMP_NUM,
   cntrct_det
   )
  
   VALUES
   (
    v_tab_xml_cntrct_id(I),
    v_tab_xml_contract_dt(I),
    v_tab_xml_contract_comp(I),
    v_tab_xml_cntrct_det(I)
   );
   
   EXCEPTION
   
   WHEN NO_DATA_FOUND    THEN

      p_o_n_ret_flg := 4;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR CONTRACT DETAILS - MONTHLY'||','||g_v_pkg_id, SQLERRM);


   WHEN TOO_MANY_ROWS THEN

      p_o_n_ret_flg := 5;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR CONTRACT DETAILS- MONTHLY'||','||g_v_pkg_id, SQLERRM);

      
   WHEN OTHERS   THEN
      p_o_n_ret_flg := 20;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR CONTRACT DETAILS - MONTHLY'||','||g_v_pkg_id, SQLERRM);

         --DBMS_OUTPUT.put_line (' Inserting of TLL_CNTRCT_DET_MON_TX - WHEN OTHERS - ' || SQLERRM);
END;



IF TO_CHAR(TO_DATE(v_i_d_run_date, 'DD-MM-YYYY'),'MM') IN (03,06,09,12) THEN

BEGIN


FORALL I IN v_tab_xml_cntrct_id.FIRST..v_tab_xml_cntrct_id.LAST
   
   INSERT INTO TLL_CNTRCT_DET_QTRLY_TX
   (
   cntrct_id,
   DUE_DT,
   COMP_NUM,
   cntrct_det
   )
  
   VALUES
   (
    v_tab_xml_cntrct_id(I),
    v_tab_xml_contract_dt(I),
    v_tab_xml_contract_comp(I),
    v_tab_xml_cntrct_det(I)
   );

   EXCEPTION
      
   
   WHEN NO_DATA_FOUND    THEN

      p_o_n_ret_flg := 4;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR CONTRACT DETAILS - QRTLY'||','||g_v_pkg_id, SQLERRM);


   WHEN TOO_MANY_ROWS THEN

      p_o_n_ret_flg := 5;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR CONTRACT DETAILS- QRTLY'||','||g_v_pkg_id, SQLERRM);

      
   WHEN OTHERS   THEN
      p_o_n_ret_flg := 20;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR CONTRACT DETAILS- QRTLY'||','||g_v_pkg_id, SQLERRM);
        -- DBMS_OUTPUT.put_line (' Inserting of TLL_CNTRCT_DET_QTRLY_TX - WHEN OTHERS - ' || SQLERRM);
END;

ELSE
 
  Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','The condition does not match for qrtly', '', NULL);

  --DBMS_OUTPUT.put_line ('the condition does not match for qrtly');
  
END IF;

IF TO_CHAR(TO_DATE(v_i_d_run_date, 'DD-MM-YYYY'),'MM') IN (09) THEN

BEGIN

FORALL I IN v_tab_xml_cntrct_id.FIRST..v_tab_xml_cntrct_id.LAST
   
   INSERT INTO TLL_CNTRCT_DET_YRLY_TX
   (
   cntrct_id,
   DUE_DT,
   COMP_NUM,
   cntrct_det
   )
  
   VALUES
   (
    v_tab_xml_cntrct_id(I),
    v_tab_xml_contract_dt(I),
    v_tab_xml_contract_comp(I),
    v_tab_xml_cntrct_det(I)
   );

   EXCEPTION
      
   WHEN NO_DATA_FOUND    THEN

      p_o_n_ret_flg := 4;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR CONTRACT DETAILS - YEARLY'||','||g_v_pkg_id, SQLERRM);


   WHEN TOO_MANY_ROWS THEN

      p_o_n_ret_flg := 5;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR CONTRACT DETAILS - YEARLY'||','||g_v_pkg_id, SQLERRM);

      
   WHEN OTHERS   THEN
      p_o_n_ret_flg := 20;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR CONTRACT DETAILS - YEARLY'||','||g_v_pkg_id, SQLERRM);
         --DBMS_OUTPUT.put_line (' Inserting of TLL_CNTRCT_DET_YRLY_TX - WHEN OTHERS - ' || SQLERRM);
END;

ELSE

  Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','The condition does not match for Yearly', '', NULL); 
  --DBMS_OUTPUT.put_line ('the condition does not match for Yearly');
  
END IF;


EXIT WHEN xml_cur_contract%NOTFOUND;
--COMMIT;
END LOOP;
  CLOSE xml_cur_contract;
  
  Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','INSERTING FOR CONTRACT DETAILS -ENDS   ', '',NULL);
  EXCEPTION
      
      WHEN OTHERS   THEN
      p_o_n_ret_flg := 20;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'cursor of INSERTING CONTRACT DEATILS '||','||g_v_pkg_id, SQLERRM);

         --DBMS_OUTPUT.put_line (' cursor of INSERTING CONTRACT DEATILS - WHEN OTHERS - ' || SQLERRM);         
END;
  

BEGIN

  Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','INSERTING FOR REFIN DETAILS -STRATS   ', '',NULL);

OPEN xml_cur_refin;
LOOP
FETCH xml_cur_refin BULK COLLECT into v_tab_xml_refin_id,v_tab_xml_refin_dt,v_tab_xml_refin_comp,v_tab_xml_refin_det LIMIT 5000;

BEGIN

FORALL I IN v_tab_xml_refin_id.FIRST..v_tab_xml_refin_id.LAST
   
   INSERT INTO TLL_REFIN_DET_MON_TX
   (
   cntrct_id,
   DUE_DT,
   COMP_NUM,
   REFIN_DET
   )
  
   VALUES
   (
    v_tab_xml_refin_id(I),
    v_tab_xml_refin_dt(I),
    v_tab_xml_refin_comp(I),
    v_tab_xml_refin_det(I)
   );
   
   EXCEPTION
      
   WHEN NO_DATA_FOUND    THEN

      p_o_n_ret_flg := 4;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR REFIN DETAILS - MONTHLY'||','||g_v_pkg_id, SQLERRM);


   WHEN TOO_MANY_ROWS THEN

      p_o_n_ret_flg := 5;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR REFIN DETAILS - MONTHLY'||','||g_v_pkg_id, SQLERRM);

      
   WHEN OTHERS   THEN
      p_o_n_ret_flg := 20;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR REFIN DETAILS - MONTHLY'||','||g_v_pkg_id, SQLERRM);
         --DBMS_OUTPUT.put_line (' Inserting of TLL_REFIN_DET_MON_TX - WHEN OTHERS - ' || SQLERRM);
END;



IF TO_CHAR(TO_DATE(v_i_d_run_date, 'DD-MM-YYYY'),'MM') IN (03,06,09,12) THEN

BEGIN


FORALL I IN v_tab_xml_refin_id.FIRST..v_tab_xml_refin_id.LAST
   
   INSERT INTO TLL_REFIN_DET_QTRLY_TX
   (
   cntrct_id,
   DUE_DT,
   COMP_NUM,
   REFIN_DET
   )
  
   VALUES
   (
    v_tab_xml_refin_id(I),
    v_tab_xml_refin_dt(I),
    v_tab_xml_refin_comp(I),
    v_tab_xml_refin_det(I)
   );

   EXCEPTION
       
    WHEN NO_DATA_FOUND    THEN

      p_o_n_ret_flg := 4;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR REFIN DETAILS - QRTLY '||','||g_v_pkg_id, SQLERRM);


   WHEN TOO_MANY_ROWS THEN

      p_o_n_ret_flg := 5;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR REFIN DETAILS - QRTLY '||','||g_v_pkg_id, SQLERRM);

      
   WHEN OTHERS   THEN
      p_o_n_ret_flg := 20;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR REFIN DETAILS - QRTLY '||','||g_v_pkg_id, SQLERRM);
         --DBMS_OUTPUT.put_line (' Inserting of TLL_REFIN_DET_QTRLY_TX - WHEN OTHERS - ' || SQLERRM);
END;

ELSE
 
  Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','The condition does not match for qrtly - REFIN', '', NULL);
  --DBMS_OUTPUT.put_line ('the condition does not match for qrtly');
  
END IF;

IF TO_CHAR(TO_DATE(v_i_d_run_date, 'DD-MM-YYYY'),'MM') IN (09) THEN

BEGIN

FORALL I IN v_tab_xml_refin_id.FIRST..v_tab_xml_refin_id.LAST
   
   INSERT INTO TLL_REFIN_DET_YRLY_TX
   (
   cntrct_id,
   DUE_DT,
   COMP_NUM,
   REFIN_DET
   )
  
   VALUES
   (
    v_tab_xml_refin_id(I),
    v_tab_xml_refin_dt(I),
    v_tab_xml_refin_comp(I),
    v_tab_xml_refin_det(I)
   );

   EXCEPTION
   
   WHEN NO_DATA_FOUND    THEN

      p_o_n_ret_flg := 4;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR REFIN DETAILS - YEARLY '||','||g_v_pkg_id, SQLERRM);


   WHEN TOO_MANY_ROWS THEN

      p_o_n_ret_flg := 5;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR REFIN DETAILS - YEARLY '||','||g_v_pkg_id, SQLERRM);

      
   WHEN OTHERS   THEN
      p_o_n_ret_flg := 20;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR REFIN DETAILS - YEARLY'||','||g_v_pkg_id, SQLERRM);

         --DBMS_OUTPUT.put_line (' Inserting of TLL_REFIN_DET_YRLY_TX - WHEN OTHERS - ' || SQLERRM);
END;

ELSE
 
  Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','The condition does not match for yearly - REFIN', '', NULL);
  --DBMS_OUTPUT.put_line ('the condition does not match for Yearly');
  
END IF;


EXIT WHEN xml_cur_refin%NOTFOUND;
--COMMIT;
END LOOP;
  CLOSE xml_cur_refin;
  
  Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','INSERTING FOR REFIN DETAILS -ENDS   ', '',NULL);
  

  
   EXCEPTION
      
      WHEN OTHERS   THEN
      
      p_o_n_ret_flg := 20;
      
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'cursor of INSERTING REFIN DEATILS '||','||g_v_pkg_id, SQLERRM);
         
      --DBMS_OUTPUT.put_line (' cursor of INSERTING REFIN DEATILS - WHEN OTHERS - ' || SQLERRM);
         
END;

BEGIN

Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','INSERTING FOR SAP DETAILS -STRATS   ', '',NULL);

OPEN xml_cur_sap;
LOOP
FETCH xml_cur_sap BULK COLLECT into v_tab_xml_sap_id,v_tab_xml_sap_dt,v_tab_xml_sap_comp,v_tab_xml_sap_det LIMIT 5000;

BEGIN

FORALL I IN v_tab_xml_sap_id.FIRST..v_tab_xml_sap_id.LAST
   
   INSERT INTO TLL_SAP_DEPRC_MON_TX
   (
   OBJ_PKG_NUM,
   DUE_DT,
   COMP_NUM,
   deprc_det
   )
  
   VALUES
   (
    v_tab_xml_sap_id(I),
    v_tab_xml_sap_dt(I),
	v_tab_xml_sap_comp(I),
    v_tab_xml_sap_det(I)
   );
   
   EXCEPTION
   
   WHEN NO_DATA_FOUND    THEN

      p_o_n_ret_flg := 4;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR SAP DETAILS - MONTHLY '||','||g_v_pkg_id, SQLERRM);


   WHEN TOO_MANY_ROWS THEN

      p_o_n_ret_flg := 5;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR SAP DETAILS - MONTHLY  '||','||g_v_pkg_id, SQLERRM);

      
   WHEN OTHERS   THEN
      p_o_n_ret_flg := 20;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR SAP DETAILS - MONTHLY '||','||g_v_pkg_id, SQLERRM);

        -- DBMS_OUTPUT.put_line (' Inserting of TLL_SAP_DEPRC_MON_TX - WHEN OTHERS - ' || SQLERRM);
END;



IF TO_CHAR(TO_DATE(v_i_d_run_date, 'DD-MM-YYYY'),'MM') IN (03,06,09,12) THEN

BEGIN


FORALL I IN v_tab_xml_sap_id.FIRST..v_tab_xml_sap_id.LAST
   
   INSERT INTO TLL_SAP_DEPRC_QTRLY_TX
   (
   OBJ_PKG_NUM,
   DUE_DT,
   COMP_NUM,
   deprc_det
   )
  
   VALUES
   (
    v_tab_xml_sap_id(I),
    v_tab_xml_sap_dt(I),
	v_tab_xml_sap_comp(I),
    v_tab_xml_sap_det(I)
   );

   EXCEPTION
   
   WHEN NO_DATA_FOUND    THEN

      p_o_n_ret_flg := 4;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR SAP DETAILS - QRTLY '||','||g_v_pkg_id, SQLERRM);


   WHEN TOO_MANY_ROWS THEN

      p_o_n_ret_flg := 5;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR SAP DETAILS - QRTLY  '||','||g_v_pkg_id, SQLERRM);

      
   WHEN OTHERS   THEN
      p_o_n_ret_flg := 20;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR SAP DETAILS - QRTLY '||','||g_v_pkg_id, SQLERRM);

         --DBMS_OUTPUT.put_line (' Inserting of TLL_SAP_DEPR_QTRLY_TX - WHEN OTHERS - ' || SQLERRM);
END;

ELSE
 
  Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','The condition does not match for qrtly - SAP', '', NULL);
  --DBMS_OUTPUT.put_line ('the condition does not match for qrtly');
  
END IF;

IF TO_CHAR(TO_DATE(v_i_d_run_date, 'DD-MM-YYYY'),'MM') IN (09) THEN

BEGIN

FORALL I IN v_tab_xml_sap_id.FIRST..v_tab_xml_sap_id.LAST
   
   INSERT INTO TLL_SAP_DEPRC_YRLY_TX
   (
   OBJ_PKG_NUM,
   DUE_DT,
   COMP_NUM,
   deprc_det
   )
  
   VALUES
   (
    v_tab_xml_sap_id(I),
    v_tab_xml_sap_dt(I),
	v_tab_xml_sap_comp(I),
    v_tab_xml_sap_det(I)
   );

   EXCEPTION
   
   WHEN NO_DATA_FOUND    THEN

      p_o_n_ret_flg := 4;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR SAP DETAILS - YEARLY '||','||g_v_pkg_id, SQLERRM);


   WHEN TOO_MANY_ROWS THEN

      p_o_n_ret_flg := 5;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR SAP DETAILS - YEARLY  '||','||g_v_pkg_id, SQLERRM);

      
   WHEN OTHERS   THEN
      p_o_n_ret_flg := 20;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR SAP DETAILS - YEARLY '||','||g_v_pkg_id, SQLERRM);
         --DBMS_OUTPUT.put_line (' Inserting of TLL_SAP_DEPRC_YRLY_TX - WHEN OTHERS - ' || SQLERRM);
END;

ELSE
 
  Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','The condition does not match for Yearly - SAP', '', NULL);
--  DBMS_OUTPUT.put_line ('the condition does not match for Yearly');
  
END IF;


EXIT WHEN xml_cur_sap%NOTFOUND;
--COMMIT;
END LOOP;
  CLOSE xml_cur_sap;
  
  Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','INSERTING FOR SAP DETAILS -ENDS   ', '',NULL);
  EXCEPTION
   
      WHEN OTHERS   THEN
      
      p_o_n_ret_flg := 20;
      
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'cursor of INSERTING SAP DEATILS '||','||g_v_pkg_id, SQLERRM);
         
         --DBMS_OUTPUT.put_line (' cursor of INSERTING SAP DEATILS - WHEN OTHERS - ' || SQLERRM);       
END;

BEGIN
Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','INSERTING FOR STAGGING DETAILS -STRATS', '',NULL);
OPEN xml_cur_stg;
LOOP
FETCH xml_cur_stg BULK COLLECT into v_tab_xml_stg_id,v_tab_xml_stg_num,v_tab_xml_stg_comp,v_tab_xml_stg_dt LIMIT 5000;

BEGIN

FORALL I IN v_tab_xml_stg_id.FIRST..v_tab_xml_stg_id.LAST
   
   INSERT INTO TLL_CNTRCT_STG_MON_TX
   (
   CNTRCT_ID,
   OBJ_PKG_NUM,
   COMP_NUM,
   DUE_DT
   )
  
   VALUES
   (
    v_tab_xml_stg_id(I),
    v_tab_xml_stg_num(I),
	v_tab_xml_stg_comp(I),
    v_tab_xml_stg_dt(I)
   );
   
   EXCEPTION
   
   WHEN NO_DATA_FOUND    THEN

      p_o_n_ret_flg := 4;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR STG DETAILS - MONTHLY '||','||g_v_pkg_id, SQLERRM);


   WHEN TOO_MANY_ROWS THEN

      p_o_n_ret_flg := 5;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR STG DETAILS - MONTHLY  '||','||g_v_pkg_id, SQLERRM);

      
   WHEN OTHERS   THEN
      p_o_n_ret_flg := 20;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR STG DETAILS - MONTHLY '||','||g_v_pkg_id, SQLERRM);

        -- DBMS_OUTPUT.put_line (' Inserting of TLL_SAP_DEPRC_MON_TX - WHEN OTHERS - ' || SQLERRM);
END;



IF TO_CHAR(TO_DATE(v_i_d_run_date, 'DD-MM-YYYY'),'MM') IN (03,06,09,12) THEN

BEGIN


FORALL I IN v_tab_xml_stg_id.FIRST..v_tab_xml_stg_id.LAST
   
   INSERT INTO TLL_CNTRCT_STG_QTRLY_TX
   (
   CNTRCT_ID,
   OBJ_PKG_NUM,
   COMP_NUM,
   DUE_DT
   )
  
   VALUES
   (
    v_tab_xml_stg_id(I),
    v_tab_xml_stg_num(I),
    v_tab_xml_stg_comp(I),
    v_tab_xml_stg_dt(I)
   );

   EXCEPTION
   
   WHEN NO_DATA_FOUND    THEN

      p_o_n_ret_flg := 4;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR STG DETAILS - QRTLY '||','||g_v_pkg_id, SQLERRM);


   WHEN TOO_MANY_ROWS THEN

      p_o_n_ret_flg := 5;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR STG DETAILS - QRTLY  '||','||g_v_pkg_id, SQLERRM);

      
   WHEN OTHERS   THEN
      p_o_n_ret_flg := 20;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR STG DETAILS - QRTLY '||','||g_v_pkg_id, SQLERRM);

         --DBMS_OUTPUT.put_line (' Inserting of TLL_SAP_DEPR_QTRLY_TX - WHEN OTHERS - ' || SQLERRM);
END;

ELSE
 
  Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','The condition does not match for qrtly - STG', '', NULL);
  --DBMS_OUTPUT.put_line ('the condition does not match for qrtly');
  
END IF;

IF TO_CHAR(TO_DATE(v_i_d_run_date, 'DD-MM-YYYY'),'MM') IN (09) THEN

BEGIN

FORALL I IN v_tab_xml_stg_id.FIRST..v_tab_xml_stg_id.LAST
   
   INSERT INTO TLL_CNTRCT_STG_YRLY_TX
   (
   CNTRCT_ID,
   OBJ_PKG_NUM,
   COMP_NUM,
   DUE_DT
   )
  
   VALUES
   (
    v_tab_xml_stg_id(I),
    v_tab_xml_stg_num(I),
	v_tab_xml_stg_comp(I),
    v_tab_xml_stg_dt(I)
   );

   EXCEPTION
   
   WHEN NO_DATA_FOUND    THEN

      p_o_n_ret_flg := 4;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR STG DETAILS - YEARLY '||','||g_v_pkg_id, SQLERRM);


   WHEN TOO_MANY_ROWS THEN

      p_o_n_ret_flg := 5;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR STG DETAILS - YEARLY  '||','||g_v_pkg_id, SQLERRM);

      
   WHEN OTHERS   THEN
      p_o_n_ret_flg := 20;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'INSERTING FOR STG DETAILS - YEARLY '||','||g_v_pkg_id, SQLERRM);
         --DBMS_OUTPUT.put_line (' Inserting of TLL_SAP_DEPRC_YRLY_TX - WHEN OTHERS - ' || SQLERRM);
END;

ELSE
 
  Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','The condition does not match for Yearly - STG', '', NULL);
--  DBMS_OUTPUT.put_line ('the condition does not match for Yearly');
  
END IF;


EXIT WHEN xml_cur_stg%NOTFOUND;
--COMMIT;
END LOOP;
  CLOSE xml_cur_stg;
  

  Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','INSERTING FOR STG DETAILS -ENDS', '',NULL);

  
   EXCEPTION
   
      WHEN OTHERS   THEN
      
      p_o_n_ret_flg := 20;
      
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'cursor of INSERTING SAP DEATILS '||','||g_v_pkg_id, SQLERRM);
         
         --DBMS_OUTPUT.put_line (' cursor of INSERTING SAP DEATILS - WHEN OTHERS - ' || SQLERRM);       
END;



/*----------------------------------------------------*/
/* deleting all the records with due_dt in TP tables  */
/*----------------------------------------------------*/

Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','START TIME FOR deleting the TP tables  : ', '', TO_CHAR(SYSDATE,'hh:mi:ss'));

delete from TLL_CNTRCT_DET_TP;
delete from TLL_REFIN_DET_TP;
delete from TLL_SAP_DEPRC_TP;
delete from TLL_CNTRCT_STG_TP;
COMMIT;
Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','END TIME FOR deleting the TP tables  : ', '', TO_CHAR(SYSDATE,'hh:mi:ss'));


END PRO_INS_TLL_TAB;

PROCEDURE PRO_DEL_TLL_TAB (
                           v_i_d_run_date         IN DATE,
                           p_o_n_ret_flg          OUT NUMBER
                          )
                          
AS
--v_mon_date DATE := ADD_MONTHS(TO_DATE(p_process_dt, 'DD-MM-YYYY'),-12);
--v_qrtly_date DATE := TO_CHAR(); 
--v_yearly_date DATE := ADD_MONTHS(TO_DATE(p_process_dt, 'DD-MM-YYYY'),-144) ;


BEGIN

p_o_n_ret_flg         := 0;

Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','START TIME FOR deleting the data in PRO_DEL_TLL_TAB  : ', '', TO_CHAR(SYSDATE,'hh:mi:ss'));

/*--------------------------------------------------*/
/*deleting the records with due_dt more than a year */
/*--------------------------------------------------*/

DELETE FROM TLL_CNTRCT_DET_MON_TX where due_dt <= ADD_MONTHS(TO_DATE(v_i_d_run_date, 'DD-MM-RRRR'),-12);
DELETE FROM TLL_REFIN_DET_MON_TX  where due_dt <= ADD_MONTHS(TO_DATE(v_i_d_run_date, 'DD-MM-RRRR'),-12);
DELETE FROM TLL_SAP_DEPRC_MON_TX  where due_dt <= ADD_MONTHS(TO_DATE(v_i_d_run_date, 'DD-MM-RRRR'),-12);
DELETE FROM TLL_CNTRCT_STG_MON_TX where due_dt <= ADD_MONTHS(TO_DATE(v_i_d_run_date, 'DD-MM-RRRR'),-12);

DELETE FROM TLL_PROCESSING_TX where due_dt <= ADD_MONTHS(TO_DATE(v_i_d_run_date, 'DD-MM-RRRR'),-12) and TO_CHAR(due_dt,'MM') NOT IN ('03','06','09','12');

--Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','debug run date ', '',v_i_d_run_date);

/*----------------------------------------------------*/
/* deleting the records with due_dt more than 12 years*/
/*----------------------------------------------------*/


IF TO_CHAR(TO_DATE(v_i_d_run_date, 'DD-MM-YYYY'),'MM') IN (09) THEN

DELETE FROM TLL_CNTRCT_DET_YRLY_TX where due_dt <= ADD_MONTHS(TO_DATE(v_i_d_run_date, 'DD-MM-RRRR'),-144); 
DELETE FROM TLL_REFIN_DET_YRLY_TX where due_dt  <= ADD_MONTHS(TO_DATE(v_i_d_run_date, 'DD-MM-RRRR'),-144); 
DELETE FROM TLL_SAP_DEPRC_YRLY_TX where due_dt  <= ADD_MONTHS(TO_DATE(v_i_d_run_date, 'DD-MM-RRRR'),-144);
DELETE FROM TLL_CNTRCT_STG_YRLY_TX where due_dt <= ADD_MONTHS(TO_DATE(v_i_d_run_date, 'DD-MM-RRRR'),-144); 
DELETE FROM TLL_PROCESSING_TX where due_dt <= ADD_MONTHS(TO_DATE(v_i_d_run_date, 'DD-MM-RRRR'),-144) ;
Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','debug run date -y ', '',v_i_d_run_date);
END IF;

/*-----------------------------------------------------*/
/* deleting the records with due_dt more than 6 Quaters*/
/*-----------------------------------------------------*/

IF TO_CHAR(TO_DATE(v_i_d_run_date, 'DD-MM-YYYY'),'MM') IN (03,06,09,12) THEN

DELETE FROM TLL_CNTRCT_DET_QTRLY_TX where due_dt <= ADD_MONTHS(TO_DATE(v_i_d_run_date, 'DD-MM-RRRR'),-18); 
DELETE FROM TLL_REFIN_DET_QTRLY_TX where due_dt  <= ADD_MONTHS(TO_DATE(v_i_d_run_date, 'DD-MM-RRRR'),-18); 
DELETE FROM TLL_SAP_DEPRC_QTRLY_TX where due_dt  <= ADD_MONTHS(TO_DATE(v_i_d_run_date, 'DD-MM-RRRR'),-18);
DELETE FROM TLL_CNTRCT_STG_QTRLY_TX where due_dt <= ADD_MONTHS(TO_DATE(v_i_d_run_date, 'DD-MM-RRRR'),-18); 
DELETE FROM TLL_PROCESSING_TX where due_dt <= ADD_MONTHS(TO_DATE(v_i_d_run_date, 'DD-MM-RRRR'),-18) and  TO_CHAR(due_dt,'MM') NOT IN ('09');
Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','debug run date-q ', '',v_i_d_run_date);
END IF;

COMMIT;

Pkg_Batch_Logger.proc_log (lf_file_handle,'DEBUG','END TIME FOR deleting the data in PRO_DEL_TLL_TAB  : ', '', TO_CHAR(SYSDATE,'hh:mi:ss'));

EXCEPTION
   
   WHEN OTHERS   THEN

      p_o_n_ret_flg := 20;
      PKG_BATCH_LOGGER.proc_log (lf_file_handle,'FATAL','BAT_F_9999', 'PRO_DEL_TLL_TAB '||','||g_v_pkg_id, SQLERRM);



END PRO_DEL_TLL_TAB;



END PKG_TLL_HISTORIZATION;
/



