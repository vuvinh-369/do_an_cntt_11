"""Server-side connection to the first-aid schema in Supabase PostgreSQL."""
from contextlib import contextmanager

import psycopg
from psycopg.conninfo import conninfo_to_dict
from psycopg.rows import dict_row

from sqlite_store import KnowledgeStore, StoreError


def connect_postgres(dsn):
    try:
        options = conninfo_to_dict(dsn)
    except psycopg.ProgrammingError:
        raise StoreError('Chuỗi kết nối PostgreSQL chưa hợp lệ.', 503) from None
    options.setdefault('sslmode', 'require')
    options.setdefault('connect_timeout', '5')
    try:
        return psycopg.connect(**options, prepare_threshold=None)
    except psycopg.Error:
        raise StoreError(
            'Không kết nối được kho Supabase. Kiểm tra Session pooler, mật khẩu và kết nối mạng.',
            503,
        ) from None


class _KnowledgeQueries:
    def __init__(self, db):
        self.db = db

    def execute(self, query, params=()):
        return self.db.execute(query.replace('?', '%s'), params)

    def executemany(self, query, rows):
        with self.db.cursor() as cursor:
            cursor.executemany(query.replace('?', '%s'), rows)


class SupabaseKnowledgeStore(KnowledgeStore):
    backend_name = 'supabase'
    integrity_error = psycopg.IntegrityError

    def __init__(self, dsn, source_root, allow_source_demo=False):
        super().__init__(source_root, allow_source_demo)
        self.dsn = dsn

    @contextmanager
    def session(self, write=False):
        try:
            with connect_postgres(self.dsn) as db:
                db.row_factory = dict_row
                if not write:
                    db.execute('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY')
                db.execute('SET LOCAL search_path TO medgemma_kb, pg_catalog')
                db.execute("SET LOCAL statement_timeout TO '5s'")
                if write:
                    db.execute('LOCK TABLE knowledge_entries IN SHARE ROW EXCLUSIVE MODE')
                yield _KnowledgeQueries(db)
        except psycopg.errors.UndefinedTable:
            raise StoreError('Kho Supabase chưa được nhập. Hãy chạy lệnh nhập SQLite trước.', 503) from None
        except psycopg.OperationalError:
            raise StoreError('Kết nối kho Supabase bị gián đoạn. Hãy thử lại.', 503) from None
        except psycopg.errors.QueryCanceled:
            raise StoreError('Kho Supabase phản hồi quá chậm. Hãy thử lại.', 503) from None
        except psycopg.IntegrityError:
            raise StoreError('Thao tác không hợp lệ với trạng thái hiện tại của kho.', 409) from None

    def review_document(self, db, name):
        row = db.execute('SELECT content FROM review_documents WHERE name=?', (name,)).fetchone()
        return row['content'] if row else {}
