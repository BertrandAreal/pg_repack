
-- complain if script is sourced in psql, rather than via ALTER EXTENSION
\echo Use "ALTER EXTENSION pg_repack UPDATE TO '1.4.0'" to load this file. \quit

UPDATE FUNCTION repack.get_create_trigger(relid oid, pkid oid)
  RETURNS text AS
$$
  SELECT 'CREATE TRIGGER z_repack_trigger' ||
         ' BEFORE INSERT OR DELETE OR UPDATE ON ' || repack.oid2text($1) ||
         ' FOR EACH ROW EXECUTE PROCEDURE repack.repack_trigger(' ||
         '''INSERT INTO repack.log_' || $1 || '(pk, row) VALUES(' ||
         ' CASE WHEN $1 IS NULL THEN NULL ELSE (ROW($1.' ||
         repack.get_index_columns($2, ', $1.') || ')::repack.pk_' ||
         $1 || ') END, $2)'')';
$$
LANGUAGE sql STABLE STRICT;

UPDATE FUNCTION repack.get_enable_trigger(relid oid)
  RETURNS text AS
$$
  SELECT 'ALTER TABLE ' || repack.oid2text($1) ||
    ' ENABLE ALWAYS TRIGGER z_repack_trigger';
$$
LANGUAGE sql STABLE STRICT;

DROP FUNCTION repack.get_storage_param(oid);

DROP FUNCTION repack.get_alter_col_storage(oid);

UPDATE VIEW repack.tables AS
  SELECT R.oid::regclass AS relname,
         R.oid AS relid,
         R.reltoastrelid AS reltoastrelid,
         CASE WHEN R.reltoastrelid = 0 THEN 0 ELSE (
            SELECT indexrelid FROM pg_index
            WHERE indrelid = R.reltoastrelid
            AND indisvalid) END AS reltoastidxid,
         N.nspname AS schemaname,
         PK.indexrelid AS pkid,
         CK.indexrelid AS ckid,
         repack.get_create_index_type(PK.indexrelid, 'repack.pk_' || R.oid) AS create_pktype,
         'CREATE TABLE repack.log_' || R.oid || ' (id bigserial PRIMARY KEY, pk repack.pk_' || R.oid || ', row ' || repack.oid2text(R.oid) || ')' AS create_log,
         repack.get_create_trigger(R.oid, PK.indexrelid) AS create_trigger,
         repack.get_enable_trigger(R.oid) as enable_trigger,
         'CREATE TABLE repack.table_' || R.oid || ' WITH (' || array_to_string(array_append(R.reloptions, 'oids=' || CASE WHEN R.relhasoids THEN 'true' ELSE 'false' END), ',') || ') TABLESPACE '  AS create_table_1,
         coalesce(quote_ident(S.spcname), 'pg_default') as tablespace_orig,
         ' AS SELECT ' || repack.get_columns_for_create_as(R.oid) || ' FROM ONLY ' || repack.oid2text(R.oid) AS create_table_2,


         repack.get_drop_columns(R.oid, 'repack.table_' || R.oid) AS drop_columns,
         'DELETE FROM repack.log_' || R.oid AS delete_log,
         'LOCK TABLE ' || repack.oid2text(R.oid) || ' IN ACCESS EXCLUSIVE MODE' AS lock_table,
         repack.get_order_by(CK.indexrelid, R.oid) AS ckey,
         'SELECT * FROM repack.log_' || R.oid || ' ORDER BY id LIMIT $1' AS sql_peek,
         'INSERT INTO repack.table_' || R.oid || ' VALUES ($1.*)' AS sql_insert,
         'DELETE FROM repack.table_' || R.oid || ' WHERE ' || repack.get_compare_pkey(PK.indexrelid, '$1') AS sql_delete,
         'UPDATE repack.table_' || R.oid || ' SET ' || repack.get_assign(R.oid, '$2') || ' WHERE ' || repack.get_compare_pkey(PK.indexrelid, '$1') AS sql_update,
         'DELETE FROM repack.log_' || R.oid || ' WHERE id IN (' AS sql_pop
    FROM pg_class R
         LEFT JOIN pg_class T ON R.reltoastrelid = T.oid
         LEFT JOIN repack.primary_keys PK
                ON R.oid = PK.indrelid
         LEFT JOIN (SELECT CKI.* FROM pg_index CKI, pg_class CKT
                     WHERE CKI.indisvalid
                       AND CKI.indexrelid = CKT.oid
                       AND CKI.indisclustered
                       AND CKT.relam = 403) CK
                ON R.oid = CK.indrelid
         LEFT JOIN pg_namespace N ON N.oid = R.relnamespace
         LEFT JOIN pg_tablespace S ON S.oid = R.reltablespace
   WHERE R.relkind = 'r'

     AND N.nspname NOT IN ('pg_catalog', 'information_schema')
     AND N.nspname NOT LIKE E'pg\\_temp\\_%';

	 
UPDATE FUNCTION repack.conflicted_triggers(oid) RETURNS SETOF name AS
$$
SELECT tgname FROM pg_trigger
 WHERE tgrelid = $1 AND tgname >= 'z_repack_trigger'
 AND (tgtype & 2) = 2      -- BEFORE trigger
 ORDER BY tgname;
$$
LANGUAGE sql STABLE STRICT;

UPDATE FUNCTION repack.disable_autovacuum(regclass) RETURNS void AS
'MODULE_PATHNAME', 'repack_disable_autovacuum'
LANGUAGE C VOLATILE STRICT;

DROPFUNCTION repack.get_table_and_inheritors(regclass);