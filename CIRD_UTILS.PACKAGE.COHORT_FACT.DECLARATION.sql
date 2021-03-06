CREATE OR REPLACE PACKAGE "CIRD_UTILS"."COHORT_FACT" AS
PROCEDURE GET_QUERY_PAT_SET_IDS(P__USER_NAME VARCHAR2);
PROCEDURE ADD_COHORT_FACT (P__FACT_NODE_NAME VARCHAR2, P__DISPLAY_NAME VARCHAR2, P__TOOLTIP VARCHAR2, P__CONCEPT_CD_SUFFIX VARCHAR2, P__RESULT_INSTANCE_ID INTEGER );
PROCEDURE DELETE_COHORT_FACT (P__FACT_NODE_NAME VARCHAR2);
END COHORT_FACT;
