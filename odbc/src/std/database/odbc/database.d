module std.database.odbc.database;
pragma(lib, "odbc");

import std.string;
import std.c.stdlib;
import std.conv;

import std.database.odbc.sql;
import std.database.odbc.sqltypes;
import std.database.odbc.sqlext;

public import std.database.exception;

import std.stdio;
import std.typecons;

import std.container.array;

import core.memory : GC;

//alias long SQLLEN;
//alias ubyte SQLULEN;

alias SQLINTEGER SQLLEN;
alias SQLUINTEGER SQLULEN;

struct Database {
    public:

        static Database create(string defaultURI) {
            return Database(defaultURI);
        }

        this(string defaultURI) {
            data_ = Data(defaultURI);
        }

        void showDrivers() {
            SQLUSMALLINT direction;

            SQLCHAR driver[256];
            SQLCHAR attr[256];
            SQLSMALLINT driver_ret;
            SQLSMALLINT attr_ret;
            SQLRETURN ret;

            direction = SQL_FETCH_FIRST;
            writeln("DRIVERS:");
            while(SQL_SUCCEEDED(ret = SQLDrivers(
                            data_.env, 
                            direction,
                            driver.ptr, 
                            driver.sizeof, 
                            &driver_ret,
                            attr.ptr, 
                            attr.sizeof, 
                            &attr_ret))) {
                direction = SQL_FETCH_NEXT;
                printf("%s - %s\n", driver.ptr, attr.ptr);
                if (ret == SQL_SUCCESS_WITH_INFO) printf("\tdata truncation\n");
            }
        }

    private:

        struct Payload {
            string defaultURI;
            SQLHENV env;

            this(string defaultURI_) {
                defaultURI = defaultURI_;
                check(
                        "SQLAllocHandle", 
                        SQLAllocHandle(
                            SQL_HANDLE_ENV, 
                            SQL_NULL_HANDLE,
                            &env));
                SQLSetEnvAttr(env, SQL_ATTR_ODBC_VERSION, cast(void *) SQL_OV_ODBC3, 0);
            }

            ~this() {
                writeln("odbc: closing database");
                if (!env) return;
                check("SQLFreeHandle", SQLFreeHandle(SQL_HANDLE_ENV, env));
                env = null;
            }

            this(this) { assert(false); }
            void opAssign(Database.Payload rhs) { assert(false); }
        }

        private alias RefCounted!(Payload, RefCountedAutoInitialize.no) Data;
        private Data data_;


}

struct Connection {
    alias Statement = .Statement;

    private struct Payload {
        Database db;
        string source;
        SQLHDBC con;
        bool connected;

        this(Database db_, string source_) {
            db = db_;
            source = source_;

            char[1024] outstr;
            SQLSMALLINT outstrlen;
            string DSN = "DSN=testdb";

            writeln("ODBC opening: ", source);

            SQLRETURN ret = SQLAllocHandle(SQL_HANDLE_DBC,db.data_.env,&con);
            if ((ret != SQL_SUCCESS) && (ret != SQL_SUCCESS_WITH_INFO)) {
                throw new DatabaseException("SQLAllocHandle error: " ~ to!string(ret));
            }

            string server = source;
            string un = "";
            string pw = "";

            check("SQLConnect", SQL_HANDLE_DBC, con, SQLConnect(
                        con,
                        cast(SQLCHAR*) toStringz(server),
                        SQL_NTS,
                        cast(SQLCHAR*) toStringz(un),
                        SQL_NTS,
                        cast(SQLCHAR*) toStringz(pw),
                        SQL_NTS));
            connected = true;
        }

        ~this() {
            writeln("ODBC closing ", source);
            if (connected) check("SQLDisconnect", SQLDisconnect(con));
            check("SQLFreeHandle", SQLFreeHandle(SQL_HANDLE_DBC, con));
        }

        this(this) { assert(false); }
        void opAssign(Connection.Payload rhs) { assert(false); }
    }

    private alias RefCounted!(Payload, RefCountedAutoInitialize.no) Data;
    private Data data_;

    package this(Database db, string source) {
        data_ = Data(db,source);
    }
}

struct Statement {
    alias Result = .Result;
    alias Range = .ResultRange;

    this(Connection con, string sql) {
        data_ = Data(con,sql);
        prepare();
        // must be able to detect binds in all DBs
        if (!data_.binds) execute();
    }

    this(T...) (Connection con, string sql, T args) {
        data_ = Data(con,sql);
        prepare();
        bindAll(args);
        execute();
    }

    string sql() {return data_.sql;}
    int columns() {return data_.columns;}
    int binds() {return data_.binds;}

    void bind(int n, int value) {
        writeln("input bind: n: ", n, ", value: ", value);

        Bind b;
        b.type = SQL_C_LONG;
        b.dbtype = SQL_INTEGER;
        b.size = SQLINTEGER.sizeof;
        b.allocSize = b.size;
        b.data = malloc(b.allocSize);
        inputBind(n, b);

        *(cast(SQLINTEGER*) data_.inputBind[n-1].data) = value;
    }

