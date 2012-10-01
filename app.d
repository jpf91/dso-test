module app;

import dso;
import std.stdio;

/*
 * Known problems
 * ==============
 * 
 * Problems that also happen with static runtime:
 * * Collateral exceptions don't work. Grep for @@FIXME@@: Collateral exceptions
 * * Some stuff should be moved out of dmain2.d: _d_assert, ...
 *   This functionality must be available even if the main app isn't written in D
 *   and dmain2.o is never linked in.
 * 
 * Problems that only happen with shared runtime:
 * * TLS section, __gshared and static data in shared libraries is not scanned by GC
 *   (stack seems to be working)
 * * Because of that a shared druntime/phobos will often crash after the first GC collection
 */



/**
 * Exception handling in local lib
 */
//----------------------------------------------------------------------
void test1()
{
    try
    {
        test1_helper();
    }
    catch(Exception e)
    {
        assert(e.msg == "Simple exception test");
    }
}

void test1_helper()
{
    throw new Exception("Simple exception test");
}

//----------------------

void test2()
{
    try
    {
        test2_helper1();
    }
    catch(Exception e)
    {
        assert(e.msg == "test2_helper1");
    }
}

void test2_helper1()
{
    try
    {
        test2_helper2();
    }
    catch(Exception e)
    {
        //@@FIXME@@: Collateral exceptions
        version(none)
        {
            assert(e.msg == "test2_helper3");
            assert(e.next && e.next.msg == "test2_helper2");
        }
    }
    finally
    {
        throw new Exception("test2_helper1");
    }
}

void test2_helper2()
{
    try
    {
        test2_helper3();
    }
    finally
    {
        throw new Exception("test2_helper2");
    }
    
}

void test2_helper3()
{
    throw new Exception("test2_helper3");
}

//----------------------------------------------------------------------


/**
 * Exception thrown in phobos, handled locally
 */
//----------------------------------------------------------------------

void test3()
{
    import std.conv;
    import std.exception;
    assertThrown(to!float("abc"));
}

//----------------------------------------------------------------------

/**
 * Exception thrown in application, handled in dso, rethrown in dso,
 * handled in local app
 */
//----------------------------------------------------------------------

void test4()
{
    //uses dso_test.di
    try
    {
        dso_test4(&test4_helper);
    }
    catch(Test4Exception e)
    {
        assert(e.mynum == 4);
    }
}

class LocalAppException : Exception
{
    this(string msg)
    {
        super(msg);
    }
}

void test4_helper()
{
    throw new LocalAppException("local app");
}
//----------------------------------------------------------------------


/**
 * ModuleInfo tests
 */
//----------------------------------------------------------------------

void test5()
{
    size_t dso_count = 0;
    size_t app_count = 0;
    size_t phobos_conv_count = 0;

    foreach(m; ModuleInfo)
    {
        if(m.name == "dso")
            dso_count++;
        if(m.name == "app")
            app_count++;
        if(m.name == "std.conv")
            phobos_conv_count++;
    }

    assert(dso_count == 1);
    assert(app_count == 1);
    assert(phobos_conv_count == 1);
}

/**
 * Test if DSO can see this module, itself and phobos
 */
void test6()
{
    dso_test6();
}
//----------------------------------------------------------------------


/**
 * Unit test tests
 */
//----------------------------------------------------------------------
bool run = false;

unittest
{
    import std.stdio;
    run = true;
}

void test7()
{
    assert(dso.run == true);
    assert(run == true);
}
//----------------------------------------------------------------------

/**
 * Static variables, gshared variables, tls variables
 */

void test8()
{
    assert(test8_helper() == 1);
    assert(test8_helper() == 2);
    assert(test8_helper() == 3);
    
    assert(dso_test8(&test8_helper) == 4);
    assert(test8_helper() == 5);
    assert(dso_test8(&test8_helper) == 6);
    assert(test8_helper() == 7);
}

size_t test8_helper()
{
    static int x = 0;
    return ++x;
}

