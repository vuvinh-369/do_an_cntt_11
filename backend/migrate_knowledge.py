"""Import the current SQLite knowledge base into Supabase PostgreSQL once."""
import argparse
from contextlib import closing
import json
import os
from pathlib import Path
import sqlite3
import sys

from local_config import load_config

BACKEND = Path(__file__).resolve().parent
DEFAULT_SQLITE = BACKEND / 'runtime' / 'knowledge_base' / 'so_cuu.sqlite3'
SCHEMA_SQL = BACKEND.parent / 'supabase' / 'medgemma_knowledge_schema.sql'
TABLES = (
    'metadata', 'injury_types', 'sources', 'source_files', 'knowledge_entries',
    'entry_injury_types', 'care_steps', 'warnings', 'entry_citations',
    'evidence_summaries', 'coverage_gaps', 'review_history',
)
REVIEW_DOCUMENTS = ('demo_publication', 'ket_qua_ra_soat')
IDENTITY_TABLES = ('knowledge_entries', 'care_steps', 'warnings', 'entry_citations', 'review_history')
IMPORT_TRIGGERS = (
    ('knowledge_entries', 'entries_guard'),
    *((name, 'reviewed_children') for name in ('entry_injury_types', 'care_steps', 'warnings', 'entry_citations')),
)


def read_snapshot(path):
    with closing(sqlite3.connect(path.resolve().as_uri() + '?mode=ro', uri=True)) as db:
        db.execute('BEGIN')
        if db.execute('PRAGMA quick_check').fetchone() != ('ok',) or db.execute('PRAGMA foreign_key_check').fetchone():
            raise ValueError('Kho SQLite có lỗi toàn vẹn dữ liệu.')
        tables = {}
        for table in TABLES:
            cursor = db.execute(f'SELECT * FROM "{table}"')
            tables[table] = (tuple(col[0] for col in cursor.description), cursor.fetchall())
        documents = {
            name: json.loads((path.parent / (name + '.json')).read_text(encoding='utf-8'))
            for name in REVIEW_DOCUMENTS
            if (path.parent / (name + '.json')).is_file()
        }
    return tables, documents


def import_snapshot(db, tables, documents):
    from psycopg import sql
    from psycopg.types.json import Jsonb

    # Serialize initial imports and leave any existing cloud data intact.
    db.execute("SELECT pg_advisory_xact_lock(hashtext('medgemma_kb_import'))")
    if db.execute("SELECT to_regnamespace('medgemma_kb')").fetchone()[0] is not None:
        raise ValueError('Schema medgemma_kb đã tồn tại. Dùng --check để kiểm tra dữ liệu đang dùng.')
    db.execute(SCHEMA_SQL.read_text(encoding='utf-8'))
    for table, trigger in IMPORT_TRIGGERS:
        db.execute(sql.SQL('ALTER TABLE {} DISABLE TRIGGER {}').format(
            sql.Identifier(table), sql.Identifier(trigger),
        ))
    with db.cursor() as cursor:
        for table, (columns, rows) in tables.items():
            if rows:
                cursor.executemany(
                    sql.SQL('INSERT INTO {} ({}) VALUES ({})').format(
                        sql.Identifier(table), sql.SQL(', ').join(map(sql.Identifier, columns)),
                        sql.SQL(', ').join(sql.Placeholder() for _ in columns),
                    ),
                    rows,
                )
        cursor.executemany(
            'INSERT INTO review_documents (name, content) VALUES (%s, %s)',
            [(name, Jsonb(document)) for name, document in documents.items()],
        )
    for table, trigger in IMPORT_TRIGGERS:
        db.execute(sql.SQL('ALTER TABLE {} ENABLE TRIGGER {}').format(
            sql.Identifier(table), sql.Identifier(trigger),
        ))
    db.execute("SELECT check_approval(e) FROM knowledge_entries e WHERE status IN ('approved', 'retired')")
    for table in IDENTITY_TABLES:
        db.execute(
            sql.SQL("SELECT setval(pg_get_serial_sequence(%s, 'id'),"
                    ' greatest(coalesce(max(id), 1), 1), coalesce(max(id), 0) >= 1) FROM {}')
            .format(sql.Identifier(table)),
            (table,),
        )
    for table, (columns, rows) in tables.items():
        actual = db.execute(sql.SQL('SELECT {} FROM {}').format(
            sql.SQL(', ').join(map(sql.Identifier, columns)), sql.Identifier(table),
        )).fetchall()
        if set(rows) != set(actual) or len(rows) != len(actual):
            raise ValueError(f'Dữ liệu bảng {table} khác bản SQLite. Hủy nhập.')
    if dict(db.execute('SELECT name, content FROM review_documents').fetchall()) != documents:
        raise ValueError('Hồ sơ rà soát khác bản gốc. Hủy nhập.')


def main():
    load_config()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sqlite', type=Path, default=os.environ.get('MEDGEMMA_KB_PATH', DEFAULT_SQLITE))
    parser.add_argument('--check', action='store_true', help='Check the existing Supabase catalog without importing')
    args = parser.parse_args()
    dsn = os.environ.get('MEDGEMMA_KB_DATABASE_URL', '').strip()
    if not dsn:
        parser.exit(1, 'Hãy điền MEDGEMMA_KB_DATABASE_URL trong backend/.env.local.\n')

    sys.path.insert(0, str(BACKEND / 'medgemma'))
    try:
        import psycopg
    except ImportError:
        parser.exit(1, 'Cài thư viện bằng: python -m pip install "psycopg[binary]==3.3.9"\n')
    from postgres_store import SupabaseKnowledgeStore, connect_postgres
    from sqlite_store import StoreError

    source_root = os.environ.get('MEDGEMMA_KB_SOURCE_ROOT') or BACKEND / 'runtime'
    try:
        if not args.check:
            tables, documents = read_snapshot(args.sqlite)
            with connect_postgres(dsn) as db:
                import_snapshot(db, tables, documents)
            print(f"Đã nhập {len(tables)} bảng SQLite và {len(documents)} hồ sơ rà soát JSON.")
        summary = SupabaseKnowledgeStore(dsn, source_root, allow_source_demo=True).summary()
    except (ValueError, StoreError, OSError, sqlite3.Error) as error:
        parser.exit(1, f'{error}\n')
    except psycopg.Error as error:
        parser.exit(1, f'PostgreSQL từ chối nhập dữ liệu (SQLSTATE {error.sqlstate or "unknown"}).\n')
    print(
        f"Supabase: {sum(summary['counts'].values())} hướng dẫn, "
        f"{summary['sources']} nguồn, {summary['published']} đã duyệt chuyên môn, "
        f"{summary['demo_published']} tham khảo demo."
    )


if __name__ == '__main__':
    main()