    void bind(int n, const char[] value){
        import core.stdc.string: strncpy;
        writeln("input bind: n: ", n, ", value: ", value);
        // no null termination needed

        Bind b;
        b.type = SQL_C_CHAR;
        b.dbtype = SQL_CHAR;
        b.size = cast(SQLSMALLINT) value.length;
        b.allocSize = b.size;
        b.data = malloc(b.allocSize);
        inputBind(n, b);

        strncpy(cast(char*) b.data, value.ptr, b.size);
    }

    private:

    void inputBind(int n, ref Bind bind) {
        data_.inputBind ~= bind;
        auto b = &data_.inputBind.back();

        check("SQLBindParameter", SQLBindParameter(
                    data_.stmt,
                    cast(SQLSMALLINT) n,
                    SQL_PARAM_INPUT,
                    b.type,
                    b.dbtype,
                    0,
                    0,
                    b.data,
                    b.allocSize,
                    null));
    }

    struct Payload {
        Connection con;
        string sql;
        SQLHSTMT stmt;
        bool hasRows;
        int columns;
        int binds;
        Array!Bind inputBind;

        this(Connection con_, string sql_) {
            con = con_;
            sql = sql_;
            check("SQLAllocHandle", SQLAllocHandle(SQL_HANDLE_STMT, con.data_.con, &stmt));
        }

        ~this() {
            for(int i = 0; i < inputBind.length; ++i) {
                free(inputBind[i].data);
            }
            if (stmt) check("SQLFreeHandle", SQLFreeHandle(SQL_HANDLE_STMT, stmt));
            // stmt = null? needed
        }

        this(this) { assert(false); }
        void opAssign(Statement.Payload rhs) { assert(false); }
    }

    private alias RefCounted!(Payload, RefCountedAutoInitialize.no) Data;
    private Data data_;

    void exec() {
        check("SQLExecDirect", SQLExecDirect(data_.stmt,cast(SQLCHAR*) toStringz(data_.sql), SQL_NTS));
    }

    void prepare() {
        //if (!data_.st)
        check("SQLPrepare", SQLPrepare(
                    data_.stmt,
                    cast(SQLCHAR*) toStringz(data_.sql),
                    SQL_NTS));

        SQLSMALLINT v;
        check("SQLNumParams", SQLNumParams(data_.stmt, &v));
        data_.binds = v;
        check("SQLNumResultCols", SQLNumResultCols (data_.stmt, &v));
        data_.columns = v;
        writeln("prepare info: binds: ", data_.binds, ", columns: ", data_.columns);
    }

    void execute() {
        SQLRETURN ret = SQLExecute(data_.stmt);
        check("SQLExecute()", SQL_HANDLE_STMT, data_.stmt, ret);
    }

    void bindAll(T...) (T args) {
        int col;
        foreach (arg; args) {
            bind(++col, arg);
        }
    }

    void reset() {
        //SQLCloseCursor
    }

}

static const nameSize = 256;

struct Describe {
    char[nameSize] name;
    SQLSMALLINT nameLen;
    SQLSMALLINT type;
    SQLULEN size; 
    SQLSMALLINT digits;
    SQLSMALLINT nullable;
    SQLCHAR* data;
    //SQLCHAR[256] data;
    SQLLEN datLen;
}

struct Bind {
    SQLSMALLINT type;
    SQLSMALLINT dbtype;
    //SQLCHAR* data[maxData];
    void* data;

    // apparently the crash problem
    //SQLULEN size; 
    //SQLULEN allocSize; 
    //SQLLEN len;

    SQLINTEGER size; 
    SQLINTEGER allocSize; 
    SQLINTEGER len;
}

struct Result {
    alias Range = .ResultRange;
    alias Row = .Row;


    static const maxData = 256;

    private struct Payload {
        Statement stmt;
        Array!Describe describe;
        Array!Bind bind;
        SQLRETURN status;

        this(Statement stmt_) {
            stmt = stmt_;
            build_describe();
            build_bind();
            next();
        }

        ~this() {
            for(int i = 0; i < bind.length; ++i) {
                free(bind[i].data);
            }
        }

        void build_describe() {
            describe.reserve(stmt.data_.columns);

            for(int i = 0; i < stmt.data_.columns; ++i) {
                describe ~= Describe();
                auto d = &describe.back();

                check("SQLDescribeCol", SQLDescribeCol(
                            stmt.data_.stmt,
                            cast(SQLUSMALLINT) (i+1),
                            cast(SQLCHAR *) d.name,
                            cast(SQLSMALLINT) nameSize,
                            &d.nameLen,
                            &d.type,
                            &d.size,
                            &d.digits,
                            &d.nullable));

                //writeln("NAME: ", d.name, ", type: ", d.type);
            }
        }

