-- Purpose: Generate a FHIR Observation resource for each unique specimen and test
--          found in microbiologyevents
-- Methods: uuid_generate_v5 --> requires uuid or text input, some inputs cast to text to fit

DROP TABLE IF EXISTS mimic_fhir.observation_micro_test;
CREATE TABLE mimic_fhir.observation_micro_test(
    id          uuid PRIMARY KEY,
    patient_id  uuid NOT NULL,
    fhir        jsonb NOT NULL 
);

-- Group to avoid duplicate organisms showing up for a given specimen's test
WITH distinct_org AS (
    SELECT DISTINCT
        mi.micro_specimen_id  AS mi_MICRO_SPECIMEN_ID
        , CAST(mi.test_itemid AS TEXT) AS mi_TEST_ITEMID
        , MAX(mi.test_name) AS mi_TEST_NAME
        , MAX(mi.subject_id) AS mi_SUBJECT_ID
        , MAX(mi.hadm_id) AS mi_HADM_ID
        , MAX(CAST(mi.charttime AS TIMESTAMPTZ)) AS mi_CHARTTIME
		
        , CASE WHEN MIN(mi.org_itemid) IS NULL THEN NULL 
            ELSE
                mi.test_itemid || '-' || mi.micro_specimen_id || '-' || mi.org_itemid
            END as mi_ORGANISM
	    
        -- flag for whether a specimen has at least one organism growth  
        , CASE 
            WHEN MAX(mi.org_itemid) IS NULL AND MAX(mi.COMMENTS) IS NOT NULL 
                THEN MAX(mi.COMMENTS)
            WHEN MAX(mi.org_itemid) IS NULL AND MAX(mi.COMMENTS) IS NULL 
                THEN 'No result present' -- ADD COMMENT FOR EMPTY results
            ELSE NULL
        END AS valueString
    FROM 
        mimic_hosp.microbiologyevents mi
        INNER JOIN fhir_etl.subjects sub    
            ON mi.subject_id = sub.subject_id 
    GROUP BY 
        test_itemid
        , micro_specimen_id
        , org_itemid
), grouped_org AS (
    SELECT 
        mi_MICRO_SPECIMEN_ID
        , mi_TEST_ITEMID
        , MAX(mi_TEST_NAME) AS mi_TEST_NAME
        , MAX(mi_SUBJECT_ID) AS mi_SUBJECT_ID
        , MAX(mi_HADM_ID) AS mi_HADM_ID
        , MAX(mi_CHARTTIME) AS mi_CHARTTIME
        , MAX(valueString) AS valueString  

        -- only include organism list if specimen had at least one organism growth
        , CASE WHEN MAX(valueString) IS NULL THEN 
            json_agg(
                jsonb_build_object('reference', 
                    'Observation/' || uuid_generate_v5(ns_observation_micro_org.uuid, mi_ORGANISM)
                ) 
            )            
        ELSE NULL END AS fhir_ORGANISM
    FROM 
        distinct_org
        LEFT JOIN fhir_etl.uuid_namespace ns_observation_micro_org
            ON ns_observation_micro_org.name = 'ObservationMicroOrg'
    GROUP BY 
        mi_MICRO_SPECIMEN_ID
        , mi_TEST_ITEMID
        , ns_observation_micro_org.uuid
), fhir_observation_micro_test AS (
    SELECT 
        mi_MICRO_SPECIMEN_ID
        , mi_MICRO_SPECIMEN_ID|| '-' || mi_TEST_ITEMID AS id_MICRO_TEST
        , mi_TEST_ITEMID
        , mi_TEST_NAME
        , mi_SUBJECT_ID
        , mi_HADM_ID
        , mi_CHARTTIME
        , valueString
        , fhir_ORGANISM
        
        -- UUID references
        , uuid_generate_v5(ns_observation_micro_test.uuid, mi_MICRO_SPECIMEN_ID|| '-' || mi_TEST_ITEMID) AS uuid_MICRO_TEST
        , uuid_generate_v5(ns_patient.uuid, CAST(mi_SUBJECT_ID AS TEXT)) AS uuid_SUBJECT_ID
        , uuid_generate_v5(ns_encounter.uuid, CAST(mi_HADM_ID AS TEXT)) AS uuid_HADM_ID	
        , uuid_generate_v5(ns_encounter.uuid, CAST(mi_MICRO_SPECIMEN_ID AS TEXT)) AS uuid_SPECIMEN 
    FROM
        grouped_org
        LEFT JOIN fhir_etl.uuid_namespace ns_patient
            ON ns_patient.name = 'Patient'
        LEFT JOIN fhir_etl.uuid_namespace ns_encounter
            ON ns_encounter.name = 'Encounter'
        LEFT JOIN fhir_etl.uuid_namespace ns_observation_micro_test
            ON ns_observation_micro_test.name = 'ObservationMicroTest'
        LEFT JOIN fhir_etl.uuid_namespace ns_specimen
            ON ns_specimen.name = 'SpecimenMicro'
)

INSERT INTO mimic_fhir.observation_micro_test  
SELECT 
    uuid_MICRO_TEST AS id
    , uuid_SUBJECT_ID AS patient_id
    , jsonb_strip_nulls(jsonb_build_object(
        'resourceType', 'Observation'
        , 'id', uuid_MICRO_TEST	 
        , 'meta', jsonb_build_object(
            'profile', jsonb_build_array(
                'http://fhir.mimic.mit.edu/StructureDefinition/mimic-observation-micro-test'
            )
        ) 
        , 'identifier',  jsonb_build_array(jsonb_build_object(
            'value', id_MICRO_TEST
            , 'system', 'http://fhir.mimic.mit.edu/identifier/observation-micro-test'
        ))  
        , 'status', 'final'        
        , 'category', jsonb_build_array(jsonb_build_object(
            'coding', jsonb_build_array(jsonb_build_object(
                'system', 'http://terminology.hl7.org/CodeSystem/observation-category'  
                , 'code', 'laboratory'
            ))
        ))
        , 'code', jsonb_build_object(
            'coding', jsonb_build_array(jsonb_build_object(
                'system', 'http://fhir.mimic.mit.edu/CodeSystem/microbiology-test'  
                , 'code', mi_TEST_ITEMID
                , 'display', mi_TEST_NAME
            ))
        )
        , 'subject', jsonb_build_object('reference', 'Patient/' || uuid_SUBJECT_ID)
        , 'specimen', jsonb_build_object('reference', 'Specimen/' || uuid_SPECIMEN)
        , 'encounter', 
            CASE WHEN uuid_HADM_ID IS NOT NULL THEN
                jsonb_build_object('reference', 'Encounter/' || uuid_HADM_ID) 
            ELSE NULL END
        , 'effectiveDateTime', mi_CHARTTIME
        , 'hasMember', fhir_ORGANISM -- reference one to many organisms
        , 'valueString', valueString -- result notes for tests with no organisms associated
    )) AS fhir 
FROM
    fhir_observation_micro_test
    