void test9()
{
    assert(dso_test9() == 1);
    assert(dso_test9() == 2);
    assert(dso_test9() == 3);
    
    assert(dso_test9_helper() == 4);
    assert(dso_test9() == 5);
    assert(dso_test9_helper() == 6);
    assert(dso_test9() == 7);
}

void test10()
{
    assert(dso_test10() == 1);
    assert(dso_test10() == 2);
    assert(test10_tls == 2);
    test10_tls++;
    assert(dso_test10() == 4);

    import core.thread;
    auto t = new Thread(&test10_helper);
    t.start();
    t.join();
}

void test10_helper()
{
    assert(dso_test10() == 1);
    assert(dso_test10() == 2);
    assert(test10_tls == 2);
    test10_tls++;
    assert(dso_test10() == 4);
}

void test11()
{
    assert(dso_test11() == 1);
    assert(dso_test11() == 2);
    assert(test11_global == 2);
    test11_global++;
    assert(dso_test11() == 4);

    import core.thread;
    auto t = new Thread(&test11_helper);
    t.start();
    t.join();
}

void test11_helper()
{
    assert(dso_test11() == 5);
    assert(dso_test11() == 6);
    assert(test11_global == 6);
    test11_global++;
    assert(dso_test11() == 8);
}

/**
 * Object.factory
 * If ModuleInfos work it should work as well, but test it to be sure
 */
//----------------------------------------------------------------------

void test12()
{
    auto a = Object.factory("does.not.exist");
    assert(a is null);
    auto b = Object.factory("dso.test12_class1"); //in .di
    auto c = Object.factory("dso.test12_class2"); //not in .di
    assert(b !is null && b.toString() == "Hello from dso.test12_class1");
    assert(c !is null && c.toString() == "Hello from dso.test12_class2");
    
    auto d = dso_test12();
    assert(d !is null && d.toString() == "Hello from app.test12_local");
    auto e = cast(test12_local)d;
    assert(e !is null && e.a == 42);
}

class test12_local
{
    uint a = 42;
    override string toString()
    {
        return "Hello from app.test12_local";
    }
}

//----------------------------------------------------------------------

/**
 * GC tests
 */
//----------------------------------------------------------------------
class test13_local
{
    int a;
    
    void crashOnCollected2(string file = __FILE__, size_t line = __LINE__)
    {
        this.a++;
    }
}

void crashOnCollected(test13_local a, string file = __FILE__, size_t line = __LINE__)
{
    writef("%s:%s Crashing if reference was collected...", file, line);
    stdout.flush();
    a.crashOnCollected2();
    writeln(" OK");
}

test13_local test13_tls;
__gshared test13_local test13_global;

void test13()
{
    import core.memory;
    import core.thread;
    writeln("Running test13 GC tests (Note: these tests crash on error)");

    auto a = new test13_local(); //stack
    test13_tls = new test13_local();
    test13_global = new test13_local();
    for(int i = 0; i < 10; i++)
        GC.collect();

    a.crashOnCollected();
    test13_tls.crashOnCollected();
    test13_global.crashOnCollected();
    
    import core.thread;
    auto t = new Thread(&test13_helper);
    t.start();
    t.join();
    
    test13_helper2();
    for(int i = 0; i < 10; i++)
        GC.collect();
    test13_helper2();
    test13_helper2();
}

void test13_helper()
{
    import core.memory;

    test13_tls = new test13_local();
    for(int i = 0; i < 10; i++)
        GC.collect();
    
    test13_global.crashOnCollected();
    test13_tls.crashOnCollected();
}

void test13_helper2()
{
    static test13_local stat;
    if(stat is null)
        stat = new test13_local();

    stat.crashOnCollected();
}

//Same as test 13 in dso
void test14()
{
    dso_test14();
}

//----------------------------------------------------------------------

/**
 * Library unloading
 * Only valid for dynamically loaded dsos
 * 
 * TODO: Test if moduleinfos unregistered, GC sections unregistered,
 * static / tls / global data unregistered...
 */
//----------------------------------------------------------------------
//----------------------------------------------------------------------

void main()
{
    test1();
    test2();
    test3();
    test4();
    test5();
    test6();
    test7();
    test8();
    test9();
    test10();
    test11();
    test12();
    test13();
    test14();
}