        void build_bind() {
            bind.reserve(stmt.data_.columns);

            for(int i = 0; i < stmt.data_.columns; ++i) {
                bind ~= Bind();
                auto b = &bind.back();
                auto d = &describe[i];

                b.size = d.size;
                b.allocSize = cast(SQLULEN) (b.size + 1);
                b.data = malloc(b.allocSize);
                GC.addRange(b.data, b.allocSize);

                // just INT and VARCHAR for now
                switch (d.type) {
                    case SQL_INTEGER:
                        b.type = SQL_C_LONG;
                        break;
                    case SQL_VARCHAR:
                        b.type = SQL_C_CHAR;
                        break;
                    default: 
                        throw new DatabaseException("bind error: type: " ~ to!string(d.type));
                }

                check("SQLBINDCol", SQLBindCol (
                            stmt.data_.stmt,
                            cast(SQLUSMALLINT) (i+1),
                            b.type,
                            b.data,
                            b.size,
                            &b.len));

                writeln(
                        "output bind: index: ", i,
                        ", type: ", b.type,
                        ", size: ", b.size,
                        ", allocSize: ", b.allocSize);
            }
        }

        bool next() {
            //writeln("SQLFetch");
            status = SQLFetch(stmt.data_.stmt);
            if (status == SQL_SUCCESS) {
                return true; 
            } else if (status == SQL_NO_DATA) {
                //writeln("NODATA");
                stmt.reset();
                return false;
            }
            check("SQLFetch", SQL_HANDLE_STMT, stmt.data_.stmt, status);
            return false;
        }

        this(this) { assert(false); }
        void opAssign(Statement.Payload rhs) { assert(false); }
    }

    private alias RefCounted!(Payload, RefCountedAutoInitialize.no) Data;
    private Data data_;

    int columns() {return data_.stmt.columns();}

    this(Statement stmt) {
        data_ = Data(stmt);
    }

    ResultRange range() {return ResultRange(this);}

    public bool start() {return data_.status == SQL_SUCCESS;}
    public bool next() {return data_.next();}
}

struct Value {
    package Bind* bind_;

    public this(Bind* bind) {
        bind_ = bind;
    }

    int get(T) () {
        return toInt();
    }

    // bounds check or covered?
    int toInt() {
        check(bind_.type, SQL_C_LONG);
        return *(cast(int*) bind_.data);
    }

    //inout(char)[]
    auto chars() {
        check(bind_.type, SQL_C_CHAR);
        import core.stdc.string: strlen;
        auto data = cast(char*) bind_.data;
        return data ? data[0 .. strlen(data)] : data[0..0];
    }

    void check(SQLSMALLINT a, SQLSMALLINT b) {
        if (a != b) throw new DatabaseException("type mismatch");
    }

}

// char*, string_ref?

struct Row {
    alias Value = .Value;

    private Result* result_;

    this(Result* result) {
        result_ = result;
    }

    int columns() {return result_.columns();}

    Value opIndex(size_t idx) {
        return Value(&result_.data_.bind[idx]);
    }
}

struct ResultRange {
    // implements a One Pass Range
    alias Row = .Row;

    private Result result_;
    private bool ok_;

    this(Result result) {
        result_ = result;
        ok_ = result_.start();
    }

    bool empty() {
        return !ok_;
    }

    Row front() {
        return Row(&result_);
    }

    void popFront() {
        ok_ = result_.next();
    }
}

void check(string msg, SQLRETURN ret) {
    writeln(msg, ":", ret);
    if (ret == SQL_SUCCESS || ret == SQL_SUCCESS_WITH_INFO) return;
    throw new DatabaseException("odbc error: " ~ msg);
}

void check(string msg, SQLSMALLINT handle_type, SQLHANDLE handle, SQLRETURN ret) {
    writeln(msg, ":", ret);
    if (ret == SQL_SUCCESS || ret == SQL_SUCCESS_WITH_INFO) return;
    throw_detail(handle, handle_type, msg);
}

void throw_detail(SQLHANDLE handle, SQLSMALLINT type, string msg) {
    SQLSMALLINT i = 0;
    SQLINTEGER native;
    SQLCHAR state[ 7 ];
    SQLCHAR text[256];
    SQLSMALLINT len;
    SQLRETURN ret;

    string error;
    error ~= msg;
    error ~= ": ";

    do {
        ret = SQLGetDiagRec(
                type,
                handle,
                ++i,
                cast(char*) state,
                &native,
                cast(char*)text,
                text.length,
                &len);

        if (SQL_SUCCEEDED(ret)) {
            auto s = text[0..len];
            writeln("error: ", s);
            //error =~ s;
            //writefln("%s:%ld:%ld:%s\n", state, i, native, text);
        }
    } while (ret == SQL_SUCCESS);
    throw new DatabaseException(error);
}

