module std.database.test;
import std.database.util;
import std.stdio;

unittest {
    import std.database.sqlite;
    auto db = Database();
    auto con = db.connection("test.sqlite");
    //create_simple_table(con);
    string table = "t1";

    create_score_table(con, table);
    auto stmt = con.statement("select * from " ~ table);
    auto range = stmt.range();
    write_result(range);
}

unittest {
    // bind test
    import std.database.sqlite;
    auto db = Database();
    auto con = db.connection("test.sqlite");
    create_score_table(con, "t1");
    auto stmt = con.statement("select * from t1 where score > ?", 50);
    write_result(stmt.range());
}


unittest {
    // bind insert test
    import std.database.sqlite;
    auto db = Database();
    auto con = db.connection("test.sqlite");
    create_score_table(con, "score", false);

    auto stmt = con.statement("insert into score values(?,?)");
    stmt.execute("a",1);
    stmt.execute("b",2);
    stmt.execute("c",3);

    con.statement("select * from score").range().write_result();
}

unittest {
    // cascade interface idea
    import std.database.sqlite;

    writeln();
    writeln("cascade write_result test");
    Database()
        .connection("test.sqlite")
        .statement("select * from t1")
        .range()
        .write_result();
    writeln();
} 

unittest {
    import std.database.mysql;
    auto db = Database();
    try {
        Connection con = db.connection("");
    } catch (ConnectionException e) {
        writeln("ignoring can't connect");
    }
}

unittest {
    //auto db = Database(); // what happens here when no default arg on ctor?
    import std.database.oracle;
    auto db = Database("something");
}

unittest {
    import std.database.odbc;
    auto db = Database("something");
}

unittest {
    import std.database.poly;

    Database.register!(std.database.sqlite.database.Database)();
    Database.register!(std.database.mysql.database.Database)();

    auto db = Database("");
}



