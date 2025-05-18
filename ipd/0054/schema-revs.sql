-- schema revs:
-- 1) strict mode
-- 2) value_tbl -> blob with constraints on blob length & contents
-- 3) pitch id_tbl and let database pick id values via AUTOINCREMENT? no,
--    but keep INTEGER PRIMARY KEY where possible; use composite keys
--    otherwise
-- 4) add foreign key constraints to ensure that id-based references to other tables point at valid data
-- 5) update various application-id's in database header
  pragma application_id = <SMF-specific-value>
  pragma user_version = ??
  
--  PRAGMA encoding = 'UTF-8';
--  PRAGMA journal_mode = ?
-- "To achieve the best long-term query performance without the need to do a detailed engineering analysis of the application schema and SQL, it is recommended that applications run "PRAGMA optimize" (with no arguments) just before closing each database connection. Long-running applications might also benefit from setting a timer to run "PRAGMA optimize" every few hours. "

  --PRAGMA secure_delete = true; ?

    -- PRAGMA shrink_memory  after manifest import?
    PRAGMA trusted_schema = false;


  
-- Other ideas:
-- 1) persistent prepared statements for most queries
-- 2) minimize functionality of system libsqlite to reduce footprint w/o
-- sacrificing performance.
--
-- Open questions:
-- 1) WAL or not?   Would speed up manifest import but not help most of the
-- time

-- Read through sqlite.org for the scattered best-practice
-- recommendations (optimize, vacuum)
-- see https://www.sqlite.org/threadsafe.html

CREATE TABLE instance_tbl (
  instance_id     INTEGER PRIMARY KEY,
  instance_name   CHAR(256) NOT NULL,
  instance_svc    INTEGER NOT NULL);  -> references service_tbl(svc_id)

CREATE INDEX instance_tbl_name ON instance_tbl (instance_svc, instance_name);

CREATE TABLE pg_tbl (
  pg_id           INTEGER PRIMARY KEY,
  pg_parent_id    INTEGER NOT NULL,
  pg_name         CHAR(256) NOT NULL,
  pg_type         CHAR(256) NOT NULL,
  pg_flags        INTEGER NOT NULL,
  pg_gen_id       INTEGER NOT NULL);

CREATE INDEX pg_tbl_name ON pg_tbl (pg_parent_id, pg_name);
CREATE INDEX pg_tbl_parent ON pg_tbl (pg_parent_id);
CREATE INDEX pg_tbl_type ON pg_tbl (pg_parent_id, pg_type);

CREATE TABLE prop_lnk_tbl (
  lnk_prop_id     INTEGER PRIMARY KEY,
  lnk_pg_id       INTEGER NOT NULL,    references pg_tbl(pg_id?)
  lnk_gen_id      INTEGER NOT NULL,   
  lnk_prop_name   CHAR(256) NOT NULL,
  lnk_prop_type   CHAR(2) NOT NULL,
  lnk_val_id      INTEGER);   references value_tbl(value_id)

CREATE INDEX prop_lnk_tbl_base ON prop_lnk_tbl (lnk_pg_id, lnk_gen_id);
CREATE INDEX prop_lnk_tbl_val ON prop_lnk_tbl (lnk_val_id);

CREATE TABLE schema_version (
  schema_version  INTEGER
);

CREATE TABLE service_tbl (
  svc_id          INTEGER PRIMARY KEY,
  svc_name        CHAR(256) NOT NULL
);

CREATE INDEX service_tbl_name ON service_tbl (svc_name);

CREATE TABLE snaplevel_lnk_tbl (
  snaplvl_level_id INTEGER NOT NULL,
  snaplvl_pg_id    INTEGER NOT NULL,
  snaplvl_pg_name  CHAR(256) NOT NULL,
  snaplvl_pg_type  CHAR(256) NOT NULL,
  snaplvl_pg_flags INTEGER NOT NULL,
  snaplvl_gen_id   INTEGER NOT NULL
);

CREATE INDEX snaplevel_lnk_tbl_id ON snaplevel_lnk_tbl (snaplvl_pg_id);
CREATE INDEX snaplevel_lnk_tbl_level ON snaplevel_lnk_tbl (snaplvl_level_id);

CREATE TABLE snaplevel_tbl (
  snap_id                 INTEGER NOT NULL,
  snap_level_num          INTEGER NOT NULL,
  snap_level_id           INTEGER NOT NULL,
  snap_level_service_id   INTEGER NOT NULL,
  snap_level_service      CHAR(256) NOT NULL,
  snap_level_instance_id  INTEGER NULL,
  snap_level_instance     CHAR(256) NULL
);

CREATE INDEX snaplevel_tbl_id ON snaplevel_tbl (snap_id);

