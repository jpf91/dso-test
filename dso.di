module dso;

class Test4Exception : Exception
{
    public int mynum;
}

void dso_test4(void function() a);

void dso_test6();

bool run;

size_t dso_test8(size_t function() a);

size_t dso_test9();
size_t dso_test9_helper();

size_t test10_tls;
size_t dso_test10();

__gshared size_t test11_global;
size_t dso_test11();

class test12_class1{}
Object dso_test12();

void dso_test14();
