include(UseD)
add_d_conditions(VERSION Have_dstddb DEBUG )
include_directories(/home/dsby/code/dlang/github/dstddb/src/)
add_library(dstddb 
    /home/dsby/code/dlang/github/dstddb/src/std/database/allocator.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/array.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/common.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/exception.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/freetds/bindings.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/freetds/database.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/freetds/package.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/front.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/mysql/bindings.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/mysql/database.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/mysql/package.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/odbc/database.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/odbc/package.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/option.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/oracle/bindings.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/oracle/database.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/oracle/package.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/oracle/stubs.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/package.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/poly/database.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/poly/package.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/pool.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/postgres/bindings.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/postgres/database.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/postgres/package.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/reference/database.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/reference/package.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/resolver.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/rowset.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/source.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/sqlite/database.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/sqlite/package.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/testsuite.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/uri.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/util.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/variant.d
    /home/dsby/code/dlang/github/dstddb/src/std/database/vibehandler.d
)
target_link_libraries(dstddb  )
set_target_properties(dstddb PROPERTIES TEXT_INCLUDE_DIRECTORIES "")