CREATE TABLE snapshot_lnk_tbl (
  lnk_id          INTEGER PRIMARY KEY,
  lnk_inst_id     INTEGER NOT NULL,
  lnk_snap_name   CHAR(256) NOT NULL,
  lnk_snap_id     INTEGER NOT NULL
);

CREATE INDEX snapshot_lnk_tbl_name ON snapshot_lnk_tbl (lnk_inst_id, lnk_snap_name);
CREATE INDEX snapshot_lnk_tbl_snapid ON snapshot_lnk_tbl (lnk_snap_id);

--- Original

CREATE TABLE value_tbl (
  value_id        INTEGER NOT NULL,
  value_type      CHAR(1) NOT NULL,
  value_value     VARCHAR NOT NULL,
  value_order     INTEGER DEFAULT 0);

--- New:

-- primary key is (value_id, value_order); no rowid

CREATE TABLE value_tbl (
  value_id        INTEGER NOT NULL,
  value_type      CHAR(1) NOT NULL, -- add constraints to length == 1
  value_value     BLOB NOT NULL, -- constrain length based on value_type
  value_order     INTEGER DEFAULT 0
) STRICT;

-- types are:
--  b		boolean -> sqlite integer (0 or 1)
--  c		count   -> sqlite integer if < 2^63; 8-byte blob (in big-endian order) if >= 2^63
--  i		integer -> native SQLite integer 
--  o		opaque -> varying blob
--  s		string -> varying blob containing utf8 text
--  t		time

-- requires more convoluted code for fetching from value table but may be worth it in the on-disk space saving.

-- sqlite3_prepare_v2/v3 -> sqlite3_bind_* -> sqlite3_step() -> sqlite3_column_type() -> sqlite3_column_*() -> sqlite3_reset() -> sqlite3_finalize()

-- 	REP_PROTOCOL_TYPE_INVALID	= '\0',
-- 	REP_PROTOCOL_TYPE_BOOLEAN	= 'b',		-> 0 (false) or 1 (true)
-- 	REP_PROTOCOL_TYPE_COUNT		= 'c',		-> 64-bit BLOB (8 bytes)
-- 	REP_PROTOCOL_TYPE_INTEGER	= 'i',		-> INTEGER
-- 	REP_PROTOCOL_TYPE_TIME		= 't',		-> ??? not observed in practice
-- 	REP_PROTOCOL_TYPE_STRING	= 's',		-> TEXT
-- 	REP_PROTOCOL_TYPE_OPAQUE	= 'o',		-> BLOB
--
--	Compound types: 
-- 	REP_PROTOCOL_SUBTYPE_USTRING	= REP_PROTOCOL_TYPE_STRING|('u' << 8),
-- 	REP_PROTOCOL_SUBTYPE_URI	= REP_PROTOCOL_TYPE_STRING|('U' << 8),
-- 	REP_PROTOCOL_SUBTYPE_FMRI	= REP_PROTOCOL_TYPE_STRING|('f' << 8),
-- 
-- 	REP_PROTOCOL_SUBTYPE_HOST	= REP_PROTOCOL_TYPE_STRING|('h' << 8),
-- 	REP_PROTOCOL_SUBTYPE_HOSTNAME	= REP_PROTOCOL_TYPE_STRING|('N' << 8),
-- 	REP_PROTOCOL_SUBTYPE_NETADDR	= REP_PROTOCOL_TYPE_STRING|('n' << 8),
-- 	REP_PROTOCOL_SUBTYPE_NETADDR_V4	= REP_PROTOCOL_TYPE_STRING|('4' << 8),
-- 	REP_PROTOCOL_SUBTYPE_NETADDR_V6	= REP_PROTOCOL_TYPE_STRING|('6' << 8)

-- skip; instead define primary key as (value_id, value_order).

CREATE INDEX value_tbl_id ON value_tbl (value_id);	
							-----

-- Trigger fodder for value_tbl:

create table t (
  id integer not null,
  seq integer not null,
  type text not null,
  value any not null,
  primary key(id, seq)
) without rowid;



CREATE TRIGGER typecheck_insert
  BEFORE INSERT ON t
  FOR EACH ROW
    WHEN (SELECT count(*) from t WHERE t.id = NEW.id) > 0 AND
      ((SELECT t.type from t where t.id = NEW.id order by t.seq limit 1) != NEW.type)
    
    BEGIN
      SELECT RAISE(ROLLBACK, 'Mismatched type (insert)');
    END;

CREATE TRIGGER typecheck_update
  BEFORE UPDATE OF type ON t
  FOR EACH ROW
    WHEN (OLD.type != NEW.type) AND
    ((SELECT count(*) from t WHERE t.id = NEW.id) > 1)
    BEGIN
      SELECT RAISE(ROLLBACK, 'Mismatched type (update)');
    END;
