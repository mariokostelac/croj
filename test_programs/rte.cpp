#include <cstdio>

int main() {
  int *a = new int[100];
  a[1<<30] = 0;
  return 0;
}
