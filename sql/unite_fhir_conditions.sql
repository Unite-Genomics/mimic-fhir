DROP TABLE IF EXISTS mimic_fhir.unite_fhir_conditions
;

CREATE TABLE mimic_fhir.unite_fhir_conditions(
    subject_id  int NULL,
    patient_id  uuid NOT NULL,
    "condition" varchar(2048) NOT NULL 
)
;

INSERT INTO mimic_fhir.unite_fhir_conditions(patient_id, condition)
select DISTINCT patient_id, fhir->'code'->'coding'->0->>'display' as "condition"
    from mimic_fhir.condition
    where UPPER(fhir->'code'->'coding'->0->>'display') like '%LATERAL SCLEROSIS%'
    or UPPER(fhir->'code'->'coding'->0->>'display') like '%GRAVIS%'
    or UPPER(fhir->'code'->'coding'->0->>'display') like '%MUSCULAR DYSTROPHY%'
    or UPPER(fhir->'code'->'coding'->0->>'display') like '%SPINAL MUSCULAR ATROPHY%'
    or UPPER(fhir->'code'->'coding'->0->>'display') like '%POLYCYSTIC KIDNEY%'
    or UPPER(fhir->'code'->'coding'->0->>'display') like '%ALZHEIMER%'
    or UPPER(fhir->'code'->'coding'->0->>'display') like '%SCLERODERMA%'
;

-- 3771 is the number of unique patients generated by the query above for mimiciv-2.2
with rand_patients as (
 SELECT s.id FROM
  (SELECT id
   FROM mimic_fhir.patient p
   TABLESAMPLE BERNOULLI(1)
   where not exists (select id from mimic_fhir.unite_fhir_conditions u where u.patient_id = p.id)
   ) AS s
 ORDER BY RANDOM() LIMIT 3771
)
INSERT INTO mimic_fhir.unite_fhir_conditions (patient_id, condition)
select DISTINCT patient_id, fhir->'code'->'coding'->0->>'display' as "condition"
    from mimic_fhir.condition c, rand_patients r
    where c.patient_id = r.id
;

UPDATE mimic_fhir.unite_fhir_conditions ufc
SET subject_id = p.subject_id
FROM mimiciv_hosp.patients p
    LEFT JOIN fhir_etl.uuid_namespace ns_patient
        ON ns_patient.name = 'Patient'
WHERE ufc.patient_id = uuid_generate_v5(ns_patient.uuid, CAST(p.subject_id AS text))
;

ALTER TABLE mimic_fhir.unite_fhir_conditions ALTER COLUMN subject_id SET NOT NULL
;