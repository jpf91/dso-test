module dso;

import std.exception;

/**
 * DSO part for test 4
 */

class Test4Exception : Exception
{
    public this(string msg, int n)
    {
        mynum = n;
        super(msg);
    }
    public int mynum;
}

void dso_test4(void function() a)
{
    auto ex = collectException(a());
    assert(ex && ex.msg == "local app");
    assertThrown(a());
    try{a();}
    catch(Exception e){}
    finally {throw new Test4Exception("dso", 4);}
}

/**
 * DSO part for test 6
 */

void dso_test6()
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
 * DSO part for test 7
 */
bool run = false;
unittest
{
    run = true;
}

/**
 * DSO part for test 8
 */
size_t dso_test8(size_t function() a)
{
    return a();
}

/**
 * DSO part for test 9
 */
size_t dso_test9()
{
    static int x = 0;
    return ++x;
}

size_t dso_test9_helper()
{
    return dso_test9();
}

/**
 * DSO part for test 10
 */
size_t test10_tls;
size_t dso_test10()
{
    return ++test10_tls;
}

/**
 * DSO part for test 11
 */
__gshared size_t test11_global;
size_t dso_test11()
{
    return ++test11_global;
}

/**
 * DSO part for test 12
 */
 
class test12_class1
{
    override string toString()
    {
        return "Hello from dso.test12_class1";
    }
}

class test12_class2
{
    override string toString()
    {
        return "Hello from dso.test12_class2";
    }
}

Object dso_test12()
{
    auto a = Object.factory("app.test12_local");
    assert(a !is null && a.toString() == "Hello from app.test12_local");
    return a;
}



/**
 * DSO part for test 14
 */

import std.stdio;

class test14_dso
{
    int a;
    
    void crashOnCollected2(string file = __FILE__, size_t line = __LINE__)
    {
        this.a++;
    }
}

void crashOnCollected(test14_dso a, string file = __FILE__, size_t line = __LINE__)
{
    writef("%s:%s Crashing if reference was collected...", file, line);
    stdout.flush();
    a.crashOnCollected2();
    writeln(" OK");
}

test14_dso test14_tls;
__gshared test14_dso test14_global;

void dso_test14()
{
    import core.memory;
    import core.thread;
    writeln("Running test14 GC tests (Note: these tests crash on error)");

    auto a = new test14_dso(); //stack
    test14_tls = new test14_dso();
    test14_global = new test14_dso();
    for(int i = 0; i < 10; i++)
        GC.collect();

    a.crashOnCollected();
    test14_tls.crashOnCollected();
    test14_global.crashOnCollected();
    
    import core.thread;
    auto t = new Thread(&test14_helper);
    t.start();
    t.join();
    
    test14_helper2();
    for(int i = 0; i < 10; i++)
        GC.collect();
    test14_helper2();
    test14_helper2();
}

void test14_helper()
{
    import core.memory;

    test14_tls = new test14_dso();
    for(int i = 0; i < 10; i++)
        GC.collect();
    
    test14_global.crashOnCollected();
    test14_tls.crashOnCollected();
}

void test14_helper2()
{
    static test14_dso stat;
    if(stat is null)
        stat = new test14_dso();

    stat.crashOnCollected();
}
