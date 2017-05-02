CREATE OR REPLACE PACKAGE BODY "CIRD_UTILS"."COHORT_FACT" AS

PROCEDURE GET_QUERY_PAT_SET_IDS(P__USER_NAME VARCHAR2) AS

        CURSOR QUERY_PAT_SETS IS
        SELECT  A.NAME,
                C.RESULT_INSTANCE_ID,
                B.START_DATE,
                C.REAL_SET_SIZE
        FROM    BLUEHERONDATA.QT_QUERY_MASTER A
        INNER JOIN
                BLUEHERONDATA.QT_QUERY_INSTANCE B
        ON      A.QUERY_MASTER_ID = B.QUERY_MASTER_ID
        INNER JOIN
                BLUEHERONDATA.QT_QUERY_RESULT_INSTANCE C
        ON      B.QUERY_INSTANCE_ID = C.QUERY_INSTANCE_ID
        WHERE   A.USER_ID = P__USER_NAME
        AND     C.REAL_SET_SIZE > 0
        AND     EXISTS (SELECT * FROM BLUEHERONDATA.QT_PATIENT_SET_COLLECTION WHERE RESULT_INSTANCE_ID = C.RESULT_INSTANCE_ID)
        ORDER BY B.START_DATE DESC;    
        
        V__NAME                 BLUEHERONDATA.QT_QUERY_MASTER.NAME%TYPE;
        V__RESULT_INSTANCE_ID   BLUEHERONDATA.QT_QUERY_RESULT_INSTANCE.RESULT_INSTANCE_ID%TYPE;
        V__START_DATE           BLUEHERONDATA.QT_QUERY_INSTANCE.START_DATE%TYPE;
        V__REAL_SET_SIZE        BLUEHERONDATA.QT_QUERY_RESULT_INSTANCE.REAL_SET_SIZE%TYPE; 
BEGIN
        
        OPEN  QUERY_PAT_SETS;
        
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE(RPAD('NAME', 30) || ' ' || 'RESULT_INSTANCE_ID' || ' ' || RPAD('START_DATE',15) || ' ' || 'REAL_SET_SIZE');
        
        LOOP
                FETCH QUERY_PAT_SETS INTO  V__NAME, V__RESULT_INSTANCE_ID, V__START_DATE, V__REAL_SET_SIZE;
                EXIT WHEN QUERY_PAT_SETS%NOTFOUND;
                
                DBMS_OUTPUT.PUT_LINE(RPAD(V__NAME,30) || ' ' || RPAD(TO_CHAR(V__RESULT_INSTANCE_ID),LENGTH('RESULT_INSTANCE_ID')) ||' ' ||  RPAD(V__START_DATE,15) || ' ' || V__REAL_SET_SIZE);
        END LOOP;
        
        CLOSE QUERY_PAT_SETS;
        
END GET_QUERY_PAT_SET_IDS;


PROCEDURE ADD_COHORT_FACT (P__FACT_NODE_NAME VARCHAR2, P__DISPLAY_NAME VARCHAR2, P__TOOLTIP VARCHAR2, P__CONCEPT_CD_SUFFIX VARCHAR2, P__RESULT_INSTANCE_ID INTEGER ) IS
        
        V__FACT_PATH       VARCHAR2(500)    := '\i2b2\Cohorts\' || P__FACT_NODE_NAME || '\';
        V__BASECODE        BLUEHERONMETADATA.HERON_TERMS.C_BASECODE%TYPE := 'COHORT:' || P__CONCEPT_CD_SUFFIX;
        V__FULLNAME        BLUEHERONMETADATA.HERON_TERMS.C_FULLNAME%TYPE;
        V__ROW_COUNT       INTEGER :=0;
                
        CURSOR CHECK_PATH IS SELECT COUNT(*) FROM BLUEHERONMETADATA.HERON_TERMS WHERE C_FULLNAME = V__FACT_PATH;

        CURSOR CHECK_BASE_CODE IS SELECT C_FULLNAME FROM BLUEHERONMETADATA.HERON_TERMS WHERE C_BASECODE = V__BASECODE;
        
        CURSOR CHECK_PAT_SET_COUNT IS SELECT COUNT(*) FROM BLUEHERONDATA.QT_PATIENT_SET_COLLECTION WHERE RESULT_INSTANCE_ID = P__RESULT_INSTANCE_ID;
        
        CURSOR VALIDATE_PAT_SET IS 
        SELECT  COUNT(*)
        FROM    BLUEHERONDATA.QT_PATIENT_SET_COLLECTION A 
        INNER JOIN 
                BLUEHERONDATA.PATIENT_DIMENSION B 
        ON      A.PATIENT_NUM = B.PATIENT_NUM 
        AND     A.RESULT_INSTANCE_ID = P__RESULT_INSTANCE_ID;
        
         
