CREATE OR REPLACE PACKAGE PKG_TLL_UTILS
IS

PROCEDURE GET_DIR_LIST( P_DIRECTORY IN VARCHAR2 );

FUNCTION fn_get_oracle_dir_path(if_file_handle utl_file.file_type,
                                 p_directory_name in VARCHAR2,p_return_cd IN OUT NUMBER) RETURN VARCHAR2;

END PKG_TLL_UTILS;
/

CREATE OR REPLACE PACKAGE BODY PKG_TLL_UTILS
AS

 procedure get_dir_list( p_directory in varchar2 )
 as language java
 name 'DirList.getList( java.lang.String )';


 FUNCTION fn_get_oracle_dir_path(if_file_handle utl_file.file_type,
                                 p_directory_name in VARCHAR2,
                                 p_return_cd IN OUT NUMBER
        ) RETURN VARCHAR2 IS
     v_dir                         VARCHAR2(1000) := ' ';
     v_prog_id                     VARCHAR2(100)  := '' ;
     v_pkg_id                      VARCHAR2(100)  := '' ;
     v_pkg_prog_id                 VARCHAR2(1000) := '';
   BEGIN
     
      p_return_cd := 0;

      SELECT TRIM(directory_path) 
      INTO   v_dir
      FROM   all_directories
      WHERE  directory_name = p_directory_name;
      p_return_cd := 0;

      RETURN v_dir;
   EXCEPTION
      WHEN NO_DATA_FOUND 
      THEN
         Pkg_Batch_Logger.proc_log(
            if_file_handle, 'DEBUG', p_directory_name||'Directory Not Available ', '', ''
         );
         Pkg_Batch_Logger.proc_log(
            if_file_handle, 'FATAL', 'BAT_F_9999',SQLERRM,
            v_pkg_prog_id
         ); --caution dont remove sqlcode here
         p_return_cd := 1;
      WHEN OTHERS 
      THEN
        Pkg_Batch_Logger.proc_log(
            if_file_handle, 'FATAL', 'BAT_F_9999', SQLERRM,
            v_pkg_prog_id
         ); --caution dont remove sqlcode here
         p_return_cd := 1;
   END fn_get_oracle_dir_path;

END PKG_TLL_UTILS;
/
