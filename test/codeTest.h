//! This class does stuff
class testClass
{
  public:
    testClass() {} 
    const void foo(int a = 100)
      {
      int JUMP[] = {123,321,0};
      //test escaping special TeX characters
      JUMP[0] ^= JUMP[1] & JUMP[2];
      }
};