BEGIN
        IF P__FACT_NODE_NAME IS NULL OR P__DISPLAY_NAME IS NULL OR P__TOOLTIP IS NULL OR P__CONCEPT_CD_SUFFIX IS NULL OR P__RESULT_INSTANCE_ID IS NULL
        THEN 
            RAISE_APPLICATION_ERROR(-20001, 'One or more parameters are null');
        END IF;

        IF INSTR(P__FACT_NODE_NAME,'\') > 0
        THEN
           RAISE_APPLICATION_ERROR(-20001, 'The fact node name cannot contain slashes ''\''  : "' || P__FACT_NODE_NAME || '"');
           RETURN;
        END IF;
              
        OPEN  CHECK_PATH;
        FETCH CHECK_PATH INTO V__ROW_COUNT;
        CLOSE CHECK_PATH;
        
        IF V__ROW_COUNT > 0
        THEN
            RAISE_APPLICATION_ERROR(-20001,'The cohort fact path: "' || V__FACT_PATH || '" already exit'); 
            RETURN;          
        END IF;
        
        OPEN CHECK_BASE_CODE;
        FETCH CHECK_BASE_CODE INTO V__FULLNAME;
        CLOSE CHECK_BASE_CODE;
        
        IF V__FULLNAME IS NOT NULL
        THEN 
           RAISE_APPLICATION_ERROR(-20001,'The C_BASECODE: "' || V__BASECODE || '" is already in use by Cohort fact: "' || V__FULLNAME);
           RETURN;
        END IF;

        
        OPEN CHECK_PAT_SET_COUNT;
        FETCH CHECK_PAT_SET_COUNT INTO V__ROW_COUNT;
        CLOSE CHECK_PAT_SET_COUNT;
        
        IF V__ROW_COUNT = 0
        THEN
           RAISE_APPLICATION_ERROR(-20001,'There are no PATIENT_NUM''s found in QT_PATIENT_SET_COLLECTION for P__RESULT_INSTANCE_ID=' || P__RESULT_INSTANCE_ID );
           RETURN;
        END IF;
       
        OPEN VALIDATE_PAT_SET;
        FETCH VALIDATE_PAT_SET INTO V__ROW_COUNT;
        CLOSE VALIDATE_PAT_SET;
        
        IF V__ROW_COUNT = 0
        THEN
           RAISE_APPLICATION_ERROR(-20001,'The PATIENT_NUM''s in QT_PATIENT_SET_COLLECTION for P__RESULT_INSTANCE_ID=' || P__RESULT_INSTANCE_ID || ' are not found in the PATIENT_DIMENSION. They may not be current patient numbers');
           RETURN;
        END IF;
        
        INSERT INTO BLUEHERONMETADATA.HERON_TERMS
        (
                C_HLEVEL,
                C_FULLNAME,
                C_NAME,
                C_SYNONYM_CD,
                C_VISUALATTRIBUTES,
                C_TOTALNUM,
                C_BASECODE,
                C_METADATAXML,
                C_FACTTABLECOLUMN,
                C_TABLENAME,
                C_COLUMNNAME,
                C_COLUMNDATATYPE,
                C_OPERATOR,
                C_DIMCODE,
                C_COMMENT,
                C_TOOLTIP,
                M_APPLIED_PATH,
                UPDATE_DATE,
                DOWNLOAD_DATE,
                IMPORT_DATE,
                SOURCESYSTEM_CD,
                VALUETYPE_CD,
                M_EXCLUSION_CD,
                C_PATH,
                C_SYMBOL,
                TERM_ID
        )
        VALUES
        (
                2,
                V__FACT_PATH,
                P__DISPLAY_NAME,
                'N',
                'LA',
                V__ROW_COUNT,
                V__BASECODE,
                NULL,
                'concept_cd',
                'concept_dimension',
                'concept_path',
                'T',
                'LIKE',
                V__FACT_PATH,
                NULL,
                P__TOOLTIP,
                '@',
                SYSDATE,
                SYSDATE,
                SYSDATE,
                'COHORT FACT',
                NULL,
                NULL,
                NULL,
                NULL,
                (SELECT MAX(TERM_ID) + 1 FROM BLUEHERONMETADATA.HERON_TERMS)
        );

        INSERT INTO BLUEHERONDATA.CONCEPT_DIMENSION
        (
                CONCEPT_PATH,
                CONCEPT_CD,
                NAME_CHAR,
                CONCEPT_BLOB,
                UPDATE_DATE,
                DOWNLOAD_DATE,
                IMPORT_DATE,
                SOURCESYSTEM_CD,
                UPLOAD_ID
        )
        VALUES
        (
                V__FACT_PATH,
                V__BASECODE,
                P__DISPLAY_NAME,
                NULL,
                SYSDATE,
                SYSDATE,
                SYSDATE,
                'COHORT FACT',
                0
        );


        INSERT INTO BLUEHERONDATA.OBSERVATION_FACT
        SELECT  PAT_MIN_ENC.ENCOUNTER_NUM,
                PAT_MIN_ENC.PATIENT_NUM,
                V__BASECODE      AS CONCEPT_CD,
                '@'              AS PROVIDER_ID,
                VD.START_DATE    AS START_DATE,
                '@'              AS MODIFIER_CD,
                0                AS INSTANCE_NUMBER,
                '@'              AS VALTYPE_CD,
                '@'              AS TVAL_CHAR,
                0                AS NVAL_NUM,
                NULL             AS VALUE_FLAG_CD,
                NULL             AS QUANTITY_NUM,
                NULL             AS UNITS_CD,
                VD.START_DATE    AS END_DATE,
                NULL             AS LOCATION_CD, 
                NULL             AS OBSERVATION_BLOB, 
                NULL             AS CONFIDENCE_NUM,
                SYSTIMESTAMP     AS UPDATE_DATE, 
                SYSTIMESTAMP     AS DOWNLOAD_DATE, 
                SYSTIMESTAMP     AS IMPORT_DATE,
                'CIRD@UTHSCSA.EDU' AS SOURCESYSTEM_CD,
                0                AS UPLOAD_ID,
                ''               AS SUB_ENCOUNTER
        FROM 
        (
                SELECT A.PATIENT_NUM, 
                       MIN(ENCOUNTER_NUM) AS ENCOUNTER_NUM 
                FROM   BLUEHERONDATA.QT_PATIENT_SET_COLLECTION A
                INNER JOIN
                       BLUEHERONDATA.VISIT_DIMENSION B
                ON     A.PATIENT_NUM = B.PATIENT_NUM
                WHERE  A.RESULT_INSTANCE_ID = P__RESULT_INSTANCE_ID
                GROUP BY A.PATIENT_NUM
        ) PAT_MIN_ENC
        INNER JOIN
                BLUEHERONDATA.VISIT_DIMENSION VD
        ON      PAT_MIN_ENC.PATIENT_NUM   = VD.PATIENT_NUM
        AND     PAT_MIN_ENC.ENCOUNTER_NUM = VD.ENCOUNTER_NUM;
        
END ADD_COHORT_FACT;

PROCEDURE DELETE_COHORT_FACT (P__FACT_NODE_NAME VARCHAR2) IS
        
        V__FACT_PATH       VARCHAR2(500)    := '\i2b2\Cohorts\' || P__FACT_NODE_NAME || '\';
        V__BASECODE        BLUEHERONMETADATA.HERON_TERMS.C_BASECODE%TYPE;
        V__FULLNAME        BLUEHERONMETADATA.HERON_TERMS.C_FULLNAME%TYPE;
        V__ROW_COUNT       INTEGER :=0;
                
        CURSOR CHECK_PATH IS SELECT COUNT(*) FROM BLUEHERONMETADATA.HERON_TERMS WHERE C_FULLNAME = V__FACT_PATH;

        CURSOR GET_BASE_CODE IS SELECT C_BASECODE FROM BLUEHERONMETADATA.HERON_TERMS WHERE C_FULLNAME = V__FACT_PATH;       
         
BEGIN
        IF P__FACT_NODE_NAME IS NULL
        THEN 
            RAISE_APPLICATION_ERROR(-20001, 'P__FACT_NODE_NAME is null');
        END IF;
              
        OPEN  CHECK_PATH;
        FETCH CHECK_PATH INTO V__ROW_COUNT;
        CLOSE CHECK_PATH;
        
        IF V__ROW_COUNT = 0
        THEN
            RAISE_APPLICATION_ERROR(-20001,'The cohort fact path: "' || V__FACT_PATH || '" does not exist'); 
            RETURN;          
        END IF;
        
        OPEN  GET_BASE_CODE;
        FETCH GET_BASE_CODE INTO V__BASECODE;
        CLOSE GET_BASE_CODE;
        
        DELETE FROM BLUEHERONMETADATA.HERON_TERMS WHERE C_FULLNAME = V__FACT_PATH;
        DELETE FROM BLUEHERONDATA.CONCEPT_DIMENSION WHERE CONCEPT_PATH = V__FACT_PATH;
        DELETE FROM BLUEHERONDATA.OBSERVATION_FACT WHERE CONCEPT_CD = V__BASECODE;
        
END DELETE_COHORT_FACT;

END COHORT_FACT;
