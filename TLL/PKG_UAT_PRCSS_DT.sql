/*<TOAD_FILE_CHUNK>*/
CREATE OR REPLACE PACKAGE PKG_UAT_PRCSS_DT
IS -- {
/*----------------------------------------------------------------------------------------------*/
/*  Name                  :     PKG_UAT_PRCSS_DT                                                */
/*  Author                :     Hexaware Technologies                                           */
/*  Purpose               :                                                                     */
/*                                                                                              */
/*  Revision History    :                                                                       */
/*  <<Ver No>>        <<Modified By>>      <<Modified Date>>                                    */
/*      1.0            Venkatachalam          11-Aug-2004                                       */
/*      Initial Version                                                                         */
/*--------------------------------------------------------------------------------------------- */

   /*------------------------*/
   /*  Global Variables      */
   /*------------------------*/

 -- Public function and procedure declarations
     PROCEDURE MAIN_PROC   (v_process_date      IN     DATE,
                            v_chng_uat_dt  IN     VARCHAR2,
                            v_ret_flg       OUT    NUMBER
                           );


END PKG_UAT_PRCSS_DT; -- }
/
/*<TOAD_FILE_CHUNK>*/
CREATE OR REPLACE PACKAGE BODY PKG_UAT_PRCSS_DT
AS -- {

   /*-----------------------------------------------------*/
   /*      Global variable declarations                   */
   /*-----------------------------------------------------*/

   v_pkg_id        CONSTANT     VARCHAR2(15)  := 'UAT_PRCSS_DT';       /* Variable to Store Package Name */
   v_prog_id       CONSTANT     VARCHAR2(15)  := 'UAT_PRCSS_DT';       /* Variable to Store Program Name */
   v_pkg_prog_id   CONSTANT     VARCHAR2(30) := v_pkg_id || ' , ' || v_prog_id;

   lf_file_handle               UTL_FILE.FILE_TYPE;               /* Variable for File Handler      */

   v_excp_buss_err              EXCEPTION;
   v_excp_parm_err              EXCEPTION;
   v_file_open_err              EXCEPTION;

   /*-----------------------------------------------------*/
   /*      Assignment of Hard Coded values                */
   /*-----------------------------------------------------*/


   PROCEDURE MAIN_PROC   (v_process_date  IN     DATE,
                          v_chng_uat_dt  IN     VARCHAR2,
                          v_ret_flg       OUT    NUMBER
                         )

   IS
   /*----------------------------------------------------------------------------------------------*/
   /*  Name                  :     MAIN_PROC                                                       */
   /*  Author                :     Hexaware Technologies                                           */
   /*  Purpose               :                                                                     */
   /*                                                                                              */
   /*  Calling               :     PKG_BATCH_LOGGER, PKG_COMMON_ROUTINES                           */
   /*  Parameters            :     v_process_date  - IN - Process Date                             */
   /*                              v_chng_uat_dt  - IN - Input Change UAT Process  Date            */
   /*                              v_ret_flg       - OUT - Value set for Success or Failure        */
   /*                                                      0 - Success,  1 - Failure               */
   /*  Revision History      :                                                                     */
   /*  <<Ver No>>        <<Modified By>>      <<Modified Date>>                                    */
   /*      1.0            Venkatachalam          11-Aug-2004                                       */
   /*      Initial Version                                                                         */
   /*--------------------------------------------------------------------------------------------- */

   v_uat_prcss_dt  VARCHAR2(15);
   v_prcss_dt DATE;
   
   /*-----------------------------------------------------*/
   /*      Start of Main Execution                        */
   /*-----------------------------------------------------*/

   BEGIN -- {
   
      v_ret_flg := 0;
      BEGIN -- {

         lf_file_handle := Pkg_Batch_Logger.func_open_log(v_prog_id);
      EXCEPTION
           WHEN OTHERS THEN
                RAISE v_file_open_err;
      END; -- }

      /*--------------------------------------------------------------------*/
      /*  Log Blank lines at the start of the Output files for readability  */
      /*--------------------------------------------------------------------*/

      FOR cnt IN 1..25
      LOOP -- {
          Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0000', '', '');
      END LOOP; -- }

      Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0008', v_pkg_prog_id, '');

      v_ret_flg := 0;  -- Exit return is defaulted to 0

      Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT','List of Input Parameters', '', '');
      Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT','Input Process date     = ','',  v_process_date);
      Pkg_Batch_Logger.proc_log (lf_file_handle,'REPORT','Input Change UAT Date  = ', '', v_chng_uat_dt);

      /* ------------------------------------------------------ */
      /*   Input "From" Date should not be null or invalid      */
      /* ------------------------------------------------------ */

      IF  Pkg_Common_Routines.fn_is_valid_date(v_chng_uat_dt,'DD.MM.YYYY') = 1
      THEN --{
          Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_E_0055','Input ', '');
          RAISE v_excp_parm_err;
      END IF; -- }

      SELECT TO_CHAR(TO_DATE(v_chng_uat_dt,'DD.MM.RRRR'),'DD.MM.YYYY')
      INTO   v_uat_prcss_dt
      FROM   DUAL;

      SELECT prcss_dt
      INTO   v_prcss_dt
      FROM   uc_batch_prcss_dt_ms
      WHERE  ROWNUM < 2
      FOR UPDATE OF prcss_dt NOWAIT;

      UPDATE uc_batch_prcss_dt_ms
      SET    prcss_dt = TO_DATE(v_uat_prcss_dt,'DD.MM.YYYY')
      WHERE  ROWNUM < 2;

      COMMIT;

      Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0012', v_pkg_prog_id,'');
      Pkg_Batch_Logger.proc_log_status (lf_file_handle,'C');
      v_ret_flg := 0;    -- Return Status is Success

   EXCEPTION
        WHEN  v_file_open_err THEN
              v_ret_flg := 16;  -- This record was not processed.
              ROLLBACK;

        WHEN  v_excp_buss_err THEN
           /* ---------------------------------------------------- */
           /*      Business Errors. Close and Terminate program    */
           /* ---------------------------------------------------- */
           v_ret_flg := 8; -- Severe Error.

           ROLLBACK;
           /* ---------------------------------------------------- */
           /*     Reinitializing the insertions counters to zero   */
           /* ---------------------------------------------------- */

           Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019', v_pkg_prog_id,NULL);
           Pkg_Batch_Logger.proc_log_status (lf_file_handle,'B');

        WHEN  v_excp_parm_err THEN

           /* ---------------------------------------------------- */
           /*    Input Parm Errors. Close and Terminate program    */
           /* ---------------------------------------------------- */
           v_ret_flg := 20; -- Fatal Error.
           Pkg_Batch_Logger.proc_log_status (lf_file_handle,'B');

	WHEN  OTHERS THEN
           /* ------------------------------------------------------- */
           /*      Other fatal Errors. Close and Terminate program    */
           /* ------------------------------------------------------- */
           v_ret_flg := 20; -- Fatal Error.

           ROLLBACK;
           /* ---------------------------------------------------- */
           /*     Reinitializing the insertions counters to zero   */
           /* ---------------------------------------------------- */

           Pkg_Batch_Logger.proc_log (lf_file_handle,'INFO','BAT_I_0019', v_pkg_prog_id,NULL);
           Pkg_Batch_Logger.proc_log (lf_file_handle,'FATAL','BAT_F_9999', NULL,SQLERRM);
           Pkg_Batch_Logger.proc_log_status (lf_file_handle,'S');

   END MAIN_PROC; -- }

END PKG_UAT_PRCSS_DT; -- }
/
